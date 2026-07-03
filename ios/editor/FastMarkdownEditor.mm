#import "FastMarkdownEditor.h"

#import <React/RCTComponentViewFactory.h>
#import <react/renderer/components/FastMarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/FastMarkdownViewSpec/Props.h>
#import <react/renderer/components/FastMarkdownViewSpec/RCTComponentViewHelpers.h>
#import <react/renderer/core/ConcreteComponentDescriptor.h>

#import <vector>

#import "../../cpp/core/EditorRuns.h"
#import "../../cpp/react/FastMarkdownEditorShadowNode.h"
#import "../style/FMDStyleConfig.h"
#import "../style/FMDTextStyle.h"

using namespace facebook::react;

// Imported directly (like the viewer) so the descriptor binds to the custom
// measurable shadow node regardless of include order.
using FMDEditorComponentDescriptor =
    ConcreteComponentDescriptor<FastMarkdownEditorShadowNode>;

// Source of truth for inline marks: a bitmask of fastmarkdown::EditorMark
// stored as a custom attribute. Display attributes (fonts, strikethrough,
// backgrounds) are always derived from it.
static NSAttributedStringKey const FMDEditorMarksAttribute = @"FMDEditorMarks";

static NSString *FMDStringFromCpp(const std::string &value) {
  return [[NSString alloc] initWithBytes:value.data()
                                  length:value.size()
                                encoding:NSUTF8StringEncoding]
      ?: @"";
}

static uint32_t FMDFlagsFromValue(id value) {
  return value == nil ? 0 : [(NSNumber *)value unsignedIntValue];
}

@interface FastMarkdownEditor () <UITextViewDelegate, RCTFastMarkdownEditorViewProtocol>
@end

@implementation FastMarkdownEditor {
  UITextView *_textView;
  UILabel *_placeholderLabel;
  NSString *_stylesJson;
  BOOL _defaultValueApplied;
  BOOL _autoFocusHandled;
  BOOL _multiline;
  CGFloat _lastPublishedHeight;
  UIFont *_baseFont;
  UIColor *_baseColor;
  // Marks armed for text typed at the collapsed cursor. Explicit while the
  // user has toggled at this caret position; re-derived from the character
  // before the caret whenever the selection moves.
  uint32_t _typingFlags;
  NSRange _lastSelection;
  uint32_t _lastStateFlags;
  BOOL _stateEmitted;
  FastMarkdownEditorShadowNode::ConcreteState::Shared _state;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<FMDEditorComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const FastMarkdownEditorProps>();
    _props = defaultProps;
    _stylesJson = @"";
    _multiline = YES;
    _lastPublishedHeight = 0;
    _baseFont = [UIFont systemFontOfSize:16];
    _baseColor = UIColor.blackColor;
    _lastSelection = NSMakeRange(0, 0);

    _textView = [[UITextView alloc] initWithFrame:CGRectZero];
    _textView.backgroundColor = UIColor.clearColor;
    _textView.delegate = self;
    _textView.scrollEnabled = NO;
    _textView.textContainer.lineFragmentPadding = 0;
    _textView.textContainerInset = UIEdgeInsetsZero;
    [self addSubview:_textView];

    _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _placeholderLabel.numberOfLines = 1;
    _placeholderLabel.userInteractionEnabled = NO;
    [self addSubview:_placeholderLabel];

    [self applyTextStyles];
  }
  return self;
}

#pragma mark - Styles

