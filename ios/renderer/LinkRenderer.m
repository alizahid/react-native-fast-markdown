#import "LinkRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation LinkRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.link;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  if (style) {
    if (style.color) attrs[NSForegroundColorAttributeName] = style.color;
    if ([style.textDecorationLine isEqualToString:@"underline"]) {
      attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
    }
  } else {
    attrs[NSForegroundColorAttributeName] = [UIColor systemBlueColor];
  }

  // Store URL for tap handling
  NSString *url = node.linkUrl;
  if (url.length > 0) {
    attrs[NSLinkAttributeName] = [NSURL URLWithString:url] ?: url;
  }

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
