#import "MarkdownMentionOverlay.h"
#import "CustomTagRenderer.h"
#import "MarkdownPressableOverlayView.h"

#import <objc/runtime.h>

static const CGFloat kOverlayCornerRadius = 4.0;

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

  // Each mention gets a unique group id so a multi-line mention
  // highlights all its line fragments in lockstep.
  NSInteger groupCounter = 0;
  for (NSDictionary *hit in mentionHits) {
    NSDictionary *data = hit[@"data"];
    NSRange charRange = [hit[@"range"] rangeValue];
    NSString *groupId =
        [NSString stringWithFormat:@"mention-%ld", (long)groupCounter++];

    NSRange glyphRange =
        [layoutManager glyphRangeForCharacterRange:charRange
                             actualCharacterRange:NULL];

    [layoutManager
        enumerateEnclosingRectsForGlyphRange:glyphRange
                    withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0)
                             inTextContainer:textContainer
                                  usingBlock:^(CGRect rect, BOOL *stop) {
      if (CGRectIsEmpty(rect) || rect.size.width < 1) return;

      CGRect overlayRect = CGRectOffset(rect, textOrigin.x, textOrigin.y);

      MarkdownPressableOverlayView *overlay =
          [[MarkdownPressableOverlayView alloc] initWithFrame:overlayRect];
      overlay.groupId = groupId;
      overlay.normalColor = [UIColor clearColor];
      overlay.pressedColor = [UIColor colorWithWhite:0.0 alpha:0.12];
      overlay.layer.cornerRadius = kOverlayCornerRadius;
      overlay.layer.masksToBounds = YES;

      // Hang the mention dict off the overlay so the press handler
      // can read it back without re-querying the attributed string.
      objc_setAssociatedObject(overlay, kMentionDataKey, data,
                               OBJC_ASSOCIATION_RETAIN_NONATOMIC);

      [overlay addTarget:self
                  action:@selector(handlePressDown:)
        forControlEvents:UIControlEventTouchDown];
      [overlay addTarget:self
                  action:@selector(handlePressUp:)
        forControlEvents:UIControlEventTouchUpInside];

      [textView addSubview:overlay];
      [self->_overlays addObject:overlay];
    }];
  }
}

#pragma mark - Press handling

- (void)handlePressDown:(MarkdownPressableOverlayView *)sender {
  // Highlight every overlay in the same group so a mention that
  // wraps across two lines highlights as one unit.
  for (MarkdownPressableOverlayView *overlay in _overlays) {
    if (overlay != sender && [overlay.groupId isEqualToString:sender.groupId]) {
      overlay.highlighted = YES;
    }
  }
}

- (void)handlePressUp:(MarkdownPressableOverlayView *)sender {
  for (MarkdownPressableOverlayView *overlay in _overlays) {
    if (overlay != sender && [overlay.groupId isEqualToString:sender.groupId]) {
      overlay.highlighted = NO;
    }
  }

  if (!_onPress) return;
  NSDictionary *data = objc_getAssociatedObject(sender, kMentionDataKey);
  if ([data isKindOfClass:[NSDictionary class]]) {
    _onPress(data);
  }
}

@end
