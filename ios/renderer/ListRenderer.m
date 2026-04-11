#import "ListRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"

@implementation ListRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  NSInteger savedDepth = context.listDepth;
  NSInteger savedIndex = context.orderedListIndex;
  BOOL savedIsOrdered = context.currentListIsOrdered;

  context.listDepth = savedDepth + 1;
  context.orderedListIndex = node.isOrderedList ? node.listStart : 0;
  context.currentListIsOrdered = node.isOrderedList;

  [context renderChildren:node into:output];

  context.listDepth = savedDepth;
  context.orderedListIndex = savedIndex;
  context.currentListIsOrdered = savedIsOrdered;
}

@end
