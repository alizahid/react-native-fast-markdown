#import "FMDBlockTextView.h"

#import <CoreText/CoreText.h>

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
  NSAttributedString *display = [self displayText];
  [self drawRunBackgroundsIn:display];
  [display drawWithRect:self.bounds
                options:NSStringDrawingUsesLineFragmentOrigin |
                        NSStringDrawingUsesFontLeading
                context:nil];
  [self drawSpoilerCovers];
}

// Unrevealed spoiler text draws fully transparent — the cover hugs the
// glyph ink, so glyphs would leak around it if drawn. Color-only changes
// keep the geometry identical to the layout manager's.
- (NSAttributedString *)displayText {
  if (self.host == nil) {
    return _attributedText;
  }
  __block NSMutableAttributedString *copy = nil;
  [_attributedText
      enumerateAttribute:FMDSpoilerIDAttributeName
                 inRange:NSMakeRange(0, _attributedText.length)
                 options:0
              usingBlock:^(NSNumber *spoilerId, NSRange range, BOOL *stop) {
                if (spoilerId == nil ||
                    [self.host isSpoilerRevealed:spoilerId.integerValue]) {
                  return;
                }
                if (copy == nil) {
                  copy = [self->_attributedText mutableCopy];
                }
                [copy addAttribute:NSForegroundColorAttributeName
                             value:UIColor.clearColor
                             range:range];
                [copy addAttribute:NSUnderlineColorAttributeName
                             value:UIColor.clearColor
                             range:range];
                [copy addAttribute:NSStrikethroughColorAttributeName
                             value:UIColor.clearColor
                             range:range];
                // A chip under the cover would peek around it.
                [copy removeAttribute:FMDRunBackgroundAttributeName
                                range:range];
              }];
  return copy ?: _attributedText;
}

