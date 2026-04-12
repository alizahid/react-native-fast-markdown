#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted whenever a new URL → size mapping is stored, or an
/// existing one changes. MarkdownView observes this to force a
/// Yoga re-measure of itself so the newly-known natural size of
/// an image replaces the default reservation in layout.
extern NSString *const MarkdownImageSizeCacheDidUpdateNotification;

/// Process-wide cache of image natural sizes keyed by URL string.
///
/// Holds two tiers: an authoritative tier populated from the
/// `images` prop on <Markdown> and a discovered tier populated when
/// a download completes. Authoritative entries always win — the
/// prop represents the caller's explicit intent about layout, so
/// discovered entries never overwrite them. This keeps layout
/// stable when the user supplies dimensions even if the actual
/// image bytes have slightly different natural dimensions.
///
/// Thread-safe — backed by NSCache instances.
@interface MarkdownImageSizeCache : NSObject

+ (instancetype)sharedCache;

/// Returns the best-known natural size for `url`. Checks the
/// authoritative tier first and falls back to the discovered
/// tier; returns CGSizeZero when neither has an entry.
- (CGSize)sizeForURLString:(NSString *)url;

/// Stores `size` for `url` in the authoritative tier. Called from
/// the shadow thread in MarkdownViewShadowNode::measureContent to
/// seed sizes from the `images` prop before the measurer runs.
/// Posts the did-update notification only when the stored value
/// changes.
- (void)setPropSize:(CGSize)size forURLString:(NSString *)url;

/// Stores `size` for `url` in the discovered tier. Called from
/// MarkdownImageView after a download completes. Returns without
/// storing (and without posting a notification) when an
/// authoritative entry already exists for `url` — prop-supplied
/// dimensions are the source of truth.
- (void)setSize:(CGSize)size forURLString:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
