#import "MarkdownEditorView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <QuartzCore/QuartzCore.h>
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

@interface MarkdownEditorTextView : UITextView
@end

@implementation MarkdownEditorTextView

- (CGRect)caretRectForPosition:(UITextPosition *)position {
  CGRect rect = [super caretRectForPosition:position];
  UIFont *font = self.typingAttributes[NSFontAttributeName];
  CGFloat height = font.lineHeight;
  if (height <= 0) return rect;

  CGFloat midY = CGRectGetMidY(rect);
  rect.origin.y = midY - height / 2.0;
  rect.size.height = height;
  return rect;
}

@end

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
  NSMutableArray<CALayer *> *_blockBackgroundLayers;

  BOOL _suppressFormatting;

  // Mention tracking
  NSSet<NSString *> *_mentionTriggers;
  NSString *_activeMentionTrigger;  // nil when not in a mention
  NSUInteger _mentionStartPos;     // position after the trigger char
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
    _blockBackgroundLayers = [NSMutableArray new];

    _textView = [[MarkdownEditorTextView alloc] initWithFrame:self.bounds];
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
  [self updateBlockBackgroundLayers];
}

// ---------------------------------------------------------------
#pragma mark - Props
// ---------------------------------------------------------------

- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  // Re-attach delegate after prepareForRecycle cleared it.
  if (!_textView.delegate) {
    _textView.delegate = self;
  }

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
    _formatter.baseLineHeight = !isnan(_styleConfig.base.lineHeight) ? _styleConfig.base.lineHeight : 0;
    // Re-apply formatting with new styles if we already have content
    if (_textView.text.length > 0) {
      [self applyFullFormatting];
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

  // Mention triggers
  NSMutableSet<NSString *> *triggers = [NSMutableSet new];
  for (const auto &t : newProps.mentionTriggers) {
    [triggers addObject:[NSString stringWithUTF8String:t.c_str()]];
  }
  _mentionTriggers = [triggers copy];

  // Content inset (padding from style prop)
  _textView.textContainerInset = UIEdgeInsetsMake(
      newProps.contentInsetTop,
      newProps.contentInsetLeft,
      newProps.contentInsetBottom,
      newProps.contentInsetRight);
  _textView.textContainer.lineFragmentPadding = 0;

  _textView.autocorrectionType = newProps.autoCorrect
      ? UITextAutocorrectionTypeYes
      : UITextAutocorrectionTypeNo;
  _textView.spellCheckingType = newProps.autoCorrect
      ? UITextSpellCheckingTypeYes
      : UITextSpellCheckingTypeNo;

  // autoCapitalize
  NSString *cap = [NSString stringWithUTF8String:newProps.autoCapitalize.c_str()];
  if ([cap isEqualToString:@"characters"]) {
    _textView.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
  } else if ([cap isEqualToString:@"words"]) {
    _textView.autocapitalizationType = UITextAutocapitalizationTypeWords;
  } else if ([cap isEqualToString:@"none"]) {
    _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
  } else {
    _textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
  }

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

  [self applyFullFormatting];
  [self resetTypingAttributes];
}

- (NSString *)exportMarkdown {
  return [MarkdownSerializer serializePlainText:_textView.text
                                      withStore:_store];
}

// ---------------------------------------------------------------
#pragma mark - Formatting Application
// ---------------------------------------------------------------

/// Full re-style — used for import and style prop changes.
- (void)applyFullFormatting {
  if (_suppressFormatting) return;
  [_formatter applyAllFormatting:_store toTextStorage:_textView.textStorage];
  [self updateBlockBackgroundLayers];
}

- (void)updateBlockBackgroundLayers {
  for (CALayer *layer in _blockBackgroundLayers) {
    [layer removeFromSuperlayer];
  }
  [_blockBackgroundLayers removeAllObjects];

  if (!_styleConfig || _textView.textStorage.length == 0) return;

  [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];

  for (FormattingRange *range in _store.allRanges) {
    if (range.type != FormattingTypeCodeBlock &&
        range.type != FormattingTypeBlockquote) {
      continue;
    }
    if (range.range.length == 0 ||
        NSMaxRange(range.range) > _textView.textStorage.length) {
      continue;
    }

    MarkdownElementStyle *style = range.type == FormattingTypeCodeBlock
        ? _styleConfig.codeBlock
        : _styleConfig.blockquote;
    CALayer *layer = [self blockBackgroundLayerForRange:range.range
                                                  style:style];
    if (!layer) continue;

    [_textView.layer insertSublayer:layer atIndex:0];
    [_blockBackgroundLayers addObject:layer];
  }
}

