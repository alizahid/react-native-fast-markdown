#import "MarkdownEditorView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

#import "FormattingRange.h"
#import "FormattingStore.h"
#import "InputFormatter.h"
#import "InputParser.h"
#import "MarkdownSerializer.h"
#import "StyleConfig.h"

using namespace facebook::react;

@interface MarkdownEditorView () <UITextViewDelegate>
@end

@implementation MarkdownEditorView {
  UITextView *_textView;
  StyleConfig *_styleConfig;
  NSString *_currentStyleJSON;
  UIFont *_baseFont;
  UIColor *_baseColor;

  FormattingStore *_store;
  InputFormatter *_formatter;

  // Guards against re-entrant formatting during programmatic edits
  BOOL _suppressFormatting;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<
      MarkdownEditorViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _store = [FormattingStore new];
    _formatter = [InputFormatter new];

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

// ---------------------------------------------------------------
#pragma mark - Props
// ---------------------------------------------------------------

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newProps =
      *std::static_pointer_cast<const MarkdownEditorViewProps>(props);

  // Style — must be parsed before default value
  NSString *styleJSON = newProps.styles.empty()
                            ? @""
                            : [NSString stringWithUTF8String:newProps.styles.c_str()];
  if (![styleJSON isEqualToString:_currentStyleJSON ?: @""]) {
    _currentStyleJSON = styleJSON;
    _styleConfig = [StyleConfig fromJSON:styleJSON];
    _baseFont = [_styleConfig.base resolvedFont]
                    ?: [UIFont systemFontOfSize:16];
    _baseColor = _styleConfig.base.color ?: [UIColor labelColor];

    _formatter.styleConfig = _styleConfig;
    _formatter.baseFont = _baseFont;
    _formatter.baseColor = _baseColor;

    // Re-apply formatting with new styles if we already have content
    if (_textView.text.length > 0) {
      [self applyFormatting];
    }
  }

  // Default value (first render only)
  if (!oldProps) {
    NSString *defaultValue =
        [NSString stringWithUTF8String:newProps.defaultValue.c_str()];
    if (defaultValue.length > 0) {
      [self importMarkdown:defaultValue];
    } else {
      [self resetTypingAttributes];
    }
  }

  _textView.editable = newProps.editable;

  if (!oldProps && newProps.autoFocus) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self->_textView becomeFirstResponder];
    });
  }

  [super updateProps:props oldProps:oldProps];
}

// ---------------------------------------------------------------
#pragma mark - Import / Export
// ---------------------------------------------------------------

- (void)importMarkdown:(NSString *)markdown {
  InputParserResult *result = [InputParser parseMarkdown:markdown];

  _suppressFormatting = YES;
  _textView.text = result.plainText;
  _store = result.store;
  _suppressFormatting = NO;

  _formatter.styleConfig = _styleConfig;
  _formatter.baseFont = _baseFont;
  _formatter.baseColor = _baseColor;

  [self applyFormatting];
  [self resetTypingAttributes];
}

- (NSString *)exportMarkdown {
  return [MarkdownSerializer serializePlainText:_textView.text
                                     withStore:_store];
}

// ---------------------------------------------------------------
#pragma mark - Formatting Application
// ---------------------------------------------------------------

- (void)applyFormatting {
  if (_suppressFormatting) return;
  [_formatter applyAllFormatting:_store toTextStorage:_textView.textStorage];
}

- (void)resetTypingAttributes {
  _textView.typingAttributes = @{
    NSFontAttributeName : _baseFont ?: [UIFont systemFontOfSize:16],
    NSForegroundColorAttributeName : _baseColor ?: [UIColor labelColor],
  };
}

// ---------------------------------------------------------------
#pragma mark - Toggle Inline Formatting
// ---------------------------------------------------------------

