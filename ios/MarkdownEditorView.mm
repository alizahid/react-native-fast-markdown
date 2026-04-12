#import "MarkdownEditorView.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <react/renderer/components/MarkdownViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/MarkdownViewSpec/EventEmitters.h>
#import <react/renderer/components/MarkdownViewSpec/Props.h>

#import "ASTNodeWrapper.h"
#import "MarkdownParser.hpp"
#import "StyleConfig.h"

using namespace facebook::react;

// Semantic attribute keys — these ride along on the attributed
// string so we can export back to markdown and detect state.
static NSString *const kBold = @"md.bold";
static NSString *const kItalic = @"md.italic";
static NSString *const kStrike = @"md.strike";
static NSString *const kCode = @"md.code";
static NSString *const kLink = @"md.link";
static NSString *const kHeading = @"md.heading";
static NSString *const kBlockquote = @"md.blockquote";
static NSString *const kCodeBlock = @"md.codeBlock";
static NSString *const kOrderedList = @"md.orderedList";
static NSString *const kUnorderedList = @"md.unorderedList";

@interface MarkdownEditorView () <UITextViewDelegate>
@end

@implementation MarkdownEditorView {
  UITextView *_textView;
  StyleConfig *_styleConfig;
  NSString *_currentStyleJSON;

  // Cached base font — resolved once per style update
  UIFont *_baseFont;
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

  // Style — must be parsed before default value so fonts are ready
  NSString *styleJSON = newProps.styles.empty()
                            ? @""
                            : [NSString stringWithUTF8String:newProps.styles.c_str()];
  if (![styleJSON isEqualToString:_currentStyleJSON ?: @""]) {
    _currentStyleJSON = styleJSON;
    _styleConfig = [StyleConfig fromJSON:styleJSON];
    _baseFont = [_styleConfig.base resolvedFont]
                    ?: [UIFont systemFontOfSize:16];
  }

  // Default value (first render only)
  if (!oldProps) {
    NSString *defaultValue =
        [NSString stringWithUTF8String:newProps.defaultValue.c_str()];
    if (defaultValue.length > 0) {
      NSAttributedString *as = [self importMarkdown:defaultValue];
      _textView.attributedText = as;
    } else {
      [self syncTypingAttributes];
    }
  }

  // Editable
  _textView.editable = newProps.editable;

  // Auto focus
  if (!oldProps && newProps.autoFocus) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self->_textView becomeFirstResponder];
    });
  }

  [super updateProps:props oldProps:oldProps];
}

// ---------------------------------------------------------------
#pragma mark - Import (Markdown → Attributed String)
// ---------------------------------------------------------------

- (NSAttributedString *)importMarkdown:(NSString *)markdown {
  if (markdown.length == 0) return [[NSAttributedString alloc] init];

  markdown::ParseOptions options;
  options.enableTables = false;
  options.enableStrikethrough = true;
  options.enableTaskLists = false;
  options.enableAutolinks = true;
  options.customTags.insert("Spoiler");
  options.customTags.insert("Superscript");

  std::string mdStr([markdown UTF8String]);
  markdown::ASTNode ast = markdown::MarkdownParser::parse(mdStr, options);
  ASTNodeWrapper *root = [[ASTNodeWrapper alloc] initWithOpaqueNode:&ast];

  NSMutableAttributedString *result = [NSMutableAttributedString new];
  [self walkNode:root into:result attrs:[self baseAttrs] blockIndex:0];

  // Trim trailing newline
  while (result.length > 0 &&
         [[result.string substringFromIndex:result.length - 1]
             isEqualToString:@"\n"]) {
    [result deleteCharactersInRange:NSMakeRange(result.length - 1, 1)];
  }

  return result;
}

- (NSDictionary *)baseAttrs {
  UIColor *color = _styleConfig.base.color ?: [UIColor labelColor];
  return @{
    NSFontAttributeName : _baseFont,
    NSForegroundColorAttributeName : color,
  };
}

