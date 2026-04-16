#import "MarkdownTableView.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

static const CGFloat kMinColumnWidth = 60.0;
static const CGFloat kMaxColumnWidthRatio = 0.8;

/// Precomputed table layout — cell contents, column widths, row heights,
/// and total size. Produced by +[MarkdownTableView computeLayout...] and
/// consumed both by the shadow-thread size query and by the actual view
/// build path so they produce identical sizes.
@interface MarkdownTableLayout : NSObject
@property (nonatomic) CGFloat totalWidth;
@property (nonatomic) CGFloat totalHeight;
@property (nonatomic, strong) NSArray<ASTNodeWrapper *> *rows;
@property (nonatomic) NSUInteger headerRowCount;
@property (nonatomic) NSUInteger colCount;
@property (nonatomic, strong) NSArray<NSNumber *> *colWidths;
@property (nonatomic, strong) NSArray<NSNumber *> *rowHeights;
@property (nonatomic, strong)
    NSArray<NSArray<NSAttributedString *> *> *cellContents;
@property (nonatomic) UIEdgeInsets cellInsets;
@property (nonatomic) UIEdgeInsets headerInsets;
@end

@implementation MarkdownTableLayout
@end

@implementation MarkdownTableView {
  CGFloat _tableHeight;
  CGFloat _totalWidth;
  BOOL _scrollBlockingConfigured;
}

#pragma mark - Layout computation (shared by view build + shadow-thread measure)

+ (UIFont *)effectiveFontForHeader:(BOOL)isHeader
                         cellStyle:(MarkdownElementStyle *)cellStyle
                   headerCellStyle:(MarkdownElementStyle *)headerCellStyle
                       styleConfig:(StyleConfig *)styleConfig {
  UIFont *baseFont = [styleConfig.base resolvedFont];
  UIFont *cellFont = [cellStyle resolvedFontWithBase:baseFont] ?: baseFont;
  if (isHeader && headerCellStyle) {
    return [headerCellStyle resolvedFontWithBase:cellFont] ?: cellFont;
  }
  return cellFont;
}

+ (NSAttributedString *)renderCellContent:(ASTNodeWrapper *)cellNode
                                 baseFont:(UIFont *)baseFont
                                textColor:(UIColor *)textColor
                              styleConfig:(StyleConfig *)styleConfig {
  RenderContext *context = [[RenderContext alloc] init];
  context.styleConfig = styleConfig;

  NSMutableDictionary *baseAttrs = [NSMutableDictionary new];
  if (baseFont) baseAttrs[NSFontAttributeName] = baseFont;
  if (textColor) baseAttrs[NSForegroundColorAttributeName] = textColor;
  if (baseAttrs.count > 0) {
    [context pushAttributes:baseAttrs];
  }

  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] init];
  for (ASTNodeWrapper *child in cellNode.children) {
    id<NodeRenderer> renderer = [RendererFactory rendererForNode:child];
    if (renderer) {
      [renderer renderNode:child into:output context:context];
    }
  }

  if (output.length > 0) {
    unichar last = [output.string characterAtIndex:output.length - 1];
    if (last == '\n') {
      [output deleteCharactersInRange:NSMakeRange(output.length - 1, 1)];
    }
  }

  return [output copy];
}

