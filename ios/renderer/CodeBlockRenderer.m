#import "CodeBlockRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

@implementation CodeBlockRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.codeBlock;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];
  [StyleAttributes applyStyle:style toAttrs:attrs];

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
