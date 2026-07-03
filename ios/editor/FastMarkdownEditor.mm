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

// Source of truth for the line's block type: (EditorBlockType << 8) | level,
// stored on every character of the line (and carried by the newline).
static NSAttributedStringKey const FMDEditorBlockAttribute = @"FMDEditorBlock";

// Linked ranges: the URL string. Mentions are links with app-scheme URLs
// plus the atomic flag (the token edits as one unit).
static NSAttributedStringKey const FMDEditorLinkAttribute = @"FMDEditorLink";
static NSAttributedStringKey const FMDEditorAtomicAttribute = @"FMDEditorAtomic";

static NSString *FMDStringFromCpp(const std::string &value) {
  return [[NSString alloc] initWithBytes:value.data()
                                  length:value.size()
                                encoding:NSUTF8StringEncoding]
      ?: @"";
}

static uint32_t FMDFlagsFromValue(id value) {
  return value == nil ? 0 : [(NSNumber *)value unsignedIntValue];
}

static uint32_t FMDPackBlock(fastmarkdown::EditorBlockType type, uint8_t level) {
  return (static_cast<uint32_t>(type) << 8) | level;
}

static fastmarkdown::EditorBlockType FMDBlockType(uint32_t packed) {
  return static_cast<fastmarkdown::EditorBlockType>(packed >> 8);
}

static BOOL FMDBlockIsList(uint32_t packed) {
  const auto type = FMDBlockType(packed);
  return type == fastmarkdown::EditorBlockType::Bullet ||
      type == fastmarkdown::EditorBlockType::Ordered;
}

@class FastMarkdownEditor;

// Draws list markers and quote bars in the gutter created by the line
// blocks' paragraph indents. Sits above the text view; never interactive.
@interface FMDEditorMarkerView : UIView
@property (nonatomic, weak) FastMarkdownEditor *editor;
@end

@interface FastMarkdownEditor () <UITextViewDelegate, RCTFastMarkdownEditorViewProtocol>
- (void)drawMarkersInContext:(CGContextRef)context view:(FMDEditorMarkerView *)view;
@end

@implementation FMDEditorMarkerView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  [self.editor drawMarkersInContext:UIGraphicsGetCurrentContext() view:self];
}

@end

@implementation FastMarkdownEditor {
  UITextView *_textView;
  UILabel *_placeholderLabel;
  FMDEditorMarkerView *_markerView;
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
  // Block armed for the caret's line (empty lines carry no characters, so
  // the attribute alone cannot represent them).
  uint32_t _typingBlock;
  BOOL _paragraphAfterNewline;
  UIColor *_linkColor;
  NSArray<NSString *> *_mentionTriggers;
  BOOL _mentionActive;
  NSString *_mentionTrigger;
  NSUInteger _mentionStart;
  // Dedupes onMentionChange: typing fires both didChangeSelection and
  // didChange, which each re-evaluate the session.
  NSString *_lastMentionQuery;
  NSRange _lastSelection;
  uint64_t _lastStateKey;
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
    _linkColor = UIColor.systemBlueColor;
    _mentionTriggers = @[];
    _lastSelection = NSMakeRange(0, 0);

    _textView = [[UITextView alloc] initWithFrame:CGRectZero];
    _textView.backgroundColor = UIColor.clearColor;
    _textView.delegate = self;
    _textView.scrollEnabled = NO;
    _textView.textContainer.lineFragmentPadding = 0;
    _textView.textContainerInset = UIEdgeInsetsZero;
    [self addSubview:_textView];

    _markerView = [[FMDEditorMarkerView alloc] initWithFrame:CGRectZero];
    _markerView.editor = self;
    [self addSubview:_markerView];

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
  _linkColor = [styles textStyleFor:@"link"].color ?: UIColor.systemBlueColor;
  _textView.font = font;
  _textView.textColor = color;
  _textView.textContainerInset = UIEdgeInsetsMake(
      styles.paddingTop, styles.paddingLeft, styles.paddingBottom, styles.paddingRight);
  self.backgroundColor = styles.backgroundColor ?: UIColor.clearColor;

  [self refreshDisplayAttributesInRange:NSMakeRange(0, _textView.textStorage.length)];
  [self applyTypingAttributes];

  _placeholderLabel.font = font;
  [self setNeedsLayout];
  [_markerView setNeedsDisplay];
  [self publishHeight];
}

