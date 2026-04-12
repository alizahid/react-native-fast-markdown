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
  CGFloat _maxWidth;
  CGFloat _maxHeight;
  NSString *_objectFit;
  NSURLSessionDataTask *_task;
  MarkdownPressableOverlayView *_pressOverlay;
}

- (instancetype)initWithURL:(NSURL *)url
                   propSize:(CGSize)propSize
              fallbackWidth:(CGFloat)fallbackWidth
             fallbackHeight:(CGFloat)fallbackHeight
                   maxWidth:(CGFloat)maxWidth
                  maxHeight:(CGFloat)maxHeight
                  objectFit:(NSString *)objectFit {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _url = url;
    _propSize =
        (propSize.width > 0 && propSize.height > 0) ? propSize : CGSizeZero;
    _fallbackWidth = fallbackWidth > 0 ? fallbackWidth : 0;
    _fallbackHeight = fallbackHeight > 0 ? fallbackHeight : 200;
    _maxWidth = maxWidth > 0 ? maxWidth : 0;
    _maxHeight = maxHeight > 0 ? maxHeight : 0;
    _objectFit = [objectFit copy];

    // Pure layout container — no background, no clipping, no
    // corner radius. All visual styling (background, border,
    // radius) comes from the enclosing MarkdownBlockView so the
    // user's `image: { ... }` styles apply untouched.
    self.backgroundColor = [UIColor clearColor];

    _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    // Match the content mode to the caller's objectFit choice.
    // Only "cover" produces cropping — everything else (nil,
    // "contain", unknown) preserves the full image. The block
    // sizeThatFits cascade already sizes the block to match the
    // desired aspect ratio, so for the default case there's
    // nothing to crop or letterbox either way.
    _imageView.contentMode = [_objectFit isEqualToString:@"cover"]
                                 ? UIViewContentModeScaleAspectFill
                                 : UIViewContentModeScaleAspectFit;
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

+ (CGSize)blockSizeForNaturalSize:(CGSize)natural
                   availableWidth:(CGFloat)availableWidth
                         maxWidth:(CGFloat)maxWidth
                        maxHeight:(CGFloat)maxHeight
                        objectFit:(NSString *)objectFit {
  if (natural.width <= 0 || natural.height <= 0) return CGSizeZero;

  // With `cover` and BOTH max constraints set the block is sized
  // to the max box exactly — the image inside is scaled to fill
  // via UIViewContentModeScaleAspectFill, cropping whatever
  // overflows. With only one max constraint (or with `contain`
  // / nil objectFit) the block keeps the natural aspect ratio
  // scaled to fit within whichever constraints are present.
  BOOL cover = [objectFit isEqualToString:@"cover"];
  CGFloat w;
  CGFloat h;
  if (cover && maxWidth > 0 && maxHeight > 0) {
    w = maxWidth;
    h = maxHeight;
  } else {
    w = natural.width;
    h = natural.height;
    CGFloat scale = 1.0;
    if (maxWidth > 0 && w > maxWidth) {
      scale = MIN(scale, maxWidth / w);
    }
    if (maxHeight > 0 && h > maxHeight) {
      scale = MIN(scale, maxHeight / h);
    }
    w *= scale;
    h *= scale;
  }

  // Always clamp to the container's available width — that's a
  // hard layout constraint, not a style preference. Preserves
  // the current aspect ratio (which may already differ from the
  // natural one thanks to `cover`).
  if (availableWidth > 0 && w > availableWidth) {
    CGFloat s = availableWidth / w;
    w *= s;
    h *= s;
  }

  return CGSizeMake(ceil(w), ceil(h));
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

  return [MarkdownImageView blockSizeForNaturalSize:natural
                                     availableWidth:availableWidth
                                           maxWidth:_maxWidth
                                          maxHeight:_maxHeight
                                          objectFit:_objectFit];
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