- (CALayer *)blockBackgroundLayerForRange:(NSRange)range
                                    style:(MarkdownElementStyle *)style {
  NSLayoutManager *layoutManager = _textView.layoutManager;
  NSTextContainer *textContainer = _textView.textContainer;
  NSRange visualRange = [self visualBlockRangeForRange:range];
  if (visualRange.length == 0) return nil;

  NSRange glyphRange =
      [layoutManager glyphRangeForCharacterRange:visualRange
                            actualCharacterRange:nil];
  if (glyphRange.length == 0) return nil;

  UIFont *rangeFont =
      [_textView.textStorage attribute:NSFontAttributeName
                               atIndex:visualRange.location
                        effectiveRange:nil];
  if (![rangeFont isKindOfClass:[UIFont class]]) {
    rangeFont = _baseFont ?: [UIFont systemFontOfSize:UIFont.systemFontSize];
  }
  CGFloat ascender = rangeFont.ascender;
  CGFloat descender = rangeFont.descender;

  __block CGFloat minY = CGFLOAT_MAX;
  __block CGFloat maxY = -CGFLOAT_MAX;
  [layoutManager enumerateLineFragmentsForGlyphRange:glyphRange
                                          usingBlock:^(
      CGRect rect, CGRect usedRect, NSTextContainer *container,
      NSRange lineGlyphRange, BOOL *stop) {
    NSRange intersection = NSIntersectionRange(glyphRange, lineGlyphRange);
    if (intersection.length == 0) return;

    CGPoint glyphLocation =
        [layoutManager locationForGlyphAtIndex:intersection.location];
    CGFloat baseline = CGRectGetMinY(rect) + glyphLocation.y;
    minY = MIN(minY, baseline - ascender);
    maxY = MAX(maxY, baseline - descender);
  }];

  if (minY == CGFLOAT_MAX || maxY <= minY) return nil;

  UIEdgeInsets padding = style ? [style resolvedPaddingInsets] : UIEdgeInsetsZero;
  UIEdgeInsets margin = style ? [style resolvedMarginInsets] : UIEdgeInsetsZero;
  UIEdgeInsets borders = style ? [style resolvedBorderWidths] : UIEdgeInsetsZero;

  CGFloat x = _textView.textContainerInset.left + margin.left;
  CGFloat y = _textView.textContainerInset.top + minY - padding.top - margin.top;
  CGFloat width = textContainer.size.width - margin.left - margin.right;
  CGFloat height =
      (maxY - minY) + padding.top + padding.bottom + margin.top + margin.bottom;
  if (width <= 0 || height <= 0) return nil;

  UIColor *background = style.backgroundColor;
  BOOL hasBorder = borders.top > 0 || borders.right > 0 ||
                   borders.bottom > 0 || borders.left > 0;
  if (!background && !hasBorder && ![style hasAnyRadius]) return nil;

  CALayer *layer = [CALayer layer];
  layer.frame = CGRectMake(x, y, width, height);
  layer.backgroundColor = background.CGColor;
  layer.masksToBounds = YES;
  if (!isnan(style.borderRadius)) {
    layer.cornerRadius = style.borderRadius;
  }

  [self addBorderLayersToLayer:layer style:style borders:borders];
  return layer;
}

- (NSRange)visualBlockRangeForRange:(NSRange)range {
  NSUInteger textLength = _textView.text.length;
  NSUInteger start = MIN(range.location, textLength);
  NSUInteger end = MIN(NSMaxRange(range), textLength);
  if (start >= end) return NSMakeRange(start, 0);

  while (end > start &&
         end < textLength &&
         [_textView.text characterAtIndex:end - 1] == '\n' &&
         [_textView.text characterAtIndex:end] == '\n') {
    end--;
  }

  while (start < end &&
         start > 0 &&
         [_textView.text characterAtIndex:start - 1] == '\n' &&
         [_textView.text characterAtIndex:start] == '\n') {
    start++;
  }

  return NSMakeRange(start, end - start);
}

- (void)addBorderLayersToLayer:(CALayer *)layer
                         style:(MarkdownElementStyle *)style
                       borders:(UIEdgeInsets)borders {
  CGSize size = layer.bounds.size;
  [self addBorderToLayer:layer
                   frame:CGRectMake(0, 0, size.width, borders.top)
                   color:[style resolvedBorderColorForEdge:UIRectEdgeTop]];
  [self addBorderToLayer:layer
                   frame:CGRectMake(size.width - borders.right,
                                    0,
                                    borders.right,
                                    size.height)
                   color:[style resolvedBorderColorForEdge:UIRectEdgeRight]];
  [self addBorderToLayer:layer
                   frame:CGRectMake(0,
                                    size.height - borders.bottom,
                                    size.width,
                                    borders.bottom)
                   color:[style resolvedBorderColorForEdge:UIRectEdgeBottom]];
  [self addBorderToLayer:layer
                   frame:CGRectMake(0, 0, borders.left, size.height)
                   color:[style resolvedBorderColorForEdge:UIRectEdgeLeft]];
}

- (void)addBorderToLayer:(CALayer *)layer
                   frame:(CGRect)frame
                   color:(UIColor *)color {
  if (CGRectGetWidth(frame) <= 0 || CGRectGetHeight(frame) <= 0 || !color) {
    return;
  }
  CALayer *border = [CALayer layer];
  border.frame = frame;
  border.backgroundColor = color.CGColor;
  [layer addSublayer:border];
}



- (void)resetTypingAttributes {
  NSMutableDictionary *attrs = [@{
    NSFontAttributeName : _baseFont ?: [UIFont systemFontOfSize:16],
    NSForegroundColorAttributeName : _baseColor ?: [UIColor labelColor],
  } mutableCopy];

  CGFloat lineHeight = _styleConfig.base.lineHeight;
  NSMutableParagraphStyle *pStyle = [NSMutableParagraphStyle new];
  if (lineHeight > 0) {
    pStyle.minimumLineHeight = lineHeight;
    pStyle.maximumLineHeight = lineHeight;
  }

  [self applyActiveBlockTypingAttributes:attrs paragraphStyle:pStyle];

  attrs[NSParagraphStyleAttributeName] = pStyle;

  _textView.typingAttributes = attrs;
}

