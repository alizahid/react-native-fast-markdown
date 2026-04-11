#import "MarkdownSpoilerOverlay.h"
#import "CustomTagRenderer.h"
#import "MarkdownPressableOverlayView.h"

static const CGFloat kOverlayCornerRadius = 4.0;
static const CGFloat kRevealAnimationDuration = 0.25;

@implementation MarkdownSpoilerOverlay {
  __weak UITextView *_textView;
  NSMutableArray<MarkdownPressableOverlayView *> *_overlays;
  // Track which spoiler IDs are revealed
  NSMutableSet<NSString *> *_revealedIds;
}

- (instancetype)initWithTextView:(UITextView *)textView {
  self = [super init];
  if (self) {
    _textView = textView;
    _overlays = [NSMutableArray new];
    _revealedIds = [NSMutableSet new];
    _overlayColor = [UIColor labelColor];
  }
  return self;
}

- (void)removeAllOverlays {
  for (UIView *overlay in _overlays) {
    [overlay removeFromSuperview];
  }
  [_overlays removeAllObjects];
}

- (void)updateOverlays {
  UITextView *textView = _textView;
  if (!textView) return;

  // Without a real width the layout manager wraps everything into a
  // single bogus line fragment, so any rects we compute here are
  // garbage. Skip until the text view has been sized and we'll get
  // called back when layoutSubviews runs again.
  if (textView.bounds.size.width <= 0) return;

  NSAttributedString *attrText = textView.attributedText;
  if (!attrText || attrText.length == 0) {
    [self removeAllOverlays];
    return;
  }

  NSLayoutManager *layoutManager = textView.layoutManager;
  NSTextContainer *textContainer = textView.textContainer;
  if (!layoutManager || !textContainer) {
    [self removeAllOverlays];
    return;
  }

  // Force the layout manager to compute glyph positions for the full
  // text container. Without this, enumerateEnclosingRectsForGlyphRange
  // can return stale / empty rects on the first pass.
  [layoutManager ensureLayoutForTextContainer:textContainer];

  CGPoint textOrigin =
      CGPointMake(textView.textContainerInset.left,
                  textView.textContainerInset.top);

  // Find all spoiler ranges
  NSMutableDictionary<NSString *, NSMutableArray<NSValue *> *> *spoilerRanges =
      [NSMutableDictionary new];

  [attrText enumerateAttribute:MarkdownSpoilerRangeKey
                       inRange:NSMakeRange(0, attrText.length)
                       options:0
                    usingBlock:^(id value, NSRange range, BOOL *stop) {
    if (![value isKindOfClass:[NSString class]]) return;
    NSString *spoilerId = (NSString *)value;

    if (!spoilerRanges[spoilerId]) {
      spoilerRanges[spoilerId] = [NSMutableArray new];
    }
    [spoilerRanges[spoilerId] addObject:[NSValue valueWithRange:range]];
  }];

  [self removeAllOverlays];

  // A spoiler is "normally" its overlayColor (opaque) and flashes
  // slightly transparent on touch to acknowledge the tap. On touch-up
  // it toggles revealed state.
  UIColor *normalColor = _overlayColor;
  UIColor *pressedColor = [_overlayColor colorWithAlphaComponent:0.8];

  for (NSString *spoilerId in spoilerRanges) {
    BOOL isRevealed = [_revealedIds containsObject:spoilerId];

    for (NSValue *rangeValue in spoilerRanges[spoilerId]) {
      NSRange charRange = rangeValue.rangeValue;

      NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange
                                                 actualCharacterRange:NULL];

      [layoutManager enumerateEnclosingRectsForGlyphRange:glyphRange
                                 withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0)
                                          inTextContainer:textContainer
                                               usingBlock:^(CGRect rect, BOOL *stop) {
        if (CGRectIsEmpty(rect) || rect.size.width < 1) return;

        CGRect overlayRect = CGRectOffset(rect, textOrigin.x, textOrigin.y);

        MarkdownPressableOverlayView *overlay =
            [[MarkdownPressableOverlayView alloc] initWithFrame:overlayRect];
        overlay.groupId = spoilerId;
        overlay.normalColor = normalColor;
        overlay.pressedColor = pressedColor;
        overlay.layer.cornerRadius = kOverlayCornerRadius;
        overlay.layer.masksToBounds = YES;
        overlay.alpha = isRevealed ? 0.0 : 1.0;

        [overlay addTarget:self
                    action:@selector(handleSpoilerPressDown:)
          forControlEvents:UIControlEventTouchDown];
        [overlay addTarget:self
                    action:@selector(handleSpoilerPressUp:)
          forControlEvents:UIControlEventTouchUpInside];

        [textView addSubview:overlay];
        [self->_overlays addObject:overlay];
      }];
    }
  }
}

#pragma mark - Press handling

- (void)handleSpoilerPressDown:(MarkdownPressableOverlayView *)sender {
  // Mirror the press state to every other overlay in the same group
  // so a multi-line spoiler highlights as one unit.
  for (MarkdownPressableOverlayView *overlay in _overlays) {
    if (overlay != sender && [overlay.groupId isEqualToString:sender.groupId]) {
      overlay.highlighted = YES;
    }
  }
}

- (void)handleSpoilerPressUp:(MarkdownPressableOverlayView *)sender {
  for (MarkdownPressableOverlayView *overlay in _overlays) {
    if (overlay != sender && [overlay.groupId isEqualToString:sender.groupId]) {
      overlay.highlighted = NO;
    }
  }

  NSString *spoilerId = sender.groupId;
  if (!spoilerId) return;

  BOOL willReveal = ![_revealedIds containsObject:spoilerId];
  if (willReveal) {
    [_revealedIds addObject:spoilerId];
  } else {
    [_revealedIds removeObject:spoilerId];
  }

  for (MarkdownPressableOverlayView *overlay in _overlays) {
    if ([overlay.groupId isEqualToString:spoilerId]) {
      [UIView animateWithDuration:kRevealAnimationDuration animations:^{
        overlay.alpha = willReveal ? 0.0 : 1.0;
      }];
    }
  }
}

@end
