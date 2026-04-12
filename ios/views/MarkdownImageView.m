#import "MarkdownImageView.h"

#import "MarkdownImageSizeCache.h"
#import "MarkdownPressableOverlayView.h"

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

    // Pure layout container — no background, no clipping, no
    // corner radius. All visual styling (background, border,
    // radius) comes from the enclosing MarkdownBlockView so the
    // user's `image: { ... }` styles apply untouched.
    self.backgroundColor = [UIColor clearColor];

    _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    // ScaleAspectFill (CSS object-fit: cover) so the image always
    // fills the rect reserved for it. The block's sizeThatFits
    // cascade already aims for the natural aspect ratio whenever
    // we know it, so cropping is at most a few pixels when the
    // declared dimensions don't exactly match the image bytes.
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    _imageView.backgroundColor = [UIColor clearColor];
    [self addSubview:_imageView];

    // Press overlay sits as a sibling above the image view at the
    // exact same frame. The wrapper has no background or styling
    // of its own, so the overlay can't hijack any style the
    // caller applied via `image: { ... }` — the block wraps the
    // image tightly and the overlay only shows a dark tint on
    // press, covering the image content without any inset.
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

- (CGSize)sizeThatFits:(CGSize)size {
  CGFloat availableWidth = size.width > 0 ? size.width : _fallbackWidth;
  CGSize natural = [self bestKnownNaturalSize];

  // Nothing known — use the raw fallback dimensions directly so
  // the enclosing block still reserves sensible space.
  if (natural.width <= 0 || natural.height <= 0 || availableWidth <= 0) {
    CGFloat w = _fallbackWidth > 0 ? _fallbackWidth : availableWidth;
    return CGSizeMake(w, _fallbackHeight);
  }

  // Return the natural size, scaled proportionally down only if
  // wider than the available space. Never scale up — tiny
  // images keep their natural size. No extra padding: the image
  // sits flush inside the block's content box so user-supplied
  // borders / corner radii wrap the image tightly.
  CGFloat w = natural.width;
  CGFloat h = natural.height;
  if (w > availableWidth) {
    CGFloat scale = availableWidth / w;
    w = availableWidth;
    h = h * scale;
  }
  return CGSizeMake(ceil(w), ceil(h));
}

- (void)layoutSubviews {
  [super layoutSubviews];

  // Image view and press overlay both fill the wrapper's bounds
  // exactly — no inset. The enclosing MarkdownBlockView hugs
  // the image's natural size, so the bounds already match what
  // the caller's style (bg, border, radius) should wrap.
  _imageView.frame = self.bounds;
  _pressOverlay.frame = self.bounds;
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