- (void)applyActiveBlockTypingAttributes:(NSMutableDictionary *)attrs
                          paragraphStyle:(NSMutableParagraphStyle *)pStyle {
  FormattingType blockType = [self activeTypingBlockType];
  if (blockType != FormattingTypeBlockquote &&
      blockType != FormattingTypeCodeBlock) {
    return;
  }

  MarkdownElementStyle *style = blockType == FormattingTypeCodeBlock
      ? _styleConfig.codeBlock
      : _styleConfig.blockquote;
  UIEdgeInsets padding = style ? [style resolvedPaddingInsets] : UIEdgeInsetsZero;
  UIEdgeInsets borders = style ? [style resolvedBorderWidths] : UIEdgeInsetsZero;
  CGFloat indent = borders.left + padding.left;

  pStyle.firstLineHeadIndent = indent;
  pStyle.headIndent = indent;
  CGFloat rightInset = borders.right + padding.right;
  if (rightInset > 0) {
    pStyle.tailIndent = -rightInset;
  }
  if (style.lineHeight > 0) {
    pStyle.minimumLineHeight = style.lineHeight;
    pStyle.maximumLineHeight = style.lineHeight;
  }

  UIFont *font = [style resolvedFontWithBase:_baseFont];
  if (font) {
    attrs[NSFontAttributeName] = font;
  }
  if (style.color) {
    attrs[NSForegroundColorAttributeName] = style.color;
  }
}

- (FormattingType)activeTypingBlockType {
  if ([_store.pendingStyles containsObject:@(FormattingTypeCodeBlock)]) {
    return FormattingTypeCodeBlock;
  }
  if ([_store.pendingStyles containsObject:@(FormattingTypeBlockquote)]) {
    return FormattingTypeBlockquote;
  }
  if ([self selectionIsOnEmptyLine]) {
    return FormattingTypeBold;
  }

  NSUInteger idx = _textView.selectedRange.location > 0
      ? _textView.selectedRange.location - 1
      : 0;
  if ([_store isEffectivelyActive:FormattingTypeCodeBlock atIndex:idx]) {
    return FormattingTypeCodeBlock;
  }
  if ([_store isEffectivelyActive:FormattingTypeBlockquote atIndex:idx]) {
    return FormattingTypeBlockquote;
  }
  return FormattingTypeBold;
}

- (BOOL)selectionIsOnEmptyLine {
  if (_textView.text.length == 0) return YES;

  NSUInteger location =
      MIN(_textView.selectedRange.location, _textView.text.length);
  NSRange lineRange =
      [_textView.text lineRangeForRange:NSMakeRange(location, 0)];
  if (lineRange.length == 0) return YES;

  NSString *line = [_textView.text substringWithRange:lineRange];
  NSString *trimmed = [line stringByTrimmingCharactersInSet:
      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return trimmed.length == 0;
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

    [self applyFullFormatting];
    [self emitMarkdownChange];
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
  NSRange lineRange = [self selectedLineRange];
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

  [self applyFullFormatting];
  [self detectAndEmitState];
  [self emitMarkdownChange];
}

- (void)toggleBlockType:(FormattingType)type {
  NSRange lineRange = [self selectedLineRange];
  if (lineRange.length == 0) {
    NSNumber *key = @(type);
    if ([_store.pendingStyles containsObject:key]) {
      [_store.pendingStyles removeObject:key];
      [_store.pendingRemovals addObject:key];
    } else {
      [_store.pendingRemovals removeObject:key];
      [_store.pendingStyles addObject:key];
    }
    [self detectAndEmitState];
    return;
  }

  NSArray *existing = [_store rangesOfType:type intersecting:lineRange];
  BOOL fullyCovered = [self isRange:lineRange fullyCoveredBy:existing];

  if (fullyCovered) {
    [_store removeRangesOfType:type intersecting:lineRange];
  } else {
    if (type == FormattingTypeBlockquote) {
      [_store removeRangesOfType:FormattingTypeCodeBlock
                    intersecting:lineRange];
    } else if (type == FormattingTypeCodeBlock) {
      [_store removeRangesOfType:FormattingTypeBlockquote
                    intersecting:lineRange];
    }
    [_store removeRangesOfType:type intersecting:lineRange];
    [_store addRange:[FormattingRange rangeWithType:type range:lineRange]];
  }

  [self applyFullFormatting];
  [self detectAndEmitState];
  [self emitMarkdownChange];
}

- (void)toggleCodeBlock {
  NSRange lineRange = [self selectedLineRange];
  if (lineRange.length == 0) {
    NSNumber *key = @(FormattingTypeCodeBlock);
    if ([_store.pendingStyles containsObject:key]) {
      [_store.pendingStyles removeObject:key];
      [_store.pendingRemovals addObject:key];
    } else {
      [_store.pendingRemovals removeObject:key];
      [_store.pendingStyles addObject:key];
    }
    [self detectAndEmitState];
    return;
  }

  NSArray *existing = [_store rangesOfType:FormattingTypeCodeBlock
                              intersecting:lineRange];
  BOOL fullyCovered = [self isRange:lineRange fullyCoveredBy:existing];
  if (fullyCovered) {
    [_store removeRangesOfType:FormattingTypeCodeBlock intersecting:lineRange];
  } else {
    [_store removeRangesOfType:FormattingTypeBlockquote intersecting:lineRange];
    [_store removeRangesOfType:FormattingTypeCodeBlock intersecting:lineRange];
    FormattingRange *range =
        [FormattingRange rangeWithType:FormattingTypeCodeBlock
                                 range:lineRange];
    [_store addRange:range];
  }

  [self applyFullFormatting];
  [self detectAndEmitState];
  [self emitMarkdownChange];
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
    FormattingRange *range = [FormattingRange rangeWithType:listType
                                                      range:lineRange];
    if (listType == FormattingTypeOrderedList) {
      range.listStart = [self orderedNumberInLine:
          [_textView.text substringWithRange:lineRange]];
    }
    [_store addRange:range];
    _textView.selectedRange =
        NSMakeRange(lineRange.location + bullet.length, 0);
  }

  [self applyFullFormatting];
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

- (NSInteger)orderedNumberInLine:(NSString *)line {
  static NSRegularExpression *regex;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    regex = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+)\\."
                                                      options:0
                                                        error:nil];
  });
  NSTextCheckingResult *match =
      [regex firstMatchInString:line
                        options:0
                          range:NSMakeRange(0, MIN(line.length, 10))];
  if (!match) return 1;
  return [[line substringWithRange:[match rangeAtIndex:1]] integerValue];
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

