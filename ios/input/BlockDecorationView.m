#import "BlockDecorationView.h"
#import "FormattingRange.h"
#import "FormattingStore.h"
#import "StyleConfig.h"

@implementation BlockDecorationView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
  }
  return self;
}

- (void)updateDecorationsForTextView:(UITextView *)textView
                               store:(FormattingStore *)store
                         styleConfig:(StyleConfig *)styleConfig {
  // Remove old decoration layers
  self.layer.sublayers = nil;

  self.frame = textView.bounds;

  NSLayoutManager *layoutManager = textView.layoutManager;
  NSTextContainer *textContainer = textView.textContainer;
  UIEdgeInsets insets = textView.textContainerInset;
  CGPoint origin = CGPointMake(insets.left, insets.top);

  // Collect and merge adjacent/overlapping block ranges by type
  // so they draw as one continuous visual block.
  NSMutableArray<FormattingRange *> *blockRanges = [NSMutableArray new];
  for (FormattingRange *r in store.allRanges) {
    if (r.type != FormattingTypeBlockquote &&
        r.type != FormattingTypeCodeBlock) continue;
    if (NSMaxRange(r.range) > textView.textStorage.length) continue;
    [blockRanges addObject:r];
  }

  // Merge ranges of the same type that are adjacent (touching or
  // separated by just a newline)
  NSMutableArray<FormattingRange *> *merged = [NSMutableArray new];
  for (FormattingRange *r in blockRanges) {
    BOOL didMerge = NO;
    for (FormattingRange *m in merged) {
      if (m.type != r.type) continue;
      NSUInteger mEnd = NSMaxRange(m.range);
      NSUInteger rStart = r.range.location;
      // Adjacent or overlapping (allow 1 char gap for newline)
      if (rStart <= mEnd + 1 && r.range.location >= m.range.location) {
        NSUInteger newEnd = MAX(mEnd, NSMaxRange(r.range));
        m.range = NSMakeRange(m.range.location, newEnd - m.range.location);
        didMerge = YES;
        break;
      }
    }
    if (!didMerge) {
      [merged addObject:[r copy]];
    }
  }

  for (FormattingRange *r in merged) {
    MarkdownElementStyle *style = nil;

    if (r.type == FormattingTypeBlockquote) {
      style = styleConfig.blockquote;
    } else if (r.type == FormattingTypeCodeBlock) {
      style = styleConfig.codeBlock;
    }

    if (!style) continue;

    // Get the bounding rect for this range's glyphs
    NSRange glyphRange =
        [layoutManager glyphRangeForCharacterRange:r.range
                              actualCharacterRange:nil];
    CGRect boundingRect =
        [layoutManager boundingRectForGlyphRange:glyphRange
                                 inTextContainer:textContainer];

    // Offset by text container inset
    boundingRect.origin.x += origin.x;
    boundingRect.origin.y += origin.y;

    // Expand rect by padding
    CGFloat padH = style.padding + style.paddingHorizontal;
    CGFloat padV = style.padding + style.paddingVertical;
    CGFloat padTop = padV + style.paddingTop;
    CGFloat padBottom = padV + style.paddingBottom;
    CGFloat padLeft = padH + style.paddingLeft;
    CGFloat padRight = padH + style.paddingRight;

    CGRect decorRect = CGRectMake(
        boundingRect.origin.x - padLeft,
        boundingRect.origin.y - padTop,
        boundingRect.size.width + padLeft + padRight,
        boundingRect.size.height + padTop + padBottom);

    // Stretch to full width
    decorRect.origin.x = origin.x;
    decorRect.size.width = textView.bounds.size.width - origin.x * 2;

    // Background fill
    CGFloat radius = style.borderRadius;
    UIBezierPath *bgPath =
        [UIBezierPath bezierPathWithRoundedRect:decorRect
                                   cornerRadius:radius];

    if (style.backgroundColor) {
      CAShapeLayer *bgLayer = [CAShapeLayer new];
      bgLayer.path = bgPath.CGPath;
      bgLayer.fillColor = style.backgroundColor.CGColor;
      [self.layer addSublayer:bgLayer];
    }

    // Left border
    CGFloat borderWidth = style.borderLeftWidth;
    if (borderWidth <= 0) borderWidth = style.borderWidth;
    UIColor *borderColor = style.borderLeftColor ?: style.borderColor;

    if (borderWidth > 0 && borderColor) {
      CGRect borderRect = CGRectMake(
          decorRect.origin.x,
          decorRect.origin.y,
          borderWidth,
          decorRect.size.height);

      UIBezierPath *borderPath =
          [UIBezierPath bezierPathWithRoundedRect:borderRect
                                byRoundingCorners:(UIRectCornerTopLeft |
                                                   UIRectCornerBottomLeft)
                                      cornerRadii:CGSizeMake(radius, radius)];

      CAShapeLayer *borderLayer = [CAShapeLayer new];
      borderLayer.path = borderPath.CGPath;
      borderLayer.fillColor = borderColor.CGColor;
      [self.layer addSublayer:borderLayer];
    }
  }
}

@end
