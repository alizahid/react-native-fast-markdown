#import "ListItemRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

@implementation ListItemRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];
  [StyleAttributes applyParagraphPropertiesFromStyle:context.styleConfig.base
                                             toAttrs:attrs];
  [StyleAttributes applyStyle:context.styleConfig.listItem toAttrs:attrs];

  // md4c omits MD_BLOCK_P for items in tight lists, so a list item's
  // text can be rendered inline without a trailing newline — which
  // would make the next item's bullet land on the same line. Force a
  // preceding newline whenever we're not at the very start of the
  // output buffer.
  if (output.length > 0) {
    unichar lastChar = [output.string characterAtIndex:output.length - 1];
    if (lastChar != '\n') {
      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n"
                                          attributes:attrs]];
    }
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
  } else if (context.currentListIsOrdered) {
    // Left-pad the number with figure spaces (U+2007 — a digit-width
    // whitespace character in most fonts) so the periods line up for
    // mixed-width markers like 1./10./11.
    NSInteger number = context.orderedListIndex;
    NSInteger digits = 1;
    NSInteger tmp = MAX(1, number);
    while (tmp >= 10) {
      digits++;
      tmp /= 10;
    }
    NSInteger padCount =
        MAX(0, context.currentListMaxMarkerDigits - digits);
    NSMutableString *padding = [NSMutableString new];
    for (NSInteger i = 0; i < padCount; i++) {
      [padding appendString:@"\u2007"];
    }
    bullet = [NSString stringWithFormat:@"%@%ld. ", padding, (long)number];
    context.orderedListIndex++;
  } else {
    NSArray *bullets = @[ @"\u2022 ", @"\u25E6 ", @"\u25AA " ];
    NSInteger bulletIndex = (context.listDepth - 1) % bullets.count;
    bullet = bullets[bulletIndex];
  }

  NSString *prefix = [indent stringByAppendingString:bullet];

  // Bullet gets its own style on top of the list item attrs
  NSMutableDictionary *bulletAttrs = [attrs mutableCopy];
  [StyleAttributes applyStyle:context.styleConfig.listBullet toAttrs:bulletAttrs];

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
