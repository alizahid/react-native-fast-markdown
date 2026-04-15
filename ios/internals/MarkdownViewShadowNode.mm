#import "MarkdownViewShadowNode.h"

#import <Foundation/Foundation.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>

#import "MarkdownMeasurer.h"

namespace facebook::react {

Size MarkdownViewShadowNode::measureContent(
    const LayoutContext & /*layoutContext*/,
    const LayoutConstraints &layoutConstraints) const {
  const auto &props = getConcreteProps();

  Float maxWidth = layoutConstraints.maximumSize.width;

  NSString *markdown = props.markdown.empty()
      ? @""
      : [NSString stringWithUTF8String:props.markdown.c_str()];
  NSString *stylesJSON = props.styles.empty()
      ? @""
      : [NSString stringWithUTF8String:props.styles.c_str()];

  NSMutableArray<NSString *> *customTags = [NSMutableArray new];
  for (const auto &tag : props.customTags) {
    [customTags addObject:[NSString stringWithUTF8String:tag.c_str()]];
  }

  // Build the URL → size dictionary from the `images` prop and
  // pass it to the measurer as an explicit parameter. Keeping the
  // prop sizes out of any process-wide cache means they're per
  // measurement (so two MarkdownViews declaring different sizes
  // for the same URL don't step on each other), reactive (when
  // the prop changes the cache key changes and we re-measure),
  // and can be dropped by simply omitting the URL from the prop.
  NSMutableDictionary<NSString *, NSValue *> *propImageSizes =
      [NSMutableDictionary new];
  for (const auto &img : props.images) {
    if (img.url.empty()) continue;
    if (img.width <= 0 || img.height <= 0) continue;
    NSString *urlKey = [NSString stringWithUTF8String:img.url.c_str()];
    propImageSizes[urlKey] =
        [NSValue valueWithCGSize:CGSizeMake(img.width, img.height)];
  }

  CGSize size = [MarkdownMeasurer measureMarkdown:markdown
                                       stylesJSON:stylesJSON
                                       customTags:customTags
                                   propImageSizes:propImageSizes
                                            width:maxWidth];

  return layoutConstraints.clamp({
      static_cast<Float>(size.width),
      static_cast<Float>(size.height),
  });
}

} // namespace facebook::react
