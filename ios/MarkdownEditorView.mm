#import "MarkdownEditorView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

#import "StyleAttributes.h"
#import "StyleConfig.h"

using namespace facebook::react;

@interface MarkdownEditorView () <UITextViewDelegate>
@end

@implementation MarkdownEditorView {
  UITextView *_textView;
  StyleConfig *_styleConfig;
  NSString *_currentStyleJSON;
  NSArray<NSString *> *_customTags;

  // Formatting state
  BOOL _isBold;
  BOOL _isItalic;
  BOOL _isStrikethrough;
  BOOL _isCode;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<
      MarkdownEditorViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _textView = [[UITextView alloc] initWithFrame:self.bounds];
    _textView.delegate = self;
    _textView.autocorrectionType = UITextAutocorrectionTypeDefault;
    _textView.scrollEnabled = YES;
    _textView.backgroundColor = [UIColor clearColor];
    [self addSubview:_textView];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _textView.frame = self.bounds;
}

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newProps =
      *std::static_pointer_cast<const MarkdownEditorViewProps>(props);

  // Default value
  if (!oldProps) {
    NSString *defaultValue =
        [NSString stringWithUTF8String:newProps.defaultValue.c_str()];
    if (defaultValue.length > 0) {
      _textView.text = defaultValue;
      [self applyMarkdownFormatting];
    }
  }

  // Editable
  _textView.editable = newProps.editable;

  // Style
  NSString *styleJSON = newProps.styles.empty()
                            ? @""
                            : [NSString stringWithUTF8String:newProps.styles.c_str()];
  if (![styleJSON isEqualToString:_currentStyleJSON ?: @""]) {
    _currentStyleJSON = styleJSON;
    _styleConfig = [StyleConfig fromJSON:styleJSON];
    [self applyMarkdownFormatting];
  }

  // Custom tags
  NSMutableArray<NSString *> *tags = [NSMutableArray new];
  for (const auto &tag : newProps.customTags) {
    [tags addObject:[NSString stringWithUTF8String:tag.c_str()]];
  }
  _customTags = tags;

  // Auto focus
  if (!oldProps && newProps.autoFocus) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self->_textView becomeFirstResponder];
    });
  }

  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Native Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  if ([commandName isEqualToString:@"focus"]) {
    [_textView becomeFirstResponder];
  } else if ([commandName isEqualToString:@"blur"]) {
    [_textView resignFirstResponder];
  } else if ([commandName isEqualToString:@"setValue"]) {
    NSString *value = args[0];
    _textView.text = value;
  } else if ([commandName isEqualToString:@"setSelection"]) {
    NSInteger start = [args[0] integerValue];
    NSInteger end = [args[1] integerValue];
    _textView.selectedRange = NSMakeRange(start, end - start);
  } else if ([commandName isEqualToString:@"toggleBold"]) {
    [self toggleFormatting:@"**"];
  } else if ([commandName isEqualToString:@"toggleItalic"]) {
    [self toggleFormatting:@"*"];
  } else if ([commandName isEqualToString:@"toggleStrikethrough"]) {
    [self toggleFormatting:@"~~"];
  } else if ([commandName isEqualToString:@"toggleCode"]) {
    [self toggleFormatting:@"`"];
  } else if ([commandName isEqualToString:@"toggleHeading"]) {
    NSInteger level = [args[0] integerValue];
    [self toggleHeading:level];
  } else if ([commandName isEqualToString:@"toggleOrderedList"]) {
    [self toggleLinePrefix:@"1. "];
  } else if ([commandName isEqualToString:@"toggleUnorderedList"]) {
    [self toggleLinePrefix:@"- "];
  } else if ([commandName isEqualToString:@"toggleBlockquote"]) {
    [self toggleLinePrefix:@"> "];
  } else if ([commandName isEqualToString:@"insertLink"]) {
    NSString *url = args[0];
    NSString *text = args.count > 1 ? args[1] : @"";
    [self insertLinkWithURL:url text:text];
  } else if ([commandName isEqualToString:@"removeLink"]) {
    [self removeLink];
  } else if ([commandName isEqualToString:@"insertMention"]) {
    NSString *user = args[0];
    [self insertText:[NSString stringWithFormat:@"<Mention user=\"%@\" />", user]];
  } else if ([commandName isEqualToString:@"insertSpoiler"]) {
    [self wrapSelection:@"<Spoiler>" suffix:@"</Spoiler>"];
  } else if ([commandName isEqualToString:@"insertCustomTag"]) {
    NSString *tag = args[0];
    NSString *propsJSON = args.count > 1 ? args[1] : @"{}";
    [self insertCustomTag:tag propsJSON:propsJSON];
  }
}

