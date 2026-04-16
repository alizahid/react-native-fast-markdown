#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Manages transparent press-feedback overlays for link ranges
/// (NSLinkAttributeName) inside a UITextView. Taps fire instantly
/// via UIControlEventTouchUpInside — no UITextView link-gesture
/// delay. Long-presses fire via a UILongPressGestureRecognizer on
/// each overlay.
@interface MarkdownLinkOverlay : NSObject

- (instancetype)initWithTextView:(UITextView *)textView;

/// Remove all overlay views from the text view.
- (void)removeAllOverlays;

/// Rebuild overlay views from the current attributed text and
/// layout. Safe to call from the text view's layoutSubviews — it
/// short-circuits when nothing relevant changed.
- (void)updateOverlays;

/// Called on touch-up-inside with the tapped link URL.
@property (nonatomic, copy, nullable) void (^onPress)(NSURL *url);

/// Called on long-press-began with the held link URL.
@property (nonatomic, copy, nullable) void (^onLongPress)(NSURL *url);

@end

NS_ASSUME_NONNULL_END