/// Recursive AST walker that builds a single flat attributed string.
- (void)walkNode:(ASTNodeWrapper *)node
            into:(NSMutableAttributedString *)output
           attrs:(NSDictionary *)attrs
      blockIndex:(NSInteger)blockIndex {

  switch (node.nodeType) {

  // ---- Container / structural ----

  case MDNodeTypeDocument: {
    NSInteger idx = 0;
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:attrs blockIndex:idx];
      idx++;
    }
    break;
  }

  case MDNodeTypeParagraph: {
    if (output.length > 0 &&
        ![[output.string substringFromIndex:output.length - 1]
            isEqualToString:@"\n"]) {
      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n" attributes:attrs]];
    }
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:attrs blockIndex:0];
    }
    break;
  }

  // ---- Block elements ----

  case MDNodeTypeHeading: {
    if (output.length > 0) {
      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n" attributes:[self baseAttrs]]];
    }

    NSMutableDictionary *headingAttrs = [attrs mutableCopy];
    headingAttrs[kHeading] = @(node.headingLevel);

    MarkdownElementStyle *style =
        [_styleConfig styleForHeadingLevel:node.headingLevel];
    UIFont *headingFont = [style resolvedFontWithBase:_baseFont];
    if (!headingFont) {
      CGFloat scales[] = {0, 2.0, 1.5, 1.25, 1.1, 1.0, 0.9};
      CGFloat s = node.headingLevel <= 6 ? scales[node.headingLevel] : 1.0;
      headingFont = [UIFont systemFontOfSize:_baseFont.pointSize * s
                                      weight:UIFontWeightBold];
    }
    headingAttrs[NSFontAttributeName] = headingFont;
    if (style.color) {
      headingAttrs[NSForegroundColorAttributeName] = style.color;
    }

    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:headingAttrs blockIndex:0];
    }
    break;
  }

  case MDNodeTypeBlockquote: {
    if (output.length > 0) {
      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n" attributes:[self baseAttrs]]];
    }

    NSMutableDictionary *bqAttrs = [attrs mutableCopy];
    bqAttrs[kBlockquote] = @YES;

    MarkdownElementStyle *style = _styleConfig.blockquote;
    UIFont *bqFont = [style resolvedFontWithBase:_baseFont];
    if (bqFont) bqAttrs[NSFontAttributeName] = bqFont;
    if (style.color) {
      bqAttrs[NSForegroundColorAttributeName] = style.color;
    }

    // Indent via paragraph style
    NSMutableParagraphStyle *pStyle = [NSMutableParagraphStyle new];
    pStyle.firstLineHeadIndent = 16;
    pStyle.headIndent = 16;
    bqAttrs[NSParagraphStyleAttributeName] = pStyle;

    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:bqAttrs blockIndex:0];
    }
    break;
  }

  case MDNodeTypeList: {
    if (output.length > 0 &&
        ![[output.string substringFromIndex:output.length - 1]
            isEqualToString:@"\n"]) {
      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n" attributes:[self baseAttrs]]];
    }

    NSInteger idx = 0;
    for (ASTNodeWrapper *child in node.children) {
      NSMutableDictionary *itemAttrs = [attrs mutableCopy];

      if (node.isOrderedList) {
        itemAttrs[kOrderedList] = @YES;
      } else {
        itemAttrs[kUnorderedList] = @YES;
      }

      // Prepend bullet / number
      NSString *bullet;
      if (node.isOrderedList) {
        bullet = [NSString stringWithFormat:@"%ld. ",
                                            (long)(node.listStart + idx)];
      } else {
        bullet = @"•  ";
      }

      MarkdownElementStyle *bulletStyle = _styleConfig.listBullet;
      NSMutableDictionary *bulletAttrs = [itemAttrs mutableCopy];
      if (bulletStyle.color) {
        bulletAttrs[NSForegroundColorAttributeName] = bulletStyle.color;
      }

      if (idx > 0) {
        [output appendAttributedString:
            [[NSAttributedString alloc] initWithString:@"\n"
                                            attributes:[self baseAttrs]]];
      }

      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:bullet
                                          attributes:bulletAttrs]];

      for (ASTNodeWrapper *grandchild in child.children) {
        [self walkNode:grandchild into:output attrs:itemAttrs blockIndex:0];
      }

      idx++;
    }
    break;
  }

  case MDNodeTypeCodeBlock: {
    if (output.length > 0) {
      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n" attributes:[self baseAttrs]]];
    }

    NSMutableDictionary *cbAttrs = [attrs mutableCopy];
    cbAttrs[kCodeBlock] = @YES;

    MarkdownElementStyle *style = _styleConfig.codeBlock;
    UIFont *codeFont = [style resolvedFontWithBase:_baseFont]
                           ?: [UIFont monospacedSystemFontOfSize:_baseFont.pointSize
                                                          weight:UIFontWeightRegular];
    cbAttrs[NSFontAttributeName] = codeFont;
    if (style.color) {
      cbAttrs[NSForegroundColorAttributeName] = style.color;
    }
    UIColor *bg = style.backgroundColor
                      ?: [UIColor colorWithWhite:0.5 alpha:0.1];
    cbAttrs[NSBackgroundColorAttributeName] = bg;

    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:cbAttrs blockIndex:0];
    }
    break;
  }

  case MDNodeTypeThematicBreak: {
    if (output.length > 0) {
      [output appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n" attributes:[self baseAttrs]]];
    }
    // Render as a visible separator line
    NSMutableDictionary *hrAttrs = [attrs mutableCopy];
    hrAttrs[NSForegroundColorAttributeName] =
        [(_styleConfig.base.color ?: [UIColor labelColor])
            colorWithAlphaComponent:0.3];
    [output appendAttributedString:
        [[NSAttributedString alloc] initWithString:@"───────"
                                        attributes:hrAttrs]];
    break;
  }

  // ---- Inline elements ----

  case MDNodeTypeStrong: {
    NSMutableDictionary *boldAttrs = [attrs mutableCopy];
    boldAttrs[kBold] = @YES;

    UIFont *current = attrs[NSFontAttributeName] ?: _baseFont;
    boldAttrs[NSFontAttributeName] = [self boldVariantOf:current];

    MarkdownElementStyle *style = _styleConfig.strong;
    if (style.color) {
      boldAttrs[NSForegroundColorAttributeName] = style.color;
    }

    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:boldAttrs blockIndex:0];
    }
    break;
  }

  case MDNodeTypeEmphasis: {
    NSMutableDictionary *italicAttrs = [attrs mutableCopy];
    italicAttrs[kItalic] = @YES;

    UIFont *current = attrs[NSFontAttributeName] ?: _baseFont;
    italicAttrs[NSFontAttributeName] = [self italicVariantOf:current];

    MarkdownElementStyle *style = _styleConfig.emphasis;
    if (style.color) {
      italicAttrs[NSForegroundColorAttributeName] = style.color;
    }

    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:italicAttrs blockIndex:0];
    }
    break;
  }

  case MDNodeTypeStrikethrough: {
    NSMutableDictionary *sAttrs = [attrs mutableCopy];
    sAttrs[kStrike] = @YES;
    sAttrs[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);

    MarkdownElementStyle *style = _styleConfig.strikethrough;
    if (style.color) {
      sAttrs[NSForegroundColorAttributeName] = style.color;
      sAttrs[NSStrikethroughColorAttributeName] = style.color;
    }

    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:sAttrs blockIndex:0];
    }
    break;
  }

  case MDNodeTypeCode: {
    NSMutableDictionary *codeAttrs = [attrs mutableCopy];
    codeAttrs[kCode] = @YES;

    MarkdownElementStyle *style = _styleConfig.code;
    UIFont *codeFont = [style resolvedFontWithBase:_baseFont]
                           ?: [UIFont monospacedSystemFontOfSize:_baseFont.pointSize
                                                          weight:UIFontWeightRegular];
    codeAttrs[NSFontAttributeName] = codeFont;
    if (style.color) {
      codeAttrs[NSForegroundColorAttributeName] = style.color;
    }
    UIColor *bg = style.backgroundColor
                      ?: [UIColor colorWithWhite:0.5 alpha:0.1];
    codeAttrs[NSBackgroundColorAttributeName] = bg;

    // Code nodes have content directly (not children)
    NSString *content = node.content ?: @"";
    [output appendAttributedString:
        [[NSAttributedString alloc] initWithString:content
                                        attributes:codeAttrs]];
    break;
  }

  case MDNodeTypeLink: {
    NSMutableDictionary *linkAttrs = [attrs mutableCopy];
    linkAttrs[kLink] = node.linkUrl ?: @"";

    MarkdownElementStyle *style = _styleConfig.link;
    UIColor *linkColor = style.color ?: [UIColor systemBlueColor];
    linkAttrs[NSForegroundColorAttributeName] = linkColor;

    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:linkAttrs blockIndex:0];
    }
    break;
  }

  // ---- Leaf text ----

  case MDNodeTypeText: {
    NSString *content = node.content ?: @"";
    [output appendAttributedString:
        [[NSAttributedString alloc] initWithString:content
                                        attributes:attrs]];
    break;
  }

  case MDNodeTypeSoftBreak: {
    [output appendAttributedString:
        [[NSAttributedString alloc] initWithString:@" " attributes:attrs]];
    break;
  }

  case MDNodeTypeLineBreak: {
    [output appendAttributedString:
        [[NSAttributedString alloc] initWithString:@"\n" attributes:attrs]];
    break;
  }

  // ---- Skip / pass-through ----
  case MDNodeTypeListItem:
  case MDNodeTypeImage:
  case MDNodeTypeHtmlBlock:
  case MDNodeTypeHtmlInline:
  case MDNodeTypeCustomTag:
  default: {
    for (ASTNodeWrapper *child in node.children) {
      [self walkNode:child into:output attrs:attrs blockIndex:0];
    }
    break;
  }
  }
}