#pragma mark - Formatting

- (void)toggleFormatting:(NSString *)marker {
  NSRange selectedRange = _textView.selectedRange;
  NSString *text = _textView.text;

  if (selectedRange.length == 0) {
    NSString *newText = [NSString stringWithFormat:@"%@%@", marker, marker];
    [self insertText:newText];
    _textView.selectedRange =
        NSMakeRange(selectedRange.location + marker.length, 0);
  } else {
    NSString *selectedText = [text substringWithRange:selectedRange];

    if ([selectedText hasPrefix:marker] &&
        [selectedText hasSuffix:marker] &&
        selectedText.length > marker.length * 2) {
      NSString *unformatted = [selectedText
          substringWithRange:NSMakeRange(marker.length,
                                         selectedText.length -
                                             marker.length * 2)];
      [_textView replaceRange:[self textRangeFromNSRange:selectedRange]
                     withText:unformatted];
    } else {
      NSString *formatted = [NSString
          stringWithFormat:@"%@%@%@", marker, selectedText, marker];
      [_textView replaceRange:[self textRangeFromNSRange:selectedRange]
                     withText:formatted];
    }
  }

  [self emitChangeEvents];
}

- (void)toggleHeading:(NSInteger)level {
  NSString *prefix = @"";
  for (NSInteger i = 0; i < level; i++) {
    prefix = [prefix stringByAppendingString:@"#"];
  }
  prefix = [prefix stringByAppendingString:@" "];
  [self toggleLinePrefix:prefix];
}

- (void)toggleLinePrefix:(NSString *)prefix {
  NSRange selectedRange = _textView.selectedRange;
  NSString *text = _textView.text;

  NSRange lineRange = [text lineRangeForRange:selectedRange];
  NSString *line = [text substringWithRange:lineRange];

  if ([line hasPrefix:prefix]) {
    NSString *newLine = [line substringFromIndex:prefix.length];
    [_textView replaceRange:[self textRangeFromNSRange:lineRange]
                   withText:newLine];
  } else {
    NSString *newLine = [prefix stringByAppendingString:line];
    [_textView replaceRange:[self textRangeFromNSRange:lineRange]
                   withText:newLine];
  }

  [self emitChangeEvents];
}

- (void)insertLinkWithURL:(NSString *)url text:(NSString *)text {
  NSRange selectedRange = _textView.selectedRange;

  NSString *linkText;
  if (text.length > 0) {
    linkText = [NSString stringWithFormat:@"[%@](%@)", text, url];
  } else if (selectedRange.length > 0) {
    NSString *selected = [_textView.text substringWithRange:selectedRange];
    linkText = [NSString stringWithFormat:@"[%@](%@)", selected, url];
  } else {
    linkText = [NSString stringWithFormat:@"[link](%@)", url];
  }

  [self insertText:linkText];
}

- (void)removeLink {
  [self emitChangeEvents];
}

- (void)wrapSelection:(NSString *)prefix suffix:(NSString *)suffix {
  NSRange selectedRange = _textView.selectedRange;
  NSString *text = _textView.text;

  if (selectedRange.length > 0) {
    NSString *selected = [text substringWithRange:selectedRange];
    NSString *wrapped =
        [NSString stringWithFormat:@"%@%@%@", prefix, selected, suffix];
    [_textView replaceRange:[self textRangeFromNSRange:selectedRange]
                   withText:wrapped];
  } else {
    NSString *wrapped =
        [NSString stringWithFormat:@"%@%@", prefix, suffix];
    [self insertText:wrapped];
    _textView.selectedRange =
        NSMakeRange(selectedRange.location + prefix.length, 0);
  }

  [self emitChangeEvents];
}

- (void)insertText:(NSString *)text {
  [_textView replaceRange:[self textRangeFromNSRange:_textView.selectedRange]
                 withText:text];
  [self emitChangeEvents];
}