- (void)toggleInlineType:(FormattingType)type {
  NSRange range = _textView.selectedRange;

  if (range.length == 0) {
    // Cursor only — toggle in pending sets
    NSNumber *key = @(type);
    BOOL currentlyActive =
        [_store isEffectivelyActive:type
                            atIndex:range.location > 0 ? range.location - 1
                                                       : 0];
    if (currentlyActive) {
      [_store.pendingStyles removeObject:key];
      [_store.pendingRemovals addObject:key];
    } else {
      [_store.pendingRemovals removeObject:key];
      [_store.pendingStyles addObject:key];
    }
  } else {
    // Has selection — check if entire selection is covered
    NSArray *existing =
        [_store rangesOfType:type intersecting:range];
    BOOL fullyCovered = [self isRange:range
                      fullyCoveredBy:existing];

    if (fullyCovered) {
      [_store removeRangesOfType:type intersecting:range];
    } else {
      // Remove any existing ranges of this type first to avoid
      // partial overlaps, then add the full selection range.
      [_store removeRangesOfType:type intersecting:range];
      [_store addRange:[FormattingRange rangeWithType:type range:range]];
    }

    [self applyFormatting];
  }

  [self detectAndEmitState];
}

- (BOOL)isRange:(NSRange)range
    fullyCoveredBy:(NSArray<FormattingRange *> *)ranges {
  if (ranges.count == 0) return NO;

  // Build a union of all the ranges and check coverage
  NSMutableIndexSet *covered = [NSMutableIndexSet new];
  for (FormattingRange *r in ranges) {
    NSRange intersection = NSIntersectionRange(r.range, range);
    if (intersection.length > 0) {
      [covered addIndexesInRange:intersection];
    }
  }

  return covered.count >= range.length;
}

// ---------------------------------------------------------------
#pragma mark - Toggle Block Formatting
// ---------------------------------------------------------------

- (void)toggleHeading:(NSInteger)level {
  NSRange lineRange = [self currentLineRange];
  if (lineRange.length == 0) return;

  FormattingType hType = [FormattingRange headingTypeForLevel:level];

  // Check if this line already has this heading level
  NSArray *existing = [_store rangesOfType:hType intersecting:lineRange];

  if (existing.count > 0) {
    // Remove the heading
    [_store removeRangesOfType:hType intersecting:lineRange];
  } else {
    // Remove any other heading types on this line
    for (NSInteger l = 1; l <= 6; l++) {
      FormattingType t = [FormattingRange headingTypeForLevel:l];
      [_store removeRangesOfType:t intersecting:lineRange];
    }
    [_store addRange:[FormattingRange rangeWithType:hType range:lineRange]];
  }

  [self applyFormatting];
  [self detectAndEmitState];
}

- (void)toggleBlockquote {
  NSRange lineRange = [self currentLineRange];
  if (lineRange.length == 0) return;

  NSArray *existing = [_store rangesOfType:FormattingTypeBlockquote
                              intersecting:lineRange];

  if (existing.count > 0) {
    [_store removeRangesOfType:FormattingTypeBlockquote
                  intersecting:lineRange];
  } else {
    [_store addRange:[FormattingRange rangeWithType:FormattingTypeBlockquote
                                             range:lineRange]];
  }

  [self applyFormatting];
  [self detectAndEmitState];
}

- (void)toggleList:(FormattingType)listType {
  NSRange lineRange = [self currentLineRange];

  NSArray *existing = [_store rangesOfType:listType intersecting:lineRange];

  if (existing.count > 0) {
    // Remove the list formatting and bullet prefix
    [_store removeRangesOfType:listType intersecting:lineRange];

    NSString *line = [_textView.text substringWithRange:lineRange];
    NSUInteger bulletLen = [self bulletLengthInLine:line listType:listType];
    if (bulletLen > 0) {
      _suppressFormatting = YES;
      [_textView.textStorage deleteCharactersInRange:
          NSMakeRange(lineRange.location, bulletLen)];
      [_store adjustForEditAt:lineRange.location
                deletedLength:bulletLen
               insertedLength:0];
      _suppressFormatting = NO;
    }
  } else {
    // Remove any other list type on this line first
    FormattingType otherType = (listType == FormattingTypeOrderedList)
                                   ? FormattingTypeUnorderedList
                                   : FormattingTypeOrderedList;
    NSArray *otherExisting =
        [_store rangesOfType:otherType intersecting:lineRange];
    if (otherExisting.count > 0) {
      [_store removeRangesOfType:otherType intersecting:lineRange];
      NSString *line = [_textView.text substringWithRange:lineRange];
      NSUInteger bulletLen = [self bulletLengthInLine:line listType:otherType];
      if (bulletLen > 0) {
        _suppressFormatting = YES;
        [_textView.textStorage deleteCharactersInRange:
            NSMakeRange(lineRange.location, bulletLen)];
        [_store adjustForEditAt:lineRange.location
                  deletedLength:bulletLen
                 insertedLength:0];
        _suppressFormatting = NO;
        lineRange = [self currentLineRange];
      }
    }

    // Insert bullet prefix
    NSString *bullet =
        (listType == FormattingTypeOrderedList) ? @"1. " : @"\u2022 ";

    _suppressFormatting = YES;
    [_textView.textStorage replaceCharactersInRange:
        NSMakeRange(lineRange.location, 0) withString:bullet];
    [_store adjustForEditAt:lineRange.location
              deletedLength:0
             insertedLength:bullet.length];
    _suppressFormatting = NO;

    // Re-query line range after insertion
    lineRange = [self currentLineRange];
    [_store addRange:[FormattingRange rangeWithType:listType
                                             range:lineRange]];
  }

  [self applyFormatting];
  [self detectAndEmitState];
  [self emitMarkdownChange];
}