- (NSRange)selectedLineRange {
  NSRange selection = _textView.selectedRange;
  if (_textView.text.length == 0) return NSMakeRange(0, 0);

  NSUInteger start = MIN(selection.location, _textView.text.length);
  NSUInteger end = MIN(selection.location + selection.length,
                       _textView.text.length);
  if (selection.length > 0 && end > start) {
    end--;
  }

  NSRange startLine = [_textView.text lineRangeForRange:NSMakeRange(start, 0)];
  NSRange endLine = [_textView.text lineRangeForRange:NSMakeRange(end, 0)];
  NSUInteger location = startLine.location;
  NSUInteger max = NSMaxRange(endLine);
  if (max > location && max <= _textView.text.length &&
      [_textView.text characterAtIndex:max - 1] == '\n') {
    max--;
  }
  if (max < location) return NSMakeRange(location, 0);
  return NSMakeRange(location, max - location);
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

  // --- Headings: "# " through "###### " at start of line ---
  {
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"^(#{1,6})\\s"
                             options:0
                               error:nil];
    NSTextCheckingResult *match =
        [regex firstMatchInString:line
                          options:0
                            range:NSMakeRange(0, MIN(line.length, 8))];
    if (match && localCursor >= match.range.length) {
      NSInteger level = [match rangeAtIndex:1].length;
      FormattingType hType = [FormattingRange headingTypeForLevel:level];
      NSArray *existing = [_store rangesOfType:hType intersecting:lineRange];
      if (existing.count == 0) {
        NSString *prefix = [line substringWithRange:match.range];
        [self autoConvertBlockPrefix:prefix
                           lineStart:lineStart
                            lineText:line
                                type:hType];
        return;
      }
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

  // --- Blockquote: "> " at start of line ---
  if (localCursor >= 2 && [line hasPrefix:@"> "]) {
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

  // --- Inline code: matching backticks ---
  [self detectInlineCode];

  // --- Autolink: detect URLs ---
  [self detectAutolinks];
}

- (void)autoConvertBlockPrefix:(NSString *)prefix
                     lineStart:(NSUInteger)lineStart
                      lineText:(NSString *)line
                          type:(FormattingType)type {
  NSUInteger cursorPos = _textView.selectedRange.location;
  NSString *contentAfterPrefix = [line substringFromIndex:prefix.length];
  NSUInteger contentOffset = cursorPos - lineStart - prefix.length;

  // Delete the prefix
  _suppressFormatting = YES;
  [_textView.textStorage deleteCharactersInRange:
      NSMakeRange(lineStart, prefix.length)];
  [_store adjustForEditAt:lineStart
            deletedLength:prefix.length
           insertedLength:0];
  _suppressFormatting = NO;

  // For lists, insert a visual bullet to replace the prefix
  NSUInteger bulletLen = 0;
  if (type == FormattingTypeUnorderedList ||
      type == FormattingTypeOrderedList) {
    NSString *bullet =
        (type == FormattingTypeOrderedList) ? @"1. " : @"\u2022 ";
    bulletLen = bullet.length;
    _suppressFormatting = YES;
    [_textView.textStorage replaceCharactersInRange:
        NSMakeRange(lineStart, 0) withString:bullet];
    [_store adjustForEditAt:lineStart
              deletedLength:0
             insertedLength:bulletLen];
    _suppressFormatting = NO;
  }

  // Create the formatting range if the line has content.
  // If the line is empty after prefix removal (e.g. user typed
  // just "> "), use pending styles so the next character typed
  // picks up the formatting.
  NSRange newLineRange = [self lineRangeAt:lineStart];
  if (newLineRange.length > 0) {
    FormattingRange *range = [FormattingRange rangeWithType:type
                                                      range:newLineRange];
    if (type == FormattingTypeOrderedList) {
      range.listStart = [self orderedNumberInLine:prefix];
    }
    [_store addRange:range];
  } else if (contentAfterPrefix.length == 0) {
    // Empty line — defer formatting to pending styles
    [_store.pendingStyles addObject:@(type)];
  }

  [self applyFullFormatting];

  // Restore cursor
  NSUInteger newCursor = lineStart + bulletLen + contentOffset;
  if (newCursor > _textView.text.length) {
    newCursor = _textView.text.length;
  }
  _textView.selectedRange = NSMakeRange(newCursor, 0);

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

        [self applyFullFormatting];
        [self emitMarkdownChange];
        return;
      }
      break;
    }

    if (searchPos == 0) break;
    searchPos--;
  }
}