- (void)insertCustomTag:(NSString *)tag propsJSON:(NSString *)propsJSON {
  NSData *data = [propsJSON dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *props =
      [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

  NSMutableString *tagStr = [NSMutableString stringWithFormat:@"<%@", tag];
  for (NSString *key in props) {
    [tagStr appendFormat:@" %@=\"%@\"", key, props[key]];
  }
  [tagStr appendString:@" />"];
  [self insertText:tagStr];
}

- (UITextRange *)textRangeFromNSRange:(NSRange)range {
  UITextPosition *start =
      [_textView positionFromPosition:_textView.beginningOfDocument
                               offset:range.location];
  UITextPosition *end =
      [_textView positionFromPosition:start offset:range.length];
  return [_textView textRangeFromPosition:start toPosition:end];
}

#pragma mark - Markdown Formatting

- (void)applyMarkdownFormatting {
  NSString *text = _textView.text;
  if (text.length == 0) {
    [self updateTypingAttributes];
    return;
  }

  NSRange savedRange = _textView.selectedRange;

  UIFont *baseFont = [_styleConfig.base resolvedFont]
                         ?: [UIFont systemFontOfSize:16];
  UIColor *textColor = _styleConfig.base.color ?: [UIColor labelColor];
  UIColor *markerColor = [textColor colorWithAlphaComponent:0.35];

  NSMutableDictionary *baseAttrs = [@{
    NSFontAttributeName : baseFont,
    NSForegroundColorAttributeName : textColor,
  } mutableCopy];

  NSMutableAttributedString *as =
      [[NSMutableAttributedString alloc] initWithString:text
                                             attributes:baseAttrs];

  // Track fenced code block ranges — nothing inside them is parsed.
  NSMutableIndexSet *codeBlockChars = [NSMutableIndexSet new];

  // --- Pass 1: fenced code blocks (``` … ```) ---
  [self styleFencedCodeBlocks:as
                     baseFont:baseFont
                  markerColor:markerColor
               codeBlockChars:codeBlockChars];

  // --- Pass 2: block-level (headings, blockquotes, lists, HRs) ---
  [self styleBlockElements:as
                  baseFont:baseFont
               markerColor:markerColor
            codeBlockChars:codeBlockChars];

  // --- Pass 3: inline (bold, italic, strikethrough, code, links) ---
  [self styleInlineElements:as
                   baseFont:baseFont
                markerColor:markerColor
             codeBlockChars:codeBlockChars];

  _textView.attributedText = as;

  if (savedRange.location + savedRange.length <= text.length) {
    _textView.selectedRange = savedRange;
  }

  [self updateTypingAttributes];
}

- (void)updateTypingAttributes {
  UIFont *baseFont = [_styleConfig.base resolvedFont]
                         ?: [UIFont systemFontOfSize:16];
  UIColor *textColor = _styleConfig.base.color ?: [UIColor labelColor];
  _textView.typingAttributes = @{
    NSFontAttributeName : baseFont,
    NSForegroundColorAttributeName : textColor,
  };
}

#pragma mark - Fenced Code Blocks

- (void)styleFencedCodeBlocks:(NSMutableAttributedString *)as
                     baseFont:(UIFont *)baseFont
                  markerColor:(UIColor *)markerColor
               codeBlockChars:(NSMutableIndexSet *)codeBlockChars {
  NSString *text = as.string;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"^(`{3,})(.*?)\\n([\\s\\S]*?)^\\1\\s*$"
                           options:NSRegularExpressionAnchorsMatchLines
                             error:nil];

  [regex enumerateMatchesInString:text
                          options:0
                            range:NSMakeRange(0, text.length)
                       usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags,
                                    BOOL *stop) {
    NSRange fullRange = [match range];
    NSRange fenceOpenRange = [match rangeAtIndex:1];
    NSRange langRange = [match rangeAtIndex:2];
    NSRange contentRange = [match rangeAtIndex:3];

    [codeBlockChars addIndexesInRange:fullRange];

    // Style the content with code font + background
    MarkdownElementStyle *style = self->_styleConfig.codeBlock;
    UIFont *codeFont = [style resolvedFontWithBase:baseFont]
                           ?: [UIFont monospacedSystemFontOfSize:baseFont.pointSize
                                                          weight:UIFontWeightRegular];
    UIColor *bgColor = style.backgroundColor
                           ?: [UIColor colorWithWhite:0.5 alpha:0.1];

    [as addAttribute:NSFontAttributeName value:codeFont range:contentRange];
    [as addAttribute:NSBackgroundColorAttributeName value:bgColor range:contentRange];
    if (style.color) {
      [as addAttribute:NSForegroundColorAttributeName
                 value:style.color
                 range:contentRange];
    }

    // Dim the fence markers and language hint
    [as addAttribute:NSForegroundColorAttributeName
               value:markerColor
               range:fenceOpenRange];
    if (langRange.length > 0) {
      [as addAttribute:NSForegroundColorAttributeName
                 value:markerColor
                 range:langRange];
    }

    // Dim closing fence
    NSUInteger closeStart = contentRange.location + contentRange.length;
    NSUInteger closeLen = (fullRange.location + fullRange.length) - closeStart;
    if (closeLen > 0) {
      [as addAttribute:NSForegroundColorAttributeName
                 value:markerColor
                 range:NSMakeRange(closeStart, closeLen)];
    }
  }];
}

