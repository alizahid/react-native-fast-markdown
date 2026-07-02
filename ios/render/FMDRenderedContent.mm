#import "FMDRenderedContent.h"

@implementation FMDWidthLayout
@end

@implementation FMDRenderedContent {
  NSArray<FMDBlock *> *_blocks;
  CGFloat _topPadding;
  CGFloat _bottomPadding;
  NSMutableDictionary<NSString *, FMDWidthLayout *> *_layoutCache;
}

- (instancetype)initWithBlocks:(NSArray<FMDBlock *> *)blocks
                           gap:(CGFloat)gap
                    topPadding:(CGFloat)topPadding
                 bottomPadding:(CGFloat)bottomPadding {
  if (self = [super init]) {
    _blocks = [blocks copy];
    _gap = gap;
    _topPadding = topPadding;
    _bottomPadding = bottomPadding;
    _layoutCache = [NSMutableDictionary new];
  }
  return self;
}

+ (CGFloat)stackHeight:(NSArray<FMDMeasuredBlock *> *)children gap:(CGFloat)gap {
  CGFloat height = 0;
  for (NSUInteger i = 0; i < children.count; i++) {
    height += children[i].height;
    if (i + 1 < children.count) {
      height += gap;
    }
  }
  return height;
}

- (FMDWidthLayout *)layoutForWidth:(CGFloat)width
                        imageSizes:(nullable NSDictionary<NSString *, NSArray<NSNumber *> *> *)imageSizes {
  NSString *key = [NSString stringWithFormat:@"%.1f|%lu",
                                             width,
                                             (unsigned long)imageSizes.hash];
  @synchronized(self) {
    FMDWidthLayout *cached = _layoutCache[key];
    if (cached != nil) {
      return cached;
    }
  }

  NSMutableArray<FMDMeasuredBlock *> *measured = [NSMutableArray arrayWithCapacity:_blocks.count];
  for (FMDBlock *block in _blocks) {
    [measured addObject:[self measureBlock:block width:width imageSizes:imageSizes]];
  }

  FMDWidthLayout *layout = [FMDWidthLayout new];
  layout.measured = measured;
  layout.totalHeight =
      [FMDRenderedContent stackHeight:measured gap:_gap] + _topPadding + _bottomPadding;

  @synchronized(self) {
    if (_layoutCache.count > 4) {
      [_layoutCache removeAllObjects];
    }
    _layoutCache[key] = layout;
  }
  return layout;
}

- (CGSize)textSize:(NSAttributedString *)text width:(CGFloat)width {
  CGRect rect = [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                   options:NSStringDrawingUsesLineFragmentOrigin |
                                           NSStringDrawingUsesFontLeading
                                   context:nil];
  return CGSizeMake(ceil(rect.size.width), ceil(rect.size.height));
}

- (FMDMeasuredBlock *)measureBlock:(FMDBlock *)block
                             width:(CGFloat)width
                        imageSizes:(nullable NSDictionary<NSString *, NSArray<NSNumber *> *> *)imageSizes {
  FMDMeasuredBlock *measured = [FMDMeasuredBlock new];
  measured.block = block;
  measured.contentWidth = width;

  switch (block.kind) {
    case FMDBlockKindText: {
      const CGSize size = [self textSize:block.attributedText width:width];
      measured.height = size.height;
      measured.textHeight = size.height;
      break;
    }
    case FMDBlockKindCode: {
      const CGSize size = [self textSize:block.attributedText width:CGFLOAT_MAX];
      measured.contentWidth = size.width;
      measured.textHeight = size.height;
      measured.height =
          size.height + block.layoutStyle.paddingTop + block.layoutStyle.paddingBottom;
      break;
    }
    case FMDBlockKindQuote: {
      const CGFloat innerWidth = MAX(width - block.layoutStyle.horizontalInset, 1);
      NSMutableArray<FMDMeasuredBlock *> *children =
          [NSMutableArray arrayWithCapacity:block.children.count];
      for (FMDBlock *child in block.children) {
        [children addObject:[self measureBlock:child width:innerWidth imageSizes:imageSizes]];
      }
      measured.children = children;
      measured.height = [FMDRenderedContent stackHeight:children gap:_gap] +
          block.layoutStyle.verticalInset;
      break;
    }
    case FMDBlockKindList: {
      const CGFloat contentX =
          block.listMarginLeft + block.markerMarginLeft + block.markerWidth;
      const CGFloat contentWidth = MAX(width - contentX, 1);
      measured.contentWidth = contentWidth;
      NSMutableArray<NSNumber *> *markerHeights = [NSMutableArray new];
      NSMutableArray<NSArray<FMDMeasuredBlock *> *> *rowContents = [NSMutableArray new];
      CGFloat height = 0;
      for (NSUInteger i = 0; i < block.rows.count; i++) {
        FMDListRow *row = block.rows[i];
        const CGSize markerSize = [self textSize:row.marker width:block.markerWidth];
        NSMutableArray<FMDMeasuredBlock *> *content = [NSMutableArray new];
        for (FMDBlock *child in row.content) {
          [content addObject:[self measureBlock:child width:contentWidth imageSizes:imageSizes]];
        }
        [markerHeights addObject:@(markerSize.height)];
        [rowContents addObject:content];
        height += MAX(markerSize.height, [FMDRenderedContent stackHeight:content gap:_gap]);
        if (i + 1 < block.rows.count) {
          height += _gap / 2;
        }
      }
      measured.markerHeights = markerHeights;
      measured.rowContents = rowContents;
      measured.height = height;
      break;
    }
    case FMDBlockKindDivider:
      measured.height = block.dividerThickness;
      break;
    case FMDBlockKindImage: {
      NSArray<NSNumber *> *known = block.imageUrl != nil ? imageSizes[block.imageUrl] : nil;
      CGFloat displayH;
      CGFloat displayW;
      if (known.count == 2 && known[0].doubleValue > 0 && known[1].doubleValue > 0) {
        const CGFloat intrinsicW = known[0].doubleValue;
        const CGFloat intrinsicH = known[1].doubleValue;
        const CGFloat scale = MIN(width / intrinsicW, 1.0);
        displayH = intrinsicH * scale;
        if (block.imageHeight > 0) {
          displayH = block.imageHeight;
        }
        if (block.imageMaxHeight > 0) {
          displayH = MIN(displayH, block.imageMaxHeight);
        }
        displayW = MIN(intrinsicW * displayH / intrinsicH, width);
      } else {
        displayH = block.imageHeight > 0 ? block.imageHeight : block.imagePlaceholder;
        if (block.imageMaxHeight > 0) {
          displayH = MIN(displayH, block.imageMaxHeight);
        }
        displayW = MIN(block.imagePlaceholder, width);
      }
      measured.height = displayH;
      measured.contentWidth = displayW;
      break;
    }
  }
  return measured;
}

@end
