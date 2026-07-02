#import "FMDRenderedContent.h"

@implementation FMDRenderedContent {
  CGFloat _gap;
  CGFloat _verticalPadding;
  NSMutableDictionary<NSNumber *, NSArray<NSNumber *> *> *_heightCache;
}

- (instancetype)initWithBlocks:(NSArray<NSAttributedString *> *)blocks
                           gap:(CGFloat)gap
               verticalPadding:(CGFloat)verticalPadding {
  if (self = [super init]) {
    _blocks = [blocks copy];
    _gap = gap;
    _verticalPadding = verticalPadding;
    _heightCache = [NSMutableDictionary new];
  }
  return self;
}

- (NSArray<NSNumber *> *)blockHeightsForWidth:(CGFloat)width {
  NSNumber *key = @(round(width * 2) / 2);
  @synchronized(self) {
    NSArray<NSNumber *> *cached = _heightCache[key];
    if (cached != nil) {
      return cached;
    }
  }

  NSMutableArray<NSNumber *> *heights = [NSMutableArray arrayWithCapacity:_blocks.count];
  for (NSAttributedString *block in _blocks) {
    CGRect rect = [block boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                      options:NSStringDrawingUsesLineFragmentOrigin |
                                              NSStringDrawingUsesFontLeading
                                      context:nil];
    [heights addObject:@(ceil(rect.size.height))];
  }

  @synchronized(self) {
    if (_heightCache.count > 4) {
      [_heightCache removeAllObjects];
    }
    _heightCache[key] = heights;
  }
  return heights;
}

- (CGFloat)totalHeightForWidth:(CGFloat)width {
  NSArray<NSNumber *> *heights = [self blockHeightsForWidth:width];
  CGFloat total = _verticalPadding;
  for (NSUInteger i = 0; i < heights.count; i++) {
    total += heights[i].doubleValue;
    if (i + 1 < heights.count) {
      total += _gap;
    }
  }
  return total;
}

@end