#pragma mark - Block Elements

- (void)styleBlockElements:(NSMutableAttributedString *)as
                  baseFont:(UIFont *)baseFont
               markerColor:(UIColor *)markerColor
            codeBlockChars:(NSMutableIndexSet *)codeBlockChars {
  NSString *text = as.string;

  [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
    // Find this line's range in the full text
    // enumerateLinesUsingBlock doesn't give us the range directly
  }];

  // Use regex to find line ranges instead, which gives us positions.
  NSRegularExpression *lineRegex = [NSRegularExpression
      regularExpressionWithPattern:@"^.*$"
                           options:NSRegularExpressionAnchorsMatchLines
                             error:nil];

  [lineRegex enumerateMatchesInString:text
                              options:0
                                range:NSMakeRange(0, text.length)
                           usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags,
                                        BOOL *stop) {
    NSRange lineRange = [match range];
    if ([codeBlockChars containsIndexesInRange:lineRange]) return;

    NSString *line = [text substringWithRange:lineRange];

    // Headings: # through ######
    [self styleHeadingInLine:line range:lineRange as:as baseFont:baseFont markerColor:markerColor];

    // Blockquote: > ...
    [self styleBlockquoteInLine:line range:lineRange as:as baseFont:baseFont markerColor:markerColor];

    // Thematic break: --- or *** or ___
    [self styleThematicBreakInLine:line range:lineRange as:as markerColor:markerColor];
  }];
}

- (void)styleHeadingInLine:(NSString *)line
                     range:(NSRange)lineRange
                        as:(NSMutableAttributedString *)as
                  baseFont:(UIFont *)baseFont
               markerColor:(UIColor *)markerColor {
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"^(#{1,6})\\s+"
                           options:0
                             error:nil];
  NSTextCheckingResult *match =
      [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
  if (!match) return;

  NSRange hashRange = [match rangeAtIndex:1];
  NSInteger level = hashRange.length;

  MarkdownElementStyle *style = [_styleConfig styleForHeadingLevel:level];
  UIFont *headingFont = [style resolvedFontWithBase:baseFont];
  if (!headingFont) {
    // Default heading sizes
    CGFloat sizes[] = {0, 2.0, 1.5, 1.25, 1.1, 1.0, 0.9};
    CGFloat scale = level <= 6 ? sizes[level] : 1.0;
    headingFont = [UIFont systemFontOfSize:baseFont.pointSize * scale
                                    weight:UIFontWeightBold];
  }

  // Style the text content (after the marker)
  NSUInteger contentStart = lineRange.location + match.range.length;
  NSUInteger contentLen = lineRange.length - match.range.length;
  if (contentLen > 0) {
    NSRange contentRange = NSMakeRange(contentStart, contentLen);
    [as addAttribute:NSFontAttributeName value:headingFont range:contentRange];
    if (style.color) {
      [as addAttribute:NSForegroundColorAttributeName
                 value:style.color
                 range:contentRange];
    }
  }

  // Dim the # marker
  NSRange markerRange = NSMakeRange(lineRange.location + hashRange.location,
                                    match.range.length);
  [as addAttribute:NSForegroundColorAttributeName
             value:markerColor
             range:markerRange];
}

