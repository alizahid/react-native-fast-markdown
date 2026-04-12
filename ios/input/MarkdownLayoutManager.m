#import "MarkdownLayoutManager.h"
#import "StyleConfig.h"

NSString *const MDBlockTypeAttributeName = @"MDBlockType";
NSString *const MDBlockTypeCodeBlock = @"codeBlock";
NSString *const MDBlockTypeBlockquote = @"blockquote";

@implementation MarkdownLayoutManager

- (void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow
                            atPoint:(CGPoint)origin {
  [super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];

  if (!_styleConfig) return;

  NSTextStorage *textStorage = self.textStorage;
  NSTextContainer *textContainer = self.textContainers.firstObject;
  if (!textStorage || !textContainer) return;

  NSRange charRange =
      [self characterRangeForGlyphRange:glyphsToShow
                       actualGlyphRange:nil];

  // Collect contiguous block runs
  [self drawBlockDecorationsInCharRange:charRange
                                origin:origin
                         textContainer:textContainer
                           textStorage:textStorage];
}

- (void)drawBlockDecorationsInCharRange:(NSRange)charRange
                                 origin:(CGPoint)origin
                          textContainer:(NSTextContainer *)textContainer
                            textStorage:(NSTextStorage *)textStorage {
  // Find all contiguous runs of the same block type and draw
  // one decoration per run.
  __block NSString *currentType = nil;
  __block NSUInteger runStart = NSNotFound;

  [textStorage enumerateAttribute:MDBlockTypeAttributeName
                          inRange:charRange
                          options:0
                       usingBlock:^(NSString *value, NSRange range,
                                    BOOL *stop) {
    if (value && [value isEqualToString:currentType]) {
      // Continue the current run
      return;
    }

    // End the previous run if there was one
    if (currentType && runStart != NSNotFound) {
      NSRange blockRange = NSMakeRange(runStart, range.location - runStart);
      [self drawDecorationForType:currentType
                            range:blockRange
                           origin:origin
                    textContainer:textContainer];
    }

    // Start a new run
    currentType = value;
    runStart = value ? range.location : NSNotFound;
  }];

  // Draw the last run
  if (currentType && runStart != NSNotFound) {
    NSRange blockRange =
        NSMakeRange(runStart, NSMaxRange(charRange) - runStart);
    [self drawDecorationForType:currentType
                          range:blockRange
                         origin:origin
                  textContainer:textContainer];
  }
}

- (void)drawDecorationForType:(NSString *)type
                        range:(NSRange)charRange
                       origin:(CGPoint)origin
                textContainer:(NSTextContainer *)textContainer {
  MarkdownElementStyle *style = nil;
  if ([type isEqualToString:MDBlockTypeCodeBlock]) {
    style = _styleConfig.codeBlock;
  } else if ([type isEqualToString:MDBlockTypeBlockquote]) {
    style = _styleConfig.blockquote;
  }
  if (!style) return;

  // Get the bounding rect for this range
  NSRange glyphRange =
      [self glyphRangeForCharacterRange:charRange
                   actualCharacterRange:nil];

  // Enumerate line fragments to build the full rect
  __block CGRect fullRect = CGRectNull;
  [self enumerateLineFragmentsForGlyphRange:glyphRange
      usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *tc,
                   NSRange lineGlyphRange, BOOL *stop) {
    CGRect lineRect = CGRectMake(origin.x,
                                  rect.origin.y + origin.y,
                                  textContainer.size.width,
                                  rect.size.height);
    if (CGRectIsNull(fullRect)) {
      fullRect = lineRect;
    } else {
      fullRect = CGRectUnion(fullRect, lineRect);
    }
  }];

  if (CGRectIsNull(fullRect)) return;

  CGContextRef ctx = UIGraphicsGetCurrentContext();
  if (!ctx) return;

  CGFloat radius = style.borderRadius;

  // Background
  if (style.backgroundColor) {
    CGContextSetFillColorWithColor(ctx, style.backgroundColor.CGColor);
    UIBezierPath *bgPath =
        [UIBezierPath bezierPathWithRoundedRect:fullRect
                                   cornerRadius:radius];
    CGContextAddPath(ctx, bgPath.CGPath);
    CGContextFillPath(ctx);
  }

  // Left border (for blockquotes)
  CGFloat borderWidth = style.borderLeftWidth;
  if (borderWidth <= 0) borderWidth = style.borderWidth;
  UIColor *borderColor = style.borderLeftColor ?: style.borderColor;

  if (borderWidth > 0 && borderColor) {
    CGRect borderRect = CGRectMake(fullRect.origin.x,
                                    fullRect.origin.y,
                                    borderWidth,
                                    fullRect.size.height);
    CGContextSetFillColorWithColor(ctx, borderColor.CGColor);
    UIBezierPath *borderPath =
        [UIBezierPath bezierPathWithRoundedRect:borderRect
                              byRoundingCorners:(UIRectCornerTopLeft |
                                                 UIRectCornerBottomLeft)
                                    cornerRadii:CGSizeMake(radius, radius)];
    CGContextAddPath(ctx, borderPath.CGPath);
    CGContextFillPath(ctx);
  }
}

@end