#pragma mark - Block Continuation on Enter

/// Called from shouldChangeTextInRange: when the replacement is a
/// newline. Returns YES if the newline was handled (caller should
/// return NO to prevent the default insertion).
- (BOOL)handleNewlineInBlock:(NSRange)range {
  NSString *text = _textView.text;
  if (text.length == 0) return NO;

  NSRange lineRange = [text lineRangeForRange:range];
  if (lineRange.length > 0 &&
      [text characterAtIndex:NSMaxRange(lineRange) - 1] == '\n') {
    lineRange.length--;
  }
  NSString *line = [text substringWithRange:lineRange];

  FormattingRange *blockRange =
      [self blockRangeForLine:lineRange type:FormattingTypeCodeBlock];
  FormattingType blockType = FormattingTypeCodeBlock;
  if (!blockRange) {
    blockRange = [self blockRangeForLine:lineRange
                                    type:FormattingTypeBlockquote];
    blockType = FormattingTypeBlockquote;
  }
  if (!blockRange) return NO;

  NSString *trimmed = [line stringByTrimmingCharactersInSet:
      [NSCharacterSet whitespaceCharacterSet]];
  if (trimmed.length == 0) {
    [_store.pendingStyles removeObject:@(blockType)];
    [_store.pendingRemovals removeObject:@(blockType)];

    NSUInteger removeLocation = lineRange.location > 0
        ? lineRange.location - 1
        : lineRange.location;
    NSUInteger removeLength = lineRange.location > 0 ? 1 : lineRange.length;
    if (removeLength > 0) {
      [_store removeRangesOfType:blockType
                    intersecting:NSMakeRange(removeLocation, removeLength)];
    }

    _suppressFormatting = YES;
    [_textView.textStorage replaceCharactersInRange:range withString:@"\n"];
    [_store adjustForEditAt:range.location
              deletedLength:range.length
             insertedLength:1];
    _suppressFormatting = NO;

    _textView.selectedRange = NSMakeRange(range.location + 1, 0);
    [self applyFullFormatting];
    [self resetTypingAttributes];
    [self detectAndEmitState];
    [self emitMarkdownChange];
    return YES;
  }

  _suppressFormatting = YES;
  [_textView.textStorage replaceCharactersInRange:range withString:@"\n"];
  [_store adjustForEditAt:range.location
            deletedLength:range.length
           insertedLength:1];
  _suppressFormatting = NO;

  FormattingRange *continued =
      [FormattingRange rangeWithType:blockType
                                range:NSMakeRange(lineRange.location,
                                                   lineRange.length + 1)];
  [_store addRange:continued];
  [_store.pendingStyles addObject:@(blockType)];

  _textView.selectedRange = NSMakeRange(range.location + 1, 0);
  [self applyFullFormatting];
  [self resetTypingAttributes];
  [self detectAndEmitState];
  [self emitMarkdownChange];
  return YES;
}

- (FormattingRange *)blockRangeForLine:(NSRange)lineRange
                                  type:(FormattingType)type {
  NSArray *ranges = [_store rangesOfType:type intersecting:lineRange];
  if (ranges.count > 0) return ranges.firstObject;

  if (lineRange.length == 0) {
    NSUInteger point = lineRange.location;
    for (FormattingRange *r in _store.allRanges) {
      if (r.type == type &&
          point >= r.range.location &&
          point <= NSMaxRange(r.range)) {
        return r;
      }
    }
  }

  return nil;
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

    [self applyFullFormatting];
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
    FormattingRange *newRange =
        [FormattingRange rangeWithType:listType range:newLineRange];
    if (listType == FormattingTypeOrderedList) {
      newRange.listStart = [self orderedNumberInLine:bullet];
    }
    [_store addRange:newRange];
  }

  [self applyFullFormatting];
  [self resetTypingAttributes];
  [self emitMarkdownChange];
  return YES;
}

#pragma mark - Autolink Detection

