#import <UIKit/UIKit.h>

@class MarkdownElementStyle;

NS_ASSUME_NONNULL_BEGIN

/// A styled container view for a block-level markdown element.
/// Applies ViewStyle properties (padding, margin, borders, backgrounds,
/// border radius) around a content subview.
@interface MarkdownBlockView : UIView

- (instancetype)initWithStyle:(nullable MarkdownElementStyle *)style;

@property (nonatomic, strong, nullable) MarkdownElementStyle *style;

/// The content view displayed inside the container (with padding applied).
@property (nonatomic, strong, nullable) UIView *contentView;

/// When YES, MarkdownSegmentStackView uses the block's sizeThatFits
/// width as the block's frame width instead of stretching it to
/// the full stack width. Image blocks set this so the block hugs
/// the image's natural size and the user's bg / border / radius
/// styling wraps the image tightly instead of extending across
/// the whole row.
@property (nonatomic, assign) BOOL huggingContent;

/// Re-applies the style to the view (useful after style changes).
- (void)applyStyle;

@end

NS_ASSUME_NONNULL_END
