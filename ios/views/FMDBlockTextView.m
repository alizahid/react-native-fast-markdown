#import "FMDBlockTextView.h"

@implementation FMDBlockTextView {
  NSLayoutManager *_layoutManager;
  NSTextContainer *_textContainer;
  NSTextStorage *_textStorage;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.backgroundColor = UIColor.clearColor;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

// Hit-test transparent: the host component view owns all touch handling,
// so ancestor scroll views treat markdown content like any React view.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  return nil;
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
  if (![_attributedText isEqualToAttributedString:attributedText]) {
    _attributedText = [attributedText copy];
    _layoutManager = nil;
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = attributedText.string;
    self.accessibilityTraits = UIAccessibilityTraitStaticText;
    [self setNeedsDisplay];
  }
}

// Lazy TextKit stack for hit-testing and spoiler-range geometry; drawing
// stays on NSStringDrawing so measured heights match exactly.
- (NSLayoutManager *)layoutManagerForBounds {
  if (_layoutManager == nil && _attributedText != nil) {
    _textStorage = [[NSTextStorage alloc] initWithAttributedString:_attributedText];
    _layoutManager = [NSLayoutManager new];
    _textContainer =
        [[NSTextContainer alloc] initWithSize:CGSizeMake(self.bounds.size.width, CGFLOAT_MAX)];
    _textContainer.lineFragmentPadding = 0;
    [_layoutManager addTextContainer:_textContainer];
    [_textStorage addLayoutManager:_layoutManager];
  } else if (_textContainer != nil &&
             _textContainer.size.width != self.bounds.size.width) {
    _textContainer.size = CGSizeMake(self.bounds.size.width, CGFLOAT_MAX);
  }
  return _layoutManager;
}

- (void)drawRect:(CGRect)rect {
  [_attributedText drawWithRect:self.bounds
                        options:NSStringDrawingUsesLineFragmentOrigin |
                                NSStringDrawingUsesFontLeading
                        context:nil];
  [self drawSpoilerCovers];
}

// One contiguous rounded polygon per spoiler (union of per-line run
// rects), drawn over the text until revealed.
- (void)drawSpoilerCovers {
  if (_attributedText.length == 0 || self.host == nil) {
    return;
  }
  NSLayoutManager *layoutManager = [self layoutManagerForBounds];
  if (layoutManager == nil) {
    return;
  }

  [_attributedText
      enumerateAttribute:FMDSpoilerIDAttributeName
                 inRange:NSMakeRange(0, _attributedText.length)
                 options:0
              usingBlock:^(NSNumber *spoilerId, NSRange range, BOOL *stop) {
                if (spoilerId == nil ||
                    [self.host isSpoilerRevealed:spoilerId.integerValue]) {
                  return;
                }
                UIBezierPath *path = [UIBezierPath bezierPath];
                const NSRange glyphRange =
                    [layoutManager glyphRangeForCharacterRange:range
                                          actualCharacterRange:nil];
                [layoutManager
                    enumerateEnclosingRectsForGlyphRange:glyphRange
                                withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0)
                                         inTextContainer:self->_textContainer
                                              usingBlock:^(CGRect rect, BOOL *stopRects) {
                                                [path appendPath:
                                                          [UIBezierPath
                                                              bezierPathWithRoundedRect:
                                                                  CGRectInset(rect, -2, 0)
                                                                           cornerRadius:
                                                                               self.spoilerRadius]];
                                              }];
                [self.spoilerColor ?: UIColor.darkGrayColor setFill];
                [path fill];
              }];
}

- (nullable NSDictionary *)attributesAtPoint:(CGPoint)point {
  NSLayoutManager *layoutManager = [self layoutManagerForBounds];
  if (layoutManager == nil || _attributedText.length == 0) {
    return nil;
  }
  const NSUInteger glyphIndex = [layoutManager glyphIndexForPoint:point
                                                  inTextContainer:_textContainer];
  const CGRect glyphRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                                    inTextContainer:_textContainer];
  if (!CGRectContainsPoint(CGRectInset(glyphRect, -8, -4), point)) {
    return nil;
  }
  const NSUInteger charIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
  if (charIndex >= _attributedText.length) {
    return nil;
  }
  return [_attributedText attributesAtIndex:charIndex effectiveRange:nil];
}

@end
