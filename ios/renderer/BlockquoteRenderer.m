#import "BlockquoteRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

@implementation BlockquoteRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.blockquote;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];
  [StyleAttributes applyStyle:style toAttrs:attrs];

  // Vertical bar indicator — uses borderLeftColor if set, else current color
  NSString *prefix = @"\u2503 ";
  NSMutableDictionary *prefixAttrs = [attrs mutableCopy];
  if (style.borderLeftColor) {
    prefixAttrs[NSForegroundColorAttributeName] = style.borderLeftColor;
  }

  [output appendAttributedString:
      [[NSAttributedString alloc] initWithString:prefix attributes:prefixAttrs]];

  context.isInsideBlockquote = YES;
  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
  context.isInsideBlockquote = NO;
}

@end