+ (MarkdownTableLayout *)computeLayoutForTableNode:(ASTNodeWrapper *)tableNode
                                       styleConfig:(StyleConfig *)styleConfig
                                          maxWidth:(CGFloat)maxWidth {
  MarkdownTableLayout *layout = [MarkdownTableLayout new];

  MarkdownElementStyle *cellStyle = styleConfig.tableCell;
  MarkdownElementStyle *headerCellStyle = styleConfig.tableHeaderCell;

  // Cell-grid division width (used to reserve space between cells
  // during layout). Read from tableCell; the outer table border is
  // handled by the wrapping MarkdownBlockView and doesn't influence
  // the scrollable grid size here.
  CGFloat borderWidth = cellStyle.borderWidth;

  // Collect rows
  NSMutableArray<ASTNodeWrapper *> *headerRows = [NSMutableArray new];
  NSMutableArray<ASTNodeWrapper *> *bodyRows = [NSMutableArray new];

  for (ASTNodeWrapper *child in tableNode.children) {
    if (child.nodeType == MDNodeTypeTableHead) {
      for (ASTNodeWrapper *row in child.children) {
        if (row.nodeType == MDNodeTypeTableRow) {
          [headerRows addObject:row];
        }
      }
    } else if (child.nodeType == MDNodeTypeTableBody) {
      for (ASTNodeWrapper *row in child.children) {
        if (row.nodeType == MDNodeTypeTableRow) {
          [bodyRows addObject:row];
        }
      }
    } else if (child.nodeType == MDNodeTypeTableRow) {
      [bodyRows addObject:child];
    }
  }

  NSArray<ASTNodeWrapper *> *allRows =
      [headerRows arrayByAddingObjectsFromArray:bodyRows];
  layout.rows = allRows;
  layout.headerRowCount = headerRows.count;

  if (allRows.count == 0) return layout;

  NSUInteger colCount = 0;
  for (ASTNodeWrapper *row in allRows) {
    colCount = MAX(colCount, row.children.count);
  }
  layout.colCount = colCount;
  if (colCount == 0) return layout;

  // Render each cell's content
  NSMutableArray<NSMutableArray<NSAttributedString *> *> *cellContents =
      [NSMutableArray new];
  for (NSUInteger r = 0; r < allRows.count; r++) {
    ASTNodeWrapper *row = allRows[r];
    BOOL isHeader = r < layout.headerRowCount;

    MarkdownElementStyle *textStyle =
        isHeader ? (headerCellStyle ?: cellStyle) : cellStyle;

    UIFont *baseFont = [self effectiveFontForHeader:isHeader
                                          cellStyle:cellStyle
                                    headerCellStyle:headerCellStyle
                                        styleConfig:styleConfig];
    UIColor *textColor = textStyle.color ?: styleConfig.base.color;

    NSMutableArray<NSAttributedString *> *rowContents = [NSMutableArray new];
    for (NSUInteger c = 0; c < colCount; c++) {
      NSAttributedString *content = nil;
      if (c < row.children.count) {
        content = [self renderCellContent:row.children[c]
                                 baseFont:baseFont
                                textColor:textColor
                              styleConfig:styleConfig];
      }
      if (!content) {
        content = [[NSAttributedString alloc] initWithString:@""];
      }
      [rowContents addObject:content];
    }
    [cellContents addObject:rowContents];
  }
  layout.cellContents = cellContents;

  // Padding insets (header may override)
  UIEdgeInsets cellInsets = [cellStyle resolvedPaddingInsets];
  UIEdgeInsets headerInsets = headerCellStyle
                                  ? [headerCellStyle resolvedPaddingInsets]
                                  : cellInsets;
  if (headerInsets.top == 0 && headerInsets.bottom == 0 &&
      headerInsets.left == 0 && headerInsets.right == 0) {
    headerInsets = cellInsets;
  }
  layout.cellInsets = cellInsets;
  layout.headerInsets = headerInsets;

  // Column widths
  CGFloat maxCellWidth = maxWidth * kMaxColumnWidthRatio;
  NSMutableArray<NSNumber *> *colWidths = [NSMutableArray new];
  for (NSUInteger c = 0; c < colCount; c++) {
    CGFloat maxW = kMinColumnWidth;
    for (NSUInteger r = 0; r < cellContents.count; r++) {
      BOOL isHeader = r < layout.headerRowCount;
      UIEdgeInsets insets = isHeader ? headerInsets : cellInsets;
      NSAttributedString *content = cellContents[r][c];
      CGSize textSize =
          [content boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                options:NSStringDrawingUsesLineFragmentOrigin
                                context:nil]
              .size;
      maxW = MAX(maxW, ceil(textSize.width) + insets.left + insets.right);
    }
    maxW = MIN(maxW, maxCellWidth);
    [colWidths addObject:@(maxW)];
  }
  layout.colWidths = colWidths;

  // Total width
  CGFloat totalWidth = borderWidth;
  for (NSNumber *w in colWidths) {
    totalWidth += w.doubleValue + borderWidth;
  }
  layout.totalWidth = totalWidth;

  // Per-row heights (wrapped at the computed column widths)
  NSMutableArray<NSNumber *> *rowHeights = [NSMutableArray new];
  CGFloat totalHeight = 0;
  for (NSUInteger r = 0; r < cellContents.count; r++) {
    BOOL isHeader = r < layout.headerRowCount;
    UIEdgeInsets insets = isHeader ? headerInsets : cellInsets;
    CGFloat maxCellHeight = 0;
    for (NSUInteger c = 0; c < colCount; c++) {
      NSAttributedString *content = cellContents[r][c];
      CGFloat innerWidth = colWidths[c].doubleValue - insets.left - insets.right;
      CGSize textSize =
          [content boundingRectWithSize:CGSizeMake(innerWidth, CGFLOAT_MAX)
                                options:NSStringDrawingUsesLineFragmentOrigin
                                context:nil]
              .size;
      CGFloat cellHeight = ceil(textSize.height) + insets.top + insets.bottom;
      maxCellHeight = MAX(maxCellHeight, cellHeight);
    }
    [rowHeights addObject:@(maxCellHeight)];
    totalHeight += maxCellHeight + borderWidth;
  }
  layout.rowHeights = rowHeights;
  layout.totalHeight = totalHeight;

  return layout;
}

