#import "MarkdownSpoilerOverlay.h"
#import "CustomTagRenderer.h"

static const CGFloat kOverlayCornerRadius = 4.0;
static const CGFloat kRevealAnimationDuration = 0.25;

@interface MarkdownSpoilerOverlayView : UIView
@property (nonatomic, copy) NSString *spoilerId;
@property (nonatomic, assign) BOOL revealed;
@end

@implementation MarkdownSpoilerOverlayView

- (void)toggleReveal {
  _revealed = !_revealed;
  [UIView animateWithDuration:kRevealAnimationDuration animations:^{
    self.alpha = self->_revealed ? 0.0 : 1.0;
  }];
}

@end

@implementation MarkdownSpoilerOverlay {
  __weak UITextView *_textView;
  NSMutableArray<MarkdownSpoilerOverlayView *> *_overlays;
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

  // For each spoiler, get glyph rects and create overlays
  for (NSString *spoilerId in spoilerRanges) {
    BOOL isRevealed = [_revealedIds containsObject:spoilerId];

    for (NSValue *rangeValue in spoilerRanges[spoilerId]) {
      NSRange charRange = rangeValue.rangeValue;

      // Convert to glyph range
      NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange
                                                 actualCharacterRange:NULL];

      // Enumerate enclosing rects (one per line fragment the range spans)
      [layoutManager enumerateEnclosingRectsForGlyphRange:glyphRange
                                 withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0)
                                          inTextContainer:textContainer
                                               usingBlock:^(CGRect rect, BOOL *stop) {
        if (CGRectIsEmpty(rect) || rect.size.width < 1) return;

        CGRect overlayRect = CGRectOffset(rect, textOrigin.x, textOrigin.y);

        MarkdownSpoilerOverlayView *overlay =
            [[MarkdownSpoilerOverlayView alloc] initWithFrame:overlayRect];
        overlay.spoilerId = spoilerId;
        overlay.backgroundColor = self->_overlayColor;
        overlay.layer.cornerRadius = kOverlayCornerRadius;
        overlay.layer.masksToBounds = YES;
        overlay.revealed = isRevealed;
        overlay.alpha = isRevealed ? 0.0 : 1.0;
        overlay.userInteractionEnabled = YES;

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleSpoilerTap:)];
        [overlay addGestureRecognizer:tap];

        [textView addSubview:overlay];
        [self->_overlays addObject:overlay];
      }];
    }
  }
}

- (void)handleSpoilerTap:(UITapGestureRecognizer *)gesture {
  MarkdownSpoilerOverlayView *tappedOverlay =
      (MarkdownSpoilerOverlayView *)gesture.view;
  if (!tappedOverlay) return;

  NSString *spoilerId = tappedOverlay.spoilerId;
  if (!spoilerId) return;

  // Toggle all overlays with the same spoiler ID
  BOOL willReveal = ![_revealedIds containsObject:spoilerId];

  if (willReveal) {
    [_revealedIds addObject:spoilerId];
  } else {
    [_revealedIds removeObject:spoilerId];
  }

  for (MarkdownSpoilerOverlayView *overlay in _overlays) {
    if ([overlay.spoilerId isEqualToString:spoilerId]) {
      overlay.revealed = willReveal;
      [UIView animateWithDuration:kRevealAnimationDuration animations:^{
        overlay.alpha = willReveal ? 0.0 : 1.0;
      }];
    }
  }
}

@end
