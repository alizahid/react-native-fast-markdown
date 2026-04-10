#import "MarkdownTableView.h"
#import "ASTNodeWrapper.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

static const CGFloat kDefaultCellPadding = 10.0;
static const CGFloat kDefaultBorderWidth = 1.0;
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

    MarkdownElementStyle *style = styleConfig.table;
    CGFloat cellPadding = (style && style.cellPadding > 0) ? style.cellPadding : kDefaultCellPadding;
    CGFloat borderWidth = (style && style.borderWidth > 0) ? style.borderWidth : kDefaultBorderWidth;
    UIColor *borderColor = style.borderColor ?: [UIColor separatorColor];
    UIColor *headerBg = style.headerBackgroundColor ?: [UIColor colorWithWhite:0.95 alpha:1.0];
    UIColor *cellBg = style.backgroundColor ?: [UIColor clearColor];
    UIFont *headerFont = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    UIFont *cellFont = [UIFont systemFontOfSize:14];
    UIColor *textColor = style.color ?: [UIColor labelColor];

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

    // Render each cell's content as an attributed string via RendererFactory.
    // This handles bold, italic, code, links, etc. inside cells.
    NSMutableArray<NSMutableArray<NSAttributedString *> *> *cellContents =
        [NSMutableArray new];
    for (NSUInteger r = 0; r < allRows.count; r++) {
      ASTNodeWrapper *row = allRows[r];
      BOOL isHeader = r < headerRowCount;
      UIFont *baseFont = isHeader ? headerFont : cellFont;

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

    // Measure natural column widths based on attributed string sizes
    CGFloat maxCellWidth = maxWidth * kMaxColumnWidthRatio;
    NSMutableArray<NSNumber *> *colWidths = [NSMutableArray new];
    for (NSUInteger c = 0; c < colCount; c++) {
      CGFloat maxW = kMinColumnWidth;
      for (NSUInteger r = 0; r < cellContents.count; r++) {
        NSAttributedString *content = cellContents[r][c];
        CGSize textSize = [content boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                                context:nil].size;
        maxW = MAX(maxW, ceil(textSize.width) + cellPadding * 2);
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
      CGFloat maxCellHeight = ceil(cellFont.lineHeight) + cellPadding * 2;
      for (NSUInteger c = 0; c < colCount; c++) {
        NSAttributedString *content = cellContents[r][c];
        CGFloat innerWidth = colWidths[c].doubleValue - cellPadding * 2;
        CGSize textSize = [content boundingRectWithSize:CGSizeMake(innerWidth, CGFLOAT_MAX)
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                                context:nil].size;
        CGFloat cellHeight = ceil(textSize.height) + cellPadding * 2;
        maxCellHeight = MAX(maxCellHeight, cellHeight);
      }
      [rowHeights addObject:@(maxCellHeight)];
    }

    // Build the grid
    CGFloat y = 0;
    UIView *gridContainer = [[UIView alloc] init];

    for (NSUInteger r = 0; r < allRows.count; r++) {
      BOOL isHeader = r < headerRowCount;
      UIColor *rowBg = isHeader ? headerBg : cellBg;
      CGFloat rowHeight = rowHeights[r].doubleValue;

      CGFloat x = 0;
      for (NSUInteger c = 0; c < colCount; c++) {
        CGFloat colW = colWidths[c].doubleValue;

        UIView *cellView = [[UIView alloc] initWithFrame:
            CGRectMake(x, y, colW + borderWidth, rowHeight + borderWidth)];
        cellView.backgroundColor = rowBg;

        // Borders
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

        // Cell label — use attributed text directly
        UILabel *label = [[UILabel alloc] initWithFrame:
            CGRectMake(cellPadding, cellPadding,
                       colW - cellPadding * 2,
                       rowHeight - cellPadding * 2)];
        label.attributedText = (r < cellContents.count && c < cellContents[r].count)
            ? cellContents[r][c]
            : [[NSAttributedString alloc] initWithString:@""];
        label.numberOfLines = 0;
        label.lineBreakMode = NSLineBreakByWordWrapping;
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

    // Apply corner radius to the inner grid so corner cells are clipped
    // cleanly. The scroll view itself has no corner radius — that was
    // causing the cells at the edges to look cut off because the scroll
    // view's mask clipped them.
    CGFloat radius = (style && style.borderRadius > 0) ? style.borderRadius : 6;
    gridContainer.layer.cornerRadius = radius;
    gridContainer.layer.masksToBounds = YES;
  }
  return self;
}

- (NSAttributedString *)renderCellContent:(ASTNodeWrapper *)cellNode
                                 baseFont:(UIFont *)baseFont
                                textColor:(UIColor *)textColor
                              styleConfig:(StyleConfig *)styleConfig {
  RenderContext *context = [[RenderContext alloc] init];
  context.styleConfig = styleConfig;
  [context pushAttributes:@{
    NSFontAttributeName : baseFont,
    NSForegroundColorAttributeName : textColor,
  }];

  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] init];
  // TableCell's children are inline nodes (Text, Strong, Emphasis, Code, Link, etc.)
  for (ASTNodeWrapper *child in cellNode.children) {
    id<NodeRenderer> renderer = [RendererFactory rendererForNode:child];
    if (renderer) {
      [renderer renderNode:child into:output context:context];
    }
  }

  // Trim trailing newline if any
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
