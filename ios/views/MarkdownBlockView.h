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

/// Re-applies the style to the view (useful after style changes).
- (void)applyStyle;

@end

NS_ASSUME_NONNULL_END
