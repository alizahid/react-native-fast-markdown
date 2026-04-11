#import "MarkdownViewShadowNode.h"

#import <Foundation/Foundation.h>

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
