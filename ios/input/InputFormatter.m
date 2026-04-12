#import "InputFormatter.h"
#import "FormattingRange.h"
#import "FormattingStore.h"
#import "MarkdownLayoutManager.h"
#import "StyleConfig.h"

@implementation InputFormatter

- (void)applyAllFormatting:(FormattingStore *)store
             toTextStorage:(NSTextStorage *)textStorage {
  if (textStorage.length == 0) return;

  NSRange fullRange = NSMakeRange(0, textStorage.length);

  [textStorage beginEditing];

  CGFloat lineHeight = _baseLineHeight > 0
      ? _baseLineHeight
      : _styleConfig.base.lineHeight;
  CGFloat gap = _paragraphSpacing > 0
      ? _paragraphSpacing
      : _styleConfig.base.gap;

  // 1. Reset base text attributes WITHOUT clearing MDBlockType.
  // We overwrite font, color, paragraph style, and clear inline
  // decorations, but preserve the block type attribute so
  // UITextView's paragraph propagation stays intact.
  NSMutableParagraphStyle *basePStyle = [NSMutableParagraphStyle new];
  if (lineHeight > 0) {
    basePStyle.minimumLineHeight = lineHeight;
    basePStyle.maximumLineHeight = lineHeight;
  }
  if (gap > 0) {
    basePStyle.paragraphSpacing = gap;
  }

  [textStorage addAttribute:NSFontAttributeName value:_baseFont range:fullRange];
  [textStorage addAttribute:NSForegroundColorAttributeName value:_baseColor range:fullRange];
  [textStorage addAttribute:NSParagraphStyleAttributeName value:basePStyle range:fullRange];
  [textStorage removeAttribute:NSBackgroundColorAttributeName range:fullRange];
  [textStorage removeAttribute:NSStrikethroughStyleAttributeName range:fullRange];
  [textStorage removeAttribute:NSStrikethroughColorAttributeName range:fullRange];

  // Also set MDBlockType from the store for freshly imported/toggled blocks
  for (FormattingRange *r in store.allRanges) {
    NSString *blockType = nil;
    if (r.type == FormattingTypeCodeBlock) {
      blockType = MDBlockTypeCodeBlock;
    } else if (r.type == FormattingTypeBlockquote) {
      blockType = MDBlockTypeBlockquote;
    }
    if (!blockType) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;
    [textStorage addAttribute:MDBlockTypeAttributeName
                        value:blockType
                        range:r.range];
  }

  // 2. Apply block-level formatting from the store
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isBlockType:r.type]) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;
    [self applyBlockRange:r
            toTextStorage:textStorage
               lineHeight:lineHeight
                      gap:gap];
  }

  // 3. Apply block formatting from paragraph attributes (blocks
  //    that were continued via Enter — they're in the attributed
  //    string but not in the FormattingStore)
  [self applyBlockTypesFromAttributes:textStorage
                           lineHeight:lineHeight
                                  gap:gap];

  // 4. Apply inline formatting on top
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isInlineType:r.type]) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;
    [self applyInlineRange:r toTextStorage:textStorage];
  }

  [textStorage endEditing];
}

- (void)applyBlockTypesFromAttributes:(NSTextStorage *)textStorage
                           lineHeight:(CGFloat)lineHeight
                                  gap:(CGFloat)gap {
  [textStorage enumerateAttribute:MDBlockTypeAttributeName
                          inRange:NSMakeRange(0, textStorage.length)
                          options:0
                       usingBlock:^(NSString *value, NSRange range,
                                    BOOL *stop) {
    if (!value) return;

    if ([value isEqualToString:MDBlockTypeCodeBlock]) {
      [self applyCodeBlockStyling:range
                    toTextStorage:textStorage
                       lineHeight:lineHeight
                              gap:gap];
    } else if ([value isEqualToString:MDBlockTypeBlockquote]) {
      [self applyBlockquoteStyling:range
                     toTextStorage:textStorage
                        lineHeight:lineHeight
                               gap:gap];
    }
  }];
}

#pragma mark - Block Formatting

