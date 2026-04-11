#import "MarkdownBlockView.h"
#import "StyleConfig.h"

@implementation MarkdownBlockView {
  // Per-side border subviews (used when borders are non-uniform)
  UIView *_topBorderView;
  UIView *_bottomBorderView;
  UIView *_leftBorderView;
  UIView *_rightBorderView;

  // Shape layer mask for per-corner radii
  CAShapeLayer *_cornerMaskLayer;
}

- (instancetype)initWithStyle:(MarkdownElementStyle *)style {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _style = style;
    [self applyStyle];
  }
  return self;
}

- (void)setStyle:(MarkdownElementStyle *)style {
  _style = style;
  [self applyStyle];
  [self setNeedsLayout];
}

- (void)setContentView:(UIView *)contentView {
  if (_contentView) {
    [_contentView removeFromSuperview];
  }
  _contentView = contentView;
  if (contentView) {
    [self addSubview:contentView];
    // Border subviews should stay on top of content
    [self bringSubviewsToFront];
  }
  [self setNeedsLayout];
}

- (void)bringSubviewsToFront {
  if (_topBorderView) [self bringSubviewToFront:_topBorderView];
  if (_bottomBorderView) [self bringSubviewToFront:_bottomBorderView];
  if (_leftBorderView) [self bringSubviewToFront:_leftBorderView];
  if (_rightBorderView) [self bringSubviewToFront:_rightBorderView];
}

