#import "HeadingRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation HeadingRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style =
      [context.styleConfig styleForHeadingLevel:node.headingLevel];
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  if (style) {
    UIFont *font = [style resolvedFont];
    if (font) attrs[NSFontAttributeName] = font;
    if (style.color) attrs[NSForegroundColorAttributeName] = style.color;
  }

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];

  NSAttributedString *newline =
      [[NSAttributedString alloc] initWithString:@"\n"
                                      attributes:context.currentAttributes];
  [output appendAttributedString:newline];
}

@end
