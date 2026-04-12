#import "MarkdownSpoilerOverlay.h"
#import "CustomTagRenderer.h"
#import "MarkdownPressableOverlayView.h"

static const CGFloat kRevealAnimationDuration = 0.25;

// Breathing room around the text glyphs on all sides of the overlay.
static const CGFloat kSpoilerPadding = 2.0;

// Returns a darkened (or lightened, for very dark inputs) variant
// of `color` to use as the press-feedback fill. Stays fully opaque
// so the text underneath doesn't peek through during the tap.
static UIColor *MarkdownSpoilerPressedColor(UIColor *color) {
  if (!color) return [UIColor colorWithWhite:0.0 alpha:1.0];

  CGFloat h = 0, s = 0, b = 0, a = 0;
  if ([color getHue:&h saturation:&s brightness:&b alpha:&a]) {
    // ~15% shift. Darken by default; if the color is already very
    // dark, lighten instead so the feedback stays visible.
    CGFloat targetBrightness = b < 0.2 ? MIN(b + 0.15, 1.0) : b * 0.85;
    return [UIColor colorWithHue:h
                       saturation:s
                       brightness:targetBrightness
                            alpha:a];
  }

  // Grayscale / pattern fallback: shift via white component.
  CGFloat w = 0;
  if ([color getWhite:&w alpha:&a]) {
    CGFloat target = w < 0.2 ? MIN(w + 0.15, 1.0) : w * 0.85;
    return [UIColor colorWithWhite:target alpha:a];
  }

  return color;
}

@implementation MarkdownSpoilerOverlay {
  __weak UITextView *_textView;
  NSMutableArray<MarkdownPressableOverlayView *> *_overlays;
  // Track which spoiler IDs are revealed
  NSMutableSet<NSString *> *_revealedIds;

  // Cache so we can short-circuit updateOverlays when layoutSubviews
  // fires without a relevant change (e.g. during animations on an
  // ancestor view). A rebuild is only needed when the text view's
  // width or attributed text actually changed.
  CGFloat _cachedWidth;
  __weak NSAttributedString *_cachedText;
}

- (instancetype)initWithTextView:(UITextView *)textView {
  self = [super init];
  if (self) {
    _textView = textView;
    _overlays = [NSMutableArray new];
    _revealedIds = [NSMutableSet new];
    _overlayColor = [UIColor labelColor];
    _cachedWidth = 0;
    _cachedText = nil;
  }
  return self;
}

- (void)removeAllOverlays {
  for (UIView *overlay in _overlays) {
    [overlay removeFromSuperview];
  }
  [_overlays removeAllObjects];
  _cachedWidth = 0;
  _cachedText = nil;
}

- (void)updateOverlays {
  UITextView *textView = _textView;
  if (!textView) return;

  // Without a real width the layout manager wraps everything into a
  // single bogus line fragment, so any rects we compute here are
  // garbage. Skip until the text view has been sized and we'll get
  // called back when layoutSubviews runs again.
  CGFloat width = textView.bounds.size.width;
  if (width <= 0) return;

  NSAttributedString *attrText = textView.attributedText;
  if (!attrText || attrText.length == 0) {
    [self removeAllOverlays];
    return;
  }

  // Skip the rebuild when layoutSubviews fires without a change we
  // care about. We compare attributedText by pointer identity
  // because MarkdownView always rebuilds a fresh NSAttributedString
  // when the markdown or style JSON changes, so same-pointer means
  // same content.
  if (fabs(width - _cachedWidth) < 0.5 && attrText == _cachedText) {
    return;
  }
  _cachedWidth = width;
  _cachedText = attrText;

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
  // Press feedback: darken the overlay color ~15% (or lighten it if
  // the color is already very dark). Alpha-based feedback would make
  // the hidden text peek through during the tap, so we stay fully
  // opaque and just shift brightness instead.
  UIColor *pressedColor = MarkdownSpoilerPressedColor(_overlayColor);

  for (NSString *spoilerId in spoilerRanges) {
    BOOL isRevealed = [_revealedIds containsObject:spoilerId];

    NSMutableArray<NSValue *> *perLineRects = [NSMutableArray new];

    for (NSValue *rangeValue in spoilerRanges[spoilerId]) {
      NSRange charRange = rangeValue.rangeValue;
      NSRange chunkGlyphRange =
          [layoutManager glyphRangeForCharacterRange:charRange
                               actualCharacterRange:NULL];

      // Look up the font once per range. Spoilers use the
      // surrounding text's font in the ~100% case — looking it up
      // per line fragment was a redundant O(log N) attribute
      // lookup per call.
      UIFont *rangeFont = [attrText attribute:NSFontAttributeName
                                      atIndex:charRange.location
                               effectiveRange:NULL];
      if (![rangeFont isKindOfClass:[UIFont class]]) {
        rangeFont = [UIFont systemFontOfSize:UIFont.systemFontSize];
      }
      CGFloat ascender = rangeFont.ascender;
      CGFloat descender = rangeFont.descender; // negative

      // Walk line fragments touching this chunk. For each line we
      // compute a tight text rect from font metrics (baseline
      // minus ascender to baseline minus descender), NOT from the
      // line fragment rect — that includes leading (the paragraph
      // style's extra line height above the ascender) which left
      // asymmetric empty space above the text.
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

        CGRect horizBounds =
            [layoutManager boundingRectForGlyphRange:intersection
                                     inTextContainer:container];

        CGPoint glyphLoc =
            [layoutManager locationForGlyphAtIndex:intersection.location];
        CGFloat baseline = CGRectGetMinY(lineRect) + glyphLoc.y;
        CGFloat top = baseline - ascender;
        CGFloat bottom = baseline - descender;

        CGRect rect = CGRectMake(CGRectGetMinX(horizBounds),
                                 top,
                                 CGRectGetWidth(horizBounds),
                                 bottom - top);
        rect = CGRectOffset(rect, textOrigin.x, textOrigin.y);
        // Breathing room on all four sides.
        rect = CGRectInset(rect, -kSpoilerPadding, -kSpoilerPadding);
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
