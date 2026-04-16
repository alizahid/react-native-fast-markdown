#import "MarkdownInternalTextView.h"

@implementation MarkdownInternalTextView

- (void)layoutSubviews {
  [super layoutSubviews];
  if (_onLayoutSubviews) {
    _onLayoutSubviews();
  }
}

#pragma mark - Hit testing

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  // Let UITextView's default hit test check subviews first. Our
  // overlay subviews (spoiler, mention, link — all UIControl) sit
  // on top of the text content. If one claims the touch, return it.
  UIView *hitView = [super hitTest:point withEvent:event];

  if (hitView != nil && [hitView isKindOfClass:[UIControl class]]) {
    return hitView;
  }

  // No overlay was hit. Pass through so a parent Pressable (from
  // React Native or React Native Gesture Handler) can handle it.
  // We intentionally skip UITextView's own link-gesture handling
  // here — links are covered by MarkdownLinkOverlay which fires
  // instantly via UIControlEventTouchUpInside instead of going
  // through UITextView's delayed UITextItemInteraction path.
  return nil;
}

@end
