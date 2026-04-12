#import "MarkdownPressableOverlayView.h"

@implementation MarkdownPressableOverlayView {
  CAShapeLayer *_fillLayer;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _normalColor = [UIColor clearColor];
    _pressedColor = [UIColor colorWithWhite:0.0 alpha:0.12];

    self.backgroundColor = [UIColor clearColor];

    _fillLayer = [CAShapeLayer layer];
    _fillLayer.fillColor = _normalColor.CGColor;
    _fillLayer.frame = self.bounds;
    [self.layer addSublayer:_fillLayer];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _fillLayer.frame = self.bounds;
  // When no explicit shapePath is set (rectangular overlays like
  // the one on MarkdownImageView), fill the full bounds. Without
  // this the CAShapeLayer has no path and nothing draws, even
  // though the UIControl still receives touches.
  if (!_shapePath) {
    _fillLayer.path =
        [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
  }
}

- (void)setShapePath:(UIBezierPath *)shapePath {
  _shapePath = shapePath;
  _fillLayer.path = shapePath.CGPath;
}

- (void)setNormalColor:(UIColor *)normalColor {
  _normalColor = normalColor ?: [UIColor clearColor];
  if (!self.highlighted) {
    _fillLayer.fillColor = _normalColor.CGColor;
  }
}

- (void)setPressedColor:(UIColor *)pressedColor {
  _pressedColor = pressedColor;
  if (self.highlighted) {
    _fillLayer.fillColor = _pressedColor.CGColor;
  }
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];
  _fillLayer.fillColor =
      highlighted ? _pressedColor.CGColor : _normalColor.CGColor;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  // When a shape path is set, only register taps that land inside
  // the filled region — otherwise the bounding box of a multi-line
  // highlight would eat touches on empty staircase corners and text
  // outside the highlight.
  if (_shapePath) {
    return [_shapePath containsPoint:point];
  }
  return [super pointInside:point withEvent:event];
}

#pragma mark - Shape path builder

static inline CGPoint addRoundedVertex(CGMutablePathRef path, CGPoint prev,
                                        CGPoint curr, CGPoint next,
                                        CGFloat radius, BOOL isFirst) {
  CGFloat d1 = hypot(curr.x - prev.x, curr.y - prev.y);
  CGFloat d2 = hypot(next.x - curr.x, next.y - curr.y);
  CGFloat r = MIN(radius, MIN(d1 * 0.5, d2 * 0.5));
  CGFloat t1 = d1 > 0 ? r / d1 : 0;
  CGFloat t2 = d2 > 0 ? r / d2 : 0;

  CGPoint inPt = CGPointMake(curr.x - (curr.x - prev.x) * t1,
                             curr.y - (curr.y - prev.y) * t1);
  CGPoint outPt = CGPointMake(curr.x + (next.x - curr.x) * t2,
                              curr.y + (next.y - curr.y) * t2);

  if (isFirst) {
    CGPathMoveToPoint(path, NULL, inPt.x, inPt.y);
  } else {
    CGPathAddLineToPoint(path, NULL, inPt.x, inPt.y);
  }
  CGPathAddQuadCurveToPoint(path, NULL, curr.x, curr.y, outPt.x, outPt.y);
  return outPt;
}

+ (UIBezierPath *)shapePathForRects:(NSArray<NSValue *> *)rects
                       cornerRadius:(CGFloat)radius {
  UIBezierPath *empty = [UIBezierPath bezierPath];
  if (rects.count == 0) return empty;

  // Single rect — just a rounded rect, no polygon math needed.
  if (rects.count == 1) {
    CGRect r = [rects[0] CGRectValue];
    return [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
  }

  // Build the clockwise staircase outline of the stacked rects.
  // The vertex list is expressed in the same coordinate space as
  // the input rects; the caller is expected to pass rects already
  // converted to the overlay's local coordinate space (i.e. the
  // union bounding box origin at 0,0).
  NSMutableArray<NSValue *> *vertices = [NSMutableArray new];

  CGRect r0 = [rects[0] CGRectValue];
  [vertices addObject:[NSValue valueWithCGPoint:
                          CGPointMake(r0.origin.x, r0.origin.y)]];
  [vertices addObject:[NSValue valueWithCGPoint:
                          CGPointMake(CGRectGetMaxX(r0), r0.origin.y)]];

  // Right side walk top→bottom. At each line boundary where the
  // next line's right edge differs, emit a horizontal step.
  for (NSUInteger i = 0; i < rects.count - 1; i++) {
    CGRect curr = [rects[i] CGRectValue];
    CGRect next = [rects[i + 1] CGRectValue];
    [vertices addObject:[NSValue valueWithCGPoint:
                            CGPointMake(CGRectGetMaxX(curr),
                                        CGRectGetMaxY(curr))]];
    if (fabs(CGRectGetMaxX(next) - CGRectGetMaxX(curr)) > 0.5) {
      [vertices addObject:[NSValue valueWithCGPoint:
                              CGPointMake(CGRectGetMaxX(next),
                                          CGRectGetMaxY(curr))]];
    }
  }

  // Bottom-right and bottom-left of the last rect.
  CGRect rLast = [rects.lastObject CGRectValue];
  [vertices addObject:[NSValue valueWithCGPoint:
                          CGPointMake(CGRectGetMaxX(rLast),
                                      CGRectGetMaxY(rLast))]];
  [vertices addObject:[NSValue valueWithCGPoint:
                          CGPointMake(rLast.origin.x,
                                      CGRectGetMaxY(rLast))]];

  // Left side walk bottom→top with mirror-image steps.
  for (NSInteger i = rects.count - 1; i > 0; i--) {
    CGRect curr = [rects[i] CGRectValue];
    CGRect prev = [rects[i - 1] CGRectValue];
    [vertices addObject:[NSValue valueWithCGPoint:
                            CGPointMake(curr.origin.x, curr.origin.y)]];
    if (fabs(prev.origin.x - curr.origin.x) > 0.5) {
      [vertices addObject:[NSValue valueWithCGPoint:
                              CGPointMake(prev.origin.x, curr.origin.y)]];
    }
  }

  NSUInteger n = vertices.count;
  CGMutablePathRef path = CGPathCreateMutable();

  if (radius <= 0 || n < 3) {
    CGPoint start = [vertices[0] CGPointValue];
    CGPathMoveToPoint(path, NULL, start.x, start.y);
    for (NSUInteger i = 1; i < n; i++) {
      CGPoint p = [vertices[i] CGPointValue];
      CGPathAddLineToPoint(path, NULL, p.x, p.y);
    }
    CGPathCloseSubpath(path);
  } else {
    // Round every vertex with a quadratic bezier. Convex corners
    // curve outward, concave staircase corners curve inward —
    // both cases handled by the same tangent-point math.
    for (NSUInteger i = 0; i < n; i++) {
      CGPoint prev = [vertices[(i + n - 1) % n] CGPointValue];
      CGPoint curr = [vertices[i] CGPointValue];
      CGPoint next = [vertices[(i + 1) % n] CGPointValue];
      addRoundedVertex(path, prev, curr, next, radius, i == 0);
    }
    CGPathCloseSubpath(path);
  }

  UIBezierPath *result = [UIBezierPath bezierPathWithCGPath:path];
  CGPathRelease(path);
  return result;
}

@end
