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
  CGFloat _fallbackWidth;
  CGFloat _fallbackHeight;
  NSURLSessionDataTask *_task;
  MarkdownPressableOverlayView *_pressOverlay;
}

- (instancetype)initWithURL:(NSURL *)url
              fallbackWidth:(CGFloat)fallbackWidth
             fallbackHeight:(CGFloat)fallbackHeight {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _url = url;
    _fallbackWidth = fallbackWidth > 0 ? fallbackWidth : 0;
    _fallbackHeight = fallbackHeight > 0 ? fallbackHeight : 200;

    self.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    self.clipsToBounds = YES;

    _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    // ScaleAspectFit so we never crop — the overlay frame should
    // already match the image's aspect ratio once the natural
    // size is known; the placeholder state is the only time we
    // could letterbox and that's fine.
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.clipsToBounds = YES;
    [self addSubview:_imageView];

    // Pressable overlay for tap handling. Transparent normally,
    // subtle dark tint on press. Fires our onPress block on
    // touch-up-inside with the best-known size at tap time.
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

- (void)layoutSubviews {
  [super layoutSubviews];
  _imageView.frame = self.bounds;
  _pressOverlay.frame = self.bounds;
}

#pragma mark - Sizing

- (CGSize)sizeThatFits:(CGSize)size {
  CGFloat availableWidth = size.width > 0 ? size.width : _fallbackWidth;
  CGSize cachedNatural =
      [[MarkdownImageSizeCache sharedCache]
          sizeForURLString:_url.absoluteString];

  if (cachedNatural.width > 0 && cachedNatural.height > 0 &&
      availableWidth > 0) {
    // Scale the natural size down to fit the available width while
    // preserving the aspect ratio. Don't scale up — a 100×100 image
    // stays 100×100 even if the container is wider, so tiny images
    // don't get unnaturally stretched.
    CGFloat scale =
        availableWidth < cachedNatural.width
            ? availableWidth / cachedNatural.width
            : 1.0;
    return CGSizeMake(ceil(cachedNatural.width * scale),
                      ceil(cachedNatural.height * scale));
  }

  // No cached size — use the fallback dimensions. Fallback width
  // is 0 when we want the layout to take whatever the container
  // gives us.
  CGFloat width = _fallbackWidth > 0 ? _fallbackWidth : availableWidth;
  return CGSizeMake(width, _fallbackHeight);
}

#pragma mark - Loading

- (void)loadImageIfNeeded {
  if (!_url) return;
  NSString *key = _url.absoluteString;

  UIImage *cached = [MarkdownSharedImageCache() objectForKey:key];
  if (cached) {
    _imageView.image = cached;
    self.backgroundColor = [UIColor clearColor];
    // Make sure the size cache knows about this one too — it
    // usually already does, but this is cheap and keeps invariants
    // simple.
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
          // Guard against stale callbacks if the URL changed under
          // us (we don't currently support that but it's cheap).
          if (![strongSelf->_url.absoluteString isEqualToString:key]) {
            return;
          }
          strongSelf->_imageView.image = image;
          strongSelf.backgroundColor = [UIColor clearColor];
          // Let the enclosing MarkdownView know it should
          // invalidate Yoga layout — the notification is posted
          // from MarkdownImageSizeCache on setSize:forURLString:
          // so we don't do it here explicitly.
        });
      }];
  [_task resume];
}

#pragma mark - Press

- (void)handlePressUp:(MarkdownPressableOverlayView *)sender {
  if (!_onPress) return;
  CGSize size =
      [[MarkdownImageSizeCache sharedCache]
          sizeForURLString:_url.absoluteString];
  if (size.width <= 0 || size.height <= 0) {
    size = CGSizeMake(_fallbackWidth, _fallbackHeight);
  }
  _onPress(_url, size);
}

@end
