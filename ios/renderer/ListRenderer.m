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
  NSInteger savedMaxDigits = context.currentListMaxMarkerDigits;

  context.listDepth = savedDepth + 1;
  context.orderedListIndex = node.isOrderedList ? node.listStart : 0;
  context.currentListIsOrdered = node.isOrderedList;

  if (node.isOrderedList) {
    NSInteger itemCount = 0;
    for (ASTNodeWrapper *child in node.children) {
      if (child.nodeType == MDNodeTypeListItem) itemCount++;
    }
    NSInteger listStart = node.listStart > 0 ? node.listStart : 1;
    NSInteger lastNumber = MAX(1, listStart + itemCount - 1);
    NSInteger digits = 1;
    while (lastNumber >= 10) {
      digits++;
      lastNumber /= 10;
    }
    context.currentListMaxMarkerDigits = digits;
  } else {
    context.currentListMaxMarkerDigits = 0;
  }

  [context renderChildren:node into:output];

  context.listDepth = savedDepth;
  context.orderedListIndex = savedIndex;
  context.currentListIsOrdered = savedIsOrdered;
  context.currentListMaxMarkerDigits = savedMaxDigits;
}

@end
