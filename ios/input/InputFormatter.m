#import "InputFormatter.h"
#import "FormattingRange.h"
#import "FormattingStore.h"
#import "StyleConfig.h"

@implementation InputFormatter

- (void)applyAllFormatting:(FormattingStore *)store
             toTextStorage:(NSTextStorage *)textStorage {
  if (textStorage.length == 0) return;

  NSRange fullRange = NSMakeRange(0, textStorage.length);

  [textStorage beginEditing];

  // 1. Reset to base attributes
  NSDictionary *baseAttrs = @{
    NSFontAttributeName : _baseFont,
    NSForegroundColorAttributeName : _baseColor,
  };
  [textStorage setAttributes:baseAttrs range:fullRange];

  // 2. Apply block-level formatting first (sets base font for headings)
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isBlockType:r.type]) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;

    [self applyBlockRange:r toTextStorage:textStorage];
  }

  // 3. Apply inline formatting on top
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isInlineType:r.type]) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;

    [self applyInlineRange:r toTextStorage:textStorage];
  }

  [textStorage endEditing];
}

#pragma mark - Block Formatting

- (void)applyBlockRange:(FormattingRange *)r
          toTextStorage:(NSTextStorage *)textStorage {
  switch (r.type) {
  case FormattingTypeHeading1:
  case FormattingTypeHeading2:
  case FormattingTypeHeading3:
  case FormattingTypeHeading4:
  case FormattingTypeHeading5:
  case FormattingTypeHeading6: {
    NSInteger level = [FormattingRange headingLevelForType:r.type];
    MarkdownElementStyle *style = [_styleConfig styleForHeadingLevel:level];
    UIFont *headingFont = [style resolvedFontWithBase:_baseFont];
    if (!headingFont) {
      CGFloat scales[] = {0, 2.0, 1.5, 1.25, 1.1, 1.0, 0.9};
      CGFloat s = level <= 6 ? scales[level] : 1.0;
      headingFont = [UIFont systemFontOfSize:_baseFont.pointSize * s
                                      weight:UIFontWeightBold];
    }
    [textStorage addAttribute:NSFontAttributeName
                        value:headingFont
                        range:r.range];
    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:r.range];
    }
    break;
  }

  case FormattingTypeBlockquote: {
    MarkdownElementStyle *style = _styleConfig.blockquote;
    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:r.range];
    }
    UIFont *bqFont = [style resolvedFontWithBase:_baseFont];
    if (bqFont) {
      [textStorage addAttribute:NSFontAttributeName
                          value:bqFont
                          range:r.range];
    }
    // Background and border are drawn by BlockDecorationView.
    // Here we just set indent + spacing so text is positioned
    // inside the decoration.
    CGFloat indent = style.borderLeftWidth + style.padding +
                     style.paddingLeft + style.paddingHorizontal;
    if (indent <= 0) indent = 16;

    NSMutableParagraphStyle *pStyle = [NSMutableParagraphStyle new];
    pStyle.firstLineHeadIndent = indent;
    pStyle.headIndent = indent;
    pStyle.paragraphSpacingBefore = style.padding + style.paddingTop +
                                    style.paddingVertical;
    pStyle.paragraphSpacing = style.padding + style.paddingBottom +
                              style.paddingVertical;
    [textStorage addAttribute:NSParagraphStyleAttributeName
                        value:pStyle
                        range:r.range];
    break;
  }

  case FormattingTypeCodeBlock: {
    MarkdownElementStyle *style = _styleConfig.codeBlock;
    UIFont *codeFont =
        [style resolvedFontWithBase:_baseFont]
            ?: [UIFont monospacedSystemFontOfSize:_baseFont.pointSize
                                          weight:UIFontWeightRegular];
    [textStorage addAttribute:NSFontAttributeName
                        value:codeFont
                        range:r.range];
    UIColor *bg = style.backgroundColor
                      ?: [UIColor colorWithWhite:0.5 alpha:0.1];
    [textStorage addAttribute:NSBackgroundColorAttributeName
                        value:bg
                        range:r.range];
    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:r.range];
    }

    CGFloat pad = style.padding;
    if (pad > 0) {
      NSMutableParagraphStyle *pStyle = [NSMutableParagraphStyle new];
      pStyle.firstLineHeadIndent = pad;
      pStyle.headIndent = pad;
      pStyle.tailIndent = -pad;
      pStyle.paragraphSpacingBefore = pad;
      pStyle.paragraphSpacing = pad;
      [textStorage addAttribute:NSParagraphStyleAttributeName
                          value:pStyle
                          range:r.range];
    }
    break;
  }

  case FormattingTypeOrderedList:
  case FormattingTypeUnorderedList: {
    // Lists use base styling; bullet color is handled at import.
    break;
  }

  default:
    break;
  }
}