- (NSUInteger)bulletLengthInLine:(NSString *)line
                        listType:(FormattingType)type {
  if (type == FormattingTypeUnorderedList) {
    // Check longest prefix first
    if ([line hasPrefix:@"\u2022  "]) return 3;
    if ([line hasPrefix:@"\u2022 "]) return 2;
    if ([line hasPrefix:@"\u2022"]) return 1;
    if ([line hasPrefix:@"- "]) return 2;
    if ([line hasPrefix:@"* "]) return 2;
  } else if (type == FormattingTypeOrderedList) {
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"^\\d+\\.\\s"
                             options:0
                               error:nil];
    NSTextCheckingResult *match =
        [regex firstMatchInString:line
                          options:0
                            range:NSMakeRange(0, MIN(line.length, 10))];
    if (match) return match.range.length;
  }
  return 0;
}

- (NSRange)currentLineRange {
  NSRange range = _textView.selectedRange;
  NSRange lineRange = [_textView.text lineRangeForRange:range];
  // Trim trailing newline
  if (lineRange.length > 0 &&
      [_textView.text characterAtIndex:lineRange.location +
                                           lineRange.length - 1] == '\n') {
    lineRange.length--;
  }
  return lineRange;
}

// ---------------------------------------------------------------
#pragma mark - Auto-formatting (syntax detection as you type)
// ---------------------------------------------------------------

- (void)detectAutoFormatting {
  NSString *text = _textView.text;
  NSRange cursor = _textView.selectedRange;
  if (text.length == 0) return;

  // Get current line
  NSRange fullLineRange = [text lineRangeForRange:cursor];
  // Trim trailing newline for our line content
  NSRange lineRange = fullLineRange;
  if (lineRange.length > 0 &&
      [text characterAtIndex:NSMaxRange(lineRange) - 1] == '\n') {
    lineRange.length--;
  }
  NSString *line = [text substringWithRange:lineRange];
  NSUInteger lineStart = lineRange.location;
  NSUInteger localCursor = cursor.location - lineStart;

  // --- Blockquote: "> " at start of line ---
  if (localCursor >= 2 && [line hasPrefix:@"> "]) {
    // Don't trigger if the line already has blockquote formatting
    NSArray *existing = [_store rangesOfType:FormattingTypeBlockquote
                                intersecting:lineRange];
    if (existing.count == 0) {
      [self autoConvertBlockPrefix:@"> "
                         lineStart:lineStart
                          lineText:line
                              type:FormattingTypeBlockquote];
      return;
    }
  }

  // --- Unordered list: "- " or "* " at start of line ---
  if (localCursor >= 2 &&
      ([line hasPrefix:@"- "] || [line hasPrefix:@"* "])) {
    NSArray *existing = [_store rangesOfType:FormattingTypeUnorderedList
                                intersecting:lineRange];
    if (existing.count == 0) {
      NSString *prefix = [line substringToIndex:2];
      [self autoConvertBlockPrefix:prefix
                         lineStart:lineStart
                          lineText:line
                              type:FormattingTypeUnorderedList];
      return;
    }
  }

  // --- Ordered list: "1. " (or any number) at start of line ---
  {
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"^(\\d+\\.\\s)"
                             options:0
                               error:nil];
    NSTextCheckingResult *match =
        [regex firstMatchInString:line
                          options:0
                            range:NSMakeRange(0, MIN(line.length, 10))];
    if (match && localCursor >= match.range.length) {
      NSArray *existing = [_store rangesOfType:FormattingTypeOrderedList
                                  intersecting:lineRange];
      if (existing.count == 0) {
        NSString *prefix = [line substringWithRange:[match rangeAtIndex:1]];
        [self autoConvertBlockPrefix:prefix
                           lineStart:lineStart
                            lineText:line
                                type:FormattingTypeOrderedList];
        return;
      }
    }
  }

  // --- Inline code: matching backticks ---
  [self detectInlineCode];

  // --- Autolink: detect URLs ---
  [self detectAutolinks];
}