// ---------------------------------------------------------------
#pragma mark - Export (Attributed String → Markdown)
// ---------------------------------------------------------------

- (NSString *)exportMarkdown {
  NSAttributedString *as = _textView.attributedText;
  if (as.length == 0) return @"";

  NSString *text = as.string;
  NSMutableString *md = [NSMutableString new];

  // Process line by line
  __block NSUInteger lineStart = 0;
  [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                           options:NSStringEnumerationByLines |
                                   NSStringEnumerationSubstringNotRequired
                        usingBlock:^(NSString *substring, NSRange substringRange,
                                     NSRange enclosingRange, BOOL *stop) {
    [self exportLine:substringRange from:as into:md];
    [md appendString:@"\n"];
  }];

  // Trim trailing newlines
  while (md.length > 0 && [md characterAtIndex:md.length - 1] == '\n') {
    [md deleteCharactersInRange:NSMakeRange(md.length - 1, 1)];
  }

  return [md copy];
}

- (void)exportLine:(NSRange)lineRange
              from:(NSAttributedString *)as
              into:(NSMutableString *)md {
  if (lineRange.length == 0) return;

  // Check block-level attributes from the first character
  NSDictionary *firstAttrs =
      [as attributesAtIndex:lineRange.location effectiveRange:nil];

  NSNumber *heading = firstAttrs[kHeading];
  if (heading) {
    for (int i = 0; i < heading.intValue; i++) [md appendString:@"#"];
    [md appendString:@" "];
  }

  if ([firstAttrs[kBlockquote] boolValue]) {
    [md appendString:@"> "];
  }

  if ([firstAttrs[kCodeBlock] boolValue]) {
    // For code blocks, emit raw content — no inline formatting
    [md appendString:[as.string substringWithRange:lineRange]];
    return;
  }

  // Walk attribute runs for inline formatting
  [as enumerateAttributesInRange:lineRange
                         options:0
                      usingBlock:^(NSDictionary *attrs, NSRange range,
                                   BOOL *stop) {
    NSString *runText = [as.string substringWithRange:range];

    BOOL bold = [attrs[kBold] boolValue];
    BOOL italic = [attrs[kItalic] boolValue];
    BOOL strike = [attrs[kStrike] boolValue];
    BOOL code = [attrs[kCode] boolValue];
    NSString *link = attrs[kLink];

    if (code) {
      [md appendFormat:@"`%@`", runText];
    } else {
      BOOL hasLink = link.length > 0;
      if (hasLink) [md appendString:@"["];
      if (bold) [md appendString:@"**"];
      if (italic) [md appendString:@"*"];
      if (strike) [md appendString:@"~~"];

      [md appendString:runText];

      if (strike) [md appendString:@"~~"];
      if (italic) [md appendString:@"*"];
      if (bold) [md appendString:@"**"];
      if (hasLink) [md appendFormat:@"](%@)", link];
    }
  }];
}

