#import "FMDBlockTextView.h"

@implementation FMDBlockTextView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.backgroundColor = UIColor.clearColor;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
  if (![_attributedText isEqualToAttributedString:attributedText]) {
    _attributedText = [attributedText copy];
    [self setNeedsDisplay];
  }
}

- (void)drawRect:(CGRect)rect {
  [_attributedText drawWithRect:self.bounds
                        options:NSStringDrawingUsesLineFragmentOrigin |
                                NSStringDrawingUsesFontLeading
                        context:nil];
}

@end