- (void)autoConvertBlockPrefix:(NSString *)prefix
                     lineStart:(NSUInteger)lineStart
                      lineText:(NSString *)line
                          type:(FormattingType)type {
  // Delete the prefix from text
  _suppressFormatting = YES;
  [_textView.textStorage deleteCharactersInRange:
      NSMakeRange(lineStart, prefix.length)];
  [_store adjustForEditAt:lineStart
            deletedLength:prefix.length
           insertedLength:0];
  _suppressFormatting = NO;

  // For lists, insert a visual bullet
  if (type == FormattingTypeUnorderedList ||
      type == FormattingTypeOrderedList) {
    NSString *bullet =
        (type == FormattingTypeOrderedList) ? @"1. " : @"\u2022 ";
    _suppressFormatting = YES;
    [_textView.textStorage replaceCharactersInRange:
        NSMakeRange(lineStart, 0) withString:bullet];
    [_store adjustForEditAt:lineStart
              deletedLength:0
             insertedLength:bullet.length];
    _suppressFormatting = NO;
  }

  // Apply formatting to the current line
  NSRange newLineRange = [self lineRangeAt:lineStart];
  if (newLineRange.length > 0) {
    [_store addRange:[FormattingRange rangeWithType:type
                                             range:newLineRange]];
  }

  [self applyFormatting];
  [self emitMarkdownChange];
}

/// Returns the line range at a given position, trimming the
/// trailing newline.
- (NSRange)lineRangeAt:(NSUInteger)position {
  if (position >= _textView.text.length && _textView.text.length > 0) {
    position = _textView.text.length - 1;
  }
  NSRange lineRange = [_textView.text lineRangeForRange:
      NSMakeRange(position, 0)];
  if (lineRange.length > 0 &&
      [_textView.text characterAtIndex:NSMaxRange(lineRange) - 1] == '\n') {
    lineRange.length--;
  }
  return lineRange;
}

#pragma mark - Inline Code Detection

- (void)detectInlineCode {
  NSString *text = _textView.text;
  NSRange cursor = _textView.selectedRange;
  if (cursor.location == 0) return;

  unichar lastChar = [text characterAtIndex:cursor.location - 1];
  if (lastChar != '`') return;

  // Look backwards for a matching opening backtick on the same line
  if (cursor.location < 2) return;
  NSUInteger searchPos = cursor.location - 2;

  while (searchPos != NSNotFound) {
    unichar ch = [text characterAtIndex:searchPos];
    if (ch == '\n') break;

    if (ch == '`') {
      NSUInteger contentStart = searchPos + 1;
      NSUInteger contentEnd = cursor.location - 1;
      if (contentEnd > contentStart) {
        NSString *content = [text substringWithRange:
            NSMakeRange(contentStart, contentEnd - contentStart)];

        // Remove both backticks, create code range
        _suppressFormatting = YES;
        [_textView.textStorage deleteCharactersInRange:
            NSMakeRange(contentEnd, 1)];
        [_store adjustForEditAt:contentEnd
                  deletedLength:1
                 insertedLength:0];
        [_textView.textStorage deleteCharactersInRange:
            NSMakeRange(searchPos, 1)];
        [_store adjustForEditAt:searchPos
                  deletedLength:1
                 insertedLength:0];
        _suppressFormatting = NO;

        NSRange codeRange = NSMakeRange(searchPos, content.length);
        [_store addRange:[FormattingRange rangeWithType:FormattingTypeCode
                                                  range:codeRange]];
        _textView.selectedRange =
            NSMakeRange(searchPos + content.length, 0);

        [self applyFormatting];
        [self emitMarkdownChange];
        return;
      }
      break;
    }

    if (searchPos == 0) break;
    searchPos--;
  }
}

