#import "MeasurementCache.h"
#import <os/lock.h>

static const NSUInteger kMaxCacheEntries = 256;

@implementation MeasurementCache {
  NSMutableDictionary<NSString *, NSValue *> *_cache;
  NSMutableArray<NSString *> *_order;
  os_unfair_lock _lock;
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
    _lock = OS_UNFAIR_LOCK_INIT;
  }
  return self;
}

- (nullable NSValue *)cachedSizeForKey:(NSString *)key {
  os_unfair_lock_lock(&_lock);
  NSValue *value = _cache[key];
  os_unfair_lock_unlock(&_lock);
  return value;
}

- (void)cacheSize:(CGSize)size forKey:(NSString *)key {
  os_unfair_lock_lock(&_lock);
  _cache[key] = [NSValue valueWithCGSize:size];
  [_order addObject:key];

  while (_order.count > kMaxCacheEntries) {
    NSString *oldKey = _order.firstObject;
    [_order removeObjectAtIndex:0];
    [_cache removeObjectForKey:oldKey];
  }
  os_unfair_lock_unlock(&_lock);
}

- (void)clearCache {
  os_unfair_lock_lock(&_lock);
  [_cache removeAllObjects];
  [_order removeAllObjects];
  os_unfair_lock_unlock(&_lock);
}

@end