+ (CGSize)sizeForTableNode:(ASTNodeWrapper *)tableNode
               styleConfig:(StyleConfig *)styleConfig
                  maxWidth:(CGFloat)maxWidth {
  MarkdownTableLayout *layout = [self computeLayoutForTableNode:tableNode
                                                     styleConfig:styleConfig
                                                        maxWidth:maxWidth];
  return CGSizeMake(layout.totalWidth, layout.totalHeight);
}

#pragma mark - Init / view build

- (instancetype)initWithTableNode:(ASTNodeWrapper *)tableNode
                      styleConfig:(StyleConfig *)styleConfig
                         maxWidth:(CGFloat)maxWidth {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.showsVerticalScrollIndicator = NO;
    self.backgroundColor = [UIColor clearColor];
    self.alwaysBounceHorizontal = NO;
    self.alwaysBounceVertical = NO;
    self.bounces = NO;
    self.showsHorizontalScrollIndicator = NO;

    MarkdownTableLayout *layout =
        [MarkdownTableView computeLayoutForTableNode:tableNode
                                          styleConfig:styleConfig
                                             maxWidth:maxWidth];

    _totalWidth = layout.totalWidth;
    _tableHeight = layout.totalHeight;

    if (layout.rows.count == 0 || layout.colCount == 0) return self;

    MarkdownElementStyle *tableStyle = styleConfig.table;
    MarkdownElementStyle *rowStyle = styleConfig.tableRow;
    MarkdownElementStyle *headerRowStyle = styleConfig.tableHeaderRow;
    MarkdownElementStyle *cellStyle = styleConfig.tableCell;
    MarkdownElementStyle *headerCellStyle = styleConfig.tableHeaderCell;

    // The cell-grid lines come from tableCell (the cell's own border).
    // The outer table box is drawn separately by the MarkdownBlockView
    // wrapper using tableStyle.borderColor / borderWidth, so we don't
    // read those here — otherwise setting table.borderWidth alone would
    // leak onto every cell division too.
    UIColor *borderColor = cellStyle.borderColor;
    CGFloat borderWidth = cellStyle.borderWidth;
    UIColor *headerRowBg = headerRowStyle.backgroundColor;
    UIColor *rowBg = rowStyle.backgroundColor;

    // Build the grid using the precomputed layout
    CGFloat y = 0;
    UIView *gridContainer = [[UIView alloc] init];

    for (NSUInteger r = 0; r < layout.rows.count; r++) {
      BOOL isHeader = r < layout.headerRowCount;
      CGFloat rowHeight = layout.rowHeights[r].doubleValue;
      UIColor *effectiveRowBg = isHeader ? (headerRowBg ?: rowBg) : rowBg;
      UIEdgeInsets insets = isHeader ? layout.headerInsets : layout.cellInsets;

      UIColor *cellBg = isHeader
          ? (headerCellStyle.backgroundColor ?: cellStyle.backgroundColor)
          : cellStyle.backgroundColor;

      CGFloat x = 0;
      for (NSUInteger c = 0; c < layout.colCount; c++) {
        CGFloat colW = layout.colWidths[c].doubleValue;

        UIView *cellView = [[UIView alloc]
            initWithFrame:CGRectMake(x, y, colW + borderWidth,
                                     rowHeight + borderWidth)];
        cellView.backgroundColor = effectiveRowBg ?: cellBg;

        if (borderWidth > 0 && borderColor) {
          UIView *bottomBorder = [[UIView alloc]
              initWithFrame:CGRectMake(0, rowHeight, colW + borderWidth,
                                       borderWidth)];
          bottomBorder.backgroundColor = borderColor;
          [cellView addSubview:bottomBorder];

          UIView *rightBorder = [[UIView alloc]
              initWithFrame:CGRectMake(colW, 0, borderWidth,
                                       rowHeight + borderWidth)];
          rightBorder.backgroundColor = borderColor;
          [cellView addSubview:rightBorder];

          if (r == 0) {
            UIView *topBorder = [[UIView alloc]
                initWithFrame:CGRectMake(0, 0, colW + borderWidth,
                                         borderWidth)];
            topBorder.backgroundColor = borderColor;
            [cellView addSubview:topBorder];
          }

          if (c == 0) {
            UIView *leftBorder = [[UIView alloc]
                initWithFrame:CGRectMake(0, 0, borderWidth,
                                         rowHeight + borderWidth)];
            leftBorder.backgroundColor = borderColor;
            [cellView addSubview:leftBorder];
          }
        }

        UILabel *label = [[UILabel alloc]
            initWithFrame:CGRectMake(insets.left, insets.top,
                                     colW - insets.left - insets.right,
                                     rowHeight - insets.top - insets.bottom)];
        label.attributedText = layout.cellContents[r][c];
        label.numberOfLines = 0;
        label.lineBreakMode = NSLineBreakByWordWrapping;

        NSString *textAlign = isHeader
            ? (headerCellStyle.textAlign ?: cellStyle.textAlign)
            : cellStyle.textAlign;
        if ([textAlign isEqualToString:@"center"]) {
          label.textAlignment = NSTextAlignmentCenter;
        } else if ([textAlign isEqualToString:@"right"]) {
          label.textAlignment = NSTextAlignmentRight;
        } else {
          label.textAlignment = NSTextAlignmentLeft;
        }

        [cellView addSubview:label];
        [gridContainer addSubview:cellView];
        x += colW + borderWidth;
      }
      y += rowHeight + borderWidth;
    }

    gridContainer.frame = CGRectMake(0, 0, _totalWidth, _tableHeight);
    self.contentSize = CGSizeMake(_totalWidth, _tableHeight);
    [self addSubview:gridContainer];

    CGFloat radius = tableStyle.borderRadius;
    if (radius > 0) {
      gridContainer.layer.cornerRadius = radius;
      gridContainer.layer.masksToBounds = YES;
    }

    if (tableStyle.backgroundColor) {
      self.backgroundColor = tableStyle.backgroundColor;
    }
  }
  return self;
}