#pragma mark - List Continuation on Enter

/// Called from shouldChangeTextInRange: when the replacement is a
/// newline. Returns YES if the newline was handled (caller should
/// return NO to prevent the default insertion).
- (BOOL)handleNewlineInList:(NSRange)range {
  NSString *text = _textView.text;
  if (text.length == 0) return NO;

  // Find the line the cursor is on
  NSRange lineRange = [text lineRangeForRange:range];
  if (lineRange.length > 0 &&
      [text characterAtIndex:NSMaxRange(lineRange) - 1] == '\n') {
    lineRange.length--;
  }
  NSString *line = [text substringWithRange:lineRange];

  // Check if this line is in a list
  FormattingType listType = FormattingTypeUnorderedList;
  BOOL inList = NO;
  NSArray *ulRanges = [_store rangesOfType:FormattingTypeUnorderedList
                              intersecting:lineRange];
  NSArray *olRanges = [_store rangesOfType:FormattingTypeOrderedList
                              intersecting:lineRange];
  if (ulRanges.count > 0) {
    inList = YES;
    listType = FormattingTypeUnorderedList;
  } else if (olRanges.count > 0) {
    inList = YES;
    listType = FormattingTypeOrderedList;
  }

  if (!inList) return NO;

  // Determine the bullet prefix length
  NSUInteger bulletLen = [self bulletLengthInLine:line listType:listType];

  // If the line is ONLY a bullet (empty list item), break out of
  // the list: delete the bullet and don't insert a new one.
  NSString *contentAfterBullet =
      bulletLen < line.length ? [line substringFromIndex:bulletLen] : @"";
  contentAfterBullet = [contentAfterBullet
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceCharacterSet]];

  if (contentAfterBullet.length == 0) {
    // Empty list item — break out of list
    _suppressFormatting = YES;
    [_textView.textStorage deleteCharactersInRange:lineRange];
    [_store adjustForEditAt:lineRange.location
              deletedLength:lineRange.length
             insertedLength:0];
    // Remove the list range for this line
    [_store removeRangesOfType:listType intersecting:lineRange];
    _suppressFormatting = NO;

    [self applyFormatting];
    [self emitMarkdownChange];
    return YES;
  }

  // Non-empty list item — continue the list on the next line
  NSString *bullet;
  if (listType == FormattingTypeOrderedList) {
    // Increment number
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"^(\\d+)"
                             options:0
                               error:nil];
    NSTextCheckingResult *match =
        [regex firstMatchInString:line
                          options:0
                            range:NSMakeRange(0, MIN(line.length, 10))];
    NSInteger num = 1;
    if (match) {
      num = [[line substringWithRange:[match rangeAtIndex:1]] integerValue] + 1;
    }
    bullet = [NSString stringWithFormat:@"%ld. ", (long)num];
  } else {
    bullet = @"\u2022 ";
  }

  NSString *insertion = [NSString stringWithFormat:@"\n%@", bullet];
  NSUInteger insertAt = range.location;

  _suppressFormatting = YES;
  [_textView.textStorage replaceCharactersInRange:range
                                       withString:insertion];
  [_store adjustForEditAt:insertAt
            deletedLength:range.length
           insertedLength:insertion.length];
  _suppressFormatting = NO;

  // Create a list range for the new line
  _textView.selectedRange =
      NSMakeRange(insertAt + insertion.length, 0);
  NSRange newLineRange = [self lineRangeAt:insertAt + 1];
  if (newLineRange.length > 0) {
    [_store addRange:[FormattingRange rangeWithType:listType
                                             range:newLineRange]];
  }

  [self applyFormatting];
  [self resetTypingAttributes];
  [self emitMarkdownChange];
  return YES;
}

#pragma mark - Autolink Detection