- (void)detectAutolinks {
  NSString *text = _textView.text;
  if (text.length == 0) return;

  // Only run when the user just typed a word boundary (space,
  // newline, or is at end of text after a non-whitespace char).
  // This prevents partial URL detection while still typing.
  NSRange cursor = _textView.selectedRange;
  if (cursor.location > 0 && cursor.location <= text.length) {
    unichar prev = [text characterAtIndex:cursor.location - 1];
    if (prev != ' ' && prev != '\n' && cursor.location != text.length) {
      return;
    }
  }

  NSDataDetector *detector =
      [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink
                                      error:nil];
  if (!detector) return;

  NSArray<NSTextCheckingResult *> *matches =
      [detector matchesInString:text
                        options:0
                          range:NSMakeRange(0, text.length)];

  // Build a set of detected URL ranges
  NSMutableArray<FormattingRange *> *detected = [NSMutableArray new];
  for (NSTextCheckingResult *match in matches) {
    NSURL *url = match.URL;
    if (!url) continue;
    FormattingRange *range = [FormattingRange rangeWithType:FormattingTypeLink
                                                      range:match.range
                                                        url:url.absoluteString];
    range.autolink = YES;
    [detected addObject:range];
  }

  // Remove any autodetected links that no longer match (the URL
  // was edited or deleted). We identify autodetected links as
  // those whose display text equals the URL.
  NSArray *existingLinks =
      [_store rangesOfType:FormattingTypeLink
              intersecting:NSMakeRange(0, text.length)];

  BOOL changed = NO;
  for (FormattingRange *existing in existingLinks) {
    if (existing.range.location + existing.range.length > text.length) continue;
    NSString *displayText = [text substringWithRange:existing.range];

    // If the display text IS the URL (or starts with http), it's
    // an autodetected link — check if it still matches a detection
    BOOL isAutolink = [displayText hasPrefix:@"http://"] ||
                      [displayText hasPrefix:@"https://"] ||
                      [displayText isEqualToString:existing.url];
    if (!isAutolink) continue;

    // See if this autolink is still valid
    BOOL stillValid = NO;
    for (FormattingRange *d in detected) {
      if (NSEqualRanges(d.range, existing.range)) {
        stillValid = YES;
        break;
      }
    }

    if (!stillValid) {
      [_store removeRangesOfType:FormattingTypeLink
                    intersecting:existing.range];
      changed = YES;
    }
  }

  // Add newly detected links
  for (FormattingRange *d in detected) {
    NSArray *overlap =
        [_store rangesOfType:FormattingTypeLink intersecting:d.range];
    if (overlap.count == 0) {
      [_store addRange:d];
      [self emitLinkDetected:d.url];
      changed = YES;
    }
  }

  // Don't call applyFullFormatting here — the dirty range
  // formatting in textViewDidChange handles re-styling. Calling
  // full formatting would wipe block attributes.
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

  [self applyFullFormatting];
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
      [self applyFullFormatting];
      [self emitMarkdownChange];
      return;
    }
  }
}

- (void)insertSpoiler {
  NSRange range = _textView.selectedRange;
  NSString *text = range.length > 0
      ? [_textView.text substringWithRange:range]
      : @"spoiler";

  _suppressFormatting = YES;
  [_textView.textStorage replaceCharactersInRange:range withString:text];
  [_store adjustForEditAt:range.location
            deletedLength:range.length
           insertedLength:text.length];
  _suppressFormatting = NO;

  NSRange spoilerRange = NSMakeRange(range.location, text.length);
  [_store addRange:[FormattingRange rangeWithType:FormattingTypeSpoiler
                                            range:spoilerRange]];
  _textView.selectedRange = range.length > 0
      ? NSMakeRange(NSMaxRange(spoilerRange), 0)
      : spoilerRange;

  [self applyFullFormatting];
  [self detectAndEmitState];
  [self emitMarkdownChange];
}

