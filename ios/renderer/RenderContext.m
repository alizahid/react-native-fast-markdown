#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

@implementation RenderContext

- (instancetype)init {
  self = [super init];
  if (self) {
    _attributeStack = [NSMutableArray new];
    _listDepth = 0;
    _orderedListIndex = 0;
    _isInsideBlockquote = NO;
    _isInsideCodeBlock = NO;
    _taskListIndex = 0;

    // Start with empty base; will be replaced when styleConfig is set
    [_attributeStack addObject:@{}];
  }
  return self;
}

- (void)setStyleConfig:(StyleConfig *)styleConfig {
  _styleConfig = styleConfig;

  // Reset the stack and push the `text` base style as the root attributes.
  // All subsequent renderers inherit these unless they override explicitly.
  [_attributeStack removeAllObjects];
  [_attributeStack addObject:[self baseAttributesFromStyleConfig:styleConfig]];
}

- (NSDictionary<NSAttributedStringKey, id> *)baseAttributesFromStyleConfig:
    (StyleConfig *)styleConfig {
  NSMutableDictionary *baseAttrs = [NSMutableDictionary new];

  MarkdownElementStyle *base = styleConfig.base;
  if (!base) return baseAttrs;

  UIFont *font = [base resolvedFont];
  if (font) {
    baseAttrs[NSFontAttributeName] = font;
  }

  if (base.color) {
    baseAttrs[NSForegroundColorAttributeName] = base.color;
  }

  // Note: lineHeight is applied per-block by ParagraphRenderer etc.
  // to avoid clipping elements with larger fonts (like headings).

  return [baseAttrs copy];
}

- (void)pushAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs {
  NSMutableDictionary *merged = [self.currentAttributes mutableCopy];
  [merged addEntriesFromDictionary:attrs];
  [_attributeStack addObject:[merged copy]];
}

- (void)popAttributes {
  if (_attributeStack.count > 1) {
    [_attributeStack removeLastObject];
  }
}

- (NSDictionary<NSAttributedStringKey, id> *)currentAttributes {
  return _attributeStack.lastObject ?: @{};
}

- (void)renderChildren:(ASTNodeWrapper *)node
                  into:(NSMutableAttributedString *)output {
  NSArray<ASTNodeWrapper *> *children = [node children];
  for (ASTNodeWrapper *child in children) {
    id<NodeRenderer> renderer = [RendererFactory rendererForNode:child];
    if (renderer) {
      [renderer renderNode:child into:output context:self];
    }
  }
}

@end
