#import "CodeBlockRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation CodeBlockRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.codeBlock;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  if (style) {
    UIFont *font = [style resolvedFont];
    if (font) attrs[NSFontAttributeName] = font;
    if (style.color) attrs[NSForegroundColorAttributeName] = style.color;
    if (style.backgroundColor) {
      attrs[NSBackgroundColorAttributeName] = style.backgroundColor;
    }
  } else {
    attrs[NSFontAttributeName] = [UIFont fontWithName:@"Menlo" size:14] ?: [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    attrs[NSBackgroundColorAttributeName] = [UIColor colorWithWhite:0.96 alpha:1.0];
  }

  context.isInsideCodeBlock = YES;
  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
  context.isInsideCodeBlock = NO;

  // Ensure code block ends with newline
  if (output.length > 0) {
    unichar lastChar = [output.string characterAtIndex:output.length - 1];
    if (lastChar != '\n') {
      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n"
                                         attributes:context.currentAttributes]];
    }
  }
}

@end