// ---------------------------------------------------------------
#pragma mark - Toggle Formatting
// ---------------------------------------------------------------

- (void)toggleInlineAttr:(NSString *)attrKey
            visualUpdate:(void (^)(NSMutableDictionary *attrs,
                                   BOOL enabling))visualBlock {
  NSRange range = _textView.selectedRange;

  if (range.length == 0) {
    // No selection — toggle in typingAttributes
    NSMutableDictionary *attrs = [_textView.typingAttributes mutableCopy];
    BOOL wasOn = [attrs[attrKey] boolValue];
    if (wasOn) {
      [attrs removeObjectForKey:attrKey];
    } else {
      attrs[attrKey] = @YES;
    }
    visualBlock(attrs, !wasOn);
    _textView.typingAttributes = attrs;
  } else {
    // Has selection — check if the entire range already has this attr
    __block BOOL allHave = YES;
    [_textView.textStorage
        enumerateAttribute:attrKey
                   inRange:range
                   options:0
                usingBlock:^(id value, NSRange r, BOOL *stop) {
                  if (![value boolValue]) {
                    allHave = NO;
                    *stop = YES;
                  }
                }];

    BOOL enabling = !allHave;
    if (enabling) {
      [_textView.textStorage addAttribute:attrKey value:@YES range:range];
    } else {
      [_textView.textStorage removeAttribute:attrKey range:range];
    }

    // Apply visual changes to the range
    [_textView.textStorage
        enumerateAttributesInRange:range
                           options:0
                        usingBlock:^(NSDictionary *existing, NSRange r,
                                     BOOL *stop) {
                          NSMutableDictionary *updated =
                              [existing mutableCopy];
                          visualBlock(updated, enabling);
                          [self->_textView.textStorage setAttributes:updated
                                                              range:r];
                        }];
  }

  [self detectFormattingState];
  [self emitMarkdownChange];
}

