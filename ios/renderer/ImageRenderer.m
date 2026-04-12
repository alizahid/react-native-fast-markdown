#import "ImageRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"

@implementation ImageRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  // For now, render image alt text as placeholder
  // Full image loading requires async download + text attachment
  NSString *altText = @"";
  for (ASTNodeWrapper *child in node.children) {
    if (child.nodeType == MDNodeTypeText) {
      altText = [altText stringByAppendingString:child.content];
    }
  }

  if (altText.length == 0) {
    altText = @"[Image]";
  }

  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];
  attrs[NSForegroundColorAttributeName] = [UIColor secondaryLabelColor];

  NSString *imageText = [NSString stringWithFormat:@"[%@]\n", altText];
  [output appendAttributedString:
      [[NSAttributedString alloc] initWithString:imageText attributes:attrs]];
}

@end
