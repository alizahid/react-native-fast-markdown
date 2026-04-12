#import "MarkdownImageView.h"

#import "MarkdownImageSizeCache.h"
#import "MarkdownPressableOverlayView.h"

// Breathing room around the image on all sides, matching the 2px
// padding the mention/spoiler overlays use around their text.
// The overlay fills a rect that extends kImagePadding beyond the
// image on every side, so the press highlight has a visible gap
// between its edge and the image content.
static const CGFloat kImagePadding = 2.0;

// Process-wide image cache of decoded UIImages. Separate from
// MarkdownImageSizeCache which only tracks sizes — this one holds
// the pixel data. NSCache evicts under memory pressure and is
// thread-safe. Count limit caps distinct URLs; cost limit caps
// total bytes.
static NSCache<NSString *, UIImage *> *MarkdownSharedImageCache(void) {
  static NSCache<NSString *, UIImage *> *cache;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    cache = [[NSCache alloc] init];
    cache.name = @"MarkdownImageDataCache";
    cache.countLimit = 128;
    cache.totalCostLimit = 32 * 1024 * 1024; // 32 MB
  });
  return cache;
}

@implementation MarkdownImageView {
  NSURL *_url;
  CGSize _propSize;
  CGFloat _fallbackWidth;
  CGFloat _fallbackHeight;
  NSURLSessionDataTask *_task;
  MarkdownPressableOverlayView *_pressOverlay;
}

- (instancetype)initWithURL:(NSURL *)url
                   propSize:(CGSize)propSize
              fallbackWidth:(CGFloat)fallbackWidth
             fallbackHeight:(CGFloat)fallbackHeight {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _url = url;
    _propSize =
        (propSize.width > 0 && propSize.height > 0) ? propSize : CGSizeZero;
    _fallbackWidth = fallbackWidth > 0 ? fallbackWidth : 0;
    _fallbackHeight = fallbackHeight > 0 ? fallbackHeight : 200;

    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = NO;

    _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    // ScaleAspectFill (CSS object-fit: cover) so the image always
    // fills the rect reserved for it. The sizeThatFits cascade
    // already aims for natural aspect ratio whenever we know it,
    // so the crop is only a few pixels when the supplied
    // dimensions and the actual bytes don't line up exactly.
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    _imageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    [self addSubview:_imageView];

    // Pressable overlay for tap handling. Transparent when idle,
    // subtle dark tint on press. Added AFTER the image view so it
    // sits in front and receives touches. The overlay extends
    // kImagePadding beyond the image on every side to give the
    // press highlight breathing room, matching mentions/spoilers.
    _pressOverlay =
        [[MarkdownPressableOverlayView alloc] initWithFrame:CGRectZero];
    _pressOverlay.normalColor = [UIColor clearColor];
    _pressOverlay.pressedColor = [UIColor colorWithWhite:0.0 alpha:0.18];
    [_pressOverlay addTarget:self
                      action:@selector(handlePressUp:)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_pressOverlay];

    [self loadImageIfNeeded];
  }
  return self;
}

- (void)dealloc {
  [_task cancel];
}

#pragma mark - Sizing

/// The "best-known" natural size for the current URL. Prop size
/// wins over discovered size wins over fallback. Returns
/// CGSizeZero only when we literally know nothing and no fallback
/// width/height was supplied either.
- (CGSize)bestKnownNaturalSize {
  if (_propSize.width > 0 && _propSize.height > 0) {
    return _propSize;
  }
  CGSize discovered =
      [[MarkdownImageSizeCache sharedCache]
          sizeForURLString:_url.absoluteString];
  if (discovered.width > 0 && discovered.height > 0) {
    return discovered;
  }
  CGFloat w = _fallbackWidth > 0 ? _fallbackWidth : 0;
  CGFloat h = _fallbackHeight > 0 ? _fallbackHeight : 0;
  return CGSizeMake(w, h);
}

