#import "MarkdownBlockView.h"
#import "StyleConfig.h"

@implementation MarkdownBlockView {
  // The "border box" — a nested view inset by the style's margin.
  // All visual styling (background, border, corner radius) lives on
  // _boxView instead of self, so MarkdownBlockView's own bounds can
  // include the margin area while the visible box sits inside it.
  UIView *_boxView;

  // Per-side border subviews (used when borders are non-uniform),
  // added as subviews of _boxView.
  UIView *_topBorderView;
  UIView *_bottomBorderView;
  UIView *_leftBorderView;
  UIView *_rightBorderView;

  // Shape layer mask for per-corner radii (applied to _boxView.layer).
  CAShapeLayer *_cornerMaskLayer;

  // Cached bounds for the corner mask so we skip the CGPath rebuild
  // when layoutSubviews fires without a size change.
  CGRect _cachedCornerMaskBounds;
}

- (instancetype)initWithStyle:(MarkdownElementStyle *)style {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _style = style;
    self.backgroundColor = [UIColor clearColor];

    _boxView = [[UIView alloc] initWithFrame:CGRectZero];
    _boxView.backgroundColor = [UIColor clearColor];
    [self addSubview:_boxView];

    [self applyStyle];
  }
  return self;
}

- (void)setStyle:(MarkdownElementStyle *)style {
  _style = style;
  _cachedCornerMaskBounds = CGRectNull;
  [self applyStyle];
  [self setNeedsLayout];
}

- (void)setContentView:(UIView *)contentView {
  if (_contentView) {
    [_contentView removeFromSuperview];
  }
  _contentView = contentView;
  if (contentView) {
    [_boxView addSubview:contentView];
    // Border subviews should stay on top of the content view inside
    // the box.
    [self bringBorderSubviewsToFront];
  }
  [self setNeedsLayout];
}

- (void)bringBorderSubviewsToFront {
  if (_topBorderView) [_boxView bringSubviewToFront:_topBorderView];
  if (_bottomBorderView) [_boxView bringSubviewToFront:_bottomBorderView];
  if (_leftBorderView) [_boxView bringSubviewToFront:_leftBorderView];
  if (_rightBorderView) [_boxView bringSubviewToFront:_rightBorderView];
}

