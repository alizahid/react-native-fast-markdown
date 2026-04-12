#import "ThematicBreakRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation ThematicBreakRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  // Render as a line using a special character with strikethrough
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  MarkdownElementStyle *style = context.styleConfig.thematicBreak;
  UIColor *lineColor = style.backgroundColor ?: [UIColor separatorColor];

  attrs[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
  attrs[NSStrikethroughColorAttributeName] = lineColor;
  attrs[NSForegroundColorAttributeName] = [UIColor clearColor];

  NSAttributedString *line =
      [[NSAttributedString alloc] initWithString:@" \n" attributes:attrs];
  [output appendAttributedString:line];
}

@end
