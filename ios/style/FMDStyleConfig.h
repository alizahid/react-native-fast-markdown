#import <UIKit/UIKit.h>

#import "FMDTextStyle.h"

NS_ASSUME_NONNULL_BEGIN

@interface FMDMentionVariant : NSObject
@property (nonatomic, readonly) NSRegularExpression *pattern;
@property (nonatomic, readonly, nullable) FMDTextStyle *style;
@end

/// Parsed stylesJson with cached instances per JSON string.
@interface FMDStyleConfig : NSObject

@property (nonatomic, readonly) CGFloat gap;
@property (nonatomic, readonly) CGFloat paddingLeft;
@property (nonatomic, readonly) CGFloat paddingRight;
@property (nonatomic, readonly) CGFloat paddingTop;
@property (nonatomic, readonly) CGFloat paddingBottom;
@property (nonatomic, readonly, nullable) UIColor *backgroundColor;

/// Ordered longest-pattern-first; a link whose URL matches becomes a mention.
@property (nonatomic, readonly) NSArray<FMDMentionVariant *> *mentionVariants;

+ (instancetype)configWithJson:(NSString *)json;

/// Raw JSON section for an element key (layout parsing).
- (nullable NSDictionary *)rawSectionFor:(NSString *)key;

/// User style for an element key (paragraph, h1..h6, bold, italic,
/// strikethrough, link, mention, inlineCode, superscript, subscript,
/// listItem, tableCell, codeBlock, blockQuote). Nil when not provided.
- (nullable FMDTextStyle *)textStyleFor:(NSString *)key;

/// Built-in default font size for a heading level 1-6 or body text (0).
- (CGFloat)fontSizeForHeadingLevel:(NSInteger)level;

@end

NS_ASSUME_NONNULL_END
