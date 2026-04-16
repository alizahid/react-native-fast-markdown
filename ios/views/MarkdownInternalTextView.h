#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Internal UITextView subclass that fires a callback after every
/// layoutSubviews pass. Used to drive MarkdownSpoilerOverlay — the
/// overlay has to recompute its glyph rects whenever the text view's
/// bounds / wrapping change, otherwise it ends up sizing against the
/// zero-width bounds the text view has at construction time.
@interface MarkdownInternalTextView : UITextView

/// Called on the main thread after every call to layoutSubviews.
@property (nonatomic, copy, nullable) void (^onLayoutSubviews)(void);

/// Called instantly (touch-up) when a link is tapped.  Bypasses
/// UITextView's delayed UITextItemInteraction gesture path.
@property (nonatomic, copy, nullable) void (^onLinkTap)(NSURL *url);

/// Installs a UITapGestureRecognizer that fires onLinkTap for link
/// ranges. Call once after the text view's content is configured.
- (void)installLinkTapRecognizer;

@end

NS_ASSUME_NONNULL_END
