#import "ListItemRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation ListItemRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.listItem;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  if (style) {
    UIFont *font = [style resolvedFont];
    if (font) attrs[NSFontAttributeName] = font;
    if (style.color) attrs[NSForegroundColorAttributeName] = style.color;
  }

  // Build indent
  NSString *indent = @"";
  for (NSInteger i = 1; i < context.listDepth; i++) {
    indent = [indent stringByAppendingString:@"    "];
  }

  // Build bullet/number
  NSString *bullet;
  if (node.isTaskItem) {
    bullet = node.taskChecked ? @"[x] " : @"[ ] ";
  } else if (node.isOrderedList) {
    bullet = [NSString stringWithFormat:@"%ld. ", (long)context.orderedListIndex];
    context.orderedListIndex++;
  } else {
    // Use different bullets for different depths
    NSArray *bullets = @[ @"\u2022 ", @"\u25E6 ", @"\u25AA " ];
    NSInteger bulletIndex = (context.listDepth - 1) % bullets.count;
    bullet = bullets[bulletIndex];
  }

  NSString *prefix = [indent stringByAppendingString:bullet];

  // Build bullet attributes from listBullet style (color, font, etc.)
  NSMutableDictionary *bulletAttrs = [attrs mutableCopy];
  MarkdownElementStyle *bulletStyle = context.styleConfig.listBullet;
  if (bulletStyle) {
    if (bulletStyle.color) {
      bulletAttrs[NSForegroundColorAttributeName] = bulletStyle.color;
    }
    if (bulletStyle.fontSize > 0 || bulletStyle.fontFamily ||
        bulletStyle.fontWeight) {
      UIFont *bulletFont = [bulletStyle resolvedFont];
      if (bulletFont) {
        bulletAttrs[NSFontAttributeName] = bulletFont;
      }
    }
  }

  [output appendAttributedString:
      [[NSAttributedString alloc] initWithString:prefix attributes:bulletAttrs]];

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];

  // Ensure each list item ends with a newline
  if (output.length > 0) {
    unichar lastChar = [output.string characterAtIndex:output.length - 1];
    if (lastChar != '\n') {
      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n"
                                          attributes:attrs]];
    }
  }
}

@end
