#import "MarkdownSpoilerOverlay.h"
#import "CustomTagRenderer.h"
#import "MarkdownPressableOverlayView.h"

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
  // text container. Without this, the line-fragment enumeration can
  // return stale rects on the first pass.
  [layoutManager ensureLayoutForTextContainer:textContainer];

  CGPoint textOrigin =
      CGPointMake(textView.textContainerInset.left,
                  textView.textContainerInset.top);

  // Find all spoiler ranges, grouped by spoiler id.
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

  UIColor *normalColor = _overlayColor;
  // A subtle flicker to acknowledge the tap — the real feedback is
  // the reveal animation that runs on touch-up.
  UIColor *pressedColor = [_overlayColor colorWithAlphaComponent:0.8];

  for (NSString *spoilerId in spoilerRanges) {
    BOOL isRevealed = [_revealedIds containsObject:spoilerId];

    NSMutableArray<NSValue *> *perLineRects = [NSMutableArray new];

    for (NSValue *rangeValue in spoilerRanges[spoilerId]) {
      NSRange charRange = rangeValue.rangeValue;
      NSRange chunkGlyphRange =
          [layoutManager glyphRangeForCharacterRange:charRange
                               actualCharacterRange:NULL];

      // Walk line fragments touching this chunk. We use
      // boundingRectForGlyphRange for BOTH horizontal and vertical
      // extent — it returns the tight glyph bounding box on that
      // line (ascender→descender, no leading), which hugs the text
      // much more snugly than the full line fragment rect.
      [layoutManager
          enumerateLineFragmentsForGlyphRange:chunkGlyphRange
                                   usingBlock:^(CGRect lineRect,
                                                CGRect usedRect,
                                                NSTextContainer *container,
                                                NSRange lineGlyphRange,
                                                BOOL *stop) {
        NSRange intersection =
            NSIntersectionRange(chunkGlyphRange, lineGlyphRange);
        if (intersection.length == 0) return;

        CGRect textBounds =
            [layoutManager boundingRectForGlyphRange:intersection
                                     inTextContainer:container];
        CGRect rect = CGRectOffset(textBounds, textOrigin.x, textOrigin.y);
        [perLineRects addObject:[NSValue valueWithCGRect:rect]];
      }];
    }

    if (perLineRects.count == 0) continue;

    // Sort by y (safety — normally already in order) then extend
    // each rect's bottom down to the next rect's top, filling the
    // inter-line leading gap so adjacent lines visually connect
    // without losing the tight top/bottom hug on the outermost
    // edges.
    [perLineRects sortUsingComparator:^NSComparisonResult(NSValue *a,
                                                          NSValue *b) {
      CGFloat ay = a.CGRectValue.origin.y;
      CGFloat by = b.CGRectValue.origin.y;
      if (ay < by) return NSOrderedAscending;
      if (ay > by) return NSOrderedDescending;
      return NSOrderedSame;
    }];
    for (NSUInteger i = 0; i + 1 < perLineRects.count; i++) {
      CGRect curr = [perLineRects[i] CGRectValue];
      CGRect next = [perLineRects[i + 1] CGRectValue];
      CGFloat desiredBottom = next.origin.y;
      if (desiredBottom > CGRectGetMaxY(curr)) {
        curr.size.height = desiredBottom - curr.origin.y;
        [perLineRects replaceObjectAtIndex:i
                                withObject:[NSValue valueWithCGRect:curr]];
      }
    }

    // Bounding box for the whole spoiler — this is the overlay's
    // frame in the text view's coordinate space.
    CGRect bounds = [perLineRects[0] CGRectValue];
    for (NSValue *v in perLineRects) {
      bounds = CGRectUnion(bounds, v.CGRectValue);
    }

    // Convert per-line rects to the overlay's local coordinate
    // space (union origin at 0,0) and build a rounded shape path
    // that smooths the staircase outline.
    NSMutableArray<NSValue *> *localRects = [NSMutableArray new];
    for (NSValue *v in perLineRects) {
      CGRect local =
          CGRectOffset(v.CGRectValue, -bounds.origin.x, -bounds.origin.y);
      [localRects addObject:[NSValue valueWithCGRect:local]];
    }
    UIBezierPath *path =
        [MarkdownPressableOverlayView shapePathForRects:localRects
                                           cornerRadius:_cornerRadius];

    MarkdownPressableOverlayView *overlay =
        [[MarkdownPressableOverlayView alloc] initWithFrame:bounds];
    overlay.groupId = spoilerId;
    overlay.normalColor = normalColor;
    overlay.pressedColor = pressedColor;
    overlay.shapePath = path;
    overlay.alpha = isRevealed ? 0.0 : 1.0;

    [overlay addTarget:self
                action:@selector(handleSpoilerPressUp:)
      forControlEvents:UIControlEventTouchUpInside];

    [textView addSubview:overlay];
    [_overlays addObject:overlay];
  }
}

#pragma mark - Press handling

- (void)handleSpoilerPressUp:(MarkdownPressableOverlayView *)sender {
  NSString *spoilerId = sender.groupId;
  if (!spoilerId) return;

  BOOL willReveal = ![_revealedIds containsObject:spoilerId];
  if (willReveal) {
    [_revealedIds addObject:spoilerId];
  } else {
    [_revealedIds removeObject:spoilerId];
  }

  [UIView animateWithDuration:kRevealAnimationDuration
                   animations:^{
                     sender.alpha = willReveal ? 0.0 : 1.0;
                   }];
}

@end