- (void)styleBlockquoteInLine:(NSString *)line
                        range:(NSRange)lineRange
                           as:(NSMutableAttributedString *)as
                     baseFont:(UIFont *)baseFont
                  markerColor:(UIColor *)markerColor {
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"^(>\\s*)"
                           options:0
                             error:nil];
  NSTextCheckingResult *match =
      [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
  if (!match) return;

  MarkdownElementStyle *style = _styleConfig.blockquote;

  // Dim the > marker
  NSRange markerRange = NSMakeRange(lineRange.location, match.range.length);
  [as addAttribute:NSForegroundColorAttributeName
             value:markerColor
             range:markerRange];

  // Style the content
  if (style.color) {
    NSUInteger contentStart = lineRange.location + match.range.length;
    NSUInteger contentLen = lineRange.length - match.range.length;
    if (contentLen > 0) {
      [as addAttribute:NSForegroundColorAttributeName
                 value:style.color
                 range:NSMakeRange(contentStart, contentLen)];
    }
  }

  // Italic by default for blockquotes, unless overridden
  UIFont *bqFont = [style resolvedFontWithBase:baseFont];
  if (bqFont) {
    NSRange contentRange = NSMakeRange(lineRange.location + match.range.length,
                                       lineRange.length - match.range.length);
    [as addAttribute:NSFontAttributeName value:bqFont range:contentRange];
  }
}

- (void)styleThematicBreakInLine:(NSString *)line
                           range:(NSRange)lineRange
                              as:(NSMutableAttributedString *)as
                     markerColor:(UIColor *)markerColor {
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"^([-*_]\\s*){3,}$"
                           options:0
                             error:nil];
  if ([regex firstMatchInString:line options:0
                          range:NSMakeRange(0, line.length)]) {
    [as addAttribute:NSForegroundColorAttributeName
               value:markerColor
               range:lineRange];
  }
}

#pragma mark - Inline Elements

- (void)styleInlineElements:(NSMutableAttributedString *)as
                   baseFont:(UIFont *)baseFont
                markerColor:(UIColor *)markerColor
             codeBlockChars:(NSMutableIndexSet *)codeBlockChars {
  // Order matters: bold before italic (both use *)
  [self styleInlineCode:as baseFont:baseFont markerColor:markerColor
         codeBlockChars:codeBlockChars];
  [self styleBold:as baseFont:baseFont markerColor:markerColor
   codeBlockChars:codeBlockChars];
  [self styleItalic:as baseFont:baseFont markerColor:markerColor
     codeBlockChars:codeBlockChars];
  [self styleStrikethrough:as markerColor:markerColor
            codeBlockChars:codeBlockChars];
  [self styleLinks:as markerColor:markerColor codeBlockChars:codeBlockChars];
}

- (void)styleInlineCode:(NSMutableAttributedString *)as
               baseFont:(UIFont *)baseFont
            markerColor:(UIColor *)markerColor
         codeBlockChars:(NSMutableIndexSet *)codeBlockChars {
  NSString *text = as.string;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"(`+)(?!`)(.*?)(?<!`)\\1(?!`)"
                           options:0
                             error:nil];

  [regex enumerateMatchesInString:text
                          options:0
                            range:NSMakeRange(0, text.length)
                       usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags,
                                    BOOL *stop) {
    NSRange fullRange = [match range];
    if ([codeBlockChars containsIndexesInRange:fullRange]) return;

    NSRange contentRange = [match rangeAtIndex:2];
    NSRange openTick = [match rangeAtIndex:1];
    NSRange closeTick = NSMakeRange(contentRange.location + contentRange.length,
                                     openTick.length);

    MarkdownElementStyle *style = self->_styleConfig.code;
    UIFont *codeFont = [style resolvedFontWithBase:baseFont]
                           ?: [UIFont monospacedSystemFontOfSize:baseFont.pointSize
                                                          weight:UIFontWeightRegular];
    UIColor *bgColor = style.backgroundColor
                           ?: [UIColor colorWithWhite:0.5 alpha:0.1];

    [as addAttribute:NSFontAttributeName value:codeFont range:contentRange];
    [as addAttribute:NSBackgroundColorAttributeName value:bgColor range:contentRange];
    if (style.color) {
      [as addAttribute:NSForegroundColorAttributeName
                 value:style.color
                 range:contentRange];
    }

    // Dim backticks
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:openTick];
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:closeTick];
  }];
}

