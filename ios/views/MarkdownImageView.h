#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Block-level image view used by MarkdownView for standalone
/// `![alt](url)` lines in the markdown. Wraps an internal
/// UIImageView, async-downloads the URL via NSURLSession, and
/// caches the decoded UIImage in a process-wide NSCache.
///
/// The view's sizeThatFits: reports a size derived from whichever
/// of these is known first:
///   1. The entry in the shared MarkdownImageSizeCache for this
///      URL — populated either by a previous download, by a
///      caller pre-seeding it from the `images` prop, or by the
///      in-progress download this view just finished.
///   2. Otherwise, a fallback width/height supplied at init.
///
/// On tap (via an overlay MarkdownPressableOverlayView) it
/// invokes `onPress` with the URL and the best-known natural
/// size at the time of the tap.
@interface MarkdownImageView : UIView

- (instancetype)initWithURL:(nullable NSURL *)url
              fallbackWidth:(CGFloat)fallbackWidth
             fallbackHeight:(CGFloat)fallbackHeight;

/// Exposed so callers can tweak contentMode / tintColor / etc.
@property (nonatomic, strong, readonly) UIImageView *imageView;

/// Invoked when the user taps the image. `size` is the best-
/// known natural size at the time of the tap — from the shared
/// MarkdownImageSizeCache if set, otherwise the fallback size.
@property (nonatomic, copy, nullable)
    void (^onPress)(NSURL *url, CGSize size);

@end

NS_ASSUME_NONNULL_END
