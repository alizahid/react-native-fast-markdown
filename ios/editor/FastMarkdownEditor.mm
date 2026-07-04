#import "FastMarkdownEditor.h"

#import <React/RCTConversions.h>
#import <react/renderer/components/FastMarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/FastMarkdownViewSpec/Props.h>
#import <react/renderer/components/FastMarkdownViewSpec/RCTComponentViewHelpers.h>
#import <react/renderer/core/ConcreteComponentDescriptor.h>

#import <vector>

#import "../../cpp/core/EditorRuns.h"
#import "../../cpp/react/FastMarkdownEditorShadowNode.h"
#import "../style/FMDFontScale.h"
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

// Draws the full-width background stripe behind code-block lines. Sits
// below the text view so glyphs stay crisp.
@interface FMDEditorCodeBackgroundView : UIView
@property (nonatomic, weak) FastMarkdownEditor *editor;
@end

@protocol FMDEditorTextViewActions <NSObject>
- (void)editorTextViewDidPaste;
- (void)editorTextViewShortcut:(uint32_t)mark;
// Backspace with the caret at the very start of the document: UIKit has
// nothing to delete, but a formatted first line should shed its block.
- (BOOL)editorTextViewHandleDeleteAtDocumentStart;
@end

// Intercepts paste (the clipboard is reported to JS, which owns the
// default insertion) and adds hardware keyboard formatting shortcuts.
@interface FMDEditorTextView : UITextView
@property (nonatomic, weak) id<FMDEditorTextViewActions> actionDelegate;
@end

@implementation FMDEditorTextView

- (void)paste:(id)sender {
  [self.actionDelegate editorTextViewDidPaste];
}

- (void)deleteBackward {
  if (self.selectedRange.location == 0 && self.selectedRange.length == 0 &&
      [self.actionDelegate editorTextViewHandleDeleteAtDocumentStart]) {
    return;
  }
  [super deleteBackward];
}

- (NSArray<UIKeyCommand *> *)keyCommands {
  UIKeyCommand *bold = [UIKeyCommand keyCommandWithInput:@"b"
                                           modifierFlags:UIKeyModifierCommand
                                                  action:@selector(fmdToggleBold:)];
  UIKeyCommand *italic = [UIKeyCommand keyCommandWithInput:@"i"
                                             modifierFlags:UIKeyModifierCommand
                                                    action:@selector(fmdToggleItalic:)];
  UIKeyCommand *strike = [UIKeyCommand
      keyCommandWithInput:@"x"
            modifierFlags:UIKeyModifierCommand | UIKeyModifierShift
                   action:@selector(fmdToggleStrikethrough:)];
  if (@available(iOS 15.0, *)) {
    bold.wantsPriorityOverSystemBehavior = YES;
    italic.wantsPriorityOverSystemBehavior = YES;
    strike.wantsPriorityOverSystemBehavior = YES;
  }
  return @[ bold, italic, strike ];
}

- (void)fmdToggleBold:(UIKeyCommand *)command {
  [self.actionDelegate editorTextViewShortcut:fastmarkdown::MarkBold];
}

- (void)fmdToggleItalic:(UIKeyCommand *)command {
  [self.actionDelegate editorTextViewShortcut:fastmarkdown::MarkItalic];
}

- (void)fmdToggleStrikethrough:(UIKeyCommand *)command {
  [self.actionDelegate editorTextViewShortcut:fastmarkdown::MarkStrikethrough];
}

@end

@interface FastMarkdownEditor () <UITextViewDelegate,
                                  FMDEditorTextViewActions,
                                  RCTFastMarkdownEditorViewProtocol>
- (void)drawMarkersInContext:(CGContextRef)context view:(FMDEditorMarkerView *)view;
- (void)drawCodeBackgroundsInView:(FMDEditorCodeBackgroundView *)view;
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

@implementation FMDEditorCodeBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  [self.editor drawCodeBackgroundsInView:self];
}

@end

