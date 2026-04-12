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

  CGFloat lineHeight = _baseLineHeight > 0
      ? _baseLineHeight
      : _styleConfig.base.lineHeight;
  CGFloat gap = _paragraphSpacing > 0
      ? _paragraphSpacing
      : _styleConfig.base.gap;

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

  // Apply block-level formatting from the store
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isBlockType:r.type]) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;
    [self applyBlockRange:r
            toTextStorage:textStorage
               lineHeight:lineHeight
                      gap:gap];
  }

  // Apply inline formatting on top
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isInlineType:r.type]) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;
    [self applyInlineRange:r toTextStorage:textStorage];
  }

  // Apply mention styling from MDMentionTag attributes
  [self applyMentionStyling:textStorage];

  [textStorage endEditing];
}

- (void)applyFormattingInRange:(NSRange)dirtyRange
                         store:(FormattingStore *)store
                 toTextStorage:(NSTextStorage *)textStorage {
  if (textStorage.length == 0) return;

  // Clamp to text storage bounds
  if (dirtyRange.location >= textStorage.length) return;
  if (NSMaxRange(dirtyRange) > textStorage.length) {
    dirtyRange.length = textStorage.length - dirtyRange.location;
  }
  if (dirtyRange.length == 0) return;

  CGFloat lineHeight = _baseLineHeight > 0
      ? _baseLineHeight
      : _styleConfig.base.lineHeight;
  CGFloat gap = _paragraphSpacing > 0
      ? _paragraphSpacing
      : _styleConfig.base.gap;

  [textStorage beginEditing];

  NSMutableParagraphStyle *basePStyle = [NSMutableParagraphStyle new];
  if (lineHeight > 0) {
    basePStyle.minimumLineHeight = lineHeight;
    basePStyle.maximumLineHeight = lineHeight;
  }
  if (gap > 0) {
    basePStyle.paragraphSpacing = gap;
  }

  [textStorage addAttribute:NSFontAttributeName
                       value:_baseFont
                       range:dirtyRange];
  [textStorage addAttribute:NSForegroundColorAttributeName
                       value:_baseColor
                       range:dirtyRange];
  [textStorage addAttribute:NSParagraphStyleAttributeName
                       value:basePStyle
                       range:dirtyRange];
  [textStorage removeAttribute:NSBackgroundColorAttributeName
                         range:dirtyRange];
  [textStorage removeAttribute:NSStrikethroughStyleAttributeName
                         range:dirtyRange];
  [textStorage removeAttribute:NSStrikethroughColorAttributeName
                         range:dirtyRange];

  // Re-apply block formatting that intersects the dirty range
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isBlockType:r.type]) continue;
    NSRange intersection = NSIntersectionRange(r.range, dirtyRange);
    if (intersection.length == 0) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;
    [self applyBlockRange:r
            toTextStorage:textStorage
               lineHeight:lineHeight
                      gap:gap];
  }

  // Re-apply inline formatting that intersects the dirty range
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isInlineType:r.type]) continue;
    NSRange intersection = NSIntersectionRange(r.range, dirtyRange);
    if (intersection.length == 0) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;
    [self applyInlineRange:r toTextStorage:textStorage];
  }

  // Apply mention styling in the dirty range
  [self applyMentionStylingInRange:dirtyRange textStorage:textStorage];

  [textStorage endEditing];
}

#pragma mark - Mention Styling

- (void)applyMentionStyling:(NSTextStorage *)textStorage {
  if (textStorage.length == 0) return;
  [self applyMentionStylingInRange:NSMakeRange(0, textStorage.length)
                       textStorage:textStorage];
}

- (void)applyMentionStylingInRange:(NSRange)range
                       textStorage:(NSTextStorage *)textStorage {
  [textStorage enumerateAttribute:@"MDMentionTag"
                          inRange:range
                          options:0
                       usingBlock:^(NSString *tag, NSRange mRange,
                                    BOOL *stop) {
    if (!tag) return;

    MarkdownElementStyle *style = nil;
    if ([tag hasPrefix:@"<UserMention"]) {
      style = self->_styleConfig.mentionUser;
    } else if ([tag hasPrefix:@"<ChannelMention"]) {
      style = self->_styleConfig.mentionChannel;
    } else if ([tag hasPrefix:@"<Command"]) {
      style = self->_styleConfig.mentionCommand;
    }
    if (!style) return;

    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:mRange];
    }
    UIFont *mFont = [style resolvedFontWithBase:self->_baseFont];
    if (mFont) {
      [textStorage addAttribute:NSFontAttributeName
                          value:mFont
                          range:mRange];
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

  case FormattingTypeBlockquote:
  case FormattingTypeCodeBlock:
    // Block-level code blocks and blockquotes are not rendered
    // in the editor. They are only used by the parser/serializer.
    break;

  case FormattingTypeOrderedList:
  case FormattingTypeUnorderedList:
    break;

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
