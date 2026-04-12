#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A minimal vertical stack view that lays out its arranged subviews
/// manually via frame-based sizeThatFits / layoutSubviews.
///
/// Unlike UIStackView it does NOT rely on Auto Layout or
/// intrinsicContentSize on its children — it queries each child's
/// sizeThatFits: for the current available width. This is what the
/// frame-based MarkdownBlockView segments need to size correctly both
/// at layout time and when computing the total content height for
/// onContentSizeChange.
@interface MarkdownSegmentStackView : UIView

/// Space between adjacent segments.
@property (nonatomic) CGFloat spacing;

/// Arranged subviews, in layout order.
@property (nonatomic, readonly) NSArray<UIView *> *arrangedSubviews;

/// Append a segment and add it as a subview.
- (void)addArrangedSubview:(UIView *)view;

/// Remove all segments from the stack and their superview.
- (void)removeAllArrangedSubviews;

@end

NS_ASSUME_NONNULL_END