- (void)insertCustomTag:(NSString *)tag propsJSON:(NSString *)propsJSON {
  if (tag.length == 0) return;

  NSData *data = [propsJSON dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *props =
      [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] ?: @{};

  NSMutableString *source = [NSMutableString stringWithFormat:@"<%@", tag];
  NSArray *keys = [[props allKeys] sortedArrayUsingSelector:@selector(compare:)];
  for (NSString *key in keys) {
    NSString *value = props[key] ?: @"";
    [source appendFormat:@" %@=\"%@\"",
                         key,
                         [self escapedAttributeValue:value]];
  }
  [source appendString:@" />"];

  NSRange range = _textView.selectedRange;
  _suppressFormatting = YES;
  [_textView.textStorage replaceCharactersInRange:range withString:source];
  [_store adjustForEditAt:range.location
            deletedLength:range.length
           insertedLength:source.length];
  _suppressFormatting = NO;

  _textView.selectedRange = NSMakeRange(range.location + source.length, 0);
  [self applyFullFormatting];
  [self emitMarkdownChange];
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

// ---------------------------------------------------------------
#pragma mark - Mentions
// ---------------------------------------------------------------

/// Called from textViewDidChange to detect mention triggers.
- (void)detectMentionTriggers {
  if (_mentionTriggers.count == 0) return;

  NSString *text = _textView.text;
  NSRange cursor = _textView.selectedRange;
  if (cursor.location == 0 || text.length == 0) {
    if (_activeMentionTrigger) [self endMention];
    return;
  }

  // If we're in an active mention, update the query
  if (_activeMentionTrigger) {
    // Check the mention is still valid (cursor after trigger,
    // no spaces/newlines in query)
    if (cursor.location < _mentionStartPos) {
      [self endMention];
      return;
    }

    NSRange queryRange = NSMakeRange(_mentionStartPos,
                                      cursor.location - _mentionStartPos);
    if (NSMaxRange(queryRange) > text.length) {
      [self endMention];
      return;
    }

    NSString *query = [text substringWithRange:queryRange];

    // End mention if query contains newline
    if ([query rangeOfString:@"\n"].location != NSNotFound) {
      [self endMention];
      return;
    }

    [self emitMentionChange:_activeMentionTrigger query:query];
    return;
  }

  // Check if the character just typed is a trigger
  unichar lastChar = [text characterAtIndex:cursor.location - 1];
  NSString *charStr = [NSString stringWithCharacters:&lastChar length:1];

  if (![_mentionTriggers containsObject:charStr]) return;

  // Only trigger at the start of a word (beginning of text,
  // or preceded by whitespace)
  if (cursor.location >= 2) {
    unichar prev = [text characterAtIndex:cursor.location - 2];
    if (prev != ' ' && prev != '\n' && prev != '\t') return;
  }

  // Start a new mention
  _activeMentionTrigger = charStr;
  _mentionStartPos = cursor.location; // position after the trigger char

  [self emitMentionStart:charStr];
}

- (void)endMention {
  if (!_activeMentionTrigger) return;

  NSString *trigger = _activeMentionTrigger;
  _activeMentionTrigger = nil;
  _mentionStartPos = 0;

  [self emitMentionEnd:trigger];
}

/// Replaces the trigger char + query with a formatted mention.
- (void)insertMentionWithTrigger:(NSString *)trigger
                           label:(NSString *)label
                       propsJSON:(NSString *)propsJSON {
  NSString *tagName;
  if ([trigger isEqualToString:@"@"]) {
    tagName = @"UserMention";
  } else if ([trigger isEqualToString:@"#"]) {
    tagName = @"ChannelMention";
  } else if ([trigger isEqualToString:@"/"]) {
    tagName = @"Command";
  } else {
    tagName = @"UserMention";
  }

  NSData *data = [propsJSON dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *props =
      [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] ?: @{};
  NSMutableDictionary *allProps = [props mutableCopy];
  if (!allProps[@"name"]) {
    allProps[@"name"] = label;
  }
  NSString *displayText = [NSString stringWithFormat:@"%@%@", trigger, label];

  if (!_activeMentionTrigger ||
      ![_activeMentionTrigger isEqualToString:trigger]) {
    _suppressFormatting = YES;
    NSRange range = _textView.selectedRange;
    [_textView.textStorage replaceCharactersInRange:_textView.selectedRange
                                         withString:displayText];
    [_store adjustForEditAt:range.location
              deletedLength:range.length
             insertedLength:displayText.length];
    _suppressFormatting = NO;
    [_store addRange:[FormattingRange mentionRangeWithTagName:tagName
                                                     tagProps:allProps
                                                        range:NSMakeRange(range.location, displayText.length)]];
    [self applyFullFormatting];
    [self emitMarkdownChange];
    return;
  }

  // Calculate the range to replace (trigger char + query)
  NSUInteger triggerPos = _mentionStartPos - 1; // the trigger char
  NSUInteger cursorPos = _textView.selectedRange.location;
  NSRange replaceRange = NSMakeRange(triggerPos, cursorPos - triggerPos);

  // Replace the trigger + query with the display text
  _suppressFormatting = YES;
  [_textView.textStorage replaceCharactersInRange:replaceRange
                                       withString:displayText];
  [_store adjustForEditAt:replaceRange.location
            deletedLength:replaceRange.length
           insertedLength:displayText.length];
  _suppressFormatting = NO;

  NSRange mentionRange = NSMakeRange(replaceRange.location, displayText.length);

  [_store addRange:[FormattingRange mentionRangeWithTagName:tagName
                                                   tagProps:allProps
                                                      range:mentionRange]];

  // End the mention
  _activeMentionTrigger = nil;
  _mentionStartPos = 0;

  _textView.selectedRange = NSMakeRange(NSMaxRange(mentionRange), 0);
  [self applyFullFormatting];
  [self emitMarkdownChange];
}

#pragma mark - Mention Events

- (void)emitMentionStart:(NSString *)trigger {
  if (!_eventEmitter) return;
  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);
  emitter.onMentionStart(
      {.trigger = std::string([trigger UTF8String])});
}

- (void)emitMentionChange:(NSString *)trigger query:(NSString *)query {
  if (!_eventEmitter) return;
  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);
  emitter.onMentionChange({
      .trigger = std::string([trigger UTF8String]),
      .query = std::string([query UTF8String]),
  });
}

- (void)emitMentionEnd:(NSString *)trigger {
  if (!_eventEmitter) return;
  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);
  emitter.onMentionEnd(
      {.trigger = std::string([trigger UTF8String])});
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
  } else if ([commandName isEqualToString:@"toggleSuperscript"]) {
    [self toggleInlineType:FormattingTypeSuperscript];
  } else if ([commandName isEqualToString:@"toggleHeading"]) {
    [self toggleHeading:[args[0] integerValue]];
  } else if ([commandName isEqualToString:@"toggleBlockquote"]) {
    [self toggleBlockType:FormattingTypeBlockquote];
  } else if ([commandName isEqualToString:@"toggleCodeBlock"]) {
    [self toggleCodeBlock];
  } else if ([commandName isEqualToString:@"toggleOrderedList"]) {
    [self toggleList:FormattingTypeOrderedList];
  } else if ([commandName isEqualToString:@"toggleUnorderedList"]) {
    [self toggleList:FormattingTypeUnorderedList];
  } else if ([commandName isEqualToString:@"insertLink"]) {
    NSString *url = args[0];
    NSString *text = args.count > 1 ? args[1] : @"";
    [self insertLinkWithURL:url text:text];
  } else if ([commandName isEqualToString:@"removeLink"]) {
    [self removeLink];
  } else if ([commandName isEqualToString:@"insertMention"]) {
    NSString *trigger = args[0];
    NSString *label = args[1];
    NSString *propsJSON = args.count > 2 ? args[2] : @"{}";
    [self insertMentionWithTrigger:trigger label:label propsJSON:propsJSON];
  } else if ([commandName isEqualToString:@"toggleSpoiler"]) {
    [self toggleInlineType:FormattingTypeSpoiler];
  } else if ([commandName isEqualToString:@"insertSpoiler"]) {
    [self insertSpoiler];
  } else if ([commandName isEqualToString:@"insertCustomTag"]) {
    NSString *tag = args.count > 0 ? args[0] : @"";
    NSString *propsJSON = args.count > 1 ? args[1] : @"{}";
    [self insertCustomTag:tag propsJSON:propsJSON];
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
  BOOL spoiler = [_store isEffectivelyActive:FormattingTypeSpoiler atIndex:idx];
  BOOL superscript =
      [_store isEffectivelyActive:FormattingTypeSuperscript atIndex:idx];
  BOOL blockquote =
      [_store isEffectivelyActive:FormattingTypeBlockquote atIndex:idx];
  BOOL codeBlock =
      [_store isEffectivelyActive:FormattingTypeCodeBlock atIndex:idx];

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
      .spoiler = spoiler,
      .superscript = superscript,
      .blockquote = blockquote,
      .codeBlock = codeBlock,
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

- (void)emitLinkDetected:(NSString *)url {
  if (!_eventEmitter || url.length == 0) return;
  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);
  emitter.onLinkDetected({.url = std::string([url UTF8String])});
}

