#import "MarkdownTableView.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

static const CGFloat kMinColumnWidth = 60.0;
static const CGFloat kMaxColumnWidthRatio = 0.8;

@implementation MarkdownTableView {
  CGFloat _tableHeight;
  CGFloat _totalWidth;
}

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

    MarkdownElementStyle *tableStyle = styleConfig.table;
    MarkdownElementStyle *rowStyle = styleConfig.tableRow;
    MarkdownElementStyle *headerRowStyle = styleConfig.tableHeaderRow;
    MarkdownElementStyle *cellStyle = styleConfig.tableCell;
    MarkdownElementStyle *headerCellStyle = styleConfig.tableHeaderCell;

    // All styling comes from JS. If not set, we don't draw.
    UIColor *borderColor = tableStyle.borderColor;
    CGFloat borderWidth = tableStyle.borderWidth;

    // Header/body row background colors (body cells fall through to tableRow, then cell)
    UIColor *headerRowBg = headerRowStyle.backgroundColor;
    UIColor *rowBg = rowStyle.backgroundColor;

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
    NSUInteger headerRowCount = headerRows.count;

    if (allRows.count == 0) {
      _tableHeight = 0;
      return self;
    }

    NSUInteger colCount = 0;
    for (ASTNodeWrapper *row in allRows) {
      colCount = MAX(colCount, row.children.count);
    }
    if (colCount == 0) {
      _tableHeight = 0;
      return self;
    }

    // Render each cell's content as attributed string via RendererFactory.
    NSMutableArray<NSMutableArray<NSAttributedString *> *> *cellContents =
        [NSMutableArray new];
    for (NSUInteger r = 0; r < allRows.count; r++) {
      ASTNodeWrapper *row = allRows[r];
      BOOL isHeader = r < headerRowCount;

      MarkdownElementStyle *textStyle = isHeader
          ? (headerCellStyle ?: cellStyle)
          : cellStyle;

      // Compose the effective font: headerCellStyle overrides cellStyle
      UIFont *baseFont = [self effectiveFontForHeader:isHeader
                                            cellStyle:cellStyle
                                      headerCellStyle:headerCellStyle];
      UIColor *textColor = textStyle.color;

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

    // Calculate padding insets for cells (header may override)
    UIEdgeInsets cellInsets = [cellStyle resolvedPaddingInsets];
    UIEdgeInsets headerInsets = headerCellStyle
        ? [headerCellStyle resolvedPaddingInsets]
        : cellInsets;
    // If header style has no explicit padding, inherit from cellStyle
    if (headerInsets.top == 0 && headerInsets.bottom == 0 &&
        headerInsets.left == 0 && headerInsets.right == 0) {
      headerInsets = cellInsets;
    }

    // Measure natural column widths based on attributed string sizes
    CGFloat maxCellWidth = maxWidth * kMaxColumnWidthRatio;
    NSMutableArray<NSNumber *> *colWidths = [NSMutableArray new];
    for (NSUInteger c = 0; c < colCount; c++) {
      CGFloat maxW = kMinColumnWidth;
      for (NSUInteger r = 0; r < cellContents.count; r++) {
        BOOL isHeader = r < headerRowCount;
        UIEdgeInsets insets = isHeader ? headerInsets : cellInsets;
        NSAttributedString *content = cellContents[r][c];
        CGSize textSize = [content boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                                context:nil].size;
        maxW = MAX(maxW, ceil(textSize.width) + insets.left + insets.right);
      }
      maxW = MIN(maxW, maxCellWidth);
      [colWidths addObject:@(maxW)];
    }

    // Calculate total width
    _totalWidth = borderWidth;
    for (NSNumber *w in colWidths) {
      _totalWidth += w.doubleValue + borderWidth;
    }

    // Calculate per-row heights based on wrapped attributed strings
    NSMutableArray<NSNumber *> *rowHeights = [NSMutableArray new];
    for (NSUInteger r = 0; r < cellContents.count; r++) {
      BOOL isHeader = r < headerRowCount;
      UIEdgeInsets insets = isHeader ? headerInsets : cellInsets;
      CGFloat maxCellHeight = 0;
      for (NSUInteger c = 0; c < colCount; c++) {
        NSAttributedString *content = cellContents[r][c];
        CGFloat innerWidth = colWidths[c].doubleValue - insets.left - insets.right;
        CGSize textSize = [content boundingRectWithSize:CGSizeMake(innerWidth, CGFLOAT_MAX)
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                                context:nil].size;
        CGFloat cellHeight = ceil(textSize.height) + insets.top + insets.bottom;
        maxCellHeight = MAX(maxCellHeight, cellHeight);
      }
      [rowHeights addObject:@(maxCellHeight)];
    }

    // Build the grid
    CGFloat y = 0;
    UIView *gridContainer = [[UIView alloc] init];

    for (NSUInteger r = 0; r < allRows.count; r++) {
      BOOL isHeader = r < headerRowCount;
      CGFloat rowHeight = rowHeights[r].doubleValue;
      UIColor *effectiveRowBg = isHeader ? (headerRowBg ?: rowBg) : rowBg;
      UIEdgeInsets insets = isHeader ? headerInsets : cellInsets;

      // Body cell background (from tableCell.backgroundColor) falls back to row bg
      UIColor *cellBg = isHeader
          ? (headerCellStyle.backgroundColor ?: cellStyle.backgroundColor)
          : cellStyle.backgroundColor;

      CGFloat x = 0;
      for (NSUInteger c = 0; c < colCount; c++) {
        CGFloat colW = colWidths[c].doubleValue;

        UIView *cellView = [[UIView alloc] initWithFrame:
            CGRectMake(x, y, colW + borderWidth, rowHeight + borderWidth)];
        // Row background takes priority when set, otherwise use cell bg
        cellView.backgroundColor = effectiveRowBg ?: cellBg;

        // Borders — only drawn when both width and color are set in JS
        if (borderWidth > 0 && borderColor) {
          UIView *bottomBorder = [[UIView alloc] initWithFrame:
              CGRectMake(0, rowHeight, colW + borderWidth, borderWidth)];
          bottomBorder.backgroundColor = borderColor;
          [cellView addSubview:bottomBorder];

          UIView *rightBorder = [[UIView alloc] initWithFrame:
              CGRectMake(colW, 0, borderWidth, rowHeight + borderWidth)];
          rightBorder.backgroundColor = borderColor;
          [cellView addSubview:rightBorder];

          if (r == 0) {
            UIView *topBorder = [[UIView alloc] initWithFrame:
                CGRectMake(0, 0, colW + borderWidth, borderWidth)];
            topBorder.backgroundColor = borderColor;
            [cellView addSubview:topBorder];
          }

          if (c == 0) {
            UIView *leftBorder = [[UIView alloc] initWithFrame:
                CGRectMake(0, 0, borderWidth, rowHeight + borderWidth)];
            leftBorder.backgroundColor = borderColor;
            [cellView addSubview:leftBorder];
          }
        }

        // Cell label
        UILabel *label = [[UILabel alloc] initWithFrame:
            CGRectMake(insets.left,
                       insets.top,
                       colW - insets.left - insets.right,
                       rowHeight - insets.top - insets.bottom)];
        label.attributedText = (r < cellContents.count && c < cellContents[r].count)
            ? cellContents[r][c]
            : [[NSAttributedString alloc] initWithString:@""];
        label.numberOfLines = 0;
        label.lineBreakMode = NSLineBreakByWordWrapping;

        // textAlign
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

    _tableHeight = y;

    gridContainer.frame = CGRectMake(0, 0, _totalWidth, _tableHeight);
    self.contentSize = CGSizeMake(_totalWidth, _tableHeight);
    [self addSubview:gridContainer];

    // Corner radius on the inner grid so corner cells are clipped cleanly
    CGFloat radius = tableStyle.borderRadius;
    if (radius > 0) {
      gridContainer.layer.cornerRadius = radius;
      gridContainer.layer.masksToBounds = YES;
    }

    // Outer background (separate from grid, so corners can show through)
    if (tableStyle.backgroundColor) {
      self.backgroundColor = tableStyle.backgroundColor;
    }
  }
  return self;
}

- (UIFont *)effectiveFontForHeader:(BOOL)isHeader
                         cellStyle:(MarkdownElementStyle *)cellStyle
                   headerCellStyle:(MarkdownElementStyle *)headerCellStyle {
  // Cascade: header values override cell values. All come from JS.
  MarkdownElementStyle *effective = [[MarkdownElementStyle alloc] init];
  effective.fontSize = cellStyle.fontSize;
  effective.fontFamily = cellStyle.fontFamily;
  effective.fontWeight = cellStyle.fontWeight;
  effective.fontStyle = cellStyle.fontStyle;

  if (isHeader && headerCellStyle) {
    if (headerCellStyle.fontSize > 0) effective.fontSize = headerCellStyle.fontSize;
    if (headerCellStyle.fontFamily) effective.fontFamily = headerCellStyle.fontFamily;
    if (headerCellStyle.fontWeight) effective.fontWeight = headerCellStyle.fontWeight;
    if (headerCellStyle.fontStyle) effective.fontStyle = headerCellStyle.fontStyle;
  }

  return [effective resolvedFont];
}

- (NSAttributedString *)renderCellContent:(ASTNodeWrapper *)cellNode
                                 baseFont:(nullable UIFont *)baseFont
                                textColor:(nullable UIColor *)textColor
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

- (void)layoutSubviews {
  [super layoutSubviews];

  BOOL scrollable = _totalWidth > self.bounds.size.width + 0.5;
  self.scrollEnabled = scrollable;
  self.showsHorizontalScrollIndicator = scrollable;
  self.bounces = scrollable;
}

@end
