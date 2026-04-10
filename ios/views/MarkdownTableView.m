#import "MarkdownTableView.h"
#import "ASTNodeWrapper.h"
#import "StyleConfig.h"

static const CGFloat kDefaultCellPadding = 10.0;
static const CGFloat kDefaultBorderWidth = 1.0;
static const CGFloat kMinColumnWidth = 60.0;

@implementation MarkdownTableView {
  CGFloat _tableHeight;
}

- (instancetype)initWithTableNode:(ASTNodeWrapper *)tableNode
                      styleConfig:(StyleConfig *)styleConfig
                         maxWidth:(CGFloat)maxWidth {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.showsVerticalScrollIndicator = NO;
    self.backgroundColor = [UIColor clearColor];

    MarkdownElementStyle *style = styleConfig.table;
    CGFloat cellPadding = (style && style.cellPadding > 0) ? style.cellPadding : kDefaultCellPadding;
    CGFloat borderWidth = (style && style.borderWidth > 0) ? style.borderWidth : kDefaultBorderWidth;
    UIColor *borderColor = style.borderColor ?: [UIColor separatorColor];
    UIColor *headerBg = style.headerBackgroundColor ?: [UIColor colorWithWhite:0.95 alpha:1.0];
    UIColor *cellBg = style.backgroundColor ?: [UIColor clearColor];
    UIFont *headerFont = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    UIFont *cellFont = [UIFont systemFontOfSize:14];
    UIColor *textColor = style.color ?: [UIColor labelColor];

    // Collect rows: first from TableHead, then from TableBody
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

    // Determine column count
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

    // Measure column widths
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
      [colWidths addObject:@(maxW)];
    }

    // Calculate total width and row height
    CGFloat totalWidth = borderWidth;
    for (NSNumber *w in colWidths) {
      totalWidth += w.doubleValue + borderWidth;
    }
    CGFloat rowHeight = ceil(cellFont.lineHeight) + cellPadding * 2;

    // Build the grid
    CGFloat y = 0;
    UIView *gridContainer = [[UIView alloc] init];

    for (NSUInteger r = 0; r < allRows.count; r++) {
      BOOL isHeader = r < headerRowCount;
      UIColor *rowBg = isHeader ? headerBg : cellBg;

      CGFloat x = 0;
      for (NSUInteger c = 0; c < colCount; c++) {
        CGFloat colW = colWidths[c].doubleValue;

        // Cell container
        UIView *cellView = [[UIView alloc] initWithFrame:
            CGRectMake(x, y, colW + borderWidth, rowHeight + borderWidth)];
        cellView.backgroundColor = rowBg;

        // Border (bottom and right)
        UIView *bottomBorder = [[UIView alloc] initWithFrame:
            CGRectMake(0, rowHeight, colW + borderWidth, borderWidth)];
        bottomBorder.backgroundColor = borderColor;
        [cellView addSubview:bottomBorder];

        UIView *rightBorder = [[UIView alloc] initWithFrame:
            CGRectMake(colW, 0, borderWidth, rowHeight + borderWidth)];
        rightBorder.backgroundColor = borderColor;
        [cellView addSubview:rightBorder];

        // Top border for first row
        if (r == 0) {
          UIView *topBorder = [[UIView alloc] initWithFrame:
              CGRectMake(0, 0, colW + borderWidth, borderWidth)];
          topBorder.backgroundColor = borderColor;
          [cellView addSubview:topBorder];
        }

        // Left border for first column
        if (c == 0) {
          UIView *leftBorder = [[UIView alloc] initWithFrame:
              CGRectMake(0, 0, borderWidth, rowHeight + borderWidth)];
          leftBorder.backgroundColor = borderColor;
          [cellView addSubview:leftBorder];
        }

        // Text label
        UILabel *label = [[UILabel alloc] initWithFrame:
            CGRectMake(cellPadding, 0, colW - cellPadding * 2, rowHeight)];
        label.text = (r < cellTexts.count && c < cellTexts[r].count)
            ? cellTexts[r][c] : @"";
        label.font = isHeader ? headerFont : cellFont;
        label.textColor = textColor;
        label.numberOfLines = 1;
        [cellView addSubview:label];

        [gridContainer addSubview:cellView];
        x += colW + borderWidth;
      }
      y += rowHeight + borderWidth;
    }

    _tableHeight = y;

    // Content size is the actual grid width — no forced expansion.
    // Only scroll if the grid is wider than the container.
    gridContainer.frame = CGRectMake(0, 0, totalWidth, _tableHeight);
    self.contentSize = CGSizeMake(totalWidth, _tableHeight);
    self.bounces = totalWidth > maxWidth;
    self.showsHorizontalScrollIndicator = totalWidth > maxWidth;
    [self addSubview:gridContainer];

    // Round corners
    self.layer.cornerRadius = 6;
    self.layer.masksToBounds = YES;
    self.layer.borderWidth = 0;
  }
  return self;
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
