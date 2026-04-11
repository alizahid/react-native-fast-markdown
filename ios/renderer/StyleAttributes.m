#import "StyleAttributes.h"
#import "StyleConfig.h"

@implementation StyleAttributes

+ (void)applyStyle:(MarkdownElementStyle *)style
            toAttrs:(NSMutableDictionary *)attrs {
  if (!style) return;

  // Font: cascade from base font in attrs, override with style properties
  UIFont *baseFont = attrs[NSFontAttributeName];
  UIFont *font = [style resolvedFontWithBase:baseFont];
  if (font) {
    attrs[NSFontAttributeName] = font;
  }

  // Color
  if (style.color) {
    attrs[NSForegroundColorAttributeName] = style.color;
  }

  // Background color — applies to the text range (inline highlighting)
  if (style.backgroundColor) {
    attrs[NSBackgroundColorAttributeName] = style.backgroundColor;
  }

  // Text decoration
  if (style.textDecorationLine) {
    if ([style.textDecorationLine isEqualToString:@"underline"]) {
      attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
    } else if ([style.textDecorationLine isEqualToString:@"line-through"]) {
      attrs[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
    }
  }

  // Paragraph style
  NSParagraphStyle *existing = attrs[NSParagraphStyleAttributeName];
  NSMutableParagraphStyle *pStyle =
      [self paragraphStyleFromStyle:style existingPStyle:existing];
  if (pStyle) {
    attrs[NSParagraphStyleAttributeName] = pStyle;
  }
}

+ (NSMutableParagraphStyle *)
    paragraphStyleFromStyle:(MarkdownElementStyle *)style
            existingPStyle:(NSParagraphStyle *)existing {
  BOOL hasLineHeight = style.lineHeight > 0;

  // Padding maps to indent and paragraph spacing
  UIEdgeInsets padding = [style resolvedPaddingInsets];
  BOOL hasPadding = padding.top > 0 || padding.bottom > 0 ||
                    padding.left > 0 || padding.right > 0;

  BOOL hasAlign = style.textAlign != nil;

  if (!(hasLineHeight || hasPadding || hasAlign)) {
    return nil;
  }

  NSMutableParagraphStyle *pStyle = existing
      ? [existing mutableCopy]
      : [[NSMutableParagraphStyle alloc] init];

  if (hasLineHeight) {
    pStyle.minimumLineHeight = style.lineHeight;
    pStyle.maximumLineHeight = style.lineHeight;
  }

  if (hasPadding) {
    pStyle.firstLineHeadIndent = padding.left;
    pStyle.headIndent = padding.left;
    pStyle.tailIndent = -padding.right;
    pStyle.paragraphSpacingBefore = padding.top;
    pStyle.paragraphSpacing = padding.bottom;
  }

  if (hasAlign) {
    if ([style.textAlign isEqualToString:@"center"]) {
      pStyle.alignment = NSTextAlignmentCenter;
    } else if ([style.textAlign isEqualToString:@"right"]) {
      pStyle.alignment = NSTextAlignmentRight;
    } else if ([style.textAlign isEqualToString:@"justify"]) {
      pStyle.alignment = NSTextAlignmentJustified;
    } else {
      pStyle.alignment = NSTextAlignmentLeft;
    }
  }

  return pStyle;
}

@end
