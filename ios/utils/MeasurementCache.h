#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MeasurementCache : NSObject

+ (instancetype)shared;

- (nullable NSValue *)cachedSizeForKey:(NSString *)key;
- (void)cacheSize:(CGSize)size forKey:(NSString *)key;
- (void)clearCache;

@end

NS_ASSUME_NONNULL_END
