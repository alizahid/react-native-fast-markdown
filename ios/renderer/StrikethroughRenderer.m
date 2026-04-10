#import "StrikethroughRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation StrikethroughRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.strikethrough;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  attrs[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);

  if (style && style.color) {
    attrs[NSForegroundColorAttributeName] = style.color;
    attrs[NSStrikethroughColorAttributeName] = style.color;
  }

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