- (void)toggleBold {
  [self toggleInlineAttr:kBold
            visualUpdate:^(NSMutableDictionary *attrs, BOOL enabling) {
              UIFont *font = attrs[NSFontAttributeName] ?: self->_baseFont;
              attrs[NSFontAttributeName] = enabling
                  ? [self boldVariantOf:font]
                  : [self unboldVariantOf:font];
            }];
}

- (void)toggleItalic {
  [self toggleInlineAttr:kItalic
            visualUpdate:^(NSMutableDictionary *attrs, BOOL enabling) {
              UIFont *font = attrs[NSFontAttributeName] ?: self->_baseFont;
              attrs[NSFontAttributeName] = enabling
                  ? [self italicVariantOf:font]
                  : [self unitalicVariantOf:font];
            }];
}

- (void)toggleStrikethrough {
  [self toggleInlineAttr:kStrike
            visualUpdate:^(NSMutableDictionary *attrs, BOOL enabling) {
              if (enabling) {
                attrs[NSStrikethroughStyleAttributeName] =
                    @(NSUnderlineStyleSingle);
              } else {
                [attrs removeObjectForKey:NSStrikethroughStyleAttributeName];
                [attrs removeObjectForKey:NSStrikethroughColorAttributeName];
              }
            }];
}

- (void)toggleCode {
  [self toggleInlineAttr:kCode
            visualUpdate:^(NSMutableDictionary *attrs, BOOL enabling) {
              if (enabling) {
                MarkdownElementStyle *style = self->_styleConfig.code;
                UIFont *codeFont =
                    [style resolvedFontWithBase:self->_baseFont]
                        ?: [UIFont monospacedSystemFontOfSize:
                                       self->_baseFont.pointSize
                                                      weight:UIFontWeightRegular];
                attrs[NSFontAttributeName] = codeFont;
                UIColor *bg = style.backgroundColor
                                  ?: [UIColor colorWithWhite:0.5 alpha:0.1];
                attrs[NSBackgroundColorAttributeName] = bg;
                if (style.color) {
                  attrs[NSForegroundColorAttributeName] = style.color;
                }
              } else {
                attrs[NSFontAttributeName] = self->_baseFont;
                [attrs removeObjectForKey:NSBackgroundColorAttributeName];
                attrs[NSForegroundColorAttributeName] =
                    self->_styleConfig.base.color ?: [UIColor labelColor];
              }
            }];
}