- (void)styleBold:(NSMutableAttributedString *)as
         baseFont:(UIFont *)baseFont
      markerColor:(UIColor *)markerColor
   codeBlockChars:(NSMutableIndexSet *)codeBlockChars {
  NSString *text = as.string;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"(\\*\\*|__)(.+?)\\1"
                           options:0
                             error:nil];

  [regex enumerateMatchesInString:text
                          options:0
                            range:NSMakeRange(0, text.length)
                       usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags,
                                    BOOL *stop) {
    NSRange fullRange = [match range];
    if ([codeBlockChars containsIndexesInRange:fullRange]) return;

    NSRange markerRange = [match rangeAtIndex:1];
    NSRange contentRange = [match rangeAtIndex:2];
    NSRange closeMarker = NSMakeRange(contentRange.location + contentRange.length,
                                       markerRange.length);

    MarkdownElementStyle *style = self->_styleConfig.strong;
    UIFont *boldFont = [style resolvedFontWithBase:baseFont];
    if (!boldFont) {
      UIFontDescriptor *desc =
          [baseFont.fontDescriptor fontDescriptorWithSymbolicTraits:
              UIFontDescriptorTraitBold];
      boldFont = desc ? [UIFont fontWithDescriptor:desc size:baseFont.pointSize]
                      : [UIFont boldSystemFontOfSize:baseFont.pointSize];
    }

    [as addAttribute:NSFontAttributeName value:boldFont range:contentRange];
    if (style.color) {
      [as addAttribute:NSForegroundColorAttributeName
                 value:style.color
                 range:contentRange];
    }

    // Dim markers
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:markerRange];
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:closeMarker];
  }];
}

- (void)styleItalic:(NSMutableAttributedString *)as
           baseFont:(UIFont *)baseFont
        markerColor:(UIColor *)markerColor
     codeBlockChars:(NSMutableIndexSet *)codeBlockChars {
  NSString *text = as.string;
  // Match *text* but not **text** (negative lookbehind/ahead for *)
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)"
                           options:0
                             error:nil];

  [regex enumerateMatchesInString:text
                          options:0
                            range:NSMakeRange(0, text.length)
                       usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags,
                                    BOOL *stop) {
    NSRange fullRange = [match range];
    if ([codeBlockChars containsIndexesInRange:fullRange]) return;

    NSRange contentRange = [match rangeAtIndex:1];

    MarkdownElementStyle *style = self->_styleConfig.emphasis;
    UIFont *italicFont = [style resolvedFontWithBase:baseFont];
    if (!italicFont) {
      UIFontDescriptor *desc =
          [baseFont.fontDescriptor fontDescriptorWithSymbolicTraits:
              UIFontDescriptorTraitItalic];
      italicFont = desc ? [UIFont fontWithDescriptor:desc size:baseFont.pointSize]
                        : baseFont;
    }

    [as addAttribute:NSFontAttributeName value:italicFont range:contentRange];
    if (style.color) {
      [as addAttribute:NSForegroundColorAttributeName
                 value:style.color
                 range:contentRange];
    }

    // Dim the single * markers
    [as addAttribute:NSForegroundColorAttributeName
               value:markerColor
               range:NSMakeRange(fullRange.location, 1)];
    [as addAttribute:NSForegroundColorAttributeName
               value:markerColor
               range:NSMakeRange(fullRange.location + fullRange.length - 1, 1)];
  }];
}

- (void)styleStrikethrough:(NSMutableAttributedString *)as
               markerColor:(UIColor *)markerColor
            codeBlockChars:(NSMutableIndexSet *)codeBlockChars {
  NSString *text = as.string;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"(~~)(.+?)\\1"
                           options:0
                             error:nil];

  [regex enumerateMatchesInString:text
                          options:0
                            range:NSMakeRange(0, text.length)
                       usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags,
                                    BOOL *stop) {
    NSRange fullRange = [match range];
    if ([codeBlockChars containsIndexesInRange:fullRange]) return;

    NSRange markerRange = [match rangeAtIndex:1];
    NSRange contentRange = [match rangeAtIndex:2];
    NSRange closeMarker = NSMakeRange(contentRange.location + contentRange.length,
                                       markerRange.length);

    MarkdownElementStyle *style = self->_styleConfig.strikethrough;

    [as addAttribute:NSStrikethroughStyleAttributeName
               value:@(NSUnderlineStyleSingle)
               range:contentRange];
    if (style.color) {
      [as addAttribute:NSForegroundColorAttributeName
                 value:style.color
                 range:contentRange];
      [as addAttribute:NSStrikethroughColorAttributeName
                 value:style.color
                 range:contentRange];
    }

    // Dim markers
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:markerRange];
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:closeMarker];
  }];
}

