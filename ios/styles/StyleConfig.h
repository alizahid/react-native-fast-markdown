#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarkdownElementStyle : NSObject

// MARK: - Text properties (TextStyle)

@property (nonatomic, strong, nullable) UIColor *color;
@property (nonatomic, copy, nullable) NSString *fontFamily;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, copy, nullable) NSString *fontStyle;
@property (nonatomic, copy, nullable) NSString *fontWeight;
@property (nonatomic, assign) CGFloat letterSpacing;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, copy, nullable) NSString *textAlign;
@property (nonatomic, strong, nullable) UIColor *textDecorationColor;
@property (nonatomic, copy, nullable) NSString *textDecorationLine;
@property (nonatomic, copy, nullable) NSString *textDecorationStyle;

// MARK: - View properties (ViewStyle)

@property (nonatomic, strong, nullable) UIColor *backgroundColor;

// Layout
@property (nonatomic, assign) CGFloat gap;
@property (nonatomic, assign) CGFloat width;   // 0 = unset
@property (nonatomic, assign) CGFloat height;  // 0 = unset

// Margin
@property (nonatomic, assign) CGFloat margin;
@property (nonatomic, assign) CGFloat marginTop;
@property (nonatomic, assign) CGFloat marginBottom;
@property (nonatomic, assign) CGFloat marginLeft;
@property (nonatomic, assign) CGFloat marginRight;
@property (nonatomic, assign) CGFloat marginHorizontal;
@property (nonatomic, assign) CGFloat marginVertical;

// Padding
@property (nonatomic, assign) CGFloat padding;
@property (nonatomic, assign) CGFloat paddingTop;
@property (nonatomic, assign) CGFloat paddingBottom;
@property (nonatomic, assign) CGFloat paddingLeft;
@property (nonatomic, assign) CGFloat paddingRight;
@property (nonatomic, assign) CGFloat paddingHorizontal;
@property (nonatomic, assign) CGFloat paddingVertical;

// Borders - widths
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, assign) CGFloat borderTopWidth;
@property (nonatomic, assign) CGFloat borderBottomWidth;
@property (nonatomic, assign) CGFloat borderLeftWidth;
@property (nonatomic, assign) CGFloat borderRightWidth;

// Borders - colors
@property (nonatomic, strong, nullable) UIColor *borderColor;
@property (nonatomic, strong, nullable) UIColor *borderTopColor;
@property (nonatomic, strong, nullable) UIColor *borderBottomColor;
@property (nonatomic, strong, nullable) UIColor *borderLeftColor;
@property (nonatomic, strong, nullable) UIColor *borderRightColor;

// Border radii
@property (nonatomic, assign) CGFloat borderRadius;
@property (nonatomic, assign) CGFloat borderTopLeftRadius;
@property (nonatomic, assign) CGFloat borderTopRightRadius;
@property (nonatomic, assign) CGFloat borderBottomLeftRadius;
@property (nonatomic, assign) CGFloat borderBottomRightRadius;

// Border style
@property (nonatomic, copy, nullable) NSString *borderStyle;
@property (nonatomic, copy, nullable) NSString *borderCurve;

// MARK: - Computed helpers

/// Resolves padding into a single UIEdgeInsets, respecting the
/// specific-over-general cascade (paddingTop > paddingVertical > padding).
- (UIEdgeInsets)resolvedPaddingInsets;

/// Same for margin.
- (UIEdgeInsets)resolvedMarginInsets;

/// Effective border width per side, using borderXxxWidth > borderWidth.
- (UIEdgeInsets)resolvedBorderWidths;

/// Effective border colors per side, using borderXxxColor > borderColor.
- (nullable UIColor *)resolvedBorderColorForEdge:(UIRectEdge)edge;

/// Effective corner radius per corner. Falls back to borderRadius.
- (CGFloat)resolvedRadiusForCorner:(UIRectCorner)corner;

/// Returns true if any border side is non-zero.
- (BOOL)hasAnyBorder;

/// Returns true if any corner radius is set (even via borderRadius).
- (BOOL)hasAnyRadius;

/// Returns true if per-side borders differ (need subview edges).
/// If false, a uniform layer.border can be used.
- (BOOL)hasNonUniformBorders;

/// Resolved font built by cascading over the base font (or standalone).
- (nullable UIFont *)resolvedFont;
- (nullable UIFont *)resolvedFontWithBase:(nullable UIFont *)baseFont;

@end

@interface StyleConfig : NSObject

@property (nonatomic, strong) MarkdownElementStyle *base;

// Block elements
@property (nonatomic, strong) MarkdownElementStyle *paragraph;
@property (nonatomic, strong) MarkdownElementStyle *heading1;
@property (nonatomic, strong) MarkdownElementStyle *heading2;
@property (nonatomic, strong) MarkdownElementStyle *heading3;
@property (nonatomic, strong) MarkdownElementStyle *heading4;
@property (nonatomic, strong) MarkdownElementStyle *heading5;
@property (nonatomic, strong) MarkdownElementStyle *heading6;
@property (nonatomic, strong) MarkdownElementStyle *blockquote;
@property (nonatomic, strong) MarkdownElementStyle *codeBlock;
@property (nonatomic, strong) MarkdownElementStyle *list;
@property (nonatomic, strong) MarkdownElementStyle *listItem;
@property (nonatomic, strong) MarkdownElementStyle *listBullet;
@property (nonatomic, strong) MarkdownElementStyle *thematicBreak;
@property (nonatomic, strong) MarkdownElementStyle *image;

// Tables
@property (nonatomic, strong) MarkdownElementStyle *table;
@property (nonatomic, strong) MarkdownElementStyle *tableRow;
@property (nonatomic, strong) MarkdownElementStyle *tableHeaderRow;
@property (nonatomic, strong) MarkdownElementStyle *tableCell;
@property (nonatomic, strong) MarkdownElementStyle *tableHeaderCell;

// Inline
@property (nonatomic, strong) MarkdownElementStyle *strong;
@property (nonatomic, strong) MarkdownElementStyle *emphasis;
@property (nonatomic, strong) MarkdownElementStyle *strikethrough;
@property (nonatomic, strong) MarkdownElementStyle *underline;
@property (nonatomic, strong) MarkdownElementStyle *code;
@property (nonatomic, strong) MarkdownElementStyle *link;

// Mentions — three trigger types, each with its own text style.
@property (nonatomic, strong) MarkdownElementStyle *mentionUser;
@property (nonatomic, strong) MarkdownElementStyle *mentionChannel;
@property (nonatomic, strong) MarkdownElementStyle *mentionCommand;

// Special
@property (nonatomic, strong) MarkdownElementStyle *spoiler;

+ (instancetype)fromJSON:(NSString *)json;

- (MarkdownElementStyle *)styleForHeadingLevel:(NSInteger)level;

@end

NS_ASSUME_NONNULL_END
