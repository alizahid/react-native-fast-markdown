#import "MarkdownMentionOverlay.h"
#import "CustomTagRenderer.h"
#import "MarkdownPressableOverlayView.h"

#import <objc/runtime.h>

static const CGFloat kMentionCornerRadius = 4.0;

// Breathing room around the text glyphs on all sides of the overlay.
static const CGFloat kMentionPadding = 4.0;

// Associated-object key — any unique pointer works.
static const void *kMentionDataKey = &kMentionDataKey;

@implementation MarkdownMentionOverlay {
  __weak UITextView *_textView;
  NSMutableArray<MarkdownPressableOverlayView *> *_overlays;

  // Short-circuit cache — see MarkdownSpoilerOverlay for the
  // reasoning.
  CGFloat _cachedWidth;
  __weak NSAttributedString *_cachedText;
}

- (instancetype)initWithTextView:(UITextView *)textView {
  self = [super init];
  if (self) {
    _textView = textView;
    _overlays = [NSMutableArray new];
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

  // See MarkdownSpoilerOverlay.updateOverlays for why we skip when
  // bounds.width is 0 — the layout manager can't produce valid glyph
  // rects against a zero-width text container.
  CGFloat width = textView.bounds.size.width;
  if (width <= 0) return;

  NSAttributedString *attrText = textView.attributedText;
  if (!attrText || attrText.length == 0) {
    [self removeAllOverlays];
    return;
  }

  // Short-circuit the rebuild when nothing we care about changed.
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

  [layoutManager ensureLayoutForTextContainer:textContainer];

  CGPoint textOrigin =
      CGPointMake(textView.textContainerInset.left,
                  textView.textContainerInset.top);

  // Collect each mention range. A single mention can span multiple
  // line fragments after wrapping.
  NSMutableArray<NSDictionary *> *mentionHits = [NSMutableArray new];

  [attrText
      enumerateAttribute:MarkdownMentionKey
                 inRange:NSMakeRange(0, attrText.length)
                 options:0
              usingBlock:^(id value, NSRange range, BOOL *stop) {
    if (![value isKindOfClass:[NSDictionary class]]) return;
    [mentionHits addObject:@{
      @"data" : value,
      @"range" : [NSValue valueWithRange:range],
    }];
  }];

  [self removeAllOverlays];

  for (NSDictionary *hit in mentionHits) {
    NSDictionary *data = hit[@"data"];
    NSRange charRange = [hit[@"range"] rangeValue];
    NSRange glyphRange =
        [layoutManager glyphRangeForCharacterRange:charRange
                             actualCharacterRange:NULL];

    // Font is uniform across a single mention span (all glyphs are
    // either the @/# prefix or the name, all styled the same) — one
    // attribute lookup per mention instead of per line fragment.
    UIFont *rangeFont = [attrText attribute:NSFontAttributeName
                                    atIndex:charRange.location
                             effectiveRange:NULL];
    if (![rangeFont isKindOfClass:[UIFont class]]) {
      rangeFont = [UIFont systemFontOfSize:UIFont.systemFontSize];
    }
    CGFloat ascender = rangeFont.ascender;
    CGFloat descender = rangeFont.descender;

    // Per-line rects computed from font metrics — top = baseline -
    // ascender, bottom = baseline - descender. Tight hug on the
    // glyphs (no paragraph leading), stable even when the parent
    // paragraph style bumps lineHeight.
    NSMutableArray<NSValue *> *perLineRects = [NSMutableArray new];
    [layoutManager
        enumerateLineFragmentsForGlyphRange:glyphRange
                                 usingBlock:^(CGRect lineRect,
                                              CGRect usedRect,
                                              NSTextContainer *container,
                                              NSRange lineGlyphRange,
                                              BOOL *stop) {
      NSRange intersection =
          NSIntersectionRange(glyphRange, lineGlyphRange);
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
      rect = CGRectInset(rect, -kMentionPadding, -kMentionPadding);
      [perLineRects addObject:[NSValue valueWithCGRect:rect]];
    }];

    if (perLineRects.count == 0) continue;

    // Second pass: extend each line's bottom down to the next
    // line's top so inter-line leading is filled and adjacent
    // lines visually connect.
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

    CGRect bounds = [perLineRects[0] CGRectValue];
    for (NSValue *v in perLineRects) {
      bounds = CGRectUnion(bounds, v.CGRectValue);
    }

    NSMutableArray<NSValue *> *localRects = [NSMutableArray new];
    for (NSValue *v in perLineRects) {
      CGRect local =
          CGRectOffset(v.CGRectValue, -bounds.origin.x, -bounds.origin.y);
      [localRects addObject:[NSValue valueWithCGRect:local]];
    }
    UIBezierPath *path =
        [MarkdownPressableOverlayView shapePathForRects:localRects
                                           cornerRadius:kMentionCornerRadius];

    MarkdownPressableOverlayView *overlay =
        [[MarkdownPressableOverlayView alloc] initWithFrame:bounds];
    overlay.normalColor = [UIColor clearColor];
    overlay.pressedColor = [UIColor colorWithWhite:0.0 alpha:0.12];
    overlay.shapePath = path;

    // Hang the mention dict off the overlay so the press handler
    // can read it back without re-querying the attributed string.
    objc_setAssociatedObject(overlay, kMentionDataKey, data,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [overlay addTarget:self
                action:@selector(handlePressUp:)
      forControlEvents:UIControlEventTouchUpInside];

    [textView addSubview:overlay];
    [_overlays addObject:overlay];
  }
}

#pragma mark - Press handling

- (void)handlePressUp:(MarkdownPressableOverlayView *)sender {
  if (!_onPress) return;
  NSDictionary *data = objc_getAssociatedObject(sender, kMentionDataKey);
  if ([data isKindOfClass:[NSDictionary class]]) {
    _onPress(data);
  }
}

@end