- (void)applyStyle {
  // Background color
  self.backgroundColor = _style.backgroundColor ?: [UIColor clearColor];

  BOOL nonUniform = [_style hasNonUniformBorders];
  BOOL hasBorder = [_style hasAnyBorder];
  BOOL hasRadius = [_style hasAnyRadius];

  // Clean up previous edge views
  [_topBorderView removeFromSuperview];
  [_bottomBorderView removeFromSuperview];
  [_leftBorderView removeFromSuperview];
  [_rightBorderView removeFromSuperview];
  _topBorderView = _bottomBorderView = _leftBorderView = _rightBorderView = nil;

  if (hasBorder && nonUniform) {
    // Use subview edges for per-side borders
    UIEdgeInsets widths = [_style resolvedBorderWidths];

    if (widths.top > 0) {
      _topBorderView = [[UIView alloc] init];
      _topBorderView.backgroundColor = [_style resolvedBorderColorForEdge:UIRectEdgeTop];
      [self addSubview:_topBorderView];
    }
    if (widths.bottom > 0) {
      _bottomBorderView = [[UIView alloc] init];
      _bottomBorderView.backgroundColor = [_style resolvedBorderColorForEdge:UIRectEdgeBottom];
      [self addSubview:_bottomBorderView];
    }
    if (widths.left > 0) {
      _leftBorderView = [[UIView alloc] init];
      _leftBorderView.backgroundColor = [_style resolvedBorderColorForEdge:UIRectEdgeLeft];
      [self addSubview:_leftBorderView];
    }
    if (widths.right > 0) {
      _rightBorderView = [[UIView alloc] init];
      _rightBorderView.backgroundColor = [_style resolvedBorderColorForEdge:UIRectEdgeRight];
      [self addSubview:_rightBorderView];
    }

    // Clear layer border
    self.layer.borderWidth = 0;
  } else if (hasBorder) {
    // Uniform border via layer
    UIColor *color = [_style resolvedBorderColorForEdge:UIRectEdgeTop];
    UIEdgeInsets widths = [_style resolvedBorderWidths];
    if (color && widths.top > 0) {
      self.layer.borderColor = color.CGColor;
      self.layer.borderWidth = widths.top;
    } else {
      self.layer.borderWidth = 0;
    }
  } else {
    self.layer.borderWidth = 0;
  }

  // Border radius
  if (hasRadius) {
    CGFloat topLeft = [_style resolvedRadiusForCorner:UIRectCornerTopLeft];
    CGFloat topRight = [_style resolvedRadiusForCorner:UIRectCornerTopRight];
    CGFloat bottomLeft = [_style resolvedRadiusForCorner:UIRectCornerBottomLeft];
    CGFloat bottomRight = [_style resolvedRadiusForCorner:UIRectCornerBottomRight];

    BOOL uniform = (topLeft == topRight) && (topRight == bottomLeft) &&
                   (bottomLeft == bottomRight);

    if (uniform) {
      self.layer.cornerRadius = topLeft;
      self.layer.masksToBounds = YES;
      self.layer.mask = nil;
      _cornerMaskLayer = nil;
    } else {
      // Use CAShapeLayer mask for per-corner radii
      self.layer.cornerRadius = 0;
      _cornerMaskLayer = [CAShapeLayer layer];
      self.layer.mask = _cornerMaskLayer;
    }
  } else {
    self.layer.cornerRadius = 0;
    self.layer.masksToBounds = NO;
    self.layer.mask = nil;
    _cornerMaskLayer = nil;
  }

  // Border curve (continuous / circular)
  if ([_style.borderCurve isEqualToString:@"continuous"]) {
    self.layer.cornerCurve = kCACornerCurveContinuous;
  } else {
    self.layer.cornerCurve = kCACornerCurveCircular;
  }

  [self bringSubviewsToFront];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  UIEdgeInsets padding = [_style resolvedPaddingInsets];
  UIEdgeInsets borders = [_style resolvedBorderWidths];

  CGFloat x = padding.left + borders.left;
  CGFloat y = padding.top + borders.top;
  CGFloat w = self.bounds.size.width - padding.left - padding.right - borders.left - borders.right;
  CGFloat h = self.bounds.size.height - padding.top - padding.bottom - borders.top - borders.bottom;

  _contentView.frame = CGRectMake(x, y, MAX(0, w), MAX(0, h));

  // Position per-side border subviews
  CGFloat fullW = self.bounds.size.width;
  CGFloat fullH = self.bounds.size.height;

  if (_topBorderView) {
    _topBorderView.frame = CGRectMake(0, 0, fullW, borders.top);
  }
  if (_bottomBorderView) {
    _bottomBorderView.frame = CGRectMake(0, fullH - borders.bottom, fullW, borders.bottom);
  }
  if (_leftBorderView) {
    _leftBorderView.frame = CGRectMake(0, 0, borders.left, fullH);
  }
  if (_rightBorderView) {
    _rightBorderView.frame = CGRectMake(fullW - borders.right, 0, borders.right, fullH);
  }

  // Update per-corner mask path
  if (_cornerMaskLayer) {
    CGFloat tl = [_style resolvedRadiusForCorner:UIRectCornerTopLeft];
    CGFloat tr = [_style resolvedRadiusForCorner:UIRectCornerTopRight];
    CGFloat bl = [_style resolvedRadiusForCorner:UIRectCornerBottomLeft];
    CGFloat br = [_style resolvedRadiusForCorner:UIRectCornerBottomRight];

    CGRect rect = self.bounds;
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, CGRectGetMinX(rect) + tl, CGRectGetMinY(rect));
    CGPathAddLineToPoint(path, NULL, CGRectGetMaxX(rect) - tr, CGRectGetMinY(rect));
    CGPathAddArcToPoint(path, NULL,
                        CGRectGetMaxX(rect), CGRectGetMinY(rect),
                        CGRectGetMaxX(rect), CGRectGetMinY(rect) + tr, tr);
    CGPathAddLineToPoint(path, NULL, CGRectGetMaxX(rect), CGRectGetMaxY(rect) - br);
    CGPathAddArcToPoint(path, NULL,
                        CGRectGetMaxX(rect), CGRectGetMaxY(rect),
                        CGRectGetMaxX(rect) - br, CGRectGetMaxY(rect), br);
    CGPathAddLineToPoint(path, NULL, CGRectGetMinX(rect) + bl, CGRectGetMaxY(rect));
    CGPathAddArcToPoint(path, NULL,
                        CGRectGetMinX(rect), CGRectGetMaxY(rect),
                        CGRectGetMinX(rect), CGRectGetMaxY(rect) - bl, bl);
    CGPathAddLineToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMinY(rect) + tl);
    CGPathAddArcToPoint(path, NULL,
                        CGRectGetMinX(rect), CGRectGetMinY(rect),
                        CGRectGetMinX(rect) + tl, CGRectGetMinY(rect), tl);
    CGPathCloseSubpath(path);
    _cornerMaskLayer.path = path;
    _cornerMaskLayer.frame = rect;
    CGPathRelease(path);
  }
}

- (CGSize)sizeThatFits:(CGSize)size {
  UIEdgeInsets padding = [_style resolvedPaddingInsets];
  UIEdgeInsets borders = [_style resolvedBorderWidths];
  CGFloat extraW = padding.left + padding.right + borders.left + borders.right;
  CGFloat extraH = padding.top + padding.bottom + borders.top + borders.bottom;

  CGSize availableSize = CGSizeMake(
      MAX(0, size.width - extraW),
      MAX(0, size.height - extraH));

  CGSize contentSize = _contentView
      ? [_contentView sizeThatFits:availableSize]
      : CGSizeZero;

  CGFloat w = contentSize.width + extraW;
  CGFloat h = contentSize.height + extraH;

  // Explicit width/height from the style override any calculation.
  if (_style.width > 0) w = _style.width;
  if (_style.height > 0) h = _style.height;

  return CGSizeMake(w, h);
}

@end