- (void)toggleHeading:(NSInteger)level {
  NSRange range = _textView.selectedRange;
  NSRange lineRange = [_textView.text lineRangeForRange:range];
  // Trim the trailing newline from lineRange
  if (lineRange.length > 0 &&
      [_textView.text characterAtIndex:lineRange.location + lineRange.length - 1] == '\n') {
    lineRange.length--;
  }
  if (lineRange.length == 0) return;

  NSDictionary *currentAttrs =
      [_textView.textStorage attributesAtIndex:lineRange.location
                                effectiveRange:nil];
  NSNumber *currentLevel = currentAttrs[kHeading];
  BOOL removing = currentLevel && currentLevel.integerValue == level;

  NSMutableDictionary *newAttrs;
  if (removing) {
    newAttrs = [[self baseAttrs] mutableCopy];
  } else {
    newAttrs = [currentAttrs mutableCopy];
    newAttrs[kHeading] = @(level);

    MarkdownElementStyle *style = [_styleConfig styleForHeadingLevel:level];
    UIFont *headingFont = [style resolvedFontWithBase:_baseFont];
    if (!headingFont) {
      CGFloat scales[] = {0, 2.0, 1.5, 1.25, 1.1, 1.0, 0.9};
      CGFloat s = level <= 6 ? scales[level] : 1.0;
      headingFont = [UIFont systemFontOfSize:_baseFont.pointSize * s
                                      weight:UIFontWeightBold];
    }
    newAttrs[NSFontAttributeName] = headingFont;
    if (style.color) {
      newAttrs[NSForegroundColorAttributeName] = style.color;
    }
  }

  [_textView.textStorage setAttributes:newAttrs range:lineRange];
  [self detectFormattingState];
  [self emitMarkdownChange];
}

- (void)toggleBlockquote {
  NSRange range = _textView.selectedRange;
  NSRange lineRange = [_textView.text lineRangeForRange:range];
  if (lineRange.length > 0 &&
      [_textView.text characterAtIndex:lineRange.location + lineRange.length - 1] == '\n') {
    lineRange.length--;
  }
  if (lineRange.length == 0) return;

  NSDictionary *currentAttrs =
      [_textView.textStorage attributesAtIndex:lineRange.location
                                effectiveRange:nil];
  BOOL removing = [currentAttrs[kBlockquote] boolValue];

  NSMutableDictionary *newAttrs;
  if (removing) {
    newAttrs = [[self baseAttrs] mutableCopy];
  } else {
    newAttrs = [currentAttrs mutableCopy];
    newAttrs[kBlockquote] = @YES;

    MarkdownElementStyle *style = _styleConfig.blockquote;
    if (style.color) {
      newAttrs[NSForegroundColorAttributeName] = style.color;
    }

    NSMutableParagraphStyle *pStyle = [NSMutableParagraphStyle new];
    pStyle.firstLineHeadIndent = 16;
    pStyle.headIndent = 16;
    newAttrs[NSParagraphStyleAttributeName] = pStyle;
  }

  [_textView.textStorage setAttributes:newAttrs range:lineRange];
  [self detectFormattingState];
  [self emitMarkdownChange];
}

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

  NSMutableDictionary *attrs = [_textView.typingAttributes mutableCopy];
  attrs[kLink] = url;

  MarkdownElementStyle *style = _styleConfig.link;
  attrs[NSForegroundColorAttributeName] =
      style.color ?: [UIColor systemBlueColor];

  NSAttributedString *linkAS =
      [[NSAttributedString alloc] initWithString:linkText attributes:attrs];

  if (range.length > 0) {
    [_textView.textStorage replaceCharactersInRange:range
                               withAttributedString:linkAS];
  } else {
    [_textView.textStorage insertAttributedString:linkAS atIndex:range.location];
  }

  [self emitMarkdownChange];
}

