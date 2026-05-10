#import "InputFormatter.h"
#import "FormattingRange.h"
#import "FormattingStore.h"
#import "StyleAttributes.h"
#import "StyleConfig.h"

#import <CoreText/CoreText.h>

@implementation InputFormatter

- (void)applyAllFormatting:(FormattingStore *)store
             toTextStorage:(NSTextStorage *)textStorage {
  if (textStorage.length == 0) return;

  NSRange fullRange = NSMakeRange(0, textStorage.length);

  [textStorage beginEditing];

  CGFloat lineHeight = _baseLineHeight > 0
      ? _baseLineHeight
      : _styleConfig.base.lineHeight;
  NSMutableParagraphStyle *basePStyle = [NSMutableParagraphStyle new];
  if (lineHeight > 0) {
    basePStyle.minimumLineHeight = lineHeight;
    basePStyle.maximumLineHeight = lineHeight;
  }

  [textStorage addAttribute:NSFontAttributeName value:_baseFont range:fullRange];
  [textStorage addAttribute:NSForegroundColorAttributeName value:_baseColor range:fullRange];
  [textStorage addAttribute:NSParagraphStyleAttributeName value:basePStyle range:fullRange];
  [textStorage removeAttribute:NSBackgroundColorAttributeName range:fullRange];
  [textStorage removeAttribute:NSStrikethroughStyleAttributeName range:fullRange];
  [textStorage removeAttribute:NSStrikethroughColorAttributeName range:fullRange];
  [textStorage removeAttribute:(NSString *)kCTSuperscriptAttributeName range:fullRange];

  // Apply block-level formatting from the store
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isBlockType:r.type]) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;
    [self applyBlockRange:r
            toTextStorage:textStorage
               lineHeight:lineHeight];
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
  [textStorage beginEditing];

  NSMutableParagraphStyle *basePStyle = [NSMutableParagraphStyle new];
  if (lineHeight > 0) {
    basePStyle.minimumLineHeight = lineHeight;
    basePStyle.maximumLineHeight = lineHeight;
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
  [textStorage removeAttribute:(NSString *)kCTSuperscriptAttributeName
                         range:dirtyRange];

  // Re-apply block formatting that intersects the dirty range
  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isBlockType:r.type]) continue;
    NSRange intersection = NSIntersectionRange(r.range, dirtyRange);
    if (intersection.length == 0) continue;
    if (NSMaxRange(r.range) > textStorage.length) continue;
    [self applyBlockRange:r
            toTextStorage:textStorage
               lineHeight:lineHeight];
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
  // Mention styling is now driven by FormattingTypeMention ranges.
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
             lineHeight:(CGFloat)lineHeight {
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
    [self applyElementStyle:_styleConfig.blockquote
              toTextStorage:textStorage
                      range:r.range];
    [textStorage removeAttribute:NSBackgroundColorAttributeName range:r.range];
    [self applyBlockLayoutForStyle:_styleConfig.blockquote
                      textStorage:textStorage
                             range:r.range];
    break;

  case FormattingTypeCodeBlock: {
    MarkdownElementStyle *style = _styleConfig.codeBlock;
    [self applyElementStyle:style toTextStorage:textStorage range:r.range];
    [textStorage removeAttribute:NSBackgroundColorAttributeName range:r.range];

    [self applyBlockLayoutForStyle:style
                      textStorage:textStorage
                             range:r.range];
    break;
  }

  case FormattingTypeOrderedList:
  case FormattingTypeUnorderedList:
    [self applyElementStyle:_styleConfig.listItem
              toTextStorage:textStorage
                      range:r.range];
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
    [self applyElementStyle:style toTextStorage:textStorage range:r.range];
    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:r.range];
    }
    break;
  }

  case FormattingTypeLink: {
    MarkdownElementStyle *style = _styleConfig.link;
    if (style.color) {
      [textStorage addAttribute:NSForegroundColorAttributeName
                          value:style.color
                          range:r.range];
    }
    break;
  }

  case FormattingTypeSpoiler: {
    MarkdownElementStyle *style = _styleConfig.spoiler;
    if (style.backgroundColor) {
      [textStorage addAttribute:NSBackgroundColorAttributeName
                          value:style.backgroundColor
                          range:r.range];
    }
    break;
  }

  case FormattingTypeSuperscript: {
    MarkdownElementStyle *style = _styleConfig.superscript;
    [self applyElementStyle:style toTextStorage:textStorage range:r.range];
    [textStorage addAttribute:(NSString *)kCTSuperscriptAttributeName
                        value:@1
                        range:r.range];
    break;
  }

  case FormattingTypeMention: {
    MarkdownElementStyle *style = [self styleForMentionRange:r];
    [self applyElementStyle:style toTextStorage:textStorage range:r.range];
    NSString *tag = [self tagStringForMentionRange:r];
    if (tag.length > 0) {
      [textStorage addAttribute:@"MDMentionTag" value:tag range:r.range];
    }
    break;
  }

  default:
    break;
  }
}

