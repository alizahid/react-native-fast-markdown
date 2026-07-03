#import "FastMarkdownEditor.h"

#import <React/RCTComponentViewFactory.h>
#import <react/renderer/components/FastMarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/FastMarkdownViewSpec/Props.h>
#import <react/renderer/components/FastMarkdownViewSpec/RCTComponentViewHelpers.h>
#import <react/renderer/core/ConcreteComponentDescriptor.h>

#import "../../cpp/react/FastMarkdownEditorShadowNode.h"
#import "../style/FMDStyleConfig.h"
#import "../style/FMDTextStyle.h"

using namespace facebook::react;

// Imported directly (like the viewer) so the descriptor binds to the custom
// measurable shadow node regardless of include order.
using FMDEditorComponentDescriptor =
    ConcreteComponentDescriptor<FastMarkdownEditorShadowNode>;

static NSString *FMDStringFromCpp(const std::string &value) {
  return [[NSString alloc] initWithBytes:value.data()
                                  length:value.size()
                                encoding:NSUTF8StringEncoding]
      ?: @"";
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

  _textView.font = font;
  _textView.textColor = color;
  _textView.textContainerInset = UIEdgeInsetsMake(
      styles.paddingTop, styles.paddingLeft, styles.paddingBottom, styles.paddingRight);
  self.backgroundColor = styles.backgroundColor ?: UIColor.clearColor;

  _placeholderLabel.font = font;
  [self setNeedsLayout];
  [self publishHeight];
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
    NSString *defaultValue = FMDStringFromCpp(newProps.defaultValue);
    if (defaultValue.length > 0) {
      // E0: plain text; E1 parses markdown into formatted content.
      _textView.text = defaultValue;
      [self textContentChanged];
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

- (void)textContentChanged {
  [self refreshPlaceholderVisibility];
  [self publishHeight];
  if (const auto *emitter = [self editorEventEmitter]) {
    emitter->onEditorChangeText(
        {.text = std::string(_textView.text.UTF8String ?: "")});
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
  if (const auto *emitter = [self editorEventEmitter]) {
    const NSRange range = textView.selectedRange;
    emitter->onEditorChangeSelection({
        .start = static_cast<int>(range.location),
        .end = static_cast<int>(range.location + range.length),
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

- (void)setValue:(NSString *)value {
  // E0: plain text; E1 parses markdown into formatted content.
  _textView.text = value;
  [self textContentChanged];
}

- (void)setSelection:(NSInteger)start end:(NSInteger)end {
  const NSInteger length = (NSInteger)_textView.text.length;
  const NSInteger clampedStart = MAX(0, MIN(start, length));
  const NSInteger clampedEnd = MAX(clampedStart, MIN(end, length));
  _textView.selectedRange = NSMakeRange(clampedStart, clampedEnd - clampedStart);
}

@end
