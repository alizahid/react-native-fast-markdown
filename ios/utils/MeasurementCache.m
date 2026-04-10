#import "MeasurementCache.h"

static const NSUInteger kMaxCacheEntries = 256;

@implementation MeasurementCache {
  NSMutableDictionary<NSString *, NSValue *> *_cache;
  NSMutableArray<NSString *> *_order;
}

+ (instancetype)shared {
  static MeasurementCache *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[MeasurementCache alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _cache = [NSMutableDictionary new];
    _order = [NSMutableArray new];
  }
  return self;
}

- (nullable NSValue *)cachedSizeForKey:(NSString *)key {
  return _cache[key];
}

- (void)cacheSize:(CGSize)size forKey:(NSString *)key {
  _cache[key] = [NSValue valueWithCGSize:size];
  [_order addObject:key];

  while (_order.count > kMaxCacheEntries) {
    NSString *oldKey = _order.firstObject;
    [_order removeObjectAtIndex:0];
    [_cache removeObjectForKey:oldKey];
  }
}

- (void)clearCache {
  [_cache removeAllObjects];
  [_order removeAllObjects];
}

@end
