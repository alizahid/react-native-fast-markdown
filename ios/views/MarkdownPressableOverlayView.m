#import "MarkdownPressableOverlayView.h"

@implementation MarkdownPressableOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _normalColor = [UIColor clearColor];
    _pressedColor = [UIColor colorWithWhite:0.0 alpha:0.12];
    self.backgroundColor = _normalColor;
  }
  return self;
}

- (void)setNormalColor:(UIColor *)normalColor {
  _normalColor = normalColor ?: [UIColor clearColor];
  if (!self.highlighted) {
    self.backgroundColor = _normalColor;
  }
}

- (void)setPressedColor:(UIColor *)pressedColor {
  _pressedColor = pressedColor;
  if (self.highlighted) {
    self.backgroundColor = _pressedColor;
  }
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];
  self.backgroundColor = highlighted ? _pressedColor : _normalColor;
}

@end
