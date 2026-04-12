#import "MarkdownImageSizeCache.h"

NSString *const MarkdownImageSizeCacheDidUpdateNotification =
    @"MarkdownImageSizeCacheDidUpdateNotification";

@implementation MarkdownImageSizeCache {
  NSCache<NSString *, NSValue *> *_cache;
}

+ (instancetype)sharedCache {
  static MarkdownImageSizeCache *shared;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    shared = [[MarkdownImageSizeCache alloc] init];
  });
  return shared;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _cache = [[NSCache alloc] init];
    _cache.name = @"MarkdownImageSizeCache";
    _cache.countLimit = 512;
  }
  return self;
}

- (CGSize)sizeForURLString:(NSString *)url {
  if (url.length == 0) return CGSizeZero;
  NSValue *value = [_cache objectForKey:url];
  return value ? [value CGSizeValue] : CGSizeZero;
}

- (void)setSize:(CGSize)size forURLString:(NSString *)url {
  if (url.length == 0) return;
  if (size.width <= 0 || size.height <= 0) return;

  NSValue *existing = [_cache objectForKey:url];
  if (existing && CGSizeEqualToSize([existing CGSizeValue], size)) {
    return;
  }
  [_cache setObject:[NSValue valueWithCGSize:size] forKey:url];

  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:MarkdownImageSizeCacheDidUpdateNotification
                      object:self];
  });
}

@end
