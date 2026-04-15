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
  // Let UITextView's default hit test run first. It traverses
  // subviews (spoiler / mention overlays added by the overlay
  // managers) and, if none claim the touch, returns self.
  UIView *hitView = [super hitTest:point withEvent:event];

  // If an overlay subview claimed the touch, honour it — spoiler
  // reveals, mention presses, etc. should keep working.
  if (hitView != nil && hitView != self) {
    return hitView;
  }

  // UITextView returned self, meaning no overlay was hit. Only
  // claim the touch when the point lands on a character that
  // carries NSLinkAttributeName so link taps still work.
  // Everything else passes through so a parent Pressable (from
  // React Native or React Native Gesture Handler) can handle it.
  NSTextStorage *storage = self.textStorage;
  NSLayoutManager *lm = self.layoutManager;
  NSTextContainer *tc = self.textContainer;
  if (!storage || storage.length == 0 || !lm || !tc) {
    return nil;
  }

  CGPoint textPoint = CGPointMake(
      point.x - self.textContainerInset.left,
      point.y - self.textContainerInset.top);

  // Quick bounds check — if the point is outside all rendered text,
  // there's definitely no link under it.
  CGRect textBounds = [lm usedRectForTextContainer:tc];
  if (!CGRectContainsPoint(textBounds, textPoint)) {
    return nil;
  }

  CGFloat fraction = 0;
  NSUInteger glyphIdx =
      [lm glyphIndexForPoint:textPoint
              inTextContainer:tc
  fractionOfDistanceThroughGlyph:&fraction];

  // Verify the point actually falls inside the glyph's bounding
  // rect — glyphIndexForPoint: returns the *nearest* glyph even
  // when the point is in inter-line spacing or past the text edge.
  CGRect glyphRect =
      [lm boundingRectForGlyphRange:NSMakeRange(glyphIdx, 1)
                     inTextContainer:tc];
  if (!CGRectContainsPoint(glyphRect, textPoint)) {
    return nil;
  }

  NSUInteger charIdx = [lm characterIndexForGlyphAtIndex:glyphIdx];
  if (charIdx < storage.length) {
    id link = [storage attribute:NSLinkAttributeName
                         atIndex:charIdx
                  effectiveRange:nil];
    if (link) {
      return self;
    }
  }

  return nil;
}

@end
