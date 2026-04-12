#import "MarkdownImageView.h"

// Process-wide image cache. NSCache evicts under memory pressure
// and is thread-safe. Count limit caps how many distinct URLs we
// remember; cost limit caps the total bytes of decoded images.
static NSCache<NSString *, UIImage *> *MarkdownSharedImageCache(void) {
  static NSCache<NSString *, UIImage *> *cache;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    cache = [[NSCache alloc] init];
    cache.name = @"MarkdownImageCache";
    cache.countLimit = 128;
    cache.totalCostLimit = 32 * 1024 * 1024; // 32 MB
  });
  return cache;
}

@implementation MarkdownImageView {
  NSURL *_url;
  NSURLSessionDataTask *_task;
}

- (instancetype)initWithURL:(NSURL *)url height:(CGFloat)height {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _url = url;
    _desiredHeight = height > 0 ? height : 200;

    self.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    self.clipsToBounds = YES;

    _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    [self addSubview:_imageView];

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
}

- (CGSize)sizeThatFits:(CGSize)size {
  return CGSizeMake(size.width, _desiredHeight);
}

#pragma mark - Loading

- (void)loadImageIfNeeded {
  if (!_url) return;

  NSString *key = _url.absoluteString;
  UIImage *cached = [MarkdownSharedImageCache() objectForKey:key];
  if (cached) {
    _imageView.image = cached;
    self.backgroundColor = [UIColor clearColor];
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

        dispatch_async(dispatch_get_main_queue(), ^{
          __strong __typeof(weakSelf) strongSelf = weakSelf;
          if (!strongSelf) return;
          // Ignore stale callbacks if the URL changed (we only
          // support one URL per view for now, but the guard is
          // cheap and matches typical SDWebImage patterns).
          if (![strongSelf->_url.absoluteString isEqualToString:key]) {
            return;
          }
          strongSelf->_imageView.image = image;
          strongSelf.backgroundColor = [UIColor clearColor];
        });
      }];
  [_task resume];
}

@end
