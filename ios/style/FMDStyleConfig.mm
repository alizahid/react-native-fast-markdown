#import "FMDStyleConfig.h"

@implementation FMDStyleConfig {
  NSDictionary *_main;
}

+ (instancetype)configWithJson:(NSString *)json {
  static NSCache<NSString *, FMDStyleConfig *> *cache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [NSCache new];
    cache.countLimit = 16;
  });

  NSString *key = json.length > 0 ? json : @"{}";
  FMDStyleConfig *cached = [cache objectForKey:key];
  if (cached != nil) {
    return cached;
  }
  FMDStyleConfig *config = [[FMDStyleConfig alloc] initWithJson:key];
  [cache setObject:config forKey:key];
  return config;
}

- (instancetype)initWithJson:(NSString *)json {
  if (self = [super init]) {
    NSDictionary *root = nil;
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (data != nil) {
      id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
      if ([parsed isKindOfClass:[NSDictionary class]]) {
        root = parsed;
      }
    }
    NSDictionary *main = [root[@"main"] isKindOfClass:[NSDictionary class]] ? root[@"main"] : @{};
    _main = main;

    _gap = [self floatFor:@"gap" fallback:12];
    _paddingLeft = [self floatFor:@"paddingLeft" fallback:0];
    _paddingRight = [self floatFor:@"paddingRight" fallback:0];
    _paddingTop = [self floatFor:@"paddingTop" fallback:0];
    _paddingBottom = [self floatFor:@"paddingBottom" fallback:0];
    _backgroundColor = [self colorFor:@"backgroundColor"];
  }
  return self;
}

- (CGFloat)floatFor:(NSString *)key fallback:(CGFloat)fallback {
  NSNumber *value = [_main[key] isKindOfClass:[NSNumber class]] ? _main[key] : nil;
  return value != nil ? value.doubleValue : fallback;
}

- (nullable UIColor *)colorFor:(NSString *)key {
  NSNumber *value = [_main[key] isKindOfClass:[NSNumber class]] ? _main[key] : nil;
  if (value == nil) {
    return nil;
  }
  uint32_t argb = value.unsignedIntValue;
  return [UIColor colorWithRed:((argb >> 16) & 0xFF) / 255.0
                         green:((argb >> 8) & 0xFF) / 255.0
                          blue:(argb & 0xFF) / 255.0
                         alpha:((argb >> 24) & 0xFF) / 255.0];
}

- (CGFloat)fontSizeForHeadingLevel:(NSInteger)level {
  switch (level) {
    case 1: return 32;
    case 2: return 26;
    case 3: return 22;
    case 4: return 18;
    case 5: return 16;
    case 6: return 14;
    default: return 16;
  }
}

@end
