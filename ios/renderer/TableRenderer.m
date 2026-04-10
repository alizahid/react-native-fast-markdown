#import "TableRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation TableRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  // For table container nodes (Table, TableHead, TableBody, TableRow),
  // just render children directly. The TableGridView will be used for
  // proper native table rendering in the view layer.
  // Here we provide a text fallback.
  switch (node.nodeType) {
    case MDNodeTypeTable:
    case MDNodeTypeTableHead:
    case MDNodeTypeTableBody:
      [context renderChildren:node into:output];
      break;

    case MDNodeTypeTableRow: {
      // Render cells separated by |
      NSArray<ASTNodeWrapper *> *cells = node.children;
      NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"| " attributes:attrs]];

      for (NSUInteger i = 0; i < cells.count; i++) {
        [context renderChildren:cells[i] into:output];
        [output appendAttributedString:
            [[NSAttributedString alloc] initWithString:@" | " attributes:attrs]];
      }

      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n" attributes:attrs]];
      break;
    }

    case MDNodeTypeTableCell: {
      MarkdownElementStyle *style = context.styleConfig.table;
      NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

      if (style && style.headerBackgroundColor && node.nodeType == MDNodeTypeTableCell) {
        // Header cells could be styled differently
      }

      [context pushAttributes:attrs];
      [context renderChildren:node into:output];
      [context popAttributes];
      break;
    }

    default:
      [context renderChildren:node into:output];
      break;
  }
}

@end
