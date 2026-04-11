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

    // Union of per-line rects for this spoiler across all its
    // character-range chunks. Each chunk is a contiguous span with
    // the same spoilerId attribute; usually there's just one.
    NSMutableArray<NSValue *> *perLineRects = [NSMutableArray new];

    for (NSValue *rangeValue in spoilerRanges[spoilerId]) {
      NSRange charRange = rangeValue.rangeValue;
      NSRange chunkGlyphRange =
          [layoutManager glyphRangeForCharacterRange:charRange
                               actualCharacterRange:NULL];

      // Walk line fragments that intersect this chunk. Using
      // enumerateLineFragmentsForGlyphRange gives us the FULL line
      // rect (including leading / line spacing), so stacked rects
      // touch vertically with no visible gap.
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

        // Horizontal extent = bounding rect of the glyphs that the
        // spoiler actually covers on this line. Vertical extent =
        // the full line fragment rect (so adjacent lines touch).
        CGRect textBounds =
            [layoutManager boundingRectForGlyphRange:intersection
                                     inTextContainer:container];

        CGRect rect = CGRectMake(CGRectGetMinX(textBounds),
                                 CGRectGetMinY(lineRect),
                                 CGRectGetWidth(textBounds),
                                 CGRectGetHeight(lineRect));
        rect = CGRectOffset(rect, textOrigin.x, textOrigin.y);
        [perLineRects addObject:[NSValue valueWithCGRect:rect]];
      }];
    }

    if (perLineRects.count == 0) continue;

    // Bounding box for the whole spoiler — this is the overlay's
    // frame in the text view's coordinate space.
    CGRect bounds = [perLineRects[0] CGRectValue];
    for (NSValue *v in perLineRects) {
      bounds = CGRectUnion(bounds, v.CGRectValue);
    }

    // Build a single path containing every per-line rect, in
    // bounds-local coordinates. When adjacent line rects touch (same
    // bottom/top y), CAShapeLayer's fillRule:nonZero draws them as
    // one continuous shape.
    UIBezierPath *path = [UIBezierPath bezierPath];
    for (NSValue *v in perLineRects) {
      CGRect local =
          CGRectOffset(v.CGRectValue, -bounds.origin.x, -bounds.origin.y);
      [path appendPath:[UIBezierPath bezierPathWithRect:local]];
    }

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
