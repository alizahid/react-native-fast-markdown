#import "StrikethroughRenderer.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

@implementation StrikethroughRenderer

- (void)renderNode:(ASTNodeWrapper *)node
              into:(NSMutableAttributedString *)output
           context:(RenderContext *)context {
  MarkdownElementStyle *style = context.styleConfig.strikethrough;
  NSMutableDictionary *attrs = [context.currentAttributes mutableCopy];

  // Apply font / color / background / kerning / line-height etc. in
  // one go. applyStyle will also touch the strike attrs if the
  // caller happens to set textDecorationLine, but we overwrite
  // them below to guarantee the strike is always drawn — that's
  // the whole point of the strikethrough tag.
  [StyleAttributes applyStyle:style toAttrs:attrs];

  // Pattern — default to single, override via textDecorationStyle.
  NSUnderlineStyle pattern = NSUnderlineStyleSingle;
  if ([style.textDecorationStyle isEqualToString:@"double"]) {
    pattern = NSUnderlineStyleDouble;
  } else if ([style.textDecorationStyle isEqualToString:@"dotted"]) {
    pattern = NSUnderlineStyleSingle | NSUnderlinePatternDot;
  } else if ([style.textDecorationStyle isEqualToString:@"dashed"]) {
    pattern = NSUnderlineStyleSingle | NSUnderlinePatternDash;
  }
  attrs[NSStrikethroughStyleAttributeName] = @(pattern);

  // Color — prefer explicit textDecorationColor, fall back to the
  // text color so callers who just set `color: 'red'` still get a
  // matching red strike line.
  UIColor *strikeColor = style.textDecorationColor ?: style.color;
  if (strikeColor) {
    attrs[NSStrikethroughColorAttributeName] = strikeColor;
  }

  [context pushAttributes:attrs];
  [context renderChildren:node into:output];
  [context popAttributes];
}

@end
