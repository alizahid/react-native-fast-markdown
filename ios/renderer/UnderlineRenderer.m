#import "UnderlineRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"

@implementation UnderlineRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];
  attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