- (void)applyElementStyle:(MarkdownElementStyle *)style
            toTextStorage:(NSTextStorage *)textStorage
                    range:(NSRange)range {
  if (!style || range.length == 0 || NSMaxRange(range) > textStorage.length) {
    return;
  }

  NSMutableDictionary *attrs =
      [[textStorage attributesAtIndex:range.location
                        effectiveRange:nil] mutableCopy] ?: [NSMutableDictionary new];
  if (!attrs[NSFontAttributeName] && _baseFont) {
    attrs[NSFontAttributeName] = _baseFont;
  }
  if (!attrs[NSForegroundColorAttributeName] && _baseColor) {
    attrs[NSForegroundColorAttributeName] = _baseColor;
  }

  [StyleAttributes applyStyle:style toAttrs:attrs];
  for (NSString *key in attrs) {
    [textStorage addAttribute:key value:attrs[key] range:range];
  }
}

- (void)applyBlockLayoutForStyle:(MarkdownElementStyle *)style
                     textStorage:(NSTextStorage *)textStorage
                            range:(NSRange)range {
  if (range.length == 0 || NSMaxRange(range) > textStorage.length) return;

  UIEdgeInsets padding = style ? [style resolvedPaddingInsets] : UIEdgeInsetsZero;
  UIEdgeInsets borders = style ? [style resolvedBorderWidths] : UIEdgeInsetsZero;
  CGFloat indent = borders.left + padding.left;
  CGFloat rightPadding = borders.right + padding.right;

  [textStorage enumerateAttribute:NSParagraphStyleAttributeName
                          inRange:range
                          options:0
                       usingBlock:^(NSParagraphStyle *value, NSRange subrange,
                                    BOOL *stop) {
    NSMutableParagraphStyle *pStyle = value
        ? [value mutableCopy]
        : [[NSMutableParagraphStyle alloc] init];
    pStyle.firstLineHeadIndent = indent;
    pStyle.headIndent = indent;
    if (rightPadding > 0) {
      pStyle.tailIndent = -rightPadding;
    }
    [textStorage addAttribute:NSParagraphStyleAttributeName
                        value:pStyle
                        range:subrange];
  }];
}

- (MarkdownElementStyle *)styleForMentionRange:(FormattingRange *)range {
  if ([range.tagName isEqualToString:@"ChannelMention"]) {
    return _styleConfig.mentionChannel;
  }
  if ([range.tagName isEqualToString:@"Command"]) {
    return _styleConfig.mentionCommand;
  }
  return _styleConfig.mentionUser;
}

- (NSString *)tagStringForMentionRange:(FormattingRange *)range {
  if (!range.tagName) return nil;
  NSMutableString *tag = [NSMutableString stringWithFormat:@"<%@", range.tagName];
  NSArray *keys = [[range.tagProps allKeys]
      sortedArrayUsingSelector:@selector(compare:)];
  for (NSString *key in keys) {
    NSString *value = range.tagProps[key] ?: @"";
    [tag appendFormat:@" %@=\"%@\"", key, [self escapedAttributeValue:value]];
  }
  [tag appendString:@" />"];
  return tag;
}

- (NSString *)escapedAttributeValue:(NSString *)value {
  NSString *escaped = [value stringByReplacingOccurrencesOfString:@"&"
                                                       withString:@"&amp;"];
  escaped = [escaped stringByReplacingOccurrencesOfString:@"\""
                                               withString:@"&quot;"];
  escaped = [escaped stringByReplacingOccurrencesOfString:@"<"
                                               withString:@"&lt;"];
  escaped = [escaped stringByReplacingOccurrencesOfString:@">"
                                               withString:@"&gt;"];
  return escaped;
}

@end
