#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Block-level image view used by MarkdownView for standalone
/// `![alt](url)` lines in the markdown. Wraps an internal
/// UIImageView, kicks off an async NSURLSession download on init,
/// caches loaded UIImages in a process-wide NSCache keyed on URL,
/// and returns a stable sizeThatFits: so the shadow-thread
/// measurement and the runtime layout agree on the reserved
/// height before the image has actually arrived.
@interface MarkdownImageView : UIView

- (instancetype)initWithURL:(nullable NSURL *)url
                     height:(CGFloat)height;

/// The internal UIImageView. Exposed so callers can tweak
/// contentMode / tintColor / etc. if needed.
@property (nonatomic, strong, readonly) UIImageView *imageView;

/// Desired height of the view. Used by sizeThatFits: and by the
/// measurer so layout stays stable whether or not the image has
/// finished loading.
@property (nonatomic, assign) CGFloat desiredHeight;

@end

NS_ASSUME_NONNULL_END
