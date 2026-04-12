#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted whenever a downloaded image's natural size is stored.
/// MarkdownView observes this to force a Yoga re-measure so newly
/// discovered dimensions replace any default space reservation.
extern NSString *const MarkdownImageSizeCacheDidUpdateNotification;

/// Process-wide cache of image natural sizes discovered when a
/// download completes. Written by MarkdownImageView and read as a
/// fallback whenever the caller hasn't supplied dimensions via the
/// `images` prop.
///
/// Authoritative sizes from the `images` prop are NOT stored here
/// — they're threaded through the shadow node's measureContent
/// and the view's createImageView: path as explicit parameters so
/// they update live when the prop changes (and so two MarkdownViews
/// declaring different dimensions for the same URL don't step on
/// each other).
///
/// Thread-safe — backed by an NSCache.
@interface MarkdownImageSizeCache : NSObject

+ (instancetype)sharedCache;

/// Returns the discovered natural size for `url`, or CGSizeZero if
/// no download has completed yet.
- (CGSize)sizeForURLString:(NSString *)url;

/// Stores `size` for `url` in the discovered tier. Posts
/// MarkdownImageSizeCacheDidUpdateNotification on the main thread
/// only when the stored value actually changes.
- (void)setSize:(CGSize)size forURLString:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
