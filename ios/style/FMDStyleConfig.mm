#import "FMDStyleConfig.h"

@implementation FMDMentionVariant

- (instancetype)initWithPattern:(NSRegularExpression *)pattern
                          style:(nullable FMDTextStyle *)style {
  if (self = [super init]) {
    _pattern = pattern;
    _style = style;
  }
  return self;
}

@end

@implementation FMDStyleConfig {
  NSDictionary *_root;
  NSMutableDictionary<NSString *, id> *_textStyles;
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
    _root = root ?: @{};
    _textStyles = [NSMutableDictionary new];

    NSDictionary *main = [_root[@"main"] isKindOfClass:[NSDictionary class]] ? _root[@"main"] : @{};
    _gap = [self floatFrom:main key:@"gap" fallback:12];
    _paddingLeft = [self floatFrom:main key:@"paddingLeft" fallback:0];
    _paddingRight = [self floatFrom:main key:@"paddingRight" fallback:0];
    _paddingTop = [self floatFrom:main key:@"paddingTop" fallback:0];
    _paddingBottom = [self floatFrom:main key:@"paddingBottom" fallback:0];
    _backgroundColor = [FMDTextStyle colorFromJson:main[@"backgroundColor"]];

    NSMutableArray<FMDMentionVariant *> *variants = [NSMutableArray new];
    NSDictionary *mention =
        [_root[@"mention"] isKindOfClass:[NSDictionary class]] ? _root[@"mention"] : nil;
    NSArray *variantPairs =
        [mention[@"variants"] isKindOfClass:[NSArray class]] ? mention[@"variants"] : @[];
    for (id pair in variantPairs) {
      if (![pair isKindOfClass:[NSArray class]] || [pair count] != 2) {
        continue;
      }
      NSString *patternString = [pair[0] isKindOfClass:[NSString class]] ? pair[0] : nil;
      if (patternString == nil) {
        continue;
      }
      NSRegularExpression *pattern =
          [NSRegularExpression regularExpressionWithPattern:patternString options:0 error:nil];
      if (pattern == nil) {
        continue;
      }
      [variants addObject:[[FMDMentionVariant alloc]
                              initWithPattern:pattern
                                        style:[FMDTextStyle fromJson:pair[1]]]];
    }
    _mentionVariants = variants;
  }
  return self;
}

- (CGFloat)floatFrom:(NSDictionary *)dict key:(NSString *)key fallback:(CGFloat)fallback {
  NSNumber *value = [dict[key] isKindOfClass:[NSNumber class]] ? dict[key] : nil;
  return value != nil ? value.doubleValue : fallback;
}

- (nullable FMDTextStyle *)textStyleFor:(NSString *)key {
  @synchronized(self) {
    id cached = _textStyles[key];
    if (cached != nil) {
      return cached == NSNull.null ? nil : cached;
    }
    FMDTextStyle *style = [FMDTextStyle fromJson:_root[key]];
    _textStyles[key] = style ?: (id)NSNull.null;
    return style;
  }
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
