#import "FMDTableView.h"

#import "FMDBlockTextView.h"

/// The unclipped grid inside the scroller: row boxes + cell text.
@interface FMDTableGridView : UIView
- (void)bind:(FMDMeasuredBlock *)measured host:(nullable id<FMDMarkdownHost>)host;
@end

@implementation FMDTableGridView {
  FMDMeasuredBlock *_measured;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.backgroundColor = UIColor.clearColor;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (void)bind:(FMDMeasuredBlock *)measured host:(nullable id<FMDMarkdownHost>)host {
  _measured = measured;
  for (UIView *subview in [self.subviews copy]) {
    [subview removeFromSuperview];
  }
  FMDBlock *block = measured.block;
  for (FMDTableRow *row in block.tableRows) {
    for (NSAttributedString *cell in row.cells) {
      FMDBlockTextView *view = [[FMDBlockTextView alloc] initWithFrame:CGRectZero];
      view.host = host;
      view.attributedText = cell;
      [self addSubview:view];
    }
  }
  [self setNeedsDisplay];
  [self setNeedsLayout];
}

- (void)drawRect:(CGRect)rect {
  FMDBlock *block = _measured.block;
  FMDLayoutStyle *rowStyle = block.rowStyle;
  CGContextRef context = UIGraphicsGetCurrentContext();
  const CGFloat width = _measured.contentWidth;

  CGFloat y = 0;
  for (NSNumber *rowHeight in _measured.rowHeights) {
    if (rowStyle.backgroundColor != nil) {
      CGContextSetFillColorWithColor(context, rowStyle.backgroundColor.CGColor);
      CGContextFillRect(context, CGRectMake(0, y, width, rowHeight.doubleValue));
    }
    if (rowStyle.borderBottomWidth > 0 && rowStyle.borderBottomColor != nil) {
      CGContextSetFillColorWithColor(context, rowStyle.borderBottomColor.CGColor);
      CGContextFillRect(
          context,
          CGRectMake(
              0,
              y + rowHeight.doubleValue - rowStyle.borderBottomWidth,
              width,
              rowStyle.borderBottomWidth));
    }
    if (rowStyle.borderTopWidth > 0 && rowStyle.borderTopColor != nil) {
      CGContextSetFillColorWithColor(context, rowStyle.borderTopColor.CGColor);
      CGContextFillRect(context, CGRectMake(0, y, width, rowStyle.borderTopWidth));
    }
    y += rowHeight.doubleValue;
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  FMDBlock *block = _measured.block;
  const CGFloat cellPadH = block.cellPadding.left + block.cellPadding.right;

  NSUInteger index = 0;
  CGFloat y = 0;
  for (NSUInteger rowIndex = 0; rowIndex < block.tableRows.count; rowIndex++) {
    FMDTableRow *row = block.tableRows[rowIndex];
    CGFloat x = 0;
    for (NSUInteger column = 0; column < row.cells.count; column++) {
      if (index >= self.subviews.count) {
        break;
      }
      const CGFloat columnWidth = _measured.columnWidths[column].doubleValue;
      const CGFloat cellHeight = _measured.rowHeights[rowIndex].doubleValue -
          block.cellPadding.top - block.cellPadding.bottom -
          block.rowStyle.borderTopWidth - block.rowStyle.borderBottomWidth;
      self.subviews[index].frame = CGRectMake(
          x + block.cellPadding.left,
          y + block.cellPadding.top + block.rowStyle.borderTopWidth,
          MAX(columnWidth - cellPadH, 1),
          MAX(cellHeight, 0));
      index++;
      x += columnWidth;
    }
    y += _measured.rowHeights[rowIndex].doubleValue;
  }
}

@end

@implementation FMDTableView {
  FMDMeasuredBlock *_measured;
  UIScrollView *_scroller;
  FMDTableGridView *_grid;
}

- (void)bind:(FMDMeasuredBlock *)measured host:(nullable id<FMDMarkdownHost>)host {
  _measured = measured;
  if (_scroller == nil) {
    _scroller = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scroller.showsHorizontalScrollIndicator = NO;
    _scroller.showsVerticalScrollIndicator = NO;
    _scroller.alwaysBounceVertical = NO;
    _scroller.delaysContentTouches = NO;
    _scroller.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _grid = [[FMDTableGridView alloc] initWithFrame:CGRectZero];
    [_scroller addSubview:_grid];
    [self addSubview:_scroller];
  }

  FMDLayoutStyle *style = measured.block.layoutStyle;
  self.backgroundColor = style.backgroundColor ?: UIColor.clearColor;
  self.layer.cornerRadius = style.borderRadius;
  self.layer.cornerCurve =
      style.continuousCorners ? kCACornerCurveContinuous : kCACornerCurveCircular;
  self.layer.masksToBounds = style.borderRadius > 0;

  [_grid bind:measured host:host];
  [self setNeedsLayout];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  FMDLayoutStyle *style = _measured.block.layoutStyle;
  CGFloat gridHeight = 0;
  for (NSNumber *rowHeight in _measured.rowHeights) {
    gridHeight += rowHeight.doubleValue;
  }
  const CGFloat left = style.borderLeftWidth + style.paddingLeft;
  const CGFloat top = style.borderTopWidth + style.paddingTop;
  _scroller.frame = CGRectMake(
      left,
      top,
      self.bounds.size.width - left - style.borderRightWidth - style.paddingRight,
      gridHeight);
  _grid.frame = CGRectMake(0, 0, _measured.contentWidth, gridHeight);
  _scroller.contentSize = CGSizeMake(_measured.contentWidth, gridHeight);
}

@end