- (void)applyStyle {
  // Background color lives on the box, not on the outer wrapper,
  // so the margin area stays transparent.
  _boxView.backgroundColor = _style.backgroundColor ?: [UIColor clearColor];

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
    // Use subview edges for per-side borders, parented to _boxView.
    UIEdgeInsets widths = [_style resolvedBorderWidths];

    if (widths.top > 0) {
      _topBorderView = [[UIView alloc] init];
      _topBorderView.backgroundColor = [_style resolvedBorderColorForEdge:UIRectEdgeTop];
      [_boxView addSubview:_topBorderView];
    }
    if (widths.bottom > 0) {
      _bottomBorderView = [[UIView alloc] init];
      _bottomBorderView.backgroundColor = [_style resolvedBorderColorForEdge:UIRectEdgeBottom];
      [_boxView addSubview:_bottomBorderView];
    }
    if (widths.left > 0) {
      _leftBorderView = [[UIView alloc] init];
      _leftBorderView.backgroundColor = [_style resolvedBorderColorForEdge:UIRectEdgeLeft];
      [_boxView addSubview:_leftBorderView];
    }
    if (widths.right > 0) {
      _rightBorderView = [[UIView alloc] init];
      _rightBorderView.backgroundColor = [_style resolvedBorderColorForEdge:UIRectEdgeRight];
      [_boxView addSubview:_rightBorderView];
    }

    _boxView.layer.borderWidth = 0;
  } else if (hasBorder) {
    // Uniform border via the box's layer.
    UIColor *color = [_style resolvedBorderColorForEdge:UIRectEdgeTop];
    UIEdgeInsets widths = [_style resolvedBorderWidths];
    if (color && widths.top > 0) {
      _boxView.layer.borderColor = color.CGColor;
      _boxView.layer.borderWidth = widths.top;
    } else {
      _boxView.layer.borderWidth = 0;
    }
  } else {
    _boxView.layer.borderWidth = 0;
  }

  // Border radius — applied to _boxView, not self.
  if (hasRadius) {
    CGFloat topLeft = [_style resolvedRadiusForCorner:UIRectCornerTopLeft];
    CGFloat topRight = [_style resolvedRadiusForCorner:UIRectCornerTopRight];
    CGFloat bottomLeft = [_style resolvedRadiusForCorner:UIRectCornerBottomLeft];
    CGFloat bottomRight = [_style resolvedRadiusForCorner:UIRectCornerBottomRight];

    BOOL uniform = (topLeft == topRight) && (topRight == bottomLeft) &&
                   (bottomLeft == bottomRight);

    if (uniform) {
      _boxView.layer.cornerRadius = topLeft;
      _boxView.layer.masksToBounds = YES;
      _boxView.layer.mask = nil;
      _cornerMaskLayer = nil;
    } else {
      _boxView.layer.cornerRadius = 0;
      _cornerMaskLayer = [CAShapeLayer layer];
      _boxView.layer.mask = _cornerMaskLayer;
    }
  } else {
    _boxView.layer.cornerRadius = 0;
    _boxView.layer.masksToBounds = NO;
    _boxView.layer.mask = nil;
    _cornerMaskLayer = nil;
  }

  // Border curve (continuous / circular). Defaults to continuous
  // — the native iOS squircle — so every block view (codeBlock,
  // blockquote, image, …) gets smooth corners without the caller
  // having to opt in on each style. Callers who want old-school
  // circular arcs can set `borderCurve: 'circular'` explicitly.
  if ([_style.borderCurve isEqualToString:@"circular"]) {
    _boxView.layer.cornerCurve = kCACornerCurveCircular;
  } else {
    _boxView.layer.cornerCurve = kCACornerCurveContinuous;
  }

  [self bringBorderSubviewsToFront];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  UIEdgeInsets margin = [_style resolvedMarginInsets];
  UIEdgeInsets padding = [_style resolvedPaddingInsets];
  UIEdgeInsets borders = [_style resolvedBorderWidths];

  // The visible box is inset by the margin. Everything drawn
  // (background, borders, corners, content) lives inside it.
  CGFloat boxX = margin.left;
  CGFloat boxY = margin.top;
  CGFloat boxW = MAX(0, self.bounds.size.width - margin.left - margin.right);
  CGFloat boxH = MAX(0, self.bounds.size.height - margin.top - margin.bottom);
  _boxView.frame = CGRectMake(boxX, boxY, boxW, boxH);

  // Content view inside the box, inset by padding + borders.
  CGFloat contentX = padding.left + borders.left;
  CGFloat contentY = padding.top + borders.top;
  CGFloat contentW =
      MAX(0, boxW - padding.left - padding.right - borders.left - borders.right);
  CGFloat contentH =
      MAX(0, boxH - padding.top - padding.bottom - borders.top - borders.bottom);
  _contentView.frame = CGRectMake(contentX, contentY, contentW, contentH);

  // Per-side border subviews are positioned within the box.
  if (_topBorderView) {
    _topBorderView.frame = CGRectMake(0, 0, boxW, borders.top);
  }
  if (_bottomBorderView) {
    _bottomBorderView.frame = CGRectMake(0, boxH - borders.bottom, boxW, borders.bottom);
  }
  if (_leftBorderView) {
    _leftBorderView.frame = CGRectMake(0, 0, borders.left, boxH);
  }
  if (_rightBorderView) {
    _rightBorderView.frame = CGRectMake(boxW - borders.right, 0, borders.right, boxH);
  }

  // Per-corner mask path, computed in _boxView's coordinate space.
  // Skip the CGPath rebuild when bounds haven't changed.
  if (_cornerMaskLayer) {
    CGRect rect = _boxView.bounds;
    if (!CGRectEqualToRect(rect, _cachedCornerMaskBounds)) {
      _cachedCornerMaskBounds = rect;

      CGFloat tl = [_style resolvedRadiusForCorner:UIRectCornerTopLeft];
      CGFloat tr = [_style resolvedRadiusForCorner:UIRectCornerTopRight];
      CGFloat bl = [_style resolvedRadiusForCorner:UIRectCornerBottomLeft];
      CGFloat br = [_style resolvedRadiusForCorner:UIRectCornerBottomRight];

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
}

- (CGSize)sizeThatFits:(CGSize)size {
  UIEdgeInsets margin = [_style resolvedMarginInsets];
  UIEdgeInsets padding = [_style resolvedPaddingInsets];
  UIEdgeInsets borders = [_style resolvedBorderWidths];

  CGFloat marginW = margin.left + margin.right;
  CGFloat marginH = margin.top + margin.bottom;
  CGFloat extraW = padding.left + padding.right + borders.left + borders.right;
  CGFloat extraH = padding.top + padding.bottom + borders.top + borders.bottom;

  // Content has to fit inside (size minus margins minus padding/borders).
  CGSize availableSize = CGSizeMake(
      MAX(0, size.width - marginW - extraW),
      MAX(0, size.height - marginH - extraH));

  CGSize contentSize = _contentView
      ? [_contentView sizeThatFits:availableSize]
      : CGSizeZero;

  // Explicit width/height from the style override the calculated
  // border-box size; margins are always additive.
  CGFloat borderBoxW =
      (!isnan(_style.width) && _style.width > 0) ? _style.width : contentSize.width + extraW;
  CGFloat borderBoxH =
      (!isnan(_style.height) && _style.height > 0) ? _style.height : contentSize.height + extraH;

  return CGSizeMake(borderBoxW + marginW, borderBoxH + marginH);
}

@end
