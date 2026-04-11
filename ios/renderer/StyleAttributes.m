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

  // Background color — inline highlight (e.g. code)
  if (style.backgroundColor) {
    attrs[NSBackgroundColorAttributeName] = style.backgroundColor;
  }

  // Letter spacing (kerning)
  if (style.letterSpacing != 0) {
    attrs[NSKernAttributeName] = @(style.letterSpacing);
  }

  // Text decoration
  if (style.textDecorationLine) {
    NSUnderlineStyle underlineStyle = [self underlineStyleFromName:style.textDecorationStyle];
    if ([style.textDecorationLine isEqualToString:@"underline"]) {
      attrs[NSUnderlineStyleAttributeName] = @(underlineStyle);
      if (style.textDecorationColor) {
        attrs[NSUnderlineColorAttributeName] = style.textDecorationColor;
      }
    } else if ([style.textDecorationLine isEqualToString:@"line-through"]) {
      attrs[NSStrikethroughStyleAttributeName] = @(underlineStyle);
      if (style.textDecorationColor) {
        attrs[NSStrikethroughColorAttributeName] = style.textDecorationColor;
      }
    } else if ([style.textDecorationLine isEqualToString:@"underline line-through"]) {
      attrs[NSUnderlineStyleAttributeName] = @(underlineStyle);
      attrs[NSStrikethroughStyleAttributeName] = @(underlineStyle);
      if (style.textDecorationColor) {
        attrs[NSUnderlineColorAttributeName] = style.textDecorationColor;
        attrs[NSStrikethroughColorAttributeName] = style.textDecorationColor;
      }
    }
  }

  // Paragraph style (lineHeight, textAlign)
  NSParagraphStyle *existing = attrs[NSParagraphStyleAttributeName];
  NSMutableParagraphStyle *pStyle =
      [self paragraphStyleFromStyle:style existingPStyle:existing];
  if (pStyle) {
    attrs[NSParagraphStyleAttributeName] = pStyle;
  }
}

+ (NSUnderlineStyle)underlineStyleFromName:(NSString *)name {
  if ([name isEqualToString:@"double"]) return NSUnderlineStyleDouble;
  if ([name isEqualToString:@"dotted"]) return NSUnderlineStyleSingle | NSUnderlinePatternDot;
  if ([name isEqualToString:@"dashed"]) return NSUnderlineStyleSingle | NSUnderlinePatternDash;
  return NSUnderlineStyleSingle;
}

+ (NSMutableParagraphStyle *)
    paragraphStyleFromStyle:(MarkdownElementStyle *)style
            existingPStyle:(NSParagraphStyle *)existing {
  BOOL hasLineHeight = style.lineHeight > 0;
  BOOL hasAlign = style.textAlign != nil;

  if (!(hasLineHeight || hasAlign)) {
    return nil;
  }

  NSMutableParagraphStyle *pStyle = existing
      ? [existing mutableCopy]
      : [[NSMutableParagraphStyle alloc] init];

  if (hasLineHeight) {
    pStyle.minimumLineHeight = style.lineHeight;
    pStyle.maximumLineHeight = style.lineHeight;
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