// ---------------------------------------------------------------
#pragma mark - UITextViewDelegate
// ---------------------------------------------------------------

- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text {
  if (_suppressFormatting) return YES;

  // Handle enter key inside lists
  if ([text isEqualToString:@"\n"]) {
    if ([self handleNewlineInList:range]) {
      return NO;
    }
    if ([self handleNewlineInBlock:range]) {
      return NO;
    }
  }

  NSUInteger deleted = range.length;
  NSUInteger inserted = text.length;

  [_store adjustForEditAt:range.location
            deletedLength:deleted
           insertedLength:inserted];

  // Apply pending styles to the inserted text
  if (inserted > 0) {
    NSRange insertedRange = NSMakeRange(range.location, inserted);

    for (NSNumber *typeNum in _store.pendingStyles) {
      FormattingType type = (FormattingType)typeNum.integerValue;
      FormattingRange *range = [FormattingRange rangeWithType:type
                                                        range:insertedRange];
      [_store addRange:range];
    }

    // Handle pending removals: carve out the inserted range from
    // any existing formatting of the removed type
    for (NSNumber *typeNum in _store.pendingRemovals) {
      FormattingType type = (FormattingType)typeNum.integerValue;
      [_store removeRangesOfType:type intersecting:insertedRange];
    }
  }

  [_store clearPending];

  return YES;
}

// ---------------------------------------------------------------
#pragma mark - UITextViewDelegate
// ---------------------------------------------------------------

- (void)textViewDidChange:(UITextView *)textView {
  if (_suppressFormatting) return;

  [self detectAutoFormatting];
  [self detectMentionTriggers];
  [self applyFullFormatting];
  [self resetTypingAttributes];
  [self emitMarkdownChange];
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  if (_suppressFormatting) return;

  // Clear pending styles on cursor move (they're ephemeral)
  [_store clearPending];

  // End active mention if cursor moved away from the mention area
  if (_activeMentionTrigger) {
    NSUInteger cursorPos = textView.selectedRange.location;
    if (cursorPos < _mentionStartPos - 1 ||
        textView.selectedRange.length > 0) {
      [self endMention];
    }
  }

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

#pragma mark - Fabric Recycling

- (void)prepareForRecycle {
  [super prepareForRecycle];

  // Clear delegate to break the strong reference from textView → self.
  _textView.delegate = nil;

  // Reset editor content and formatting state
  _suppressFormatting = YES;
  _textView.text = @"";
  _suppressFormatting = NO;
  [_store removeAll];
  [self updateBlockBackgroundLayers];

  // Reset mention tracking — stale triggers from a previous use
  // would fire spurious onMentionChange events.
  _activeMentionTrigger = nil;
  _mentionStartPos = 0;
  _mentionTriggers = nil;
}

@end

Class<RCTComponentViewProtocol> MarkdownEditorViewCls(void) {
  return MarkdownEditorView.class;
}
