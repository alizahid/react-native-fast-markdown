#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarkdownElementStyle : NSObject

@property (nonatomic, strong, nullable) UIFont *font;
@property (nonatomic, strong, nullable) UIColor *color;
@property (nonatomic, strong, nullable) UIColor *backgroundColor;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, copy, nullable) NSString *fontWeight;
@property (nonatomic, copy, nullable) NSString *fontStyle;
@property (nonatomic, copy, nullable) NSString *fontFamily;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, copy, nullable) NSString *textDecorationLine;
@property (nonatomic, assign) CGFloat padding;
@property (nonatomic, assign) CGFloat borderRadius;
@property (nonatomic, assign) CGFloat marginVertical;

// Blockquote specific
@property (nonatomic, strong, nullable) UIColor *borderLeftColor;
@property (nonatomic, assign) CGFloat borderLeftWidth;

// List specific
@property (nonatomic, strong, nullable) UIColor *bulletColor;

// Table specific
@property (nonatomic, strong, nullable) UIColor *borderColor;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, strong, nullable) UIColor *headerBackgroundColor;
@property (nonatomic, assign) CGFloat cellPadding;

// Thematic break
@property (nonatomic, assign) CGFloat height;

// Mention
@property (nonatomic, copy, nullable) NSString *prefix;

// Spoiler
@property (nonatomic, strong, nullable) UIColor *overlayColor;
@property (nonatomic, copy, nullable) NSString *mode;

- (UIFont *)resolvedFont;

@end

@interface StyleConfig : NSObject

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
@property (nonatomic, strong) MarkdownElementStyle *table;
@property (nonatomic, strong) MarkdownElementStyle *thematicBreak;
@property (nonatomic, strong) MarkdownElementStyle *image;
@property (nonatomic, strong) MarkdownElementStyle *mention;
@property (nonatomic, strong) MarkdownElementStyle *spoiler;

+ (instancetype)fromJSON:(NSString *)json;

- (MarkdownElementStyle *)styleForHeadingLevel:(NSInteger)level;

@end

NS_ASSUME_NONNULL_END
