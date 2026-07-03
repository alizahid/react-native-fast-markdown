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

// One contiguous polygon per spoiler: the union outline of the per-line run
// rects with every outline corner rounded, drawn over the text until
// revealed. A wrapped spoiler reads as a single shape, not stacked pills.
- (void)drawSpoilerCovers {
  if (_attributedText.length == 0 || self.host == nil) {
    return;
  }
  NSLayoutManager *layoutManager = [self layoutManagerForBounds];
  if (layoutManager == nil) {
    return;
  }

  const CGFloat maxWidth = self.bounds.size.width;
  [_attributedText
      enumerateAttribute:FMDSpoilerIDAttributeName
                 inRange:NSMakeRange(0, _attributedText.length)
                 options:0
              usingBlock:^(NSNumber *spoilerId, NSRange range, BOOL *stop) {
                if (spoilerId == nil ||
                    [self.host isSpoilerRevealed:spoilerId.integerValue]) {
                  return;
                }
                NSMutableArray<NSValue *> *lineRects = [NSMutableArray new];
                const NSRange glyphRange =
                    [layoutManager glyphRangeForCharacterRange:range
                                          actualCharacterRange:nil];
                [layoutManager
                    enumerateEnclosingRectsForGlyphRange:glyphRange
                                withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0)
                                         inTextContainer:self->_textContainer
                                              usingBlock:^(CGRect rect, BOOL *stopRects) {
                                                CGRect expanded = CGRectInset(rect, -2, 0);
                                                if (expanded.origin.x < 0) {
                                                  expanded.size.width += expanded.origin.x;
                                                  expanded.origin.x = 0;
                                                }
                                                if (CGRectGetMaxX(expanded) > maxWidth) {
                                                  expanded.size.width =
                                                      maxWidth - expanded.origin.x;
                                                }
                                                [lineRects
                                                    addObject:[NSValue
                                                                  valueWithCGRect:expanded]];
                                              }];
                UIBezierPath *path = FMDRoundedOutlinePath(lineRects, self.spoilerRadius);
                [self.spoilerColor ?: UIColor.darkGrayColor setFill];
                [path fill];
              }];
}

// Union outline of vertically stacked per-line rects, rounded at every
// outline corner (convex and concave). Consecutive lines are merged into
// one shape only when they horizontally overlap; a wrapped run whose first
// segment ends right of where the next begins (no shared x range) renders
// as separate shapes — one polygon would self-intersect.
static void FMDAppendRoundedOutline(UIBezierPath *path,
                                    const CGRect *rects,
                                    NSUInteger count,
                                    CGFloat radius);

static UIBezierPath *FMDRoundedOutlinePath(NSArray<NSValue *> *lines, CGFloat radius) {
  UIBezierPath *path = [UIBezierPath bezierPath];
  if (lines.count == 0) {
    return path;
  }
  // Snap adjacent line rects into a contiguous stack so no hairline gaps or
  // overlaps show between lines.
  NSUInteger count = lines.count;
  CGRect rects[count];
  for (NSUInteger i = 0; i < count; i++) {
    rects[i] = lines[i].CGRectValue;
  }
  for (NSUInteger i = 0; i + 1 < count; i++) {
    const CGFloat boundary = (CGRectGetMaxY(rects[i]) + CGRectGetMinY(rects[i + 1])) / 2;
    rects[i].size.height = boundary - rects[i].origin.y;
    rects[i + 1].size.height = CGRectGetMaxY(rects[i + 1]) - boundary;
    rects[i + 1].origin.y = boundary;
  }

  NSUInteger start = 0;
  for (NSUInteger i = 1; i <= count; i++) {
    BOOL split = i == count;
    if (!split) {
      const CGFloat overlap = MIN(CGRectGetMaxX(rects[i - 1]), CGRectGetMaxX(rects[i])) -
          MAX(CGRectGetMinX(rects[i - 1]), CGRectGetMinX(rects[i]));
      split = overlap <= 0.5;
    }
    if (split) {
      FMDAppendRoundedOutline(path, rects + start, i - start, radius);
      start = i;
    }
  }
  return path;
}

static void FMDAppendRoundedOutline(UIBezierPath *path,
                                    const CGRect *rects,
                                    NSUInteger count,
                                    CGFloat radius) {
  if (count == 0) {
    return;
  }
  // Clockwise: top edge, down the right side with a jog at each width
  // change, bottom edge, back up the left side.
  NSUInteger capacity = count * 4;
  CGPoint pts[capacity];
  NSUInteger n = 0;
  pts[n++] = CGPointMake(CGRectGetMinX(rects[0]), CGRectGetMinY(rects[0]));
  pts[n++] = CGPointMake(CGRectGetMaxX(rects[0]), CGRectGetMinY(rects[0]));
  for (NSUInteger i = 0; i + 1 < count; i++) {
    if (fabs(CGRectGetMaxX(rects[i + 1]) - CGRectGetMaxX(rects[i])) > 0.5) {
      pts[n++] = CGPointMake(CGRectGetMaxX(rects[i]), CGRectGetMaxY(rects[i]));
      pts[n++] = CGPointMake(CGRectGetMaxX(rects[i + 1]), CGRectGetMaxY(rects[i]));
    }
  }
  pts[n++] = CGPointMake(CGRectGetMaxX(rects[count - 1]), CGRectGetMaxY(rects[count - 1]));
  pts[n++] = CGPointMake(CGRectGetMinX(rects[count - 1]), CGRectGetMaxY(rects[count - 1]));
  for (NSUInteger i = count - 1; i > 0; i--) {
    if (fabs(CGRectGetMinX(rects[i - 1]) - CGRectGetMinX(rects[i])) > 0.5) {
      pts[n++] = CGPointMake(CGRectGetMinX(rects[i]), CGRectGetMinY(rects[i]));
      pts[n++] = CGPointMake(CGRectGetMinX(rects[i - 1]), CGRectGetMinY(rects[i]));
    }
  }

  BOOL started = NO;
  for (NSUInteger i = 0; i < n; i++) {
    const CGPoint prev = pts[(i + n - 1) % n];
    const CGPoint v = pts[i];
    const CGPoint next = pts[(i + 1) % n];
    const CGFloat inLen = hypot(v.x - prev.x, v.y - prev.y);
    const CGFloat outLen = hypot(next.x - v.x, next.y - v.y);
    if (inLen < 0.01 || outLen < 0.01) {
      continue;
    }
    const CGFloat r = MIN(radius, MIN(inLen / 2, outLen / 2));
    const CGPoint entry =
        CGPointMake(v.x - (v.x - prev.x) / inLen * r, v.y - (v.y - prev.y) / inLen * r);
    const CGPoint exit =
        CGPointMake(v.x + (next.x - v.x) / outLen * r, v.y + (next.y - v.y) / outLen * r);
    if (!started) {
      [path moveToPoint:entry];
      started = YES;
    } else {
      [path addLineToPoint:entry];
    }
    [path addQuadCurveToPoint:exit controlPoint:v];
  }
  if (started) {
    [path closePath];
  }
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