- (void)removeLink {
  NSRange range = _textView.selectedRange;
  if (range.location == NSNotFound) return;

  // Find the link range around the cursor
  __block NSRange linkRange = NSMakeRange(NSNotFound, 0);
  NSRange searchRange = NSMakeRange(0, _textView.textStorage.length);
  [_textView.textStorage
      enumerateAttribute:kLink
                 inRange:searchRange
                 options:0
              usingBlock:^(id value, NSRange r, BOOL *stop) {
                if (value && NSLocationInRange(range.location, r)) {
                  linkRange = r;
                  *stop = YES;
                }
              }];

  if (linkRange.location == NSNotFound) return;

  [_textView.textStorage removeAttribute:kLink range:linkRange];
  [_textView.textStorage addAttribute:NSForegroundColorAttributeName
                                value:_styleConfig.base.color ?: [UIColor labelColor]
                                range:linkRange];
  [self emitMarkdownChange];
}

// ---------------------------------------------------------------
#pragma mark - Native Commands
// ---------------------------------------------------------------

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  if ([commandName isEqualToString:@"focus"]) {
    [_textView becomeFirstResponder];
  } else if ([commandName isEqualToString:@"blur"]) {
    [_textView resignFirstResponder];
  } else if ([commandName isEqualToString:@"setValue"]) {
    NSString *value = args[0];
    NSAttributedString *as = [self importMarkdown:value];
    _textView.attributedText = as;
  } else if ([commandName isEqualToString:@"setSelection"]) {
    NSInteger start = [args[0] integerValue];
    NSInteger end = [args[1] integerValue];
    _textView.selectedRange = NSMakeRange(start, end - start);
  } else if ([commandName isEqualToString:@"toggleBold"]) {
    [self toggleBold];
  } else if ([commandName isEqualToString:@"toggleItalic"]) {
    [self toggleItalic];
  } else if ([commandName isEqualToString:@"toggleStrikethrough"]) {
    [self toggleStrikethrough];
  } else if ([commandName isEqualToString:@"toggleCode"]) {
    [self toggleCode];
  } else if ([commandName isEqualToString:@"toggleHeading"]) {
    NSInteger level = [args[0] integerValue];
    [self toggleHeading:level];
  } else if ([commandName isEqualToString:@"toggleOrderedList"]) {
    // TODO: list support
  } else if ([commandName isEqualToString:@"toggleUnorderedList"]) {
    // TODO: list support
  } else if ([commandName isEqualToString:@"toggleBlockquote"]) {
    [self toggleBlockquote];
  } else if ([commandName isEqualToString:@"insertLink"]) {
    NSString *url = args[0];
    NSString *text = args.count > 1 ? args[1] : @"";
    [self insertLinkWithURL:url text:text];
  } else if ([commandName isEqualToString:@"removeLink"]) {
    [self removeLink];
  } else if ([commandName isEqualToString:@"insertMention"]) {
    // TODO: mention support
  } else if ([commandName isEqualToString:@"insertSpoiler"]) {
    // TODO: spoiler support
  } else if ([commandName isEqualToString:@"insertCustomTag"]) {
    // TODO: custom tag support
  }
}

