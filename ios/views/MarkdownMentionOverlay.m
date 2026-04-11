#import "MarkdownMentionOverlay.h"
#import "CustomTagRenderer.h"
#import "MarkdownPressableOverlayView.h"

#import <objc/runtime.h>

static const CGFloat kMentionCornerRadius = 4.0;

// Associated-object key — any unique pointer works.
static const void *kMentionDataKey = &kMentionDataKey;

@implementation MarkdownMentionOverlay {
  __weak UITextView *_textView;
  NSMutableArray<MarkdownPressableOverlayView *> *_overlays;
}

- (instancetype)initWithTextView:(UITextView *)textView {
  self = [super init];
  if (self) {
    _textView = textView;
    _overlays = [NSMutableArray new];
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

  // See MarkdownSpoilerOverlay.updateOverlays for why we skip when
  // bounds.width is 0 — the layout manager can't produce valid glyph
  // rects against a zero-width text container.
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

    // Walk each line fragment the mention touches. Use the FULL
    // line rect vertically (via enumerateLineFragmentsForGlyphRange)
    // so adjacent lines of a wrapped mention touch without a gap.
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

    if (perLineRects.count == 0) continue;

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
