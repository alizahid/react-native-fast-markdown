#import "TextRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"

@implementation TextRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  switch (node.nodeType) {
    case MDNodeTypeText: {
      NSString *text = node.content;
      if (text.length > 0) {
        NSAttributedString *attrStr =
            [[NSAttributedString alloc] initWithString:text
                                            attributes:context.currentAttributes];
        [output appendAttributedString:attrStr];
      }
      break;
    }
    case MDNodeTypeSoftBreak: {
      NSAttributedString *space =
          [[NSAttributedString alloc] initWithString:@" "
                                          attributes:context.currentAttributes];
      [output appendAttributedString:space];
      break;
    }
    case MDNodeTypeLineBreak: {
      NSAttributedString *newline =
          [[NSAttributedString alloc] initWithString:@"\n"
                                          attributes:context.currentAttributes];
      [output appendAttributedString:newline];
      break;
    }
    default:
      break;
  }
}

@end
