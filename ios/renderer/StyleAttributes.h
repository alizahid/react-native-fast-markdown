#import <UIKit/UIKit.h>

@class MarkdownElementStyle;

NS_ASSUME_NONNULL_BEGIN

/// Helpers for applying MarkdownElementStyle properties to
/// NSAttributedString attribute dictionaries.
@interface StyleAttributes : NSObject

/// Applies the style's text and paragraph properties to the attrs dict.
/// Cascades font family/size from baseFont (the current font in context).
///
/// - Font: cascades family/size from baseFont; style can override
/// - Color: set if style.color is set
/// - Background color: set via NSBackgroundColorAttributeName (inline)
/// - Paragraph style: lineHeight, padding (as indent), alignment
+ (void)applyStyle:(nullable MarkdownElementStyle *)style
            toAttrs:(NSMutableDictionary *)attrs;

/// Applies only the paragraph-level properties (lineHeight, textAlign)
/// from a style to the attrs dict. Used by block renderers to cascade
/// these from the base style without re-applying font/color/bg (which
/// already cascade via the attribute stack, and where bg would mean
/// something different at the container level vs inline).
+ (void)applyParagraphPropertiesFromStyle:(nullable MarkdownElementStyle *)style
                                  toAttrs:(NSMutableDictionary *)attrs;

/// Builds a paragraph style from the element style. Returns nil if
/// no paragraph-relevant properties are set.
+ (nullable NSMutableParagraphStyle *)
    paragraphStyleFromStyle:(MarkdownElementStyle *)style
            existingPStyle:(nullable NSParagraphStyle *)existing;

@end

NS_ASSUME_NONNULL_END
