#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Parsed stylesJson with defaults. M1 covers the main container section and
/// default text sizing; per-element styling lands in M2.
@interface FMDStyleConfig : NSObject

@property (nonatomic, readonly) CGFloat gap;
@property (nonatomic, readonly) CGFloat paddingLeft;
@property (nonatomic, readonly) CGFloat paddingRight;
@property (nonatomic, readonly) CGFloat paddingTop;
@property (nonatomic, readonly) CGFloat paddingBottom;
@property (nonatomic, readonly, nullable) UIColor *backgroundColor;

/// Cached per JSON string.
+ (instancetype)configWithJson:(NSString *)json;

/// Font size for heading level 1-6, or body text (level 0).
- (CGFloat)fontSizeForHeadingLevel:(NSInteger)level;

@end

NS_ASSUME_NONNULL_END