#pragma mark - Inline Formatting

- (void)applyInlineRange:(FormattingRange *)r
           toTextStorage:(NSTextStorage *)textStorage {
  switch (r.type) {
  case FormattingTypeBold: {
    [textStorage enumerateAttribute:NSFontAttributeName
                            inRange:r.range
                            options:0
                         usingBlock:^(UIFont *font, NSRange range,
                                      BOOL *stop) {
      UIFont *current = font ?: self->_baseFont;
      UIFontDescriptorSymbolicTraits traits =
          current.fontDescriptor.symbolicTraits | UIFontDescriptorTraitBold;
      UIFontDescriptor *desc =
          [current.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
      UIFont *bold =
          desc ? [UIFont fontWithDescriptor:desc size:current.pointSize]
               : [UIFont boldSystemFontOfSize:current.pointSize];
      [textStorage addAttribute:NSFontAttributeName value:bold range:range];
    }];

    MarkdownElementStyle *style = _styleConfig.strong;
    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:r.range];
    }
    break;
  }

  case FormattingTypeItalic: {
    [textStorage enumerateAttribute:NSFontAttributeName
                            inRange:r.range
                            options:0
                         usingBlock:^(UIFont *font, NSRange range,
                                      BOOL *stop) {
      UIFont *current = font ?: self->_baseFont;
      UIFontDescriptorSymbolicTraits traits =
          current.fontDescriptor.symbolicTraits | UIFontDescriptorTraitItalic;
      UIFontDescriptor *desc =
          [current.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
      UIFont *italic =
          desc ? [UIFont fontWithDescriptor:desc size:current.pointSize]
               : current;
      [textStorage addAttribute:NSFontAttributeName
                          value:italic
                          range:range];
    }];

    MarkdownElementStyle *style = _styleConfig.emphasis;
    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:r.range];
    }
    break;
  }

  case FormattingTypeStrikethrough: {
    [textStorage addAttribute:NSStrikethroughStyleAttributeName
                        value:@(NSUnderlineStyleSingle)
                        range:r.range];
    MarkdownElementStyle *style = _styleConfig.strikethrough;
    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:r.range];
      [textStorage addAttribute:NSStrikethroughColorAttributeName
                          value:style.color
                          range:r.range];
    }
    break;
  }

  case FormattingTypeCode: {
    MarkdownElementStyle *style = _styleConfig.code;
    UIFont *codeFont =
        [style resolvedFontWithBase:_baseFont]
            ?: [UIFont monospacedSystemFontOfSize:_baseFont.pointSize
                                          weight:UIFontWeightRegular];
    [textStorage addAttribute:NSFontAttributeName
                        value:codeFont
                        range:r.range];
    UIColor *bg = style.backgroundColor
                      ?: [UIColor colorWithWhite:0.5 alpha:0.1];
    [textStorage addAttribute:NSBackgroundColorAttributeName
                        value:bg
                        range:r.range];
    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:r.range];
    }
    break;
  }

  case FormattingTypeLink: {
    MarkdownElementStyle *style = _styleConfig.link;
    UIColor *linkColor = style.color ?: [UIColor systemBlueColor];
    [textStorage addAttribute:NSForegroundColorAttributeName
                        value:linkColor
                        range:r.range];
    break;
  }

  default:
    break;
  }
}

@end
