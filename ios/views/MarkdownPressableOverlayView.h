#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A tappable overlay with built-in highlight-on-touch feedback,
/// backed by a CAShapeLayer so it can render complex shapes like
/// multi-line text highlights as a single view.
///
/// Set `shapePath` to a UIBezierPath in the view's local coordinate
/// space to fill that shape and to constrain hit testing to it
/// (taps outside the path fall through to the text view
/// underneath). If `shapePath` is nil the entire bounds is filled
/// and hit tests against the bounds like a plain UIControl.
///
/// The fill color swaps between `normalColor` and `pressedColor`
/// automatically as the user's finger goes down / up / cancels,
/// driven by UIControl's highlighted state.
@interface MarkdownPressableOverlayView : UIControl

/// Shape filled by the overlay. Coordinates are local to the view's
/// bounds. When set, `pointInside:withEvent:` returns YES only for
/// points inside the path, so empty regions in the overlay's
/// bounding box (e.g. the staircase corners of a multi-line text
/// highlight) don't intercept touches. Pass nil to fall back to
/// the full bounds.
@property (nonatomic, strong, nullable) UIBezierPath *shapePath;

/// Fill color shown when the control is not being pressed.
/// Default: clear.
@property (nonatomic, strong, nullable) UIColor *normalColor;

/// Fill color shown while the user's finger is down on the control.
/// Default: a subtle semi-transparent dark tint.
@property (nonatomic, strong, nullable) UIColor *pressedColor;

/// Opaque identifier for grouping overlays that belong to the same
/// logical target. Currently used only for debugging / equality
/// checks by callers — the overlay itself doesn't do any group
/// coordination because each target is now a single view.
@property (nonatomic, copy, nullable) NSString *groupId;

/// Builds a rounded shape path that covers every rect in `rects`,
/// interpreted as touching horizontal strips (one per line of a
/// multi-line text highlight). Rects should be sorted by y
/// ascending and adjacent rects should share their y boundary —
/// that's what the spoiler / mention overlays produce via
/// enumerateLineFragmentsForGlyphRange:.
///
/// The path is the staircase outline of the rect union with every
/// corner (convex AND concave) smoothed by a quadratic bezier of
/// the requested radius. Concave corners at line boundaries
/// naturally get inward curves, which gives the connected-line
/// highlight look used in Messages, Discord, etc.
///
/// Radius is clamped per-corner to half of the shorter adjacent
/// segment so tight vertices don't overshoot.
///
/// The returned path is in the coordinate space of the union of
/// `rects` — pass the union as the view's frame and the path as
/// `shapePath` directly. Returns an empty path for empty input.
+ (UIBezierPath *)shapePathForRects:(NSArray<NSValue *> *)rects
                       cornerRadius:(CGFloat)radius;

@end

NS_ASSUME_NONNULL_END
