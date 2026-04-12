#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Manages spoiler overlays for a UITextView.
/// Scans attributed text for MarkdownSpoilerRangeKey attributes,
/// calculates glyph rects, and adds opaque overlay views.
/// Tap toggles reveal/hide per spoiler.
@interface MarkdownSpoilerOverlay : NSObject

- (instancetype)initWithTextView:(UITextView *)textView;

/// Scans the text view's attributed text and adds/updates overlays.
/// Call after setting attributedText and after layout.
- (void)updateOverlays;

/// Removes all overlay views.
- (void)removeAllOverlays;

/// Color for the spoiler overlay. Defaults to label color.
@property (nonatomic, strong) UIColor *overlayColor;

/// Corner radius applied to the spoiler shape path. Set by
/// MarkdownView from styleConfig.spoiler.borderRadius. Defaults to 0
/// (sharp corners).
@property (nonatomic, assign) CGFloat cornerRadius;

@end

NS_ASSUME_NONNULL_END
