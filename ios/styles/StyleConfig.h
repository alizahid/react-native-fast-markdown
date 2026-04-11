#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarkdownElementStyle : NSObject

// Text properties
@property (nonatomic, strong, nullable) UIFont *font;
@property (nonatomic, strong, nullable) UIColor *color;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, copy, nullable) NSString *fontWeight;
@property (nonatomic, copy, nullable) NSString *fontStyle;
@property (nonatomic, copy, nullable) NSString *fontFamily;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, copy, nullable) NSString *textDecorationLine;
@property (nonatomic, copy, nullable) NSString *textAlign;

// View (container) properties
@property (nonatomic, strong, nullable) UIColor *backgroundColor;

// Padding
@property (nonatomic, assign) CGFloat padding;
@property (nonatomic, assign) CGFloat paddingHorizontal;
@property (nonatomic, assign) CGFloat paddingVertical;
@property (nonatomic, assign) CGFloat paddingTop;
@property (nonatomic, assign) CGFloat paddingBottom;
@property (nonatomic, assign) CGFloat paddingLeft;
@property (nonatomic, assign) CGFloat paddingRight;

// Margin
@property (nonatomic, assign) CGFloat marginVertical;

// Border
@property (nonatomic, strong, nullable) UIColor *borderColor;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, assign) CGFloat borderRadius;
@property (nonatomic, strong, nullable) UIColor *borderLeftColor;
@property (nonatomic, assign) CGFloat borderLeftWidth;
@property (nonatomic, strong, nullable) UIColor *borderRightColor;
@property (nonatomic, assign) CGFloat borderRightWidth;
@property (nonatomic, strong, nullable) UIColor *borderTopColor;
@property (nonatomic, assign) CGFloat borderTopWidth;
@property (nonatomic, strong, nullable) UIColor *borderBottomColor;
@property (nonatomic, assign) CGFloat borderBottomWidth;

// Size
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat width;

// Computed padding insets
- (UIEdgeInsets)resolvedPaddingInsets;

// Applies ViewStyle properties to a UIView's layer and backgroundColor.
// Use this for containers that need backgroundColor, borderRadius,
// borderWidth, and borderColor support.
- (void)applyViewStyleToView:(UIView *)view;

- (UIFont *)resolvedFont;

/// Resolves a font by cascading from a base font. Properties set on
/// this style override; unset properties inherit from baseFont.
- (nullable UIFont *)resolvedFontWithBase:(nullable UIFont *)baseFont;

@end

@interface StyleConfig : NSObject

/// Base text style — applies to all text unless overridden
@property (nonatomic, strong) MarkdownElementStyle *text;

@property (nonatomic, strong) MarkdownElementStyle *heading1;
@property (nonatomic, strong) MarkdownElementStyle *heading2;
@property (nonatomic, strong) MarkdownElementStyle *heading3;
@property (nonatomic, strong) MarkdownElementStyle *heading4;
@property (nonatomic, strong) MarkdownElementStyle *heading5;
@property (nonatomic, strong) MarkdownElementStyle *heading6;
@property (nonatomic, strong) MarkdownElementStyle *paragraph;
@property (nonatomic, strong) MarkdownElementStyle *strong;
@property (nonatomic, strong) MarkdownElementStyle *emphasis;
@property (nonatomic, strong) MarkdownElementStyle *strikethrough;
@property (nonatomic, strong) MarkdownElementStyle *underline;
@property (nonatomic, strong) MarkdownElementStyle *code;
@property (nonatomic, strong) MarkdownElementStyle *codeBlock;
@property (nonatomic, strong) MarkdownElementStyle *link;
@property (nonatomic, strong) MarkdownElementStyle *blockquote;
@property (nonatomic, strong) MarkdownElementStyle *listItem;
@property (nonatomic, strong) MarkdownElementStyle *listBullet;

// Tables
@property (nonatomic, strong) MarkdownElementStyle *table;
@property (nonatomic, strong) MarkdownElementStyle *tableRow;
@property (nonatomic, strong) MarkdownElementStyle *tableHeaderRow;
@property (nonatomic, strong) MarkdownElementStyle *tableCell;
@property (nonatomic, strong) MarkdownElementStyle *tableHeaderCell;

@property (nonatomic, strong) MarkdownElementStyle *thematicBreak;
@property (nonatomic, strong) MarkdownElementStyle *image;
@property (nonatomic, strong) MarkdownElementStyle *mention;
@property (nonatomic, strong) MarkdownElementStyle *spoiler;

+ (instancetype)fromJSON:(NSString *)json;

- (MarkdownElementStyle *)styleForHeadingLevel:(NSInteger)level;

@end

NS_ASSUME_NONNULL_END