// Root text attributes come from the same cascade the viewer uses:
// base (style prop text keys) then paragraph, floored at 16pt black.
- (void)applyTextStyles {
  FMDStyleConfig *styles = [FMDStyleConfig configWithJson:_stylesJson];

  CGFloat fontSize = 16;
  NSString *fontFamily = nil;
  UIColor *color = UIColor.blackColor;
  for (NSString *key in @[ @"base", @"paragraph" ]) {
    FMDTextStyle *style = [styles textStyleFor:key];
    if (style.fontSize != nil) {
      fontSize = style.fontSize.doubleValue;
    }
    if (style.fontFamily != nil) {
      fontFamily = style.fontFamily;
    }
    if (style.color != nil) {
      color = style.color;
    }
  }

  UIFont *font = nil;
  if (fontFamily != nil) {
    font = [UIFont fontWithName:fontFamily size:fontSize];
  }
  if (font == nil) {
    font = [UIFont systemFontOfSize:fontSize];
  }

  _baseFont = font;
  _baseColor = color;
  _textView.font = font;
  _textView.textColor = color;
  _textView.textContainerInset = UIEdgeInsetsMake(
      styles.paddingTop, styles.paddingLeft, styles.paddingBottom, styles.paddingRight);
  self.backgroundColor = styles.backgroundColor ?: UIColor.clearColor;

  [self refreshDisplayAttributesInRange:NSMakeRange(0, _textView.textStorage.length)];
  [self applyTypingAttributes];

  _placeholderLabel.font = font;
  [self setNeedsLayout];
  [self publishHeight];
}

#pragma mark - Mark attributes

