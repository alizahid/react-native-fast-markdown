#import "MarkdownImageSizeCache.h"

NSString *const MarkdownImageSizeCacheDidUpdateNotification =
    @"MarkdownImageSizeCacheDidUpdateNotification";

@implementation MarkdownImageSizeCache {
  // Authoritative sizes supplied via the `images` prop. Checked
  // first on reads; never overwritten by discovered sizes.
  NSCache<NSString *, NSValue *> *_propCache;
  // Sizes discovered from completed downloads. Used as a fallback
  // when no prop entry exists.
  NSCache<NSString *, NSValue *> *_discoveredCache;
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
    _propCache = [[NSCache alloc] init];
    _propCache.name = @"MarkdownImageSizeCache.prop";
    _propCache.countLimit = 512;

    _discoveredCache = [[NSCache alloc] init];
    _discoveredCache.name = @"MarkdownImageSizeCache.discovered";
    _discoveredCache.countLimit = 512;
  }
  return self;
}

- (CGSize)sizeForURLString:(NSString *)url {
  if (url.length == 0) return CGSizeZero;
  NSValue *prop = [_propCache objectForKey:url];
  if (prop) return [prop CGSizeValue];
  NSValue *discovered = [_discoveredCache objectForKey:url];
  return discovered ? [discovered CGSizeValue] : CGSizeZero;
}

- (void)setPropSize:(CGSize)size forURLString:(NSString *)url {
  if (url.length == 0) return;
  if (size.width <= 0 || size.height <= 0) return;

  NSValue *existing = [_propCache objectForKey:url];
  if (existing && CGSizeEqualToSize([existing CGSizeValue], size)) {
    return;
  }
  [_propCache setObject:[NSValue valueWithCGSize:size] forKey:url];
  [self postDidUpdate];
}

- (void)setSize:(CGSize)size forURLString:(NSString *)url {
  if (url.length == 0) return;
  if (size.width <= 0 || size.height <= 0) return;

  // Authoritative entries win — once the caller has supplied
  // dimensions via the `images` prop, the discovered tier is
  // irrelevant for layout. Skipping the write also means the
  // did-update notification isn't posted, so there's no spurious
  // re-measure when the downloaded image's natural size differs
  // slightly from what was declared.
  if ([_propCache objectForKey:url]) {
    return;
  }

  NSValue *existing = [_discoveredCache objectForKey:url];
  if (existing && CGSizeEqualToSize([existing CGSizeValue], size)) {
    return;
  }
  [_discoveredCache setObject:[NSValue valueWithCGSize:size] forKey:url];
  [self postDidUpdate];
}

- (void)postDidUpdate {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:MarkdownImageSizeCacheDidUpdateNotification
                      object:self];
  });
}

@end
