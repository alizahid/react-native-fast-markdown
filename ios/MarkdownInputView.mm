#import "MarkdownInputView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

#import "ASTNodeWrapper.h"
#import "MarkdownParser.hpp"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

using namespace facebook::react;

@interface MarkdownInputView () <UITextViewDelegate>
@end

@implementation MarkdownInputView {
  UITextView *_textView;
  StyleConfig *_styleConfig;
  NSString *_currentStyleJSON;
  NSArray<NSString *> *_customTags;

  // Formatting state
  BOOL _isBold;
  BOOL _isItalic;
  BOOL _isStrikethrough;
  BOOL _isUnderline;
  BOOL _isCode;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<
      MarkdownInputViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _textView = [[UITextView alloc] initWithFrame:self.bounds];
    _textView.delegate = self;
    _textView.font = [UIFont systemFontOfSize:16];
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
      *std::static_pointer_cast<const MarkdownInputViewProps>(props);

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
  NSString *styleJSON = newProps.markdownStyle.empty()
                            ? @""
                            : [NSString stringWithUTF8String:newProps.markdownStyle.c_str()];
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
    [self applyMarkdownFormatting];
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
  } else if ([commandName isEqualToString:@"toggleUnderline"]) {
    [self toggleFormatting:@"__"];
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

  [self applyMarkdownFormatting];
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

  [self applyMarkdownFormatting];
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
  [self applyMarkdownFormatting];
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

  [self applyMarkdownFormatting];
  [self emitChangeEvents];
}

- (void)insertText:(NSString *)text {
  [_textView replaceRange:[self textRangeFromNSRange:_textView.selectedRange]
                 withText:text];
  [self applyMarkdownFormatting];
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
  if (!_styleConfig) return;

  NSString *text = _textView.text;
  if (text.length == 0) return;

  NSRange savedRange = _textView.selectedRange;

  markdown::ParseOptions options;
  options.enableTables = true;
  options.enableStrikethrough = true;
  options.enableTaskLists = true;
  options.enableAutolinks = true;

  for (NSString *tag in _customTags) {
    options.customTags.insert(std::string([tag UTF8String]));
  }

  std::string markdownStr([text UTF8String]);
  markdown::ASTNode ast =
      markdown::MarkdownParser::parse(markdownStr, options);

  ASTNodeWrapper *rootWrapper =
      [[ASTNodeWrapper alloc] initWithOpaqueNode:&ast];

  RenderContext *context = [[RenderContext alloc] init];
  context.styleConfig = _styleConfig;

  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] init];
  [context renderChildren:rootWrapper into:output];

  _textView.attributedText = output;

  if (savedRange.location + savedRange.length <= _textView.text.length) {
    _textView.selectedRange = savedRange;
  }
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
      static_cast<const MarkdownInputViewEventEmitter &>(*_eventEmitter);

  emitter.onChangeText({.text = std::string([_textView.text UTF8String])});
  emitter.onChangeMarkdown(
      {.markdown = std::string([_textView.text UTF8String])});
}

- (void)emitStateChange {
  if (!_eventEmitter) return;

  const auto &emitter =
      static_cast<const MarkdownInputViewEventEmitter &>(*_eventEmitter);

  emitter.onChangeState({
      .bold = _isBold,
      .italic = _isItalic,
      .strikethrough = _isStrikethrough,
      .underline = _isUnderline,
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
      static_cast<const MarkdownInputViewEventEmitter &>(*_eventEmitter);

  NSRange range = textView.selectedRange;
  emitter.onChangeSelection({
      .start = static_cast<double>(range.location),
      .end = static_cast<double>(range.location + range.length),
  });
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
  if (!_eventEmitter) return;
  const auto &emitter =
      static_cast<const MarkdownInputViewEventEmitter &>(*_eventEmitter);
  emitter.onEditorFocus({.focused = true});
}

- (void)textViewDidEndEditing:(UITextView *)textView {
  if (!_eventEmitter) return;
  const auto &emitter =
      static_cast<const MarkdownInputViewEventEmitter &>(*_eventEmitter);
  emitter.onEditorBlur({.focused = false});
}

@end

Class<RCTComponentViewProtocol> MarkdownInputViewCls(void) {
  return MarkdownInputView.class;
}