@implementation FastMarkdownEditor {
  FMDEditorTextView *_textView;
  UILabel *_placeholderLabel;
  FMDEditorMarkerView *_markerView;
  FMDEditorCodeBackgroundView *_codeBackgroundView;
  NSString *_stylesJson;
  BOOL _defaultValueApplied;
  BOOL _autoFocusHandled;
  BOOL _multiline;
  BOOL _propScrollEnabled;
  // Autogrow cap; 0 = unbounded. Past it the text view scrolls internally.
  CGFloat _maxHeight;
  CGFloat _lastPublishedHeight;
  UIFont *_baseFont;
  UIColor *_baseColor;
  // Resolved lineHeight per context; 0 = natural. Headings and code use
  // their own element style, everything else the base/paragraph cascade.
  CGFloat _lineHeight;
  CGFloat _headingLineHeights[7];
  CGFloat _codeLineHeight;
  // Marks armed for text typed at the collapsed cursor. Explicit while the
  // user has toggled at this caret position; re-derived from the character
  // before the caret whenever the selection moves.
  uint32_t _typingFlags;
  // Block armed for the caret's line (empty lines carry no characters, so
  // the attribute alone cannot represent them).
  uint32_t _typingBlock;
  BOOL _paragraphAfterNewline;
  // Autocorrect/QuickType replace a whole word ("Ab" → "An"), rebuilding it
  // with attributes that drop the custom mark keys. The replaced range's
  // per-character flags are captured in shouldChangeTextInRange and
  // restored onto the committed text in textViewDidChange.
  std::vector<uint32_t> _replacedCharFlags;
  NSRange _markRestoreRange;
  BOOL _pendingMarkRestore;
  BOOL _markdownEmitScheduled;
  // Autocorrect/autocapitalize from props; suppressed while the caret is in
  // a code context (code block line or armed inline-code mark).
  BOOL _propAutoCorrect;
  UITextAutocapitalizationType _propAutoCapitalize;
  BOOL _allowFontScaling;
  // Dynamic Type multiplier applied to font sizes and line heights; 1 when
  // allowFontScaling is off. Must match the shadow node's fontSizeMultiplier.
  CGFloat _fontScale;
  BOOL _suppressFocusEvents;
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
    _allowFontScaling = YES;
    _fontScale = FMDFontSizeMultiplier();

    [NSNotificationCenter.defaultCenter
        addObserver:self
           selector:@selector(fmdContentSizeCategoryDidChange)
               name:UIContentSizeCategoryDidChangeNotification
             object:nil];
    _lastPublishedHeight = 0;
    _baseFont = [UIFont systemFontOfSize:16];
    _baseColor = UIColor.blackColor;
    _linkColor = UIColor.systemBlueColor;
    _mentionTriggers = @[];
    _lastSelection = NSMakeRange(0, 0);

    _codeBackgroundView = [[FMDEditorCodeBackgroundView alloc] initWithFrame:CGRectZero];
    _codeBackgroundView.editor = self;
    [self addSubview:_codeBackgroundView];

    _textView = [[FMDEditorTextView alloc] initWithFrame:CGRectZero];
    _textView.actionDelegate = self;
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
  CGFloat lineHeight = 0;
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
    if (style.lineHeight != nil) {
      lineHeight = style.lineHeight.doubleValue;
    }
  }
  _fontScale = _allowFontScaling ? FMDFontSizeMultiplier() : 1.0;
  fontSize *= _fontScale;
  lineHeight *= _fontScale;

  _lineHeight = lineHeight;
  for (uint8_t level = 1; level <= 6; level++) {
    FMDTextStyle *heading =
        [styles textStyleFor:[NSString stringWithFormat:@"h%d", level]];
    _headingLineHeights[level] =
        (heading.lineHeight != nil ? heading.lineHeight.doubleValue : 0) *
        _fontScale;
  }
  FMDTextStyle *codeStyle = [styles textStyleFor:@"codeBlock"];
  _codeLineHeight = codeStyle.lineHeight != nil
      ? codeStyle.lineHeight.doubleValue * _fontScale
      : lineHeight;

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
  [self invalidateDecorations];
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
  // Inline code gets a per-run background; code BLOCK lines get a
  // full-width stripe from the background view instead.
  if ((flags & fastmarkdown::MarkInlineCode) != 0) {
    attributes[NSBackgroundColorAttributeName] =
        [UIColor colorWithWhite:0.5 alpha:0.15];
  }
  if ((flags & fastmarkdown::MarkSpoiler) != 0) {
    attributes[NSBackgroundColorAttributeName] =
        [UIColor colorWithWhite:0.35 alpha:0.25];
  }
  CGFloat baselineOffset = 0;
  if (isSuper) {
    baselineOffset = _baseFont.pointSize * 0.33;
  } else if (isSub) {
    baselineOffset = -_baseFont.pointSize * 0.15;
  }

  // Line height: headings/code use their element style, everything else
  // the base/paragraph cascade (0 = natural). Glyphs center in the line
  // box, matching React Native.
  CGFloat lineHeight = _lineHeight;
  if (isHeading) {
    lineHeight = _headingLineHeights[MIN(level, (uint8_t)6)];
  } else if (isCodeBlock) {
    lineHeight = _codeLineHeight;
  }

  NSMutableParagraphStyle *paragraph = [self paragraphStyleForBlock:block];
  if (lineHeight > 0) {
    if (paragraph == nil) {
      paragraph = [[NSMutableParagraphStyle alloc] init];
    }
    paragraph.minimumLineHeight = lineHeight;
    paragraph.maximumLineHeight = lineHeight;
    const CGFloat delta = lineHeight - font.lineHeight;
    if (delta > 0) {
      baselineOffset += delta / 2;
    }
  }
  if (paragraph != nil) {
    attributes[NSParagraphStyleAttributeName] = paragraph;
  }
  if (baselineOffset != 0) {
    attributes[NSBaselineOffsetAttributeName] = @(baselineOffset);
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

- (NSMutableParagraphStyle *)paragraphStyleForBlock:(uint32_t)block {
  const auto blockType = FMDBlockType(block);
  if (blockType != fastmarkdown::EditorBlockType::Quote && !FMDBlockIsList(block)) {
    return nil;
  }
  NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
  const CGFloat indent =
      blockType == fastmarkdown::EditorBlockType::Quote ? 16 : 28;
  paragraph.firstLineHeadIndent = indent;
  paragraph.headIndent = indent;
  return paragraph;
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

// Autocorrect/autocapitalize/spellcheck follow the caret: suppressed in
// code contexts (`let` must not become `Let`), restored from props outside.
- (void)updateInputTraits {
  const BOOL inCode =
      FMDBlockType(_typingBlock) == fastmarkdown::EditorBlockType::Code ||
      (_typingFlags & fastmarkdown::MarkInlineCode) != 0;
  const UITextAutocorrectionType correction = (!inCode && _propAutoCorrect)
      ? UITextAutocorrectionTypeDefault
      : UITextAutocorrectionTypeNo;
  const UITextAutocapitalizationType capitalization =
      inCode ? UITextAutocapitalizationTypeNone : _propAutoCapitalize;
  const UITextSpellCheckingType spelling =
      inCode ? UITextSpellCheckingTypeNo : UITextSpellCheckingTypeDefault;
  if (_textView.autocorrectionType == correction &&
      _textView.autocapitalizationType == capitalization &&
      _textView.spellCheckingType == spelling) {
    return;
  }
  _textView.autocorrectionType = correction;
  _textView.autocapitalizationType = capitalization;
  _textView.spellCheckingType = spelling;
  if (_textView.isFirstResponder && self.window != nil) {
    // reloadInputViews alone leaves an already-latched shift key engaged
    // (the first code character would still capitalize); cycling the
    // responder resets the keyboard's state. Focus/blur events are
    // suppressed — JS must not see a blip.
    _suppressFocusEvents = YES;
    __block BOOL refocused = NO;
    [UIView performWithoutAnimation:^{
      [self->_textView resignFirstResponder];
      refocused = [self->_textView becomeFirstResponder];
    }];
    _suppressFocusEvents = NO;
    if (!refocused) {
      // The keyboard is gone for real; JS must not believe the editor is
      // still focused.
      if (const auto *emitter = [self editorEventEmitter]) {
        emitter->onEditorBlur({});
      }
    }
  }
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

// Line-iteration primitive safe for every terminator (\n, \r, \r\n):
// reports the line STARTING at `location` and where the next line begins.
// Returns NO when `location` is not a line start (iteration is done). The
// old "NSMaxRange(content) + 1" advance assumed 1-char terminators and
// looped forever on \r\n.
- (BOOL)lineStartingAt:(NSUInteger)location
               content:(NSRange *)outContent
              nextLine:(NSUInteger *)outNext {
  NSString *text = _textView.text;
  if (location > text.length) {
    return NO;
  }
  NSUInteger start = 0;
  NSUInteger end = 0;
  NSUInteger contentsEnd = 0;
  [text getLineStart:&start
                  end:&end
          contentsEnd:&contentsEnd
             forRange:NSMakeRange(location, 0)];
  if (start != location) {
    return NO;
  }
  *outContent = NSMakeRange(start, contentsEnd - start);
  *outNext = end;
  return YES;
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
  // A code fence carries raw text only: marks and links on lines converted
  // to a code block would be dropped by the serializer, so shed them now.
  const BOOL toCode = FMDBlockType(block) == fastmarkdown::EditorBlockType::Code;
  [storage beginEditing];
  [storage enumerateAttributesInRange:lines
                              options:0
                           usingBlock:^(NSDictionary *attrs, NSRange runRange, BOOL *stop) {
                             const uint32_t flags =
                                 FMDFlagsFromValue(attrs[FMDEditorMarksAttribute]);
                             NSDictionary *next = toCode
                                 ? [self attributesForFlags:0 block:block]
                                 : [self attributesFromExisting:attrs
                                                      withFlags:flags
                                                          block:block];
                             [storage setAttributes:next range:runRange];
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
    NSRange content;
    NSUInteger nextLine;
    while (cursor < NSMaxRange(lines) &&
           [self lineStartingAt:cursor content:&content nextLine:&nextLine]) {
      if (content.length > 0 && [self blockOfLineAt:cursor] != target) {
        allMatch = NO;
        break;
      }
      if (content.length == 0 && _typingBlock != target) {
        allMatch = NO;
        break;
      }
      if (nextLine == cursor) {
        break;
      }
      cursor = nextLine;
    }
  }

  const uint32_t next = allMatch ? 0 : target;
  if (lines.length > 0) {
    [self applyBlock:next toLinesInRange:lines];
    _textView.selectedRange = selection;
  }
  _typingBlock = next;
  if (FMDBlockType(next) == fastmarkdown::EditorBlockType::Code) {
    // Armed marks cannot survive inside a code fence.
    _typingFlags = 0;
  }
  [self applyTypingAttributes];
  [self updateInputTraits];
  [self invalidateDecorations];
  [self textContentChanged];
  [self emitState];
}

#pragma mark - Markers

- (void)invalidateDecorations {
  [_markerView setNeedsDisplay];
  [_codeBackgroundView setNeedsDisplay];
}

// The block shown for a line: stored attribute for content lines; for the
// EMPTY caret line, the armed typing block (immediate feedback on toggle).
- (uint32_t)displayBlockForLineContent:(NSRange)content {
  if (content.length > 0) {
    return [self blockOfLineAt:content.location];
  }
  const NSRange selection = _textView.selectedRange;
  if (selection.length == 0 && selection.location == content.location) {
    return _typingBlock;
  }
  return 0;
}

- (CGRect)rectForLineContent:(NSRange)content {
  if (content.length > 0) {
    NSLayoutManager *layoutManager = _textView.layoutManager;
    const NSRange glyphs =
        [layoutManager glyphRangeForCharacterRange:content actualCharacterRange:nil];
    CGRect rect = [layoutManager boundingRectForGlyphRange:glyphs
                                           inTextContainer:_textView.textContainer];
    rect.origin.x += _textView.textContainerInset.left;
    rect.origin.y += _textView.textContainerInset.top;
    return rect;
  }
  UITextPosition *position =
      [_textView positionFromPosition:_textView.beginningOfDocument
                               offset:(NSInteger)content.location];
  if (position == nil) {
    return CGRectZero;
  }
  return [_textView caretRectForPosition:position];
}

- (void)drawMarkersInContext:(CGContextRef)context view:(FMDEditorMarkerView *)view {
  if (context == nil) {
    return;
  }
  NSString *text = _textView.text;
  const UIEdgeInsets inset = _textView.textContainerInset;
  UIColor *markerColor = [_baseColor colorWithAlphaComponent:0.6];

  NSDictionary *markerAttributes = @{
    NSFontAttributeName : _baseFont,
    NSForegroundColorAttributeName : markerColor,
  };
  NSUInteger location = 0;
  NSInteger orderedNumber = 0;
  NSRange content;
  NSUInteger nextLine;
  while ([self lineStartingAt:location content:&content nextLine:&nextLine]) {
    const uint32_t block = [self displayBlockForLineContent:content];
    const auto type = FMDBlockType(block);

    if (type == fastmarkdown::EditorBlockType::Ordered) {
      orderedNumber += 1;
    } else {
      orderedNumber = 0;
    }

    if (block != 0) {
      const CGRect lineRect = [self rectForLineContent:content];
      if (!CGRectIsEmpty(lineRect)) {
        const CGFloat top = lineRect.origin.y;

        if (type == fastmarkdown::EditorBlockType::Quote) {
          [markerColor setFill];
          UIRectFill(CGRectMake(inset.left + 4, top, 3, lineRect.size.height));
        } else if (type == fastmarkdown::EditorBlockType::Bullet ||
                   type == fastmarkdown::EditorBlockType::Ordered) {
          NSString *marker = type == fastmarkdown::EditorBlockType::Bullet
              ? @"•"
              : [NSString stringWithFormat:@"%ld.", (long)orderedNumber];
          const CGSize size = [marker sizeWithAttributes:markerAttributes];
          [marker drawAtPoint:CGPointMake(inset.left + 24 - size.width - 6, top)
               withAttributes:markerAttributes];
        }
      }
    }

    if (nextLine == location) {
      break;
    }
    location = nextLine;
  }
}

- (void)drawCodeBackgroundsInView:(FMDEditorCodeBackgroundView *)view {
  NSString *text = _textView.text;
  const UIEdgeInsets inset = _textView.textContainerInset;
  const CGFloat left = MAX(inset.left - 6, 0);
  const CGFloat width = view.bounds.size.width - left - MAX(inset.right - 6, 0);
  UIColor *fill = [UIColor colorWithWhite:0.5 alpha:0.1];

  // Contiguous code lines merge into one rounded stripe.
  CGFloat groupTop = 0;
  CGFloat groupBottom = 0;
  BOOL inGroup = NO;
  const auto flush = [&]() {
    if (inGroup) {
      UIBezierPath *path = [UIBezierPath
          bezierPathWithRoundedRect:CGRectMake(left, groupTop - 2, width,
                                               groupBottom - groupTop + 4)
                       cornerRadius:6];
      [fill setFill];
      [path fill];
      inGroup = NO;
    }
  };

  NSUInteger location = 0;
  NSRange content;
  NSUInteger nextLine;
  while ([self lineStartingAt:location content:&content nextLine:&nextLine]) {
    const uint32_t block = [self displayBlockForLineContent:content];
    const CGRect lineRect = FMDBlockType(block) == fastmarkdown::EditorBlockType::Code
        ? [self rectForLineContent:content]
        : CGRectZero;

    if (!CGRectIsEmpty(lineRect)) {
      if (!inGroup) {
        inGroup = YES;
        groupTop = lineRect.origin.y;
      }
      groupBottom = CGRectGetMaxY(lineRect);
    } else {
      flush();
    }

    if (nextLine == location) {
      break;
    }
    location = nextLine;
  }
  flush();
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
  // Marks end at the paragraph break: a newline never carries them forward
  // (otherwise a mark armed once would leak into every following line).
  if ([_textView.text characterAtIndex:probe] == '\n') {
    return 0;
  }
  return FMDFlagsFromValue([storage attribute:FMDEditorMarksAttribute
                                      atIndex:probe
                               effectiveRange:nil]);
}

// YES when the caret's armed block or any line the range touches is a code
// block.
- (BOOL)selectionTouchesCodeBlock:(NSRange)range {
  if (FMDBlockType(_typingBlock) == fastmarkdown::EditorBlockType::Code) {
    return YES;
  }
  NSString *text = _textView.text;
  NSUInteger lineStart = 0;
  [text getLineStart:&lineStart
                  end:nil
          contentsEnd:nil
             forRange:NSMakeRange(MIN(range.location, text.length), 0)];
  NSUInteger location = lineStart;
  const NSUInteger max = NSMaxRange(range);
  NSRange content;
  NSUInteger nextLine;
  while ([self lineStartingAt:location content:&content nextLine:&nextLine]) {
    if (FMDBlockType([self blockOfLineAt:location]) ==
        fastmarkdown::EditorBlockType::Code) {
      return YES;
    }
    if (nextLine == location || nextLine > max) {
      break;
    }
    location = nextLine;
  }
  return NO;
}

- (void)toggleMark:(uint32_t)mark {
  const NSRange selection = _textView.selectedRange;
  // A code fence carries raw text only — marks applied there would render
  // in the editor but silently vanish from the markdown, so refuse them.
  if ([self selectionTouchesCodeBlock:selection]) {
    return;
  }
  // Superscript and subscript are mutually exclusive: a glyph cannot sit
  // above and below the baseline, and combined they serialize to nested
  // ^~…~^ that does not round-trip.
  uint32_t exclusive = 0;
  if (mark == fastmarkdown::MarkSuperscript) {
    exclusive = fastmarkdown::MarkSubscript;
  } else if (mark == fastmarkdown::MarkSubscript) {
    exclusive = fastmarkdown::MarkSuperscript;
  }
  if (selection.length == 0) {
    _typingFlags ^= mark;
    if ((_typingFlags & mark) != 0) {
      _typingFlags &= ~exclusive;
    }
    [self applyTypingAttributes];
    [self updateInputTraits];
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
                             const uint32_t next = allHave
                                 ? (flags & ~mark)
                                 : ((flags | mark) & ~exclusive);
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
  _propScrollEnabled = newProps.scrollEnabled;
  _maxHeight = newProps.maxHeight;
  _multiline = newProps.multiline;
  [self publishHeight];

  if (newProps.allowFontScaling != _allowFontScaling) {
    _allowFontScaling = newProps.allowFontScaling;
    [self applyTextStyles];
  }

  _propAutoCorrect = newProps.autoCorrect;
  switch (newProps.autoCapitalize) {
    case FastMarkdownEditorAutoCapitalize::None:
      _propAutoCapitalize = UITextAutocapitalizationTypeNone;
      break;
    case FastMarkdownEditorAutoCapitalize::Words:
      _propAutoCapitalize = UITextAutocapitalizationTypeWords;
      break;
    case FastMarkdownEditorAutoCapitalize::Characters:
      _propAutoCapitalize = UITextAutocapitalizationTypeAllCharacters;
      break;
    case FastMarkdownEditorAutoCapitalize::Sentences:
      _propAutoCapitalize = UITextAutocapitalizationTypeSentences;
      break;
  }
  [self updateInputTraits];

  // UIKit shares one tint for the caret and the selection highlight;
  // selectionColor wins when both are set, nil restores the system tint.
  // SharedColor carries platform colors (PlatformColor/DynamicColorIOS)
  // through as dynamic-provider UIColors.
  UIColor *selectionColor = RCTUIColorFromSharedColor(newProps.selectionColor);
  UIColor *cursorColor = RCTUIColorFromSharedColor(newProps.cursorColor);
  _textView.tintColor = selectionColor ?: cursorColor;

  NSMutableArray<NSString *> *triggers = [NSMutableArray array];
  for (const auto &trigger : newProps.mentionTriggers) {
    NSString *value = FMDStringFromCpp(trigger);
    if (value.length > 0) {
      [triggers addObject:[value substringWithRange:
                                      [value rangeOfComposedCharacterSequenceAtIndex:0]]];
    }
  }
  _mentionTriggers = triggers;

  NSString *placeholder = FMDStringFromCpp(newProps.placeholder);
  if (![placeholder isEqualToString:_placeholderLabel.text]) {
    _placeholderLabel.text = placeholder;
    _textView.accessibilityLabel = placeholder;
    [self setNeedsLayout];
  }
  UIColor *placeholderColor =
      RCTUIColorFromSharedColor(newProps.placeholderTextColor);
  _placeholderLabel.textColor =
      placeholderColor ?: [UIColor colorWithWhite:0 alpha:0.3];

  if (newProps.autoFocus && !prevProps.autoFocus) {
    _autoFocusHandled = NO;
  }

  [super updateProps:props oldProps:oldProps];
  [self refreshPlaceholderVisibility];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if ([self.traitCollection
          hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
    // Marker/stripe decorations draw with (possibly dynamic) UIColors;
    // re-resolve them under the new appearance.
    [self invalidateDecorations];
  }
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  const auto &props = *std::static_pointer_cast<FastMarkdownEditorProps const>(_props);
  if (self.window != nil && props.autoFocus && !_autoFocusHandled) {
    _autoFocusHandled = YES;
    [_textView becomeFirstResponder];
  }
}

- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)fmdContentSizeCategoryDidChange {
  if (_allowFontScaling) {
    [self applyTextStyles];
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
  _codeBackgroundView.frame = self.bounds;

  const UIEdgeInsets inset = _textView.textContainerInset;
  const CGSize placeholderSize = [_placeholderLabel sizeThatFits:CGSizeMake(
      self.bounds.size.width - inset.left - inset.right, CGFLOAT_MAX)];
  _placeholderLabel.frame = CGRectMake(
      inset.left, inset.top, placeholderSize.width, placeholderSize.height);

  [self invalidateDecorations];
  [self publishHeight];
}

#pragma mark - Autogrow

- (void)publishHeight {
  const CGFloat width = self.bounds.size.width;
  if (width <= 0 || _state == nullptr) {
    return;
  }
  const CGSize size = [_textView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
  CGFloat height = size.height;
  BOOL exceedsMax = NO;
  if (_maxHeight > 0 && height > _maxHeight) {
    height = _maxHeight;
    exceedsMax = YES;
  }
  // Grow-then-scroll: once content passes maxHeight the text view scrolls
  // internally like a textarea.
  const BOOL wantScroll = exceedsMax || _propScrollEnabled;
  if (_textView.scrollEnabled != wantScroll) {
    _textView.scrollEnabled = wantScroll;
  }
  if (fabs(height - _lastPublishedHeight) < 0.5) {
    return;
  }
  _lastPublishedHeight = height;
  _state->updateState(FastMarkdownEditorState(height));
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
  NSRange content;
  NSUInteger nextLine;
  while ([self lineStartingAt:location content:&content nextLine:&nextLine]) {
    const uint32_t block =
        content.length > 0 ? [self blockOfLineAt:content.location] : 0;
    lines.push_back(
        {FMDBlockType(block), static_cast<uint8_t>(block & 0xFF)});
    if (nextLine == location) {
      break;
    }
    location = nextLine;
  }
  if (lines.empty()) {
    lines.push_back({});
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
  [self invalidateDecorations];
  if (const auto *emitter = [self editorEventEmitter]) {
    const std::string text(_textView.text.UTF8String ?: "");
    emitter->onEditorChangeText({.text = text});
  }
  // Serializing the whole document per keystroke is the expensive half of
  // this pipeline; coalesce bursts to one emission per runloop turn.
  if (!_markdownEmitScheduled) {
    _markdownEmitScheduled = YES;
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      __typeof(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }
      strongSelf->_markdownEmitScheduled = NO;
      if (const auto *emitter = [strongSelf editorEventEmitter]) {
        emitter->onEditorChangeMarkdown({.markdown = [strongSelf serializedMarkdown]});
      }
    });
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
  // Linkify in place: a bare URL re-parses as an autolink in any markdown
  // renderer, so the editor must show it as a link too (WYSIWYG). The app
  // can still restyle or remove it from the onLinkDetected callback.
  const NSRange wordRange = NSMakeRange(wordStart, location - wordStart);
  // textViewDidChange serializes right after this returns, so no extra
  // textContentChanged is needed here.
  if (FMDBlockType([self blockOfLineAt:wordStart]) !=
      fastmarkdown::EditorBlockType::Code) {
    [self applyLink:word atomic:NO inRange:wordRange];
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

  // Normalize CR line endings at the door (system drag-and-drop and some
  // input methods deliver them); the whole line model assumes "\n".
  if ([text rangeOfString:@"\r"].location != NSNotFound) {
    NSString *sanitized =
        [[text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]
            stringByReplacingOccurrencesOfString:@"\r"
                                      withString:@"\n"];
    [_textView.textStorage replaceCharactersInRange:range withString:sanitized];
    _textView.selectedRange = NSMakeRange(range.location + sanitized.length, 0);
    [self textViewDidChange:_textView];
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
    if (block != 0 && content.length == 0) {
      // Enter on any empty formatted line (list item, quote, code block,
      // heading) exits the block instead of continuing it.
      _typingBlock = 0;
      [self applyTypingAttributes];
      [self updateInputTraits];
      [self invalidateDecorations];
      [self emitState];
      return NO;
    }
    if (FMDBlockType(block) == fastmarkdown::EditorBlockType::Heading) {
      // A heading does not continue onto the next line.
      _paragraphAfterNewline = YES;
    }
  }

  // A growing word replacement is an autocorrect/QuickType commit; snapshot
  // the replaced characters' marks so they survive the rebuild (the size
  // cap keeps select-all replacements out of this path).
  _pendingMarkRestore = NO;
  if (range.length > 0 && range.length <= 512 && text.length >= range.length &&
      NSMaxRange(range) <= _textView.textStorage.length) {
    _replacedCharFlags.clear();
    NSTextStorage *storage = _textView.textStorage;
    for (NSUInteger i = 0; i < range.length; i++) {
      _replacedCharFlags.push_back(FMDFlagsFromValue(
          [storage attribute:FMDEditorMarksAttribute
                      atIndex:range.location + i
               effectiveRange:nil]));
    }
    _markRestoreRange = NSMakeRange(range.location, text.length);
    _pendingMarkRestore = YES;
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
      [self invalidateDecorations];
      [self textContentChanged];
      [self emitState];
      return NO;
    }
  }

  return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
  if (_pendingMarkRestore) {
    _pendingMarkRestore = NO;
    NSTextStorage *storage = _textView.textStorage;
    const NSUInteger location = _markRestoreRange.location;
    const NSUInteger count =
        MIN(_replacedCharFlags.size(), _markRestoreRange.length);
    if (location + count <= storage.length) {
      [storage beginEditing];
      for (NSUInteger i = 0; i < count; i++) {
        const NSUInteger position = location + i;
        NSDictionary *attrs = [storage attributesAtIndex:position
                                          effectiveRange:nil];
        const uint32_t existing =
            FMDFlagsFromValue(attrs[FMDEditorMarksAttribute]);
        const uint32_t desired = _replacedCharFlags[i];
        if (existing == desired) {
          continue;
        }
        const uint32_t block = FMDFlagsFromValue(attrs[FMDEditorBlockAttribute]);
        [storage setAttributes:[self attributesForFlags:desired
                                                   block:block
                                                    link:attrs[FMDEditorLinkAttribute]
                                                  atomic:[attrs[FMDEditorAtomicAttribute]
                                                             boolValue]]
                         range:NSMakeRange(position, 1)];
      }
      [storage endEditing];
    }
    _replacedCharFlags.clear();
  }

  if (_paragraphAfterNewline) {
    _paragraphAfterNewline = NO;
    _typingBlock = 0;
    [self applyTypingAttributes];
  }

  // A typed newline inherits the previous line's attributes, and TextKit
  // sizes the trailing empty line fragment from them — after a heading the
  // caret would stay heading-sized. Normalize the newline: base font and
  // no marks, keeping the block attr for list/quote continuation (headings
  // never continue, so theirs is dropped).
  {
    const NSRange caret = textView.selectedRange;
    if (caret.length == 0 && caret.location > 0 &&
        caret.location <= textView.text.length &&
        [textView.text characterAtIndex:caret.location - 1] == '\n') {
      NSTextStorage *storage = textView.textStorage;
      const NSRange newline = NSMakeRange(caret.location - 1, 1);
      NSDictionary *attrs = [storage attributesAtIndex:newline.location
                                        effectiveRange:nil];
      uint32_t block = FMDFlagsFromValue(attrs[FMDEditorBlockAttribute]);
      if (FMDBlockType(block) == fastmarkdown::EditorBlockType::Heading) {
        block = 0;
      }
      [storage setAttributes:[self attributesForFlags:0 block:block]
                       range:newline];
    }
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
  // The heading-to-paragraph reset above changes the caret context after
  // didChangeSelection already emitted; re-emit so toolbars never show a
  // stale block.
  [self emitState];
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
    [self updateInputTraits];
  }
  if (moved) {
    [self updateMentionSession];
    // The empty caret line renders its armed block (marker/stripe), so a
    // caret move can change what the decorations show.
    [self invalidateDecorations];
  }
  [self emitState];
  if (moved) {
    if (const auto *emitter = [self editorEventEmitter]) {
      emitter->onEditorChangeSelection({
          .start = static_cast<int>(selection.location),
          .end = static_cast<int>(selection.location + selection.length),
      });
    }
  }
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
  if (_suppressFocusEvents) {
    return;
  }
  if (const auto *emitter = [self editorEventEmitter]) {
    emitter->onEditorFocus({});
  }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
  if (_suppressFocusEvents) {
    return;
  }
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

- (NSMutableAttributedString *)attributedContentFromMarkdown:(const std::string &)markdown {
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

  return attributed;
}

- (void)applyMarkdownValue:(const std::string &)markdown {
  _textView.attributedText = [self attributedContentFromMarkdown:markdown];
  _typingFlags = 0;
  _typingBlock = 0;
  [self applyTypingAttributes];
  [self textContentChanged];
}

- (void)setValue:(NSString *)value {
  [self applyMarkdownValue:std::string(value.UTF8String ?: "")];
}

- (void)insertMarkdown:(NSString *)value {
  const std::string markdown(value.UTF8String ?: "");
  if (markdown.empty()) {
    return;
  }
  NSAttributedString *content = [self attributedContentFromMarkdown:markdown];
  const NSRange selection = _textView.selectedRange;
  [_textView.textStorage replaceCharactersInRange:selection
                             withAttributedString:content];
  _textView.selectedRange = NSMakeRange(selection.location + content.length, 0);
  [self textContentChanged];
  [self emitState];
}

#pragma mark - FMDEditorTextViewActions

- (void)editorTextViewDidPaste {
  UIPasteboard *pasteboard = UIPasteboard.generalPasteboard;
  const std::string text(pasteboard.string.UTF8String ?: "");

  if (!pasteboard.hasImages) {
    if (const auto *emitter = [self editorEventEmitter]) {
      emitter->onEditorPaste({.images = {}, .text = text});
    }
    return;
  }

  // PNG-encoding pasted photos synchronously would freeze the main thread
  // for the whole encode + disk write; do it off-main and emit when done.
  NSArray<UIImage *> *pastedImages = pasteboard.images;
  __weak __typeof(self) weakSelf = self;
  dispatch_async(
      dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        auto images =
            std::vector<FastMarkdownEditorEventEmitter::OnEditorPasteImages>();
        for (UIImage *image in pastedImages) {
          NSData *data = UIImagePNGRepresentation(image);
          if (data == nil) {
            continue;
          }
          NSString *path = [NSTemporaryDirectory()
              stringByAppendingPathComponent:
                  [NSString
                      stringWithFormat:@"fmd-paste-%@.png", NSUUID.UUID.UUIDString]];
          if (![data writeToFile:path atomically:YES]) {
            continue;
          }
          images.push_back({
              .height = image.size.height,
              .url = std::string([NSString stringWithFormat:@"file://%@", path].UTF8String),
              .width = image.size.width,
          });
        }
        auto shared =
            std::make_shared<std::vector<FastMarkdownEditorEventEmitter::OnEditorPasteImages>>(
                std::move(images));
        dispatch_async(dispatch_get_main_queue(), ^{
          __typeof(self) strongSelf = weakSelf;
          if (strongSelf == nil) {
            return;
          }
          if (const auto *emitter = [strongSelf editorEventEmitter]) {
            emitter->onEditorPaste({.images = std::move(*shared), .text = text});
          }
        });
      });
}

- (void)editorTextViewShortcut:(uint32_t)mark {
  [self toggleMark:mark];
}

- (BOOL)editorTextViewHandleDeleteAtDocumentStart {
  const uint32_t block = [self blockOfLineAt:0] ?: _typingBlock;
  if (block == 0) {
    return NO;
  }
  [self applyBlock:0 toLinesInRange:NSMakeRange(0, 0)];
  _typingBlock = 0;
  [self applyTypingAttributes];
  [self updateInputTraits];
  [self invalidateDecorations];
  [self textContentChanged];
  [self emitState];
  return YES;
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

- (NSString *)singleLine:(NSString *)value {
  NSString *flattened =
      [[value stringByReplacingOccurrencesOfString:@"\r" withString:@" "]
          stringByReplacingOccurrencesOfString:@"\n"
                                    withString:@" "];
  return flattened;
}

- (void)insertLink:(NSString *)url label:(NSString *)label {
  if (url.length == 0) {
    return;
  }
  label = [self singleLine:label ?: @""];
  const NSRange selection = _textView.selectedRange;
  // A code fence carries raw text only — a link there would render in the
  // editor but vanish from the markdown.
  if ([self selectionTouchesCodeBlock:selection]) {
    return;
  }
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
  label = [self singleLine:label];
  if ([self selectionTouchesCodeBlock:_textView.selectedRange]) {
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