/// Returns the rect (in local coordinates) that the image
/// overlay should occupy. The actual UIImageView sits inset by
/// kImagePadding inside this rect. When a natural size is known
/// the box matches that aspect ratio (scaled down to fit the
/// bounds if needed, never scaled up). When no natural size is
/// known the box covers the full bounds so the fallback
/// reservation still gets a proper overlay.
- (CGRect)imageBoxForBounds:(CGRect)bounds {
  CGFloat availableWidth = bounds.size.width;
  CGFloat availableHeight = bounds.size.height;
  if (availableWidth <= 0 || availableHeight <= 0) {
    return CGRectZero;
  }

  CGSize natural = [self bestKnownNaturalSize];
  if (natural.width > 0 && natural.height > 0) {
    CGFloat boxW = natural.width + kImagePadding * 2;
    CGFloat boxH = natural.height + kImagePadding * 2;
    if (boxW > availableWidth) {
      CGFloat scale = availableWidth / boxW;
      boxW = availableWidth;
      boxH = ceil(boxH * scale);
    }
    return CGRectMake(0, 0, boxW, boxH);
  }

  // No natural size — spread across the full bounds we were
  // given. The overlay's breathing room still comes from the
  // inset we apply to the image view in layoutSubviews.
  return CGRectMake(0, 0, availableWidth, availableHeight);
}

- (CGSize)sizeThatFits:(CGSize)size {
  CGFloat availableWidth = size.width > 0 ? size.width : _fallbackWidth;
  CGSize natural = [self bestKnownNaturalSize];

  // Nothing known — use the raw fallback dimensions directly.
  if (natural.width <= 0 || natural.height <= 0 || availableWidth <= 0) {
    CGFloat w = _fallbackWidth > 0 ? _fallbackWidth : availableWidth;
    return CGSizeMake(w, _fallbackHeight);
  }

  // With a natural size, mirror imageBoxForBounds: — total box is
  // natural + 2*padding, scaled down proportionally if wider than
  // the available space. Return that as the preferred size.
  CGFloat boxW = natural.width + kImagePadding * 2;
  CGFloat boxH = natural.height + kImagePadding * 2;
  if (boxW > availableWidth) {
    CGFloat scale = availableWidth / boxW;
    boxW = availableWidth;
    boxH = boxH * scale;
  }
  return CGSizeMake(ceil(boxW), ceil(boxH));
}

- (void)layoutSubviews {
  [super layoutSubviews];

  // MarkdownSegmentStackView stretches every block to the full
  // container width, so bounds.width may be larger than the
  // natural image size. We manually pick a box that matches the
  // image's natural aspect ratio (left-aligned) and lay the
  // overlay + image view out inside it — not across the full
  // stretched bounds.
  CGRect box = [self imageBoxForBounds:self.bounds];
  _pressOverlay.frame = box;
  _imageView.frame = CGRectInset(box, kImagePadding, kImagePadding);
}

#pragma mark - Loading

- (void)loadImageIfNeeded {
  if (!_url) return;
  NSString *key = _url.absoluteString;

  UIImage *cached = [MarkdownSharedImageCache() objectForKey:key];
  if (cached) {
    _imageView.image = cached;
    // Make sure the discovered-size cache knows about this one too —
    // it usually already does, but setSize short-circuits when the
    // value is unchanged so this is effectively free.
    [[MarkdownImageSizeCache sharedCache] setSize:cached.size
                                     forURLString:key];
    return;
  }

  NSURL *url = _url;
  __weak __typeof(self) weakSelf = self;
  _task = [[NSURLSession sharedSession]
        dataTaskWithURL:url
      completionHandler:^(NSData *data, NSURLResponse *response,
                          NSError *error) {
        if (error || !data) return;
        UIImage *image = [UIImage imageWithData:data];
        if (!image) return;

        NSUInteger cost = data.length;
        [MarkdownSharedImageCache() setObject:image forKey:key cost:cost];
        [[MarkdownImageSizeCache sharedCache] setSize:image.size
                                         forURLString:key];

        dispatch_async(dispatch_get_main_queue(), ^{
          __strong __typeof(weakSelf) strongSelf = weakSelf;
          if (!strongSelf) return;
          if (![strongSelf->_url.absoluteString isEqualToString:key]) {
            return;
          }
          strongSelf->_imageView.image = image;
          // If the caller supplied a propSize we don't need to
          // trigger a re-measure — layout is already correct.
          // For the discovered path, MarkdownImageSizeCache's
          // notification fires the re-measure for us.
        });
      }];
  [_task resume];
}

#pragma mark - Press

- (void)handlePressUp:(MarkdownPressableOverlayView *)sender {
  if (!_onPress) return;
  CGSize size = [self bestKnownNaturalSize];
  if (size.width <= 0 || size.height <= 0) {
    size = CGSizeMake(_fallbackWidth, _fallbackHeight);
  }
  _onPress(_url, size);
}

@end
