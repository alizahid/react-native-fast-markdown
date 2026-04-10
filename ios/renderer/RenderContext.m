#import "RenderContext.h"
#import "RendererFactory.h"

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

    // Push base attributes
    UIFont *baseFont = [UIFont systemFontOfSize:16];
    [_attributeStack addObject:@{
      NSFontAttributeName : baseFont,
      NSForegroundColorAttributeName : UIColor.labelColor,
    }];
  }
  return self;
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
    id<NodeRenderer> renderer =
        [RendererFactory rendererForNode:child];
    if (renderer) {
      [renderer renderNode:child into:output context:self];
    }
  }
}

@end
