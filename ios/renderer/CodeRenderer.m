#import "CodeRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation CodeRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.code;
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
    attrs[NSBackgroundColorAttributeName] = [UIColor colorWithWhite:0.94 alpha:1.0];
  }

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