- (NSDictionary<NSAttributedStringKey, id> *)attributesForFlags:(uint32_t)flags {
  const CGFloat baseSize = _baseFont.pointSize;
  const BOOL isCode = (flags & fastmarkdown::MarkInlineCode) != 0;
  const BOOL isSuper = (flags & fastmarkdown::MarkSuperscript) != 0;
  const BOOL isSub = (flags & fastmarkdown::MarkSubscript) != 0;

  // Sup/sub match the viewer's 0.7 scaling.
  const CGFloat size = (isSuper || isSub) ? baseSize * 0.7 : baseSize;
  UIFont *font = isCode
      ? [UIFont monospacedSystemFontOfSize:size weight:UIFontWeightRegular]
      : (size == baseSize ? _baseFont : [_baseFont fontWithSize:size]);

  UIFontDescriptorSymbolicTraits traits = font.fontDescriptor.symbolicTraits;
  if ((flags & fastmarkdown::MarkBold) != 0) {
    traits |= UIFontDescriptorTraitBold;
  }
  if ((flags & fastmarkdown::MarkItalic) != 0) {
    traits |= UIFontDescriptorTraitItalic;
  }
  UIFontDescriptor *descriptor =
      [font.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
  if (descriptor != nil) {
    font = [UIFont fontWithDescriptor:descriptor size:size];
  }

  NSMutableDictionary<NSAttributedStringKey, id> *attributes =
      [NSMutableDictionary dictionary];
  attributes[NSFontAttributeName] = font;
  attributes[NSForegroundColorAttributeName] = _baseColor;
  if ((flags & fastmarkdown::MarkStrikethrough) != 0) {
    attributes[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
  }
  if (isCode) {
    attributes[NSBackgroundColorAttributeName] =
        [UIColor colorWithWhite:0.5 alpha:0.15];
  }
  if ((flags & fastmarkdown::MarkSpoiler) != 0) {
    attributes[NSBackgroundColorAttributeName] =
        [UIColor colorWithWhite:0.35 alpha:0.25];
  }
  if (isSuper) {
    attributes[NSBaselineOffsetAttributeName] = @(baseSize * 0.33);
  } else if (isSub) {
    attributes[NSBaselineOffsetAttributeName] = @(-baseSize * 0.15);
  }
  if (flags != 0) {
    attributes[FMDEditorMarksAttribute] = @(flags);
  }
  return attributes;
}

- (void)refreshDisplayAttributesInRange:(NSRange)range {
  if (range.length == 0) {
    return;
  }
  NSTextStorage *storage = _textView.textStorage;
  [storage beginEditing];
  [storage enumerateAttribute:FMDEditorMarksAttribute
                      inRange:range
                      options:0
                   usingBlock:^(id value, NSRange runRange, BOOL *stop) {
                     [storage setAttributes:[self attributesForFlags:FMDFlagsFromValue(value)]
                                      range:runRange];
                   }];
  [storage endEditing];
}

- (void)applyTypingAttributes {
  _textView.typingAttributes = [self attributesForFlags:_typingFlags];
}

// Marks present across the ENTIRE range (the AND), which drives both toggle
// direction and the reported selection state.
- (uint32_t)commonFlagsInRange:(NSRange)range {
  __block uint32_t common = ~0u;
  [_textView.textStorage enumerateAttribute:FMDEditorMarksAttribute
                                    inRange:range
                                    options:0
                                 usingBlock:^(id value, NSRange runRange, BOOL *stop) {
                                   common &= FMDFlagsFromValue(value);
                                 }];
  return common == ~0u ? 0 : common;
}

- (uint32_t)flagsBeforeCaret:(NSUInteger)location {
  NSTextStorage *storage = _textView.textStorage;
  if (storage.length == 0) {
    return 0;
  }
  const NSUInteger probe = location > 0 ? location - 1 : 0;
  if (probe >= storage.length) {
    return 0;
  }
  return FMDFlagsFromValue([storage attribute:FMDEditorMarksAttribute
                                      atIndex:probe
                               effectiveRange:nil]);
}

- (void)toggleMark:(uint32_t)mark {
  const NSRange selection = _textView.selectedRange;
  if (selection.length == 0) {
    _typingFlags ^= mark;
    [self applyTypingAttributes];
    [self emitState];
    return;
  }

  const BOOL allHave = ([self commonFlagsInRange:selection] & mark) != 0;
  NSTextStorage *storage = _textView.textStorage;
  [storage beginEditing];
  [storage enumerateAttribute:FMDEditorMarksAttribute
                      inRange:selection
                      options:0
                   usingBlock:^(id value, NSRange runRange, BOOL *stop) {
                     const uint32_t flags = FMDFlagsFromValue(value);
                     const uint32_t next = allHave ? (flags & ~mark) : (flags | mark);
                     [storage setAttributes:[self attributesForFlags:next]
                                      range:runRange];
                   }];
  [storage endEditing];
  _textView.selectedRange = selection;
  [self textContentChanged];
  [self emitState];
}

#pragma mark - Fabric plumbing

- (void)updateState:(const State::Shared &)state oldState:(const State::Shared &)oldState {
  _state = std::static_pointer_cast<const FastMarkdownEditorShadowNode::ConcreteState>(state);
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &newProps = *std::static_pointer_cast<FastMarkdownEditorProps const>(props);
  const auto &prevProps = *std::static_pointer_cast<FastMarkdownEditorProps const>(_props);

  NSString *stylesJson = FMDStringFromCpp(newProps.stylesJson);
  if (![stylesJson isEqualToString:_stylesJson]) {
    _stylesJson = stylesJson;
    [self applyTextStyles];
  }

  if (!_defaultValueApplied) {
    _defaultValueApplied = YES;
    if (!newProps.defaultValue.empty()) {
      [self applyMarkdownValue:newProps.defaultValue];
    }
  }

  _textView.editable = newProps.editable;
  _textView.scrollEnabled = newProps.scrollEnabled;
  _multiline = newProps.multiline;

  _textView.autocorrectionType =
      newProps.autoCorrect ? UITextAutocorrectionTypeDefault : UITextAutocorrectionTypeNo;

  switch (newProps.autoCapitalize) {
    case FastMarkdownEditorAutoCapitalize::None:
      _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
      break;
    case FastMarkdownEditorAutoCapitalize::Words:
      _textView.autocapitalizationType = UITextAutocapitalizationTypeWords;
      break;
    case FastMarkdownEditorAutoCapitalize::Characters:
      _textView.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
      break;
    case FastMarkdownEditorAutoCapitalize::Sentences:
      _textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
      break;
  }

  if (newProps.cursorColor != 0) {
    _textView.tintColor = [FMDTextStyle colorFromJson:@(newProps.cursorColor)];
  }

  NSString *placeholder = FMDStringFromCpp(newProps.placeholder);
  if (![placeholder isEqualToString:_placeholderLabel.text]) {
    _placeholderLabel.text = placeholder;
    [self setNeedsLayout];
  }
  if (newProps.placeholderTextColor != 0) {
    _placeholderLabel.textColor =
        [FMDTextStyle colorFromJson:@(newProps.placeholderTextColor)];
  } else {
    _placeholderLabel.textColor = [UIColor colorWithWhite:0 alpha:0.3];
  }

  if (newProps.autoFocus && !prevProps.autoFocus) {
    _autoFocusHandled = NO;
  }

  [super updateProps:props oldProps:oldProps];
  [self refreshPlaceholderVisibility];
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  const auto &props = *std::static_pointer_cast<FastMarkdownEditorProps const>(_props);
  if (self.window != nil && props.autoFocus && !_autoFocusHandled) {
    _autoFocusHandled = YES;
    [_textView becomeFirstResponder];
  }
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  _textView.text = @"";
  _stylesJson = @"";
  _defaultValueApplied = NO;
  _autoFocusHandled = NO;
  _lastPublishedHeight = 0;
  _typingFlags = 0;
  _lastSelection = NSMakeRange(0, 0);
  _stateEmitted = NO;
  _state = nullptr;
  [self applyTextStyles];
  [self refreshPlaceholderVisibility];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _textView.frame = self.bounds;

  const UIEdgeInsets inset = _textView.textContainerInset;
  const CGSize placeholderSize = [_placeholderLabel sizeThatFits:CGSizeMake(
      self.bounds.size.width - inset.left - inset.right, CGFLOAT_MAX)];
  _placeholderLabel.frame = CGRectMake(
      inset.left, inset.top, placeholderSize.width, placeholderSize.height);

  [self publishHeight];
}

#pragma mark - Autogrow

- (void)publishHeight {
  const CGFloat width = self.bounds.size.width;
  if (width <= 0 || _state == nullptr) {
    return;
  }
  const CGSize size = [_textView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
  if (fabs(size.height - _lastPublishedHeight) < 0.5) {
    return;
  }
  _lastPublishedHeight = size.height;
  _state->updateState(FastMarkdownEditorState(size.height));
}

#pragma mark - Events

- (const FastMarkdownEditorEventEmitter *)editorEventEmitter {
  if (!_eventEmitter) {
    return nullptr;
  }
  return static_cast<const FastMarkdownEditorEventEmitter *>(_eventEmitter.get());
}

- (std::string)serializedMarkdown {
  NSTextStorage *storage = _textView.textStorage;
  const std::string text(_textView.text.UTF8String ?: "");
  __block std::vector<fastmarkdown::StyledRun> runs;
  [storage enumerateAttribute:FMDEditorMarksAttribute
                      inRange:NSMakeRange(0, storage.length)
                      options:0
                   usingBlock:^(id value, NSRange runRange, BOOL *stop) {
                     const uint32_t flags = FMDFlagsFromValue(value);
                     if (flags != 0) {
                       runs.push_back(
                           {static_cast<uint32_t>(runRange.location),
                            static_cast<uint32_t>(NSMaxRange(runRange)),
                            flags});
                     }
                   }];
  return fastmarkdown::markdownFromStyledText(text, runs);
}

- (void)textContentChanged {
  [self refreshPlaceholderVisibility];
  [self publishHeight];
  if (const auto *emitter = [self editorEventEmitter]) {
    const std::string text(_textView.text.UTF8String ?: "");
    emitter->onEditorChangeText({.text = text});
    emitter->onEditorChangeMarkdown({.markdown = [self serializedMarkdown]});
  }
}

- (void)emitState {
  const NSRange selection = _textView.selectedRange;
  const uint32_t flags = selection.length == 0
      ? _typingFlags
      : [self commonFlagsInRange:selection];
  if (_stateEmitted && flags == _lastStateFlags) {
    return;
  }
  _lastStateFlags = flags;
  _stateEmitted = YES;
  if (const auto *emitter = [self editorEventEmitter]) {
    emitter->onEditorChangeState({
        .headingLevel = 0,
        .isBlockQuote = false,
        .isBold = (flags & fastmarkdown::MarkBold) != 0,
        .isCodeBlock = false,
        .isInlineCode = (flags & fastmarkdown::MarkInlineCode) != 0,
        .isItalic = (flags & fastmarkdown::MarkItalic) != 0,
        .isOrderedList = false,
        .isSpoiler = (flags & fastmarkdown::MarkSpoiler) != 0,
        .isStrikethrough = (flags & fastmarkdown::MarkStrikethrough) != 0,
        .isSubscript = (flags & fastmarkdown::MarkSubscript) != 0,
        .isSuperscript = (flags & fastmarkdown::MarkSuperscript) != 0,
        .isUnorderedList = false,
    });
  }
}

- (void)refreshPlaceholderVisibility {
  _placeholderLabel.hidden = _textView.text.length > 0;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text {
  if (!_multiline && [text containsString:@"\n"]) {
    [textView resignFirstResponder];
    return NO;
  }
  return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
  [self textContentChanged];
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  const NSRange selection = textView.selectedRange;
  const BOOL moved = !NSEqualRanges(selection, _lastSelection);
  _lastSelection = selection;
  if (moved && selection.length == 0) {
    // Sticky typing state: inherit the marks of the character before the
    // caret (which is the just-typed character while typing).
    _typingFlags = [self flagsBeforeCaret:selection.location];
    [self applyTypingAttributes];
  }
  [self emitState];
  if (const auto *emitter = [self editorEventEmitter]) {
    emitter->onEditorChangeSelection({
        .start = static_cast<int>(selection.location),
        .end = static_cast<int>(selection.location + selection.length),
    });
  }
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
  if (const auto *emitter = [self editorEventEmitter]) {
    emitter->onEditorFocus({});
  }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
  if (const auto *emitter = [self editorEventEmitter]) {
    emitter->onEditorBlur({});
  }
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  RCTFastMarkdownEditorHandleCommand(self, commandName, args);
}

- (void)focus {
  [_textView becomeFirstResponder];
}

- (void)blur {
  [_textView resignFirstResponder];
}

- (void)applyMarkdownValue:(const std::string &)markdown {
  const auto styled = fastmarkdown::styledTextFromMarkdown(markdown);
  NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc]
      initWithString:FMDStringFromCpp(styled.text)
          attributes:[self attributesForFlags:0]];
  for (const auto &run : styled.runs) {
    const NSRange range = NSMakeRange(run.start, run.end - run.start);
    if (NSMaxRange(range) <= attributed.length) {
      [attributed setAttributes:[self attributesForFlags:run.flags] range:range];
    }
  }
  _textView.attributedText = attributed;
  [self applyTypingAttributes];
  [self textContentChanged];
}

- (void)setValue:(NSString *)value {
  [self applyMarkdownValue:std::string(value.UTF8String ?: "")];
}

- (void)setSelection:(NSInteger)start end:(NSInteger)end {
  const NSInteger length = (NSInteger)_textView.text.length;
  const NSInteger clampedStart = MAX(0, MIN(start, length));
  const NSInteger clampedEnd = MAX(clampedStart, MIN(end, length));
  _textView.selectedRange = NSMakeRange(clampedStart, clampedEnd - clampedStart);
}

- (void)toggleBold {
  [self toggleMark:fastmarkdown::MarkBold];
}

- (void)toggleCode {
  [self toggleMark:fastmarkdown::MarkInlineCode];
}

- (void)toggleItalic {
  [self toggleMark:fastmarkdown::MarkItalic];
}

- (void)toggleSpoiler {
  [self toggleMark:fastmarkdown::MarkSpoiler];
}

- (void)toggleStrikethrough {
  [self toggleMark:fastmarkdown::MarkStrikethrough];
}

- (void)toggleSubscript {
  [self toggleMark:fastmarkdown::MarkSubscript];
}

- (void)toggleSuperscript {
  [self toggleMark:fastmarkdown::MarkSuperscript];
}

@end
