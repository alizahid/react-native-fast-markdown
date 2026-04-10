#import "ListRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"

@implementation ListRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  NSInteger savedDepth = context.listDepth;
  NSInteger savedIndex = context.orderedListIndex;

  context.listDepth = savedDepth + 1;
  context.orderedListIndex = node.listStart;

  [context renderChildren:node into:output];

  context.listDepth = savedDepth;
  context.orderedListIndex = savedIndex;
}

@end
