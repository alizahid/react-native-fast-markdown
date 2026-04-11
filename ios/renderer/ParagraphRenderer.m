#import "ParagraphRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

@implementation ParagraphRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  // Apply the base text style's lineHeight/alignment first, then override
  // with paragraph-specific style.
  [StyleAttributes applyStyle:context.styleConfig.text toAttrs:attrs];
  [StyleAttributes applyStyle:context.styleConfig.paragraph toAttrs:attrs];

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