- (void)applyBlockRange:(FormattingRange *)r
          toTextStorage:(NSTextStorage *)textStorage
             lineHeight:(CGFloat)lineHeight
                    gap:(CGFloat)gap {
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
    [textStorage addAttribute:MDBlockTypeAttributeName
                        value:MDBlockTypeBlockquote
                        range:r.range];
    [self applyBlockquoteStyling:r.range
                   toTextStorage:textStorage
                      lineHeight:lineHeight
                             gap:gap];
    break;
  }

  case FormattingTypeCodeBlock: {
    [textStorage addAttribute:MDBlockTypeAttributeName
                        value:MDBlockTypeCodeBlock
                        range:r.range];
    [self applyCodeBlockStyling:r.range
                  toTextStorage:textStorage
                     lineHeight:lineHeight
                            gap:gap];
    break;
  }

  case FormattingTypeOrderedList:
  case FormattingTypeUnorderedList:
    break;

  default:
    break;
  }
}

- (void)applyCodeBlockStyling:(NSRange)range
                toTextStorage:(NSTextStorage *)textStorage
                   lineHeight:(CGFloat)lineHeight
                          gap:(CGFloat)gap {
  MarkdownElementStyle *style = _styleConfig.codeBlock;
  UIFont *codeFont =
      [style resolvedFontWithBase:_baseFont]
          ?: [UIFont monospacedSystemFontOfSize:_baseFont.pointSize
                                        weight:UIFontWeightRegular];
  [textStorage addAttribute:NSFontAttributeName
                      value:codeFont
                      range:range];
  if (style.color) {
    [textStorage addAttribute:NSForegroundColorAttributeName
                        value:style.color
                        range:range];
  }

  // Code blocks use tight line spacing internally — no paragraph
  // spacing between lines within the block. The padding is only
  // visual (drawn by the layout manager).
  CGFloat pad = style.padding;
  NSMutableParagraphStyle *pStyle = [NSMutableParagraphStyle new];
  if (pad > 0) {
    pStyle.firstLineHeadIndent = pad;
    pStyle.headIndent = pad;
    pStyle.tailIndent = -pad;
  }
  if (lineHeight > 0) {
    pStyle.minimumLineHeight = lineHeight;
    pStyle.maximumLineHeight = lineHeight;
  }
  // No paragraphSpacing — lines inside code blocks are tight
  pStyle.paragraphSpacing = 0;
  [textStorage addAttribute:NSParagraphStyleAttributeName
                      value:pStyle
                      range:range];
}

- (void)applyBlockquoteStyling:(NSRange)range
                 toTextStorage:(NSTextStorage *)textStorage
                    lineHeight:(CGFloat)lineHeight
                           gap:(CGFloat)gap {
  MarkdownElementStyle *style = _styleConfig.blockquote;
  if (style.color) {
    [textStorage addAttribute:NSForegroundColorAttributeName
                        value:style.color
                        range:range];
  }
  UIFont *bqFont = [style resolvedFontWithBase:_baseFont];
  if (bqFont) {
    [textStorage addAttribute:NSFontAttributeName
                        value:bqFont
                        range:range];
  }

  CGFloat indent = style.borderLeftWidth + style.padding +
                   style.paddingLeft + style.paddingHorizontal;
  if (indent <= 0) indent = 16;

  NSMutableParagraphStyle *pStyle = [NSMutableParagraphStyle new];
  pStyle.firstLineHeadIndent = indent;
  pStyle.headIndent = indent;
  if (lineHeight > 0) {
    pStyle.minimumLineHeight = lineHeight;
    pStyle.maximumLineHeight = lineHeight;
  }
  pStyle.paragraphSpacingBefore = style.padding + style.paddingTop +
                                  style.paddingVertical;
  CGFloat bqPadBottom = style.padding + style.paddingBottom +
                        style.paddingVertical;
  pStyle.paragraphSpacing = MAX(bqPadBottom, gap);
  [textStorage addAttribute:NSParagraphStyleAttributeName
                      value:pStyle
                      range:range];
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
