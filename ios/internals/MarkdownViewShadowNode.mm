#import "MarkdownViewShadowNode.h"

#import <Foundation/Foundation.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>

#import "MarkdownImageSizeCache.h"
#import "MarkdownMeasurer.h"

namespace facebook::react {

const char MarkdownViewComponentName[] = "MarkdownView";

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

  // Seed the shared image size cache from the `images` prop BEFORE
  // calling the measurer. updateProps: on the component view runs
  // on the main thread after the shadow commit — if we rely on
  // that, measureContent on the first render doesn't see the
  // user-supplied dimensions and reserves the default height
  // instead. Seeding from here runs on the shadow thread and
  // happens before the measurer reads the cache.
  //
  // MarkdownImageSizeCache.setSize:forURLString: short-circuits
  // when the size is already equal to what's cached, so repeated
  // seeding with the same values doesn't re-post the did-update
  // notification and doesn't create a re-measure loop.
  MarkdownImageSizeCache *sizeCache = [MarkdownImageSizeCache sharedCache];
  for (const auto &img : props.images) {
    if (img.url.empty()) continue;
    NSString *urlKey = [NSString stringWithUTF8String:img.url.c_str()];
    [sizeCache setSize:CGSizeMake(img.width, img.height)
          forURLString:urlKey];
  }

  CGSize size = [MarkdownMeasurer measureMarkdown:markdown
                                       stylesJSON:stylesJSON
                                       customTags:customTags
                                            width:maxWidth];

  return layoutConstraints.clamp({
      static_cast<Float>(size.width),
      static_cast<Float>(size.height),
  });
}

} // namespace facebook::react