- (void)detectAutolinks {
  NSString *text = _textView.text;
  if (text.length == 0) return;

  NSDataDetector *detector =
      [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink
                                      error:nil];
  if (!detector) return;

  NSArray<NSTextCheckingResult *> *matches =
      [detector matchesInString:text
                        options:0
                          range:NSMakeRange(0, text.length)];

  BOOL added = NO;
  for (NSTextCheckingResult *match in matches) {
    NSRange urlRange = match.range;
    NSURL *url = match.URL;
    if (!url) continue;

    NSArray *existing =
        [_store rangesOfType:FormattingTypeLink intersecting:urlRange];
    if (existing.count > 0) continue;

    [_store addRange:[FormattingRange rangeWithType:FormattingTypeLink
                                              range:urlRange
                                                url:url.absoluteString]];
    added = YES;
  }

  if (added) [self applyFormatting];
}

// ---------------------------------------------------------------
#pragma mark - Links
// ---------------------------------------------------------------

- (void)insertLinkWithURL:(NSString *)url text:(NSString *)text {
  NSRange range = _textView.selectedRange;

  NSString *linkText;
  if (text.length > 0) {
    linkText = text;
  } else if (range.length > 0) {
    linkText = [_textView.text substringWithRange:range];
  } else {
    linkText = @"link";
  }

  _suppressFormatting = YES;
  if (range.length > 0) {
    [_textView.textStorage replaceCharactersInRange:range
                                         withString:linkText];
    [_store adjustForEditAt:range.location
              deletedLength:range.length
             insertedLength:linkText.length];
  } else {
    [_textView.textStorage replaceCharactersInRange:range
                                         withString:linkText];
    [_store adjustForEditAt:range.location
              deletedLength:0
             insertedLength:linkText.length];
  }
  _suppressFormatting = NO;

  NSRange linkRange = NSMakeRange(range.location, linkText.length);
  [_store addRange:[FormattingRange rangeWithType:FormattingTypeLink
                                            range:linkRange
                                              url:url]];

  [self applyFormatting];
  [self emitMarkdownChange];
}

- (void)removeLink {
  NSRange range = _textView.selectedRange;
  NSUInteger idx = range.location > 0 ? range.location - 1 : 0;

  // Find link range at cursor
  for (FormattingRange *r in _store.allRanges) {
    if (r.type == FormattingTypeLink &&
        idx >= r.range.location &&
        idx < NSMaxRange(r.range)) {
      [_store removeRangesOfType:FormattingTypeLink intersecting:r.range];
      [self applyFormatting];
      [self emitMarkdownChange];
      return;
    }
  }
}

// ---------------------------------------------------------------
#pragma mark - Native Commands
// ---------------------------------------------------------------

- (void)handleCommand:(const NSString *)commandName
                 args:(const NSArray *)args {
  if ([commandName isEqualToString:@"focus"]) {
    [_textView becomeFirstResponder];
  } else if ([commandName isEqualToString:@"blur"]) {
    [_textView resignFirstResponder];
  } else if ([commandName isEqualToString:@"setValue"]) {
    [self importMarkdown:args[0]];
  } else if ([commandName isEqualToString:@"setSelection"]) {
    NSInteger start = [args[0] integerValue];
    NSInteger end = [args[1] integerValue];
    _textView.selectedRange = NSMakeRange(start, end - start);
  } else if ([commandName isEqualToString:@"toggleBold"]) {
    [self toggleInlineType:FormattingTypeBold];
  } else if ([commandName isEqualToString:@"toggleItalic"]) {
    [self toggleInlineType:FormattingTypeItalic];
  } else if ([commandName isEqualToString:@"toggleStrikethrough"]) {
    [self toggleInlineType:FormattingTypeStrikethrough];
  } else if ([commandName isEqualToString:@"toggleCode"]) {
    [self toggleInlineType:FormattingTypeCode];
  } else if ([commandName isEqualToString:@"toggleHeading"]) {
    [self toggleHeading:[args[0] integerValue]];
  } else if ([commandName isEqualToString:@"toggleOrderedList"]) {
    [self toggleList:FormattingTypeOrderedList];
  } else if ([commandName isEqualToString:@"toggleUnorderedList"]) {
    [self toggleList:FormattingTypeUnorderedList];
  } else if ([commandName isEqualToString:@"toggleBlockquote"]) {
    [self toggleBlockquote];
  } else if ([commandName isEqualToString:@"insertLink"]) {
    NSString *url = args[0];
    NSString *text = args.count > 1 ? args[1] : @"";
    [self insertLinkWithURL:url text:text];
  } else if ([commandName isEqualToString:@"removeLink"]) {
    [self removeLink];
  } else if ([commandName isEqualToString:@"insertMention"]) {
    // TODO
  } else if ([commandName isEqualToString:@"insertSpoiler"]) {
    // TODO
  } else if ([commandName isEqualToString:@"insertCustomTag"]) {
    // TODO
  }
}

