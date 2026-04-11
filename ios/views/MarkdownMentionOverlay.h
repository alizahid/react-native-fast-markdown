#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Manages pressable overlay views for mention spans inside a
/// UITextView. Scans attributed text for MarkdownMentionKey
/// attributes, computes glyph rects, and drops transparent
/// highlight-on-touch overlay views on each line fragment. On
/// tap-up, invokes the press handler with the mention data dict
/// (the value stored under MarkdownMentionKey).
///
/// This lives alongside MarkdownSpoilerOverlay — together they
/// replace NSLinkAttributeName for mention/spoiler tap handling,
/// so UITextView doesn't expose the long-press link menu or drag
/// behavior for our synthetic ranges.
@interface MarkdownMentionOverlay : NSObject

- (instancetype)initWithTextView:(UITextView *)textView;

/// Scans the text view's attributed text and adds/updates overlays.
/// Should be called on every layoutSubviews pass of the text view.
- (void)updateOverlays;

/// Removes all overlay views.
- (void)removeAllOverlays;

/// Called with the mention data NSDictionary when an overlay is
/// tapped. Shape matches MarkdownMentionKey's value: keys
/// @"type", @"id", @"name", @"props".
@property (nonatomic, copy, nullable) void (^onPress)(NSDictionary *mention);

@end

NS_ASSUME_NONNULL_END
