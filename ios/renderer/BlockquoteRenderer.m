#import "BlockquoteRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation BlockquoteRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.blockquote;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  if (style) {
    UIFont *font = [style resolvedFont];
    if (font) attrs[NSFontAttributeName] = font;
    if (style.color) attrs[NSForegroundColorAttributeName] = style.color;
  }

  // Add blockquote indicator
  NSString *prefix = @"\u2503 "; // vertical bar

  NSMutableDictionary *prefixAttrs = [attrs mutableCopy];
  if (style && style.borderLeftColor) {
    prefixAttrs[NSForegroundColorAttributeName] = style.borderLeftColor;
  } else {
    prefixAttrs[NSForegroundColorAttributeName] = [UIColor systemGrayColor];
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