#pragma mark - Attributes

- (NSDictionary<NSAttributedStringKey, id> *)attributesForFlags:(uint32_t)flags
                                                          block:(uint32_t)block {
  return [self attributesForFlags:flags block:block link:nil atomic:NO];
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesForFlags:(uint32_t)flags
                                                          block:(uint32_t)block
                                                           link:(NSString *)link
                                                         atomic:(BOOL)atomic {
  const auto blockType = FMDBlockType(block);
  const uint8_t level = block & 0xFF;
  const BOOL isCodeBlock = blockType == fastmarkdown::EditorBlockType::Code;
  const BOOL isHeading = blockType == fastmarkdown::EditorBlockType::Heading;
  const BOOL isCode = isCodeBlock || (flags & fastmarkdown::MarkInlineCode) != 0;
  const BOOL isSuper = (flags & fastmarkdown::MarkSuperscript) != 0;
  const BOOL isSub = (flags & fastmarkdown::MarkSubscript) != 0;

  static const CGFloat headingScale[7] = {1, 2.0, 1.5, 1.25, 1.125, 1.0, 0.875};
  CGFloat size = _baseFont.pointSize;
  if (isHeading) {
    size *= headingScale[MIN(level, (uint8_t)6)];
  }
  // Sup/sub match the viewer's 0.7 scaling.
  if (isSuper || isSub) {
    size *= 0.7;
  }

  UIFont *font = isCode
      ? [UIFont monospacedSystemFontOfSize:size weight:UIFontWeightRegular]
      : [_baseFont fontWithSize:size];

  UIFontDescriptorSymbolicTraits traits = font.fontDescriptor.symbolicTraits;
  if ((flags & fastmarkdown::MarkBold) != 0 || isHeading) {
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
    attributes[NSBaselineOffsetAttributeName] = @(_baseFont.pointSize * 0.33);
  } else if (isSub) {
    attributes[NSBaselineOffsetAttributeName] = @(-_baseFont.pointSize * 0.15);
  }

  if (blockType == fastmarkdown::EditorBlockType::Quote ||
      FMDBlockIsList(block)) {
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    const CGFloat indent =
        blockType == fastmarkdown::EditorBlockType::Quote ? 16 : 28;
    paragraph.firstLineHeadIndent = indent;
    paragraph.headIndent = indent;
    attributes[NSParagraphStyleAttributeName] = paragraph;
  }

  if (link.length > 0) {
    attributes[NSForegroundColorAttributeName] = _linkColor;
    attributes[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
    attributes[FMDEditorLinkAttribute] = link;
    if (atomic) {
      attributes[FMDEditorAtomicAttribute] = @YES;
    }
  }
  if (flags != 0) {
    attributes[FMDEditorMarksAttribute] = @(flags);
  }
  if (block != 0) {
    attributes[FMDEditorBlockAttribute] = @(block);
  }
  return attributes;
}

// Full attributes for a run described by an existing attribute dictionary.
- (NSDictionary<NSAttributedStringKey, id> *)attributesFromExisting:
                                                 (NSDictionary *)attrs
                                                          withFlags:(uint32_t)flags
                                                              block:(uint32_t)block {
  return [self attributesForFlags:flags
                            block:block
                             link:attrs[FMDEditorLinkAttribute]
                           atomic:[attrs[FMDEditorAtomicAttribute] boolValue]];
}

// Rebuilds display attributes from the data attributes (marks + block).
- (void)refreshDisplayAttributesInRange:(NSRange)range {
  if (range.length == 0) {
    return;
  }
  NSTextStorage *storage = _textView.textStorage;
  [storage beginEditing];
  [storage enumerateAttributesInRange:range
                              options:0
                           usingBlock:^(NSDictionary *attrs, NSRange runRange, BOOL *stop) {
                             const uint32_t flags =
                                 FMDFlagsFromValue(attrs[FMDEditorMarksAttribute]);
                             const uint32_t block =
                                 FMDFlagsFromValue(attrs[FMDEditorBlockAttribute]);
                             [storage setAttributes:[self attributesFromExisting:attrs
                                                                       withFlags:flags
                                                                           block:block]
                                              range:runRange];
                           }];
  [storage endEditing];
}

- (void)applyTypingAttributes {
  _textView.typingAttributes = [self attributesForFlags:_typingFlags
                                                  block:_typingBlock];
}

#pragma mark - Lines

- (NSRange)contentRangeOfLineAt:(NSUInteger)location {
  NSString *text = _textView.text;
  NSUInteger start = 0;
  NSUInteger contentsEnd = 0;
  const NSRange probe = NSMakeRange(MIN(location, text.length), 0);
  [text getLineStart:&start end:nil contentsEnd:&contentsEnd forRange:probe];
  return NSMakeRange(start, contentsEnd - start);
}

- (uint32_t)blockOfLineAt:(NSUInteger)location {
  const NSRange content = [self contentRangeOfLineAt:location];
  if (content.length == 0) {
    return 0;
  }
  return FMDFlagsFromValue([_textView.textStorage attribute:FMDEditorBlockAttribute
                                                    atIndex:content.location
                                             effectiveRange:nil]);
}

// Sets the block on every line the range touches, preserving per-character
// marks.
- (void)applyBlock:(uint32_t)block toLinesInRange:(NSRange)range {
  NSString *text = _textView.text;
  const NSRange lines = [text lineRangeForRange:range];
  if (lines.length == 0) {
    return;
  }
  NSTextStorage *storage = _textView.textStorage;
  [storage beginEditing];
  [storage enumerateAttributesInRange:lines
                              options:0
                           usingBlock:^(NSDictionary *attrs, NSRange runRange, BOOL *stop) {
                             const uint32_t flags =
                                 FMDFlagsFromValue(attrs[FMDEditorMarksAttribute]);
                             [storage setAttributes:[self attributesFromExisting:attrs
                                                                       withFlags:flags
                                                                           block:block]
                                              range:runRange];
                           }];
  [storage endEditing];
}

- (void)toggleBlock:(fastmarkdown::EditorBlockType)type level:(uint8_t)level {
  const uint32_t target = FMDPackBlock(type, level);
  const NSRange selection = _textView.selectedRange;
  NSString *text = _textView.text;
  const NSRange lines =
      text.length == 0 ? NSMakeRange(0, 0) : [text lineRangeForRange:selection];

  BOOL allMatch = YES;
  if (lines.length == 0) {
    allMatch = _typingBlock == target;
  } else {
    NSUInteger cursor = lines.location;
    while (cursor < NSMaxRange(lines)) {
      const NSRange content = [self contentRangeOfLineAt:cursor];
      if (content.length > 0 && [self blockOfLineAt:cursor] != target) {
        allMatch = NO;
        break;
      }
      if (content.length == 0 && _typingBlock != target) {
        allMatch = NO;
        break;
      }
      cursor = NSMaxRange(content) + 1;
    }
  }

  const uint32_t next = allMatch ? 0 : target;
  if (lines.length > 0) {
    [self applyBlock:next toLinesInRange:lines];
    _textView.selectedRange = selection;
  }
  _typingBlock = next;
  [self applyTypingAttributes];
  [_markerView setNeedsDisplay];
  [self textContentChanged];
  [self emitState];
}

#pragma mark - Markers

- (void)drawMarkersInContext:(CGContextRef)context view:(FMDEditorMarkerView *)view {
  if (context == nil || _textView.text.length == 0) {
    return;
  }
  NSString *text = _textView.text;
  NSLayoutManager *layoutManager = _textView.layoutManager;
  const UIEdgeInsets inset = _textView.textContainerInset;
  UIColor *markerColor = [_baseColor colorWithAlphaComponent:0.6];

  NSUInteger location = 0;
  NSInteger orderedNumber = 0;
  while (location <= text.length) {
    const NSRange content = [self contentRangeOfLineAt:location];
    const uint32_t block =
        content.length > 0 ? [self blockOfLineAt:content.location] : 0;
    const auto type = FMDBlockType(block);

    if (type == fastmarkdown::EditorBlockType::Ordered) {
      orderedNumber += 1;
    } else {
      orderedNumber = 0;
    }

    if (block != 0 && content.length > 0) {
      const NSRange glyphs =
          [layoutManager glyphRangeForCharacterRange:content actualCharacterRange:nil];
      const CGRect lineRect =
          [layoutManager boundingRectForGlyphRange:glyphs
                                   inTextContainer:_textView.textContainer];
      const CGFloat top = lineRect.origin.y + inset.top;

      if (type == fastmarkdown::EditorBlockType::Quote) {
        [markerColor setFill];
        UIRectFill(CGRectMake(inset.left + 4, top, 3, lineRect.size.height));
      } else if (type == fastmarkdown::EditorBlockType::Bullet ||
                 type == fastmarkdown::EditorBlockType::Ordered) {
        NSString *marker = type == fastmarkdown::EditorBlockType::Bullet
            ? @"•"
            : [NSString stringWithFormat:@"%ld.", (long)orderedNumber];
        NSDictionary *attributes = @{
          NSFontAttributeName : [_baseFont fontWithSize:_baseFont.pointSize],
          NSForegroundColorAttributeName : markerColor,
        };
        const CGSize size = [marker sizeWithAttributes:attributes];
        [marker drawAtPoint:CGPointMake(inset.left + 24 - size.width - 6, top)
             withAttributes:attributes];
      }
    }

    if (NSMaxRange(content) >= text.length) {
      break;
    }
    location = NSMaxRange(content) + 1;
  }
}

#pragma mark - Marks

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
  [storage enumerateAttributesInRange:selection
                              options:0
                           usingBlock:^(NSDictionary *attrs, NSRange runRange, BOOL *stop) {
                             const uint32_t flags =
                                 FMDFlagsFromValue(attrs[FMDEditorMarksAttribute]);
                             const uint32_t block =
                                 FMDFlagsFromValue(attrs[FMDEditorBlockAttribute]);
                             const uint32_t next =
                                 allHave ? (flags & ~mark) : (flags | mark);
                             [storage setAttributes:[self attributesFromExisting:attrs
                                                                       withFlags:next
                                                                           block:block]
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

  NSMutableArray<NSString *> *triggers = [NSMutableArray array];
  for (const auto &trigger : newProps.mentionTriggers) {
    NSString *value = FMDStringFromCpp(trigger);
    if (value.length > 0) {
      [triggers addObject:[value substringToIndex:1]];
    }
  }
  _mentionTriggers = triggers;

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
  _typingBlock = 0;
  _paragraphAfterNewline = NO;
  _mentionActive = NO;
  _lastMentionQuery = nil;
  _lastSelection = NSMakeRange(0, 0);
  _stateEmitted = NO;
  _state = nullptr;
  [self applyTextStyles];
  [self refreshPlaceholderVisibility];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _textView.frame = self.bounds;
  _markerView.frame = self.bounds;

  const UIEdgeInsets inset = _textView.textContainerInset;
  const CGSize placeholderSize = [_placeholderLabel sizeThatFits:CGSizeMake(
      self.bounds.size.width - inset.left - inset.right, CGFLOAT_MAX)];
  _placeholderLabel.frame = CGRectMake(
      inset.left, inset.top, placeholderSize.width, placeholderSize.height);

  [_markerView setNeedsDisplay];
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
  NSString *text = _textView.text;
  const std::string utf8(text.UTF8String ?: "");

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

  std::vector<fastmarkdown::EditorLine> lines;
  NSUInteger location = 0;
  while (location <= text.length) {
    const NSRange content = [self contentRangeOfLineAt:location];
    const uint32_t block =
        content.length > 0 ? [self blockOfLineAt:content.location] : 0;
    lines.push_back(
        {FMDBlockType(block), static_cast<uint8_t>(block & 0xFF)});
    if (NSMaxRange(content) >= text.length) {
      break;
    }
    location = NSMaxRange(content) + 1;
  }

  __block std::vector<fastmarkdown::LinkRun> links;
  [storage enumerateAttribute:FMDEditorLinkAttribute
                      inRange:NSMakeRange(0, storage.length)
                      options:0
                   usingBlock:^(id value, NSRange runRange, BOOL *stop) {
                     NSString *url = (NSString *)value;
                     if (url.length > 0) {
                       links.push_back(
                           {static_cast<uint32_t>(runRange.location),
                            static_cast<uint32_t>(NSMaxRange(runRange)),
                            std::string(url.UTF8String ?: "")});
                     }
                   }];

  return fastmarkdown::markdownFromEditor(utf8, runs, lines, links);
}

- (void)textContentChanged {
  [self refreshPlaceholderVisibility];
  [self publishHeight];
  [_markerView setNeedsDisplay];
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
  const NSRange caretLine = [self contentRangeOfLineAt:selection.location];
  const uint32_t block =
      caretLine.length > 0 ? [self blockOfLineAt:caretLine.location] : _typingBlock;
  const uint64_t stateKey = (static_cast<uint64_t>(block) << 32) | flags;
  if (_stateEmitted && stateKey == _lastStateKey) {
    return;
  }
  _lastStateKey = stateKey;
  _stateEmitted = YES;
  if (const auto *emitter = [self editorEventEmitter]) {
    const auto type = FMDBlockType(block);
    emitter->onEditorChangeState({
        .headingLevel = type == fastmarkdown::EditorBlockType::Heading
            ? static_cast<int>(block & 0xFF)
            : 0,
        .isBlockQuote = type == fastmarkdown::EditorBlockType::Quote,
        .isBold = (flags & fastmarkdown::MarkBold) != 0,
        .isCodeBlock = type == fastmarkdown::EditorBlockType::Code,
        .isInlineCode = (flags & fastmarkdown::MarkInlineCode) != 0,
        .isItalic = (flags & fastmarkdown::MarkItalic) != 0,
        .isOrderedList = type == fastmarkdown::EditorBlockType::Ordered,
        .isSpoiler = (flags & fastmarkdown::MarkSpoiler) != 0,
        .isStrikethrough = (flags & fastmarkdown::MarkStrikethrough) != 0,
        .isSubscript = (flags & fastmarkdown::MarkSubscript) != 0,
        .isSuperscript = (flags & fastmarkdown::MarkSuperscript) != 0,
        .isUnorderedList = type == fastmarkdown::EditorBlockType::Bullet,
    });
  }
}

- (void)refreshPlaceholderVisibility {
  _placeholderLabel.hidden = _textView.text.length > 0;
}

#pragma mark - Links & mentions

static BOOL FMDIsWordBreak(unichar c) {
  return c == ' ' || c == '\t' || c == '\n';
}

// The atomic token range containing (or abutting) the position, if any.
- (NSRange)atomicRangeAt:(NSUInteger)location {
  NSTextStorage *storage = _textView.textStorage;
  if (storage.length == 0 || location >= storage.length) {
    return NSMakeRange(NSNotFound, 0);
  }
  NSRange effective = NSMakeRange(NSNotFound, 0);
  id value = [storage attribute:FMDEditorAtomicAttribute
                        atIndex:location
          longestEffectiveRange:&effective
                        inRange:NSMakeRange(0, storage.length)];
  return [value boolValue] ? effective : NSMakeRange(NSNotFound, 0);
}

- (void)endMentionSession {
  if (!_mentionActive) {
    return;
  }
  _mentionActive = NO;
  _lastMentionQuery = nil;
  if (const auto *emitter = [self editorEventEmitter]) {
    emitter->onEditorMentionEnd(
        {.trigger = std::string(_mentionTrigger.UTF8String ?: "")});
  }
}

// Runs after every content or caret change: starts, updates, or ends the
// mention session based on the text between the trigger and the caret.
- (void)updateMentionSession {
  if (_mentionTriggers.count == 0) {
    return;
  }
  NSString *text = _textView.text;
  const NSRange selection = _textView.selectedRange;
  if (selection.length != 0) {
    [self endMentionSession];
    return;
  }
  const NSUInteger caret = selection.location;

  if (_mentionActive) {
    BOOL valid = _mentionStart < text.length && caret > _mentionStart &&
        caret <= text.length;
    if (valid) {
      NSString *trigger = [text substringWithRange:NSMakeRange(_mentionStart, 1)];
      valid = [trigger isEqualToString:_mentionTrigger];
    }
    NSString *query = @"";
    if (valid) {
      query = [text substringWithRange:NSMakeRange(
          _mentionStart + 1, caret - _mentionStart - 1)];
      for (NSUInteger i = 0; i < query.length; i++) {
        if (FMDIsWordBreak([query characterAtIndex:i])) {
          valid = NO;
          break;
        }
      }
    }
    if (!valid) {
      [self endMentionSession];
      return;
    }
    if ([query isEqualToString:_lastMentionQuery]) {
      return;
    }
    _lastMentionQuery = query;
    if (const auto *emitter = [self editorEventEmitter]) {
      emitter->onEditorMentionChange({
          .query = std::string(query.UTF8String ?: ""),
          .trigger = std::string(_mentionTrigger.UTF8String ?: ""),
      });
    }
    return;
  }

  // A trigger character at a word start (directly before the caret) opens
  // a session.
  if (caret == 0 || caret > text.length) {
    return;
  }
  NSString *last = [text substringWithRange:NSMakeRange(caret - 1, 1)];
  if (![_mentionTriggers containsObject:last]) {
    return;
  }
  if (caret >= 2 && !FMDIsWordBreak([text characterAtIndex:caret - 2])) {
    return;
  }
  _mentionActive = YES;
  _mentionTrigger = last;
  _mentionStart = caret - 1;
  if (const auto *emitter = [self editorEventEmitter]) {
    emitter->onEditorMentionStart(
        {.trigger = std::string(last.UTF8String ?: "")});
  }
}

// After a word break is typed, reports a bare URL the word forms (the app
// decides whether to call insertLink).
- (void)detectLinkBefore:(NSUInteger)location {
  NSString *text = _textView.text;
  if (location > text.length) {
    return;
  }
  NSUInteger wordStart = location;
  while (wordStart > 0 &&
         !FMDIsWordBreak([text characterAtIndex:wordStart - 1])) {
    wordStart--;
  }
  if (wordStart >= location) {
    return;
  }
  NSString *word = [text substringWithRange:NSMakeRange(wordStart, location - wordStart)];
  if (![word hasPrefix:@"http://"] && ![word hasPrefix:@"https://"]) {
    return;
  }
  if ([word isEqualToString:@"http://"] || [word isEqualToString:@"https://"]) {
    return;
  }
  id linked = [_textView.textStorage attribute:FMDEditorLinkAttribute
                                       atIndex:wordStart
                                effectiveRange:nil];
  if (linked != nil) {
    return;
  }
  if (const auto *emitter = [self editorEventEmitter]) {
    emitter->onEditorLinkDetected({.url = std::string(word.UTF8String ?: "")});
  }
}

- (void)applyLink:(NSString *)url atomic:(BOOL)atomic inRange:(NSRange)range {
  NSTextStorage *storage = _textView.textStorage;
  [storage beginEditing];
  [storage enumerateAttributesInRange:range
                              options:0
                           usingBlock:^(NSDictionary *attrs, NSRange runRange, BOOL *stop) {
                             const uint32_t flags =
                                 FMDFlagsFromValue(attrs[FMDEditorMarksAttribute]);
                             const uint32_t block =
                                 FMDFlagsFromValue(attrs[FMDEditorBlockAttribute]);
                             [storage setAttributes:[self attributesForFlags:flags
                                                                       block:block
                                                                        link:url
                                                                      atomic:atomic]
                                              range:runRange];
                           }];
  [storage endEditing];
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text {
  if (!_multiline && [text containsString:@"\n"]) {
    [textView resignFirstResponder];
    return NO;
  }

  // Deleting into an atomic token removes the whole token.
  if (text.length == 0 && range.length > 0) {
    NSRange expanded = range;
    const NSRange headToken = [self atomicRangeAt:range.location];
    if (headToken.location != NSNotFound) {
      expanded = NSUnionRange(expanded, headToken);
    }
    if (range.length > 1) {
      const NSRange tailToken = [self atomicRangeAt:NSMaxRange(range) - 1];
      if (tailToken.location != NSNotFound) {
        expanded = NSUnionRange(expanded, tailToken);
      }
    }
    if (!NSEqualRanges(expanded, range)) {
      [_textView.textStorage replaceCharactersInRange:expanded withString:@""];
      _textView.selectedRange = NSMakeRange(expanded.location, 0);
      [self textContentChanged];
      return NO;
    }
  }

  // Typing strictly inside an atomic token demotes it to plain text.
  if (text.length > 0 && range.length == 0 && range.location > 0) {
    const NSRange token = [self atomicRangeAt:range.location - 1];
    if (token.location != NSNotFound && range.location > token.location &&
        range.location < NSMaxRange(token)) {
      [self applyLink:nil atomic:NO inRange:token];
    }
  }

  if ([text isEqualToString:@"\n"] && range.length == 0) {
    const NSRange content = [self contentRangeOfLineAt:range.location];
    const uint32_t block =
        content.length > 0 ? [self blockOfLineAt:content.location] : _typingBlock;
    if (FMDBlockIsList(block) && content.length == 0) {
      // Enter on an empty list item exits the list instead of continuing.
      _typingBlock = 0;
      [self applyTypingAttributes];
      [_markerView setNeedsDisplay];
      [self emitState];
      return NO;
    }
    if (FMDBlockType(block) == fastmarkdown::EditorBlockType::Heading) {
      // A heading does not continue onto the next line.
      _paragraphAfterNewline = YES;
    }
  }

  // Backspace at the start of a formatted line clears the block first.
  if (text.length == 0 && range.length == 1 &&
      [_textView.text characterAtIndex:range.location] == '\n') {
    const NSUInteger lineStart = range.location + 1;
    const uint32_t block = [self blockOfLineAt:lineStart];
    if (block != 0) {
      [self applyBlock:0
          toLinesInRange:NSMakeRange(lineStart, 0)];
      _typingBlock = 0;
      [self applyTypingAttributes];
      [_markerView setNeedsDisplay];
      [self textContentChanged];
      [self emitState];
      return NO;
    }
  }

  return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
  if (_paragraphAfterNewline) {
    _paragraphAfterNewline = NO;
    _typingBlock = 0;
    [self applyTypingAttributes];
  }
  const NSRange selection = textView.selectedRange;
  if (selection.length == 0 && selection.location > 0 &&
      selection.location <= textView.text.length) {
    const unichar last = [textView.text characterAtIndex:selection.location - 1];
    if (FMDIsWordBreak(last)) {
      [self detectLinkBefore:selection.location - 1];
    }
  }
  [self updateMentionSession];
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
    const NSRange content = [self contentRangeOfLineAt:selection.location];
    if (content.length > 0) {
      _typingBlock = [self blockOfLineAt:content.location];
    } else if (selection.location > 0 &&
               selection.location <= _textView.textStorage.length) {
      // Empty line: inherit the block carried by the preceding newline so
      // lists continue across Enter.
      _typingBlock = FMDFlagsFromValue([_textView.textStorage
          attribute:FMDEditorBlockAttribute
            atIndex:selection.location - 1
     effectiveRange:nil]);
    } else {
      _typingBlock = 0;
    }
    [self applyTypingAttributes];
  }
  if (moved) {
    [self updateMentionSession];
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
  const auto document = fastmarkdown::editorFromMarkdown(markdown);
  NSString *text = FMDStringFromCpp(document.text);
  NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc]
      initWithString:text
          attributes:[self attributesForFlags:0 block:0]];

  // Line blocks first (line granularity), then mark runs refine spans.
  NSUInteger location = 0;
  size_t lineIndex = 0;
  while (location <= text.length && lineIndex < document.lines.size()) {
    NSUInteger start = 0;
    NSUInteger contentsEnd = 0;
    NSUInteger end = 0;
    [text getLineStart:&start
                   end:&end
           contentsEnd:&contentsEnd
              forRange:NSMakeRange(MIN(location, text.length), 0)];
    const auto &line = document.lines[lineIndex];
    const uint32_t block = FMDPackBlock(line.type, line.level);
    if (block != 0 && contentsEnd > start) {
      [attributed setAttributes:[self attributesForFlags:0 block:block]
                          range:NSMakeRange(start, contentsEnd - start)];
    }
    if (end <= location || end > text.length) {
      break;
    }
    location = end;
    lineIndex++;
    if (contentsEnd == end) {
      break;
    }
  }

  for (const auto &run : document.runs) {
    const NSRange range = NSMakeRange(run.start, run.end - run.start);
    if (NSMaxRange(range) <= attributed.length) {
      uint32_t block = 0;
      if (range.location < attributed.length) {
        block = FMDFlagsFromValue([attributed attribute:FMDEditorBlockAttribute
                                                atIndex:range.location
                                         effectiveRange:nil]);
      }
      [attributed setAttributes:[self attributesForFlags:run.flags block:block]
                          range:range];
    }
  }

  for (const auto &link : document.links) {
    const NSRange range = NSMakeRange(link.start, link.end - link.start);
    if (NSMaxRange(range) <= attributed.length && range.length > 0) {
      [attributed enumerateAttributesInRange:range
                                     options:0
                                  usingBlock:^(NSDictionary *attrs, NSRange runRange, BOOL *stop) {
                                    [attributed setAttributes:
                                        [self attributesForFlags:FMDFlagsFromValue(
                                                                     attrs[FMDEditorMarksAttribute])
                                                           block:FMDFlagsFromValue(
                                                                     attrs[FMDEditorBlockAttribute])
                                                            link:FMDStringFromCpp(link.url)
                                                          atomic:NO]
                                                        range:runRange];
                                  }];
    }
  }

  _textView.attributedText = attributed;
  _typingFlags = 0;
  _typingBlock = 0;
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

- (void)toggleBlockQuote {
  [self toggleBlock:fastmarkdown::EditorBlockType::Quote level:0];
}

- (void)toggleCodeBlock {
  [self toggleBlock:fastmarkdown::EditorBlockType::Code level:0];
}

- (void)toggleHeading:(NSInteger)level {
  [self toggleBlock:fastmarkdown::EditorBlockType::Heading
              level:(uint8_t)MAX(1, MIN(level, 6))];
}

- (void)toggleOrderedList {
  [self toggleBlock:fastmarkdown::EditorBlockType::Ordered level:0];
}

- (void)toggleUnorderedList {
  [self toggleBlock:fastmarkdown::EditorBlockType::Bullet level:0];
}

- (void)insertLink:(NSString *)url label:(NSString *)label {
  if (url.length == 0) {
    return;
  }
  const NSRange selection = _textView.selectedRange;
  if (selection.length > 0) {
    [self applyLink:url atomic:NO inRange:selection];
    _textView.selectedRange = NSMakeRange(NSMaxRange(selection), 0);
  } else {
    NSString *content = label.length > 0 ? label : url;
    NSAttributedString *linked = [[NSAttributedString alloc]
        initWithString:content
            attributes:[self attributesForFlags:_typingFlags
                                          block:_typingBlock
                                           link:url
                                         atomic:NO]];
    [_textView.textStorage insertAttributedString:linked
                                          atIndex:selection.location];
    _textView.selectedRange = NSMakeRange(selection.location + content.length, 0);
  }
  [self applyTypingAttributes];
  [self textContentChanged];
}

- (void)removeLink {
  const NSRange selection = _textView.selectedRange;
  NSRange target = selection;
  if (selection.length == 0) {
    NSTextStorage *storage = _textView.textStorage;
    const NSUInteger probe =
        selection.location > 0 ? selection.location - 1 : 0;
    if (storage.length == 0 || probe >= storage.length) {
      return;
    }
    NSRange effective = NSMakeRange(NSNotFound, 0);
    id value = [storage attribute:FMDEditorLinkAttribute
                          atIndex:probe
            longestEffectiveRange:&effective
                          inRange:NSMakeRange(0, storage.length)];
    if (value == nil) {
      return;
    }
    target = effective;
  }
  [self applyLink:nil atomic:NO inRange:target];
  [self textContentChanged];
}

- (void)insertMention:(NSString *)trigger label:(NSString *)label url:(NSString *)url {
  if (label.length == 0 || url.length == 0) {
    return;
  }
  // Replaces the active mention query (trigger included), or inserts at
  // the caret. A trailing space keeps typing outside the token.
  NSRange target = _textView.selectedRange;
  if (_mentionActive) {
    target = NSMakeRange(_mentionStart, target.location - _mentionStart);
  }
  NSString *token = [NSString stringWithFormat:@"%@%@", trigger ?: @"", label];
  NSMutableAttributedString *inserted = [[NSMutableAttributedString alloc]
      initWithString:token
          attributes:[self attributesForFlags:0
                                        block:_typingBlock
                                         link:url
                                       atomic:YES]];
  [inserted appendAttributedString:[[NSAttributedString alloc]
      initWithString:@" "
          attributes:[self attributesForFlags:0 block:_typingBlock]]];
  [_textView.textStorage replaceCharactersInRange:target
                             withAttributedString:inserted];
  _textView.selectedRange = NSMakeRange(target.location + inserted.length, 0);
  [self endMentionSession];
  _typingFlags = 0;
  [self applyTypingAttributes];
  [self textContentChanged];
}

@end
