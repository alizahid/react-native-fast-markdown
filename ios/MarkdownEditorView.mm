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
    // TODO
  } else if ([commandName isEqualToString:@"toggleUnorderedList"]) {
    // TODO
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
