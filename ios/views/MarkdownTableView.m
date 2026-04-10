#import "MarkdownTableView.h"
#import "ASTNodeWrapper.h"
#import "StyleConfig.h"

static const CGFloat kDefaultCellPadding = 10.0;
static const CGFloat kDefaultBorderWidth = 1.0;
static const CGFloat kMinColumnWidth = 60.0;
static const CGFloat kMaxColumnWidthRatio = 0.8; // Cap single column at 80% of container

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

    // Extract cell text
    NSMutableArray<NSMutableArray<NSString *> *> *cellTexts = [NSMutableArray new];
    for (ASTNodeWrapper *row in allRows) {
      NSMutableArray<NSString *> *rowTexts = [NSMutableArray new];
      for (NSUInteger c = 0; c < colCount; c++) {
        if (c < row.children.count) {
          NSString *text = [self extractText:row.children[c]];
          [rowTexts addObject:text];
        } else {
          [rowTexts addObject:@""];
        }
      }
      [cellTexts addObject:rowTexts];
    }

    // Measure natural column widths
    CGFloat maxCellWidth = maxWidth * kMaxColumnWidthRatio;
    NSMutableArray<NSNumber *> *colWidths = [NSMutableArray new];
    for (NSUInteger c = 0; c < colCount; c++) {
      CGFloat maxW = kMinColumnWidth;
      for (NSUInteger r = 0; r < cellTexts.count; r++) {
        NSString *text = cellTexts[r][c];
        UIFont *font = (r < headerRowCount) ? headerFont : cellFont;
        CGSize textSize = [text boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:@{NSFontAttributeName: font}
                                             context:nil].size;
        maxW = MAX(maxW, ceil(textSize.width) + cellPadding * 2);
      }
      // Cap column width at the max allowed — long cells will wrap
      maxW = MIN(maxW, maxCellWidth);
      [colWidths addObject:@(maxW)];
    }

    // Calculate total width
    _totalWidth = borderWidth;
    for (NSNumber *w in colWidths) {
      _totalWidth += w.doubleValue + borderWidth;
    }

    // Calculate per-row heights (cells may wrap to multiple lines now)
    NSMutableArray<NSNumber *> *rowHeights = [NSMutableArray new];
    for (NSUInteger r = 0; r < cellTexts.count; r++) {
      BOOL isHeader = r < headerRowCount;
      UIFont *font = isHeader ? headerFont : cellFont;
      CGFloat maxCellHeight = ceil(font.lineHeight) + cellPadding * 2;

      for (NSUInteger c = 0; c < colCount; c++) {
        NSString *text = cellTexts[r][c];
        CGFloat colW = colWidths[c].doubleValue - cellPadding * 2;
        CGSize textSize = [text boundingRectWithSize:CGSizeMake(colW, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:@{NSFontAttributeName: font}
                                             context:nil].size;
        CGFloat cellHeight = ceil(textSize.height) + cellPadding * 2;
        maxCellHeight = MAX(maxCellHeight, cellHeight);
      }
      [rowHeights addObject:@(maxCellHeight)];
    }

    // Build the grid with variable row heights
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

        // Text label (now multi-line)
        UILabel *label = [[UILabel alloc] initWithFrame:
            CGRectMake(cellPadding, cellPadding,
                       colW - cellPadding * 2,
                       rowHeight - cellPadding * 2)];
        label.text = (r < cellTexts.count && c < cellTexts[r].count)
            ? cellTexts[r][c] : @"";
        label.font = isHeader ? headerFont : cellFont;
        label.textColor = textColor;
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

    self.layer.cornerRadius = 6;
    self.layer.masksToBounds = YES;
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];

  // Enable scrolling/indicators only when content exceeds visible width
  BOOL scrollable = _totalWidth > self.bounds.size.width + 0.5;
  self.scrollEnabled = scrollable;
  self.showsHorizontalScrollIndicator = scrollable;
  self.bounces = scrollable;
}

- (NSString *)extractText:(ASTNodeWrapper *)node {
  if (node.content.length > 0) {
    return node.content;
  }

  NSMutableString *text = [NSMutableString new];
  for (ASTNodeWrapper *child in node.children) {
    [text appendString:[self extractText:child]];
  }
  return text;
}

@end
