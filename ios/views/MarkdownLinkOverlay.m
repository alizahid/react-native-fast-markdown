#import "MarkdownLinkOverlay.h"
#import "MarkdownPressableOverlayView.h"

#import <objc/runtime.h>

static const CGFloat kLinkCornerRadius = 4.0;
static const CGFloat kLinkPadding = 2.0;

static const void *kLinkURLKey = &kLinkURLKey;

@implementation MarkdownLinkOverlay {
  __weak UITextView *_textView;
  NSMutableArray<MarkdownPressableOverlayView *> *_overlays;

  CGFloat _cachedWidth;
  NSUInteger _cachedTextHash;
  NSUInteger _cachedTextLength;
}

- (instancetype)initWithTextView:(UITextView *)textView {
  self = [super init];
  if (self) {
    _textView = textView;
    _overlays = [NSMutableArray new];
    _cachedWidth = 0;
    _cachedTextHash = 0;
    _cachedTextLength = 0;
  }
  return self;
}

- (void)removeAllOverlays {
  for (UIView *overlay in _overlays) {
    [overlay removeFromSuperview];
  }
  [_overlays removeAllObjects];
  _cachedWidth = 0;
  _cachedTextHash = 0;
  _cachedTextLength = 0;
}

- (void)updateOverlays {
  UITextView *textView = _textView;
  if (!textView) return;

  CGFloat width = textView.bounds.size.width;
  if (width <= 0) return;

  NSAttributedString *attrText = textView.attributedText;
  if (!attrText || attrText.length == 0) {
    [self removeAllOverlays];
    return;
  }

  NSUInteger textHash = attrText.hash;
  NSUInteger textLength = attrText.length;
  if (fabs(width - _cachedWidth) < 0.5 &&
      textHash == _cachedTextHash &&
      textLength == _cachedTextLength) {
    return;
  }
  _cachedWidth = width;
  _cachedTextHash = textHash;
  _cachedTextLength = textLength;

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

  // Collect link ranges.
  NSMutableArray<NSDictionary *> *linkHits = [NSMutableArray new];

  [attrText
      enumerateAttribute:NSLinkAttributeName
                 inRange:NSMakeRange(0, attrText.length)
                 options:0
              usingBlock:^(id value, NSRange range, BOOL *stop) {
    if (!value) return;
    NSURL *url = nil;
    if ([value isKindOfClass:[NSURL class]]) {
      url = value;
    } else if ([value isKindOfClass:[NSString class]]) {
      url = [NSURL URLWithString:(NSString *)value];
    }
    if (!url) return;
    [linkHits addObject:@{
      @"url" : url,
      @"range" : [NSValue valueWithRange:range],
    }];
  }];

  [self removeAllOverlays];

  for (NSDictionary *hit in linkHits) {
    NSURL *url = hit[@"url"];
    NSRange charRange = [hit[@"range"] rangeValue];
    NSRange glyphRange =
        [layoutManager glyphRangeForCharacterRange:charRange
                              actualCharacterRange:NULL];

    UIFont *rangeFont = [attrText attribute:NSFontAttributeName
                                    atIndex:charRange.location
                             effectiveRange:NULL];
    if (![rangeFont isKindOfClass:[UIFont class]]) {
      rangeFont = [UIFont systemFontOfSize:UIFont.systemFontSize];
    }
    CGFloat ascender = rangeFont.ascender;
    CGFloat descender = rangeFont.descender;

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
      rect = CGRectInset(rect, -kLinkPadding, -kLinkPadding);
      [perLineRects addObject:[NSValue valueWithCGRect:rect]];
    }];

    if (perLineRects.count == 0) continue;

    // Connect inter-line leading gaps.
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
                                           cornerRadius:kLinkCornerRadius];

    MarkdownPressableOverlayView *overlay =
        [[MarkdownPressableOverlayView alloc] initWithFrame:bounds];
    overlay.normalColor = [UIColor clearColor];
    overlay.pressedColor = [UIColor colorWithWhite:0.0 alpha:0.12];
    overlay.shapePath = path;

    objc_setAssociatedObject(overlay, kLinkURLKey, url,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [overlay addTarget:self
                action:@selector(handlePressUp:)
      forControlEvents:UIControlEventTouchUpInside];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleLongPress:)];
    [overlay addGestureRecognizer:longPress];

    [textView addSubview:overlay];
    [_overlays addObject:overlay];
  }
}

#pragma mark - Press handling

- (void)handlePressUp:(MarkdownPressableOverlayView *)sender {
  if (!_onPress) return;
  NSURL *url = objc_getAssociatedObject(sender, kLinkURLKey);
  if (url) {
    _onPress(url);
  }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
  if (recognizer.state != UIGestureRecognizerStateBegan) return;
  if (!_onLongPress) return;
  NSURL *url = objc_getAssociatedObject(recognizer.view, kLinkURLKey);
  if (url) {
    _onLongPress(url);
  }
}

@end
