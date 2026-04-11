#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thread-safe measurement helper. Parses markdown, builds the same
/// NSAttributedString segments that MarkdownView would render, and
/// returns the total content size for a given width constraint.
///
/// Safe to call from any thread (including the Fabric shadow tree /
/// layout thread). Results are cached by (markdown, styleJSON, width)
/// so repeated measurements during virtualized list scrolling are
/// effectively free.
@interface MarkdownMeasurer : NSObject

+ (CGSize)measureMarkdown:(NSString *)markdown
               stylesJSON:(NSString *)stylesJSON
               customTags:(NSArray<NSString *> *)customTags
                    width:(CGFloat)width;

/// Clears the measurement cache. Exposed for tests / memory warnings.
+ (void)clearCache;

@end

NS_ASSUME_NONNULL_END
