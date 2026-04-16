#import "MarkdownInternalTextView.h"

#pragma mark - Link tap gesture recognizer

/// UITapGestureRecognizer subclass that makes UITextView's internal
/// link recognizers wait for it to fail. When this recognizer fires
/// first (instant tap), the internal recognizers are cancelled — so
/// the delayed UITextItemInteraction path never runs.
@interface MarkdownLinkTapRecognizer : UITapGestureRecognizer
@end

@implementation MarkdownLinkTapRecognizer

- (BOOL)shouldBeRequiredToFailByGestureRecognizer:
    (UIGestureRecognizer *)other {
  // Make UITextView's OWN recognizers wait for us. Recognizers on
  // other views (parent Pressable, scroll views) are unaffected.
  if (other.view == self.view) return YES;
  return NO;
}

@end

#pragma mark - MarkdownInternalTextView

@implementation MarkdownInternalTextView

- (void)layoutSubviews {
  [super layoutSubviews];
  if (_onLayoutSubviews) {
    _onLayoutSubviews();
  }
}

#pragma mark - Link detection

/// Returns the URL at `point` (in the text view's coordinate space)
/// if the character under that point carries NSLinkAttributeName.
- (nullable NSURL *)linkURLAtPoint:(CGPoint)point {
  NSTextStorage *storage = self.textStorage;
  NSLayoutManager *lm = self.layoutManager;
  NSTextContainer *tc = self.textContainer;
  if (!storage || storage.length == 0 || !lm || !tc) return nil;

  CGPoint textPoint = CGPointMake(
      point.x - self.textContainerInset.left,
      point.y - self.textContainerInset.top);

  CGRect textBounds = [lm usedRectForTextContainer:tc];
  if (!CGRectContainsPoint(textBounds, textPoint)) return nil;

  CGFloat fraction = 0;
  NSUInteger glyphIdx =
      [lm glyphIndexForPoint:textPoint
              inTextContainer:tc
  fractionOfDistanceThroughGlyph:&fraction];

  CGRect glyphRect =
      [lm boundingRectForGlyphRange:NSMakeRange(glyphIdx, 1)
                     inTextContainer:tc];
  if (!CGRectContainsPoint(glyphRect, textPoint)) return nil;

  NSUInteger charIdx = [lm characterIndexForGlyphAtIndex:glyphIdx];
  if (charIdx >= storage.length) return nil;

  id link = [storage attribute:NSLinkAttributeName
                       atIndex:charIdx
                effectiveRange:nil];
  if (!link) return nil;

  if ([link isKindOfClass:[NSURL class]]) return link;
  if ([link isKindOfClass:[NSString class]])
    return [NSURL URLWithString:link];
  return nil;
}

#pragma mark - Hit testing

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  // Let UITextView's default hit test check subviews. Our overlay
  // subviews (spoiler, mention — all UIControl) sit on top of the
  // text content. If one claims the touch, return it.
  UIView *hitView = [super hitTest:point withEvent:event];

  if (hitView != nil && [hitView isKindOfClass:[UIControl class]]) {
    return hitView;
  }

  // Check if the point is on a link. Return self so our link tap
  // recognizer (and the blocking recognizer on MarkdownView) can
  // handle the touch.
  if ([self linkURLAtPoint:point] != nil) {
    return self;
  }

  // No interactive element — pass through so a parent Pressable
  // can handle the touch.
  return nil;
}

#pragma mark - Link tap recognizer

- (void)installLinkTapRecognizer {
  MarkdownLinkTapRecognizer *tap =
      [[MarkdownLinkTapRecognizer alloc] initWithTarget:self
                                                 action:@selector(handleLinkTap:)];
  tap.cancelsTouchesInView = NO;
  [self addGestureRecognizer:tap];
}

- (void)handleLinkTap:(UITapGestureRecognizer *)recognizer {
  if (!_onLinkTap) return;
  CGPoint point = [recognizer locationInView:self];
  NSURL *url = [self linkURLAtPoint:point];
  if (url) {
    _onLinkTap(url);
  }
}

@end
