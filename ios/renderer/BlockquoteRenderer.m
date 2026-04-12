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
  [StyleAttributes applyParagraphPropertiesFromStyle:context.styleConfig.base
                                             toAttrs:attrs];
  [StyleAttributes applyStyle:style toAttrs:attrs];

  context.isInsideBlockquote = YES;
  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
  context.isInsideBlockquote = NO;
}

@end