- (CGSize)sizeThatFits:(CGSize)size {
  // UIScrollView's default sizeThatFits returns bounds.size which is
  // useless here. Return the actual rendered table size so parent
  // layout (MarkdownBlockView → MarkdownSegmentStackView) can size us.
  return CGSizeMake(_totalWidth, _tableHeight);
}

- (void)layoutSubviews {
  [super layoutSubviews];

  BOOL scrollable = _totalWidth > self.bounds.size.width + 0.5;
  self.scrollEnabled = scrollable;
  self.showsHorizontalScrollIndicator = scrollable;
  self.bounces = scrollable;

  if (scrollable) {
    [self installScrollBlockingIfNeeded];
  }
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  // Retry if layoutSubviews ran before the view was in a window.
  if (self.window && self.scrollEnabled) {
    [self installScrollBlockingIfNeeded];
  }
}

#pragma mark - Hit testing

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  // When the table content fits within the visible width, scrolling
  // is disabled and the UIScrollView doesn't need to handle any
  // gestures. Return nil so the touch passes through to a parent
  // Pressable (React Native or React Native Gesture Handler).
  if (!self.scrollEnabled) {
    return nil;
  }
  // Return self (not the deepest subview) so the touch is
  // identified as landing on a UIScrollView. The table's internal
  // labels don't need their own touch handling — only the pan
  // gesture recognizer on the scroll view matters.
  return [self pointInside:point withEvent:event] ? self : nil;
}

#pragma mark - Scroll-blocking coordination

/// Makes ancestor touch handlers (RCTSurfaceTouchHandler, RNGH
/// handlers) wait for our panGestureRecognizer to fail before
/// recognizing. Effect:
///   • User scrolls → pan recognizes → ancestor handlers fail →
///     parent Pressable does NOT fire.
///   • User taps → pan fails → ancestor handlers can recognize →
///     parent Pressable fires.
- (void)installScrollBlockingIfNeeded {
  if (_scrollBlockingConfigured) return;
  if (!self.window) return;
  _scrollBlockingConfigured = YES;

  UIPanGestureRecognizer *panGR = self.panGestureRecognizer;
  UIView *ancestor = self.superview;
  while (ancestor) {
    for (UIGestureRecognizer *gr in ancestor.gestureRecognizers) {
      // Skip pan recognizers — those drive parent scroll views
      // (FlatList, ScrollView) and must stay unblocked.
      if ([gr isKindOfClass:[UIPanGestureRecognizer class]]) continue;
      [gr requireGestureRecognizerToFail:panGR];
    }
    ancestor = ancestor.superview;
  }
}

@end
