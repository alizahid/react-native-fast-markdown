#import "ParagraphRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation ParagraphRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.paragraph;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  if (style) {
    UIFont *font = [style resolvedFont];
    if (font) attrs[NSFontAttributeName] = font;
    if (style.color) attrs[NSForegroundColorAttributeName] = style.color;
    if (style.lineHeight > 0) {
      NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
      paraStyle.minimumLineHeight = style.lineHeight;
      paraStyle.maximumLineHeight = style.lineHeight;
      attrs[NSParagraphStyleAttributeName] = paraStyle;
    }
  }

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];

  // Add paragraph spacing
  if (output.length > 0) {
    NSAttributedString *newline =
        [[NSAttributedString alloc] initWithString:@"\n"
                                        attributes:context.currentAttributes];
    [output appendAttributedString:newline];
  }
}

@end