// Approximates iOS's continuous ("squircle") corner curve for a single
// rect; falls back to a plain rounded rect when the radius dominates.
static UIBezierPath *FMDChipPath(CGRect rect, CGFloat radius, BOOL continuous) {
  radius = MIN(radius, MIN(rect.size.width, rect.size.height) / 2);
  if (radius <= 0) {
    return [UIBezierPath bezierPathWithRect:rect];
  }
  if (!continuous) {
    return [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
  }
  // The standard smooth-corner approximation: control points extend ~1.528x
  // the radius along the edges. Degrades to circular when the rect is too
  // small to fit the extended corners.
  const CGFloat k = 1.528665;
  const CGFloat ext = radius * k;
  if (rect.size.width < 2 * ext || rect.size.height < 2 * ext) {
    return [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
  }
  const CGFloat minX = CGRectGetMinX(rect), maxX = CGRectGetMaxX(rect);
  const CGFloat minY = CGRectGetMinY(rect), maxY = CGRectGetMaxY(rect);
  UIBezierPath *path = [UIBezierPath bezierPath];
  [path moveToPoint:CGPointMake(minX + ext, minY)];
  [path addLineToPoint:CGPointMake(maxX - ext, minY)];
  [path addCurveToPoint:CGPointMake(maxX, minY + ext)
          controlPoint1:CGPointMake(maxX - ext + radius, minY)
          controlPoint2:CGPointMake(maxX, minY + ext - radius)];
  [path addLineToPoint:CGPointMake(maxX, maxY - ext)];
  [path addCurveToPoint:CGPointMake(maxX - ext, maxY)
          controlPoint1:CGPointMake(maxX, maxY - ext + radius)
          controlPoint2:CGPointMake(maxX - ext + radius, maxY)];
  [path addLineToPoint:CGPointMake(minX + ext, maxY)];
  [path addCurveToPoint:CGPointMake(minX, maxY - ext)
          controlPoint1:CGPointMake(minX + ext - radius, maxY)
          controlPoint2:CGPointMake(minX, maxY - ext + radius)];
  [path addLineToPoint:CGPointMake(minX, minY + ext)];
  [path addCurveToPoint:CGPointMake(minX + ext, minY)
          controlPoint1:CGPointMake(minX, minY + ext - radius)
          controlPoint2:CGPointMake(minX + ext - radius, minY)];
  [path closePath];
  return path;
}

// Overlays hug the glyph ink. lineHeight moves line boxes around the text,
// so any box derived from them inherits that skew; the ink bounding box
// plus breathing padding is anchored on the drawn baseline and stays glued
// to the glyphs no matter the line height.
static const CGFloat FMDInkPad = 2;

// Per-line ink rects for a character range: the tight glyph bounding box
// of each line's segment, padded. Whitespace-only segments have no ink and
// produce no rect.
- (NSArray<NSValue *> *)inkRectsForRange:(NSRange)range
                           layoutManager:(NSLayoutManager *)layoutManager
                                 padLeft:(CGFloat)padLeft
                                padRight:(CGFloat)padRight {
  CGContextRef context = UIGraphicsGetCurrentContext();
  // CTLineGetImageBounds reports bounds relative to the context's current
  // text position, and NSStringDrawing leaves it wherever the last drawn
  // line ended.
  CGContextSetTextPosition(context, 0, 0);
  const CGFloat maxWidth = self.bounds.size.width;
  const CGFloat maxHeight = self.bounds.size.height;
  const NSRange glyphRange =
      [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:nil];
  NSMutableArray<NSValue *> *lineRects = [NSMutableArray new];
  NSUInteger glyphIndex = glyphRange.location;
  while (glyphIndex < NSMaxRange(glyphRange)) {
    NSRange lineGlyphRange;
    const CGRect fragment =
        [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex
                                        effectiveRange:&lineGlyphRange];
    const NSRange lineRange = NSIntersectionRange(lineGlyphRange, glyphRange);
    if (lineRange.length == 0) {
      break;
    }
    const NSRange charRange =
        [layoutManager characterRangeForGlyphRange:lineRange actualGlyphRange:nil];
    const CGPoint startLocation =
        [layoutManager locationForGlyphAtIndex:lineRange.location];
    // The typesetter already folds NSBaselineOffset (lineHeight centering,
    // sup/sub shifts) into the glyph location.
    const CGFloat baselineY = fragment.origin.y + startLocation.y;
    const CGFloat penX = fragment.origin.x + startLocation.x;

    CTLineRef line = CTLineCreateWithAttributedString(
        (__bridge CFAttributedStringRef)[self->_attributedText
            attributedSubstringFromRange:charRange]);
    const CGRect ink = CTLineGetImageBounds(line, context);
    CFRelease(line);
    if (!CGRectIsNull(ink) && ink.size.width > 0) {
      // Both TextKit's glyph location and CTLine's image bounds fold in
      // NSBaselineOffset; anchor the (offset-inclusive) ink on the
      // un-offset baseline so it counts exactly once.
      const CGFloat runOffset =
          [[self->_attributedText attribute:NSBaselineOffsetAttributeName
                                    atIndex:charRange.location
                             effectiveRange:nil] doubleValue];
      const CGFloat inkBaseline = baselineY + runOffset;
      // Image bounds are baseline-relative with y up; flip into view space.
      const CGFloat top = MAX(inkBaseline - CGRectGetMaxY(ink) - FMDInkPad, 0);
      const CGFloat bottom =
          MIN(inkBaseline - CGRectGetMinY(ink) + FMDInkPad, maxHeight);
      const CGFloat left = MAX(penX + CGRectGetMinX(ink) - padLeft, 0);
      const CGFloat right = MIN(penX + CGRectGetMaxX(ink) + padRight, maxWidth);
      if (right > left && bottom > top) {
        [lineRects addObject:[NSValue valueWithCGRect:CGRectMake(
                                                          left, top,
                                                          right - left,
                                                          bottom - top)]];
      }
    }
    glyphIndex = NSMaxRange(lineGlyphRange);
  }
  return lineRects;
}

// Run background chips (inlineCode/link/mention and plain highlights),
// drawn UNDER the text; enumerates the display copy so chips hidden with
// their spoiler don't draw.
- (void)drawRunBackgroundsIn:(NSAttributedString *)display {
  if (display.length == 0) {
    return;
  }
  NSLayoutManager *layoutManager = [self layoutManagerForBounds];
  if (layoutManager == nil) {
    return;
  }
  [display
      enumerateAttribute:FMDRunBackgroundAttributeName
                 inRange:NSMakeRange(0, display.length)
                 options:0
              usingBlock:^(FMDRunBackground *chip, NSRange range, BOOL *stop) {
                if (chip == nil) {
                  return;
                }
                NSArray<NSValue *> *rects = [self
                    inkRectsForRange:range
                       layoutManager:layoutManager
                             padLeft:chip.padLeft > 0 ? chip.padLeft : FMDInkPad
                            padRight:chip.padRight > 0 ? chip.padRight
                                                       : FMDInkPad];
                [chip.color setFill];
                for (NSValue *value in rects) {
                  [FMDChipPath(value.CGRectValue, chip.radius,
                               chip.continuousCurve) fill];
                }
              }];
}

// Spoiler cover chips, drawn OVER the (transparent) text until revealed.
// Same ink geometry as the run backgrounds so covers and backgrounds look
// identical.
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
                NSArray<NSValue *> *rects =
                    [self inkRectsForRange:range
                             layoutManager:layoutManager
                                   padLeft:FMDInkPad
                                  padRight:FMDInkPad];
                [self.spoilerColor ?: UIColor.darkGrayColor setFill];
                for (NSValue *value in rects) {
                  [FMDChipPath(value.CGRectValue, self.spoilerRadius,
                               self.spoilerContinuous) fill];
                }
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
