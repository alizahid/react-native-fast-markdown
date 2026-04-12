#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Block-level image view used by MarkdownView for standalone
/// `![alt](url)` lines in the markdown. Wraps an internal
/// UIImageView, async-downloads the URL via NSURLSession, and
/// caches the decoded UIImage in a process-wide NSCache.
///
/// The view's sizeThatFits: reports a size derived from whichever
/// of these is known first:
///   1. `propSize` — dimensions supplied by the caller via the
///      `images` prop on <Markdown>. Authoritative.
///   2. The entry in the shared MarkdownImageSizeCache — populated
///      by a download that has already completed.
///   3. Otherwise, the fallback width/height supplied at init.
///
/// On tap (via an overlay MarkdownPressableOverlayView) it invokes
/// `onPress` with the URL and the best-known natural size at the
/// time of the tap.
@interface MarkdownImageView : UIView

- (instancetype)initWithURL:(nullable NSURL *)url
                   propSize:(CGSize)propSize
              fallbackWidth:(CGFloat)fallbackWidth
             fallbackHeight:(CGFloat)fallbackHeight;

/// Exposed so callers can tweak contentMode / tintColor / etc.
@property (nonatomic, strong, readonly) UIImageView *imageView;

/// Invoked when the user taps the image. `size` is the best-
/// known natural size at the time of the tap.
@property (nonatomic, copy, nullable)
    void (^onPress)(NSURL *url, CGSize size);

@end

NS_ASSUME_NONNULL_END