// ---------------------------------------------------------------
#pragma mark - State Detection
// ---------------------------------------------------------------

- (void)detectAndEmitState {
  if (!_eventEmitter) return;

  NSRange range = _textView.selectedRange;
  // Use the character before cursor for state detection
  NSUInteger idx = range.location > 0 ? range.location - 1 : 0;

  BOOL bold = [_store isEffectivelyActive:FormattingTypeBold atIndex:idx];
  BOOL italic = [_store isEffectivelyActive:FormattingTypeItalic atIndex:idx];
  BOOL strike =
      [_store isEffectivelyActive:FormattingTypeStrikethrough atIndex:idx];
  BOOL code = [_store isEffectivelyActive:FormattingTypeCode atIndex:idx];

  NSString *linkUrl = [_store effectiveLinkAtIndex:idx] ?: @"";

  // Heading — check all levels
  NSInteger heading = 0;
  for (NSInteger l = 1; l <= 6; l++) {
    FormattingType hType = [FormattingRange headingTypeForLevel:l];
    if ([_store hasType:hType atIndex:idx]) {
      heading = l;
      break;
    }
  }

  NSString *listType = @"";
  if ([_store hasType:FormattingTypeOrderedList atIndex:idx]) {
    listType = @"ordered";
  } else if ([_store hasType:FormattingTypeUnorderedList atIndex:idx]) {
    listType = @"unordered";
  }

  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);

  emitter.onChangeState({
      .bold = bold,
      .italic = italic,
      .strikethrough = strike,
      .code = code,
      .linkUrl = std::string([linkUrl UTF8String]),
      .heading = static_cast<int>(heading),
      .list = std::string([listType UTF8String]),
  });
}

// ---------------------------------------------------------------
#pragma mark - Events
// ---------------------------------------------------------------

- (void)emitMarkdownChange {
  if (!_eventEmitter) return;

  NSString *markdown = [self exportMarkdown];
  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);

  emitter.onChangeText(
      {.text = std::string([_textView.text UTF8String])});
  emitter.onChangeMarkdown(
      {.markdown = std::string([markdown UTF8String])});
}

// ---------------------------------------------------------------
#pragma mark - UITextViewDelegate
// ---------------------------------------------------------------

- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text {
  if (_suppressFormatting) return YES;

  // Handle enter key inside lists (continue or break out)
  if ([text isEqualToString:@"\n"]) {
    if ([self handleNewlineInList:range]) {
      return NO; // we handled it
    }
  }

  NSUInteger deleted = range.length;
  NSUInteger inserted = text.length;

  // Adjust all existing ranges for this edit
  [_store adjustForEditAt:range.location
            deletedLength:deleted
           insertedLength:inserted];

  // Apply pending styles to the inserted text
  if (inserted > 0) {
    NSRange insertedRange = NSMakeRange(range.location, inserted);

    for (NSNumber *typeNum in _store.pendingStyles) {
      FormattingType type = (FormattingType)typeNum.integerValue;
      [_store addRange:[FormattingRange rangeWithType:type
                                                range:insertedRange]];
    }

    // Handle pending removals: carve out the inserted range from
    // any existing formatting of the removed type
    for (NSNumber *typeNum in _store.pendingRemovals) {
      FormattingType type = (FormattingType)typeNum.integerValue;
      [_store removeRangesOfType:type intersecting:insertedRange];
    }

    // Also expand any ranges that the cursor was inside (not at
    // the boundary) — this is the "typing inside a range expands
    // it" behavior. The adjustForEditAt already handles this for
    // ranges where the edit point is strictly inside (case 3).
  }

  [_store clearPending];

  return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
  if (_suppressFormatting) return;

  [self detectAutoFormatting];
  [self applyFormatting];
  [self resetTypingAttributes];
  [self emitMarkdownChange];
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  if (_suppressFormatting) return;

  // Clear pending styles on cursor move (they're ephemeral)
  [_store clearPending];

  [self detectAndEmitState];

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