// ---------------------------------------------------------------
#pragma mark - State Detection
// ---------------------------------------------------------------

- (void)detectFormattingState {
  NSRange range = _textView.selectedRange;
  if (range.location == NSNotFound) return;
  if (_textView.textStorage.length == 0) return;

  // Read attributes at the cursor position (or start of selection)
  NSUInteger idx = range.location > 0 ? range.location - 1 : 0;
  if (idx >= _textView.textStorage.length) {
    idx = _textView.textStorage.length - 1;
  }

  NSDictionary *attrs = [_textView.textStorage attributesAtIndex:idx
                                                  effectiveRange:nil];

  [self emitStateFromAttrs:attrs];
}

- (void)syncTypingAttributes {
  _textView.typingAttributes = [self baseAttrs];
}

// ---------------------------------------------------------------
#pragma mark - Font Helpers
// ---------------------------------------------------------------

- (UIFont *)boldVariantOf:(UIFont *)font {
  UIFontDescriptorSymbolicTraits traits =
      font.fontDescriptor.symbolicTraits | UIFontDescriptorTraitBold;
  UIFontDescriptor *desc =
      [font.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
  return desc ? [UIFont fontWithDescriptor:desc size:font.pointSize]
              : [UIFont boldSystemFontOfSize:font.pointSize];
}

- (UIFont *)unboldVariantOf:(UIFont *)font {
  UIFontDescriptorSymbolicTraits traits =
      font.fontDescriptor.symbolicTraits & ~UIFontDescriptorTraitBold;
  UIFontDescriptor *desc =
      [font.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
  return desc ? [UIFont fontWithDescriptor:desc size:font.pointSize]
              : [UIFont systemFontOfSize:font.pointSize];
}

- (UIFont *)italicVariantOf:(UIFont *)font {
  UIFontDescriptorSymbolicTraits traits =
      font.fontDescriptor.symbolicTraits | UIFontDescriptorTraitItalic;
  UIFontDescriptor *desc =
      [font.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
  return desc ? [UIFont fontWithDescriptor:desc size:font.pointSize]
              : font;
}

- (UIFont *)unitalicVariantOf:(UIFont *)font {
  UIFontDescriptorSymbolicTraits traits =
      font.fontDescriptor.symbolicTraits & ~UIFontDescriptorTraitItalic;
  UIFontDescriptor *desc =
      [font.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
  return desc ? [UIFont fontWithDescriptor:desc size:font.pointSize]
              : font;
}

// ---------------------------------------------------------------
#pragma mark - Events
// ---------------------------------------------------------------

- (void)emitMarkdownChange {
  if (!_eventEmitter) return;

  NSString *markdown = [self exportMarkdown];
  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);

  emitter.onChangeText({.text = std::string([_textView.text UTF8String])});
  emitter.onChangeMarkdown(
      {.markdown = std::string([markdown UTF8String])});
}

- (void)emitStateFromAttrs:(NSDictionary *)attrs {
  if (!_eventEmitter) return;

  const auto &emitter =
      static_cast<const MarkdownEditorViewEventEmitter &>(*_eventEmitter);

  NSString *linkUrl = attrs[kLink] ?: @"";
  NSNumber *heading = attrs[kHeading];

  NSString *listType = @"";
  if ([attrs[kOrderedList] boolValue]) listType = @"ordered";
  else if ([attrs[kUnorderedList] boolValue]) listType = @"unordered";

  emitter.onChangeState({
      .bold = [attrs[kBold] boolValue],
      .italic = [attrs[kItalic] boolValue],
      .strikethrough = [attrs[kStrike] boolValue],
      .code = [attrs[kCode] boolValue],
      .linkUrl = std::string([linkUrl UTF8String]),
      .heading = heading ? static_cast<int>(heading.integerValue) : 0,
      .list = std::string([listType UTF8String]),
  });
}

// ---------------------------------------------------------------
#pragma mark - UITextViewDelegate
// ---------------------------------------------------------------

- (void)textViewDidChange:(UITextView *)textView {
  [self emitMarkdownChange];
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
