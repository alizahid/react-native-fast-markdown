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

@end
