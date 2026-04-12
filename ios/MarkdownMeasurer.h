#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thread-safe measurement helper. Parses markdown, builds the same
/// NSAttributedString segments that MarkdownView would render, and
/// returns the total content size for a given width constraint.
///
/// `propImageSizes` is a URL-string → NSValue(CGSize) map of
/// dimensions supplied by the caller via the `images` prop on
/// <Markdown>. Authoritative: when an image URL has an entry here
/// the measurer uses it directly; otherwise it falls back to the
/// shared MarkdownImageSizeCache (discovered from completed
/// downloads) and finally to the style's default height. Prop
/// sizes are part of the cache key so changing them
/// automatically produces a fresh measurement.
///
/// Safe to call from any thread (including the Fabric shadow tree /
/// layout thread).
@interface MarkdownMeasurer : NSObject

+ (CGSize)measureMarkdown:(NSString *)markdown
               stylesJSON:(NSString *)stylesJSON
               customTags:(NSArray<NSString *> *)customTags
           propImageSizes:(nullable NSDictionary<NSString *, NSValue *> *)propImageSizes
                    width:(CGFloat)width;

/// Clears the measurement cache. Exposed for tests / memory warnings.
+ (void)clearCache;

@end

NS_ASSUME_NONNULL_END