- (void)styleLinks:(NSMutableAttributedString *)as
       markerColor:(UIColor *)markerColor
    codeBlockChars:(NSMutableIndexSet *)codeBlockChars {
  NSString *text = as.string;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:@"(\\[)(.+?)(\\]\\()(.+?)(\\))"
                           options:0
                             error:nil];

  [regex enumerateMatchesInString:text
                          options:0
                            range:NSMakeRange(0, text.length)
                       usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags,
                                    BOOL *stop) {
    NSRange fullRange = [match range];
    if ([codeBlockChars containsIndexesInRange:fullRange]) return;

    NSRange openBracket = [match rangeAtIndex:1];
    NSRange linkText = [match rangeAtIndex:2];
    NSRange closeBracketOpenParen = [match rangeAtIndex:3];
    NSRange urlRange = [match rangeAtIndex:4];
    NSRange closeParen = [match rangeAtIndex:5];

    MarkdownElementStyle *style = self->_styleConfig.link;
    UIColor *linkColor = style.color ?: [UIColor systemBlueColor];

    // Style the link text
    [as addAttribute:NSForegroundColorAttributeName value:linkColor range:linkText];

    // Dim the syntax markers and URL
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:openBracket];
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:closeBracketOpenParen];
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:urlRange];
    [as addAttribute:NSForegroundColorAttributeName value:markerColor range:closeParen];
  }];
}

#pragma mark - State Detection

- (void)detectFormattingState {
  NSRange range = _textView.selectedRange;
  if (range.location == NSNotFound) return;

  NSString *text = _textView.text;
  if (text.length == 0) return;

  _isBold = [self isInsideMarker:@"**" inText:text atPosition:range.location];
  _isItalic =
      [self isInsideMarker:@"*" inText:text atPosition:range.location] &&
      !_isBold;
  _isStrikethrough =
      [self isInsideMarker:@"~~" inText:text atPosition:range.location];
  _isCode =
      [self isInsideMarker:@"`" inText:text atPosition:range.location];

  [self emitStateChange];
}

- (BOOL)isInsideMarker:(NSString *)marker
                inText:(NSString *)text
            atPosition:(NSUInteger)pos {
  NSRange before = [text rangeOfString:marker
                               options:NSBackwardsSearch
                                 range:NSMakeRange(0, pos)];
  if (before.location == NSNotFound) return NO;

  NSUInteger searchStart = before.location + marker.length;
  if (searchStart >= text.length) return NO;

  NSRange after = [text rangeOfString:marker
                              options:0
                                range:NSMakeRange(searchStart,
                                                   text.length - searchStart)];
  if (after.location == NSNotFound) return NO;

  return pos > before.location && pos <= after.location;
}

#pragma mark - Events

- (void)emitChangeEvents {
  if (!_eventEmitter) return;

  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);

  emitter.onChangeText({.text = std::string([_textView.text UTF8String])});
  emitter.onChangeMarkdown(
      {.markdown = std::string([_textView.text UTF8String])});
}

- (void)emitStateChange {
  if (!_eventEmitter) return;

  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);

  emitter.onChangeState({
      .bold = _isBold,
      .italic = _isItalic,
      .strikethrough = _isStrikethrough,
      .code = _isCode,
      .linkUrl = std::string(""),
      .heading = 0,
      .list = std::string(""),
  });
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
  [self applyMarkdownFormatting];
  [self emitChangeEvents];
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  [self detectFormattingState];

  if (!_eventEmitter) return;
  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);

  NSRange range = textView.selectedRange;
  emitter.onChangeSelection({
      .start = static_cast<double>(range.location),
      .end = static_cast<double>(range.location + range.length),
  });
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
  if (!_eventEmitter) return;
  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);
  emitter.onEditorFocus({.focused = true});
}

- (void)textViewDidEndEditing:(UITextView *)textView {
  if (!_eventEmitter) return;
  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);
  emitter.onEditorBlur({.focused = false});
}

@end

Class<RCTComponentViewProtocol> MarkdownEditorViewCls(void) {
  return MarkdownEditorView.class;
}
