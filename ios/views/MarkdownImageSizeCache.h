#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted whenever a new URL → size mapping is stored, or an
/// existing one changes. MarkdownView observes this to force a
/// Yoga re-measure of itself so the newly-known natural size of
/// an image replaces the default reservation in layout.
extern NSString *const MarkdownImageSizeCacheDidUpdateNotification;

/// Process-wide cache of image natural sizes keyed by URL string.
/// Written by MarkdownImageView when a download completes and the
/// decoded UIImage's natural size is known; read by
/// MarkdownMeasurer when computing block-image segment heights
/// and by MarkdownImageView on init, so subsequent renders of the
/// same URL reserve the correct space before the bytes are back
/// from the network.
///
/// Thread-safe — backed by an NSCache guarded by a concurrent
/// dispatch queue.
@interface MarkdownImageSizeCache : NSObject

+ (instancetype)sharedCache;

/// Returns the cached natural size for `url`, or CGSizeZero if no
/// entry is present.
- (CGSize)sizeForURLString:(NSString *)url;

/// Stores `size` for `url`. Posts
/// MarkdownImageSizeCacheDidUpdateNotification on the main
/// thread if the size is new or differs from the existing entry.
- (void)setSize:(CGSize)size forURLString:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
