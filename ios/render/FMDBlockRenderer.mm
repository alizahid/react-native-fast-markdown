#import "FMDBlockRenderer.h"

#import <CoreText/CoreText.h>

#import "core/Parser.h"

using fastmarkdown::Node;
using fastmarkdown::NodeType;

namespace {

NSString *toNSString(const std::string &value) {
  NSString *result = [[NSString alloc] initWithBytes:value.data()
                                              length:value.size()
                                            encoding:NSUTF8StringEncoding];
  return result != nil ? result : @"";
}

// Fully-resolved text attributes at one point of the inline tree walk.
struct ResolvedAttrs {
  CGFloat fontSize = 16;
  NSInteger weight = 400;
  bool italic = false;
  NSString *__strong family = nil;
  UIColor *__strong color = nil;
  NSArray<NSString *> *__strong variants = nil;
  bool underline = false;
  bool strikethrough = false;
  UIColor *__strong decorationColor = nil;
  NSString *__strong decorationStyle = nil;
  CGFloat baselineOffset = 0;
  UIColor *__strong backgroundColor = nil;
};

void applyStyle(ResolvedAttrs &attrs, FMDTextStyle *style, CGFloat fontScale) {
  if (style == nil) {
    return;
  }
  if (style.fontSize != nil) {
    attrs.fontSize = style.fontSize.doubleValue * fontScale;
  }
  if (style.fontWeight != nil) {
    attrs.weight = style.fontWeight.integerValue;
  }
  if (style.fontFamily != nil) {
    attrs.family = style.fontFamily;
  }
  if (style.color != nil) {
    attrs.color = style.color;
  }
  if (style.fontVariant != nil) {
    attrs.variants = style.fontVariant;
  }
  if (style.textDecorationColor != nil) {
    attrs.decorationColor = style.textDecorationColor;
  }
  if (style.textDecorationStyle != nil) {
    attrs.decorationStyle = style.textDecorationStyle;
  }
  if (style.textDecorationLine != nil) {
    attrs.underline = [style.textDecorationLine containsString:@"underline"];
    attrs.strikethrough = [style.textDecorationLine containsString:@"line-through"];
  }
  if (style.backgroundColor != nil) {
    attrs.backgroundColor = style.backgroundColor;
  }
}

UIFontWeight uiWeight(NSInteger weight) {
  switch (weight) {
    case 100: return UIFontWeightUltraLight;
    case 200: return UIFontWeightThin;
    case 300: return UIFontWeightLight;
    case 400: return UIFontWeightRegular;
    case 500: return UIFontWeightMedium;
    case 600: return UIFontWeightSemibold;
    case 700: return UIFontWeightBold;
    case 800: return UIFontWeightHeavy;
    default: return weight >= 900 ? UIFontWeightBlack : UIFontWeightRegular;
  }
}

NSArray<NSDictionary *> *featureSettings(NSArray<NSString *> *variants) {
  NSMutableArray *features = [NSMutableArray new];
  for (NSString *variant in variants) {
    int type = -1;
    int selector = -1;
    if ([variant isEqualToString:@"tabular-nums"]) {
      type = kNumberSpacingType;
      selector = kMonospacedNumbersSelector;
    } else if ([variant isEqualToString:@"proportional-nums"]) {
      type = kNumberSpacingType;
      selector = kProportionalNumbersSelector;
    } else if ([variant isEqualToString:@"oldstyle-nums"]) {
      type = kNumberCaseType;
      selector = kLowerCaseNumbersSelector;
    } else if ([variant isEqualToString:@"lining-nums"]) {
      type = kNumberCaseType;
      selector = kUpperCaseNumbersSelector;
    } else if ([variant isEqualToString:@"small-caps"]) {
      type = kLowerCaseType;
      selector = kLowerCaseSmallCapsSelector;
    }
    if (type >= 0) {
      [features addObject:@{
        UIFontFeatureTypeIdentifierKey : @(type),
        UIFontFeatureSelectorIdentifierKey : @(selector),
      }];
    }
  }
  return features;
}

UIFont *buildFont(const ResolvedAttrs &attrs) {
  UIFont *base;
  if (attrs.family.length > 0) {
    UIFontDescriptor *descriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:@{
      UIFontDescriptorFamilyAttribute : attrs.family,
      UIFontDescriptorTraitsAttribute : @{
        UIFontWeightTrait : @((uiWeight(attrs.weight) - UIFontWeightRegular)),
      },
    }];
    base = [UIFont fontWithDescriptor:descriptor size:attrs.fontSize];
    if (base == nil) {
      base = [UIFont systemFontOfSize:attrs.fontSize weight:uiWeight(attrs.weight)];
    }
  } else {
    base = [UIFont systemFontOfSize:attrs.fontSize weight:uiWeight(attrs.weight)];
  }

  UIFontDescriptorSymbolicTraits traits = base.fontDescriptor.symbolicTraits;
  if (attrs.italic) {
    traits |= UIFontDescriptorTraitItalic;
  }

  NSMutableDictionary *descriptorAttributes = [NSMutableDictionary new];
  NSArray *features = attrs.variants != nil ? featureSettings(attrs.variants) : @[];
  if (features.count > 0) {
    descriptorAttributes[UIFontDescriptorFeatureSettingsAttribute] = features;
  }

  UIFontDescriptor *descriptor = base.fontDescriptor;
  if (descriptorAttributes.count > 0) {
    descriptor = [descriptor fontDescriptorByAddingAttributes:descriptorAttributes];
  }
  if (attrs.italic) {
    UIFontDescriptor *italicDescriptor = [descriptor fontDescriptorWithSymbolicTraits:traits];
    if (italicDescriptor != nil) {
      descriptor = italicDescriptor;
    }
  }
  UIFont *font = [UIFont fontWithDescriptor:descriptor size:attrs.fontSize];
  return font ?: base;
}

NSUnderlineStyle decorationMask(NSString *style) {
  if ([style isEqualToString:@"double"]) {
    return NSUnderlineStyleDouble;
  }
  if ([style isEqualToString:@"dotted"]) {
    return NSUnderlineStyleSingle | NSUnderlineStylePatternDot;
  }
  if ([style isEqualToString:@"dashed"]) {
    return NSUnderlineStyleSingle | NSUnderlineStylePatternDash;
  }
  return NSUnderlineStyleSingle;
}

NSDictionary *attributesDictionary(const ResolvedAttrs &attrs) {
  NSMutableDictionary *attributes = [NSMutableDictionary new];
  attributes[NSFontAttributeName] = buildFont(attrs);
  attributes[NSForegroundColorAttributeName] = attrs.color ?: UIColor.blackColor;
  if (attrs.underline) {
    attributes[NSUnderlineStyleAttributeName] = @(decorationMask(attrs.decorationStyle));
    if (attrs.decorationColor != nil) {
      attributes[NSUnderlineColorAttributeName] = attrs.decorationColor;
    }
  }
  if (attrs.strikethrough) {
    attributes[NSStrikethroughStyleAttributeName] = @(decorationMask(attrs.decorationStyle));
    if (attrs.decorationColor != nil) {
      attributes[NSStrikethroughColorAttributeName] = attrs.decorationColor;
    }
  }
  if (attrs.baselineOffset != 0) {
    attributes[NSBaselineOffsetAttributeName] = @(attrs.baselineOffset);
  }
  if (attrs.backgroundColor != nil) {
    attributes[NSBackgroundColorAttributeName] = attrs.backgroundColor;
  }
  return attributes;
}

class InlineWalker {
 public:
  InlineWalker(FMDStyleConfig *styles, CGFloat fontScale)
      : styles_(styles), fontScale_(fontScale) {}

  NSAttributedString *renderBlockNode(const Node *node) {
    NSMutableAttributedString *output = [NSMutableAttributedString new];

    ResolvedAttrs base;
    base.color = UIColor.blackColor;
    if (node->type == NodeType::Heading) {
      base.fontSize = [styles_ fontSizeForHeadingLevel:node->level] * fontScale_;
      base.weight = 700;
      applyStyle(
          base,
          [styles_ textStyleFor:[NSString stringWithFormat:@"h%d", (int)node->level]],
          fontScale_);
    } else {
      base.fontSize = [styles_ fontSizeForHeadingLevel:0] * fontScale_;
      applyStyle(base, [styles_ textStyleFor:@"paragraph"], fontScale_);
    }

    walk(output, node, base);
    return output;
  }

 private:
  void append(NSMutableAttributedString *output, NSString *text, const ResolvedAttrs &attrs) {
    if (text.length == 0) {
      return;
    }
    [output appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:text
                                           attributes:attributesDictionary(attrs)]];
  }

  void walk(NSMutableAttributedString *output, const Node *parent, const ResolvedAttrs &attrs) {
    for (const Node *node : parent->children) {
      switch (node->type) {
        case NodeType::Text:
          append(output, toNSString(node->text), attrs);
          break;
        case NodeType::SoftBreak:
          append(output, @" ", attrs);
          break;
        case NodeType::HardBreak:
          append(output, @"\n", attrs);
          break;
        case NodeType::Bold: {
          ResolvedAttrs next = attrs;
          next.weight = 700;
          applyStyle(next, [styles_ textStyleFor:@"bold"], fontScale_);
          walk(output, node, next);
          break;
        }
        case NodeType::Italic: {
          ResolvedAttrs next = attrs;
          next.italic = true;
          applyStyle(next, [styles_ textStyleFor:@"italic"], fontScale_);
          walk(output, node, next);
          break;
        }
        case NodeType::Strikethrough: {
          ResolvedAttrs next = attrs;
          next.strikethrough = true;
          applyStyle(next, [styles_ textStyleFor:@"strikethrough"], fontScale_);
          walk(output, node, next);
          break;
        }
        case NodeType::Link: {
          ResolvedAttrs next = attrs;
          next.color = [UIColor colorWithRed:0 green:0.478 blue:1 alpha:1];
          NSString *url = toNSString(node->url);
          FMDTextStyle *variantStyle = nil;
          bool isMention = false;
          for (FMDMentionVariant *variant in styles_.mentionVariants) {
            if ([variant.pattern firstMatchInString:url
                                            options:0
                                              range:NSMakeRange(0, url.length)] != nil) {
              isMention = true;
              variantStyle = variant.style;
              break;
            }
          }
          if (isMention) {
            applyStyle(next, [styles_ textStyleFor:@"mention"], fontScale_);
            applyStyle(next, variantStyle, fontScale_);
          } else {
            applyStyle(next, [styles_ textStyleFor:@"link"], fontScale_);
          }
          walk(output, node, next);
          break;
        }
        case NodeType::InlineCode: {
          ResolvedAttrs next = attrs;
          next.family = @"Menlo";
          next.backgroundColor = [UIColor colorWithWhite:0 alpha:0.08];
          applyStyle(next, [styles_ textStyleFor:@"inlineCode"], fontScale_);
          append(output, toNSString(node->text), next);
          break;
        }
        case NodeType::Superscript: {
          ResolvedAttrs next = attrs;
          next.fontSize = attrs.fontSize * 0.7;
          next.baselineOffset = attrs.fontSize * 0.35;
          applyStyle(next, [styles_ textStyleFor:@"superscript"], fontScale_);
          walk(output, node, next);
          break;
        }
        case NodeType::Subscript: {
          ResolvedAttrs next = attrs;
          next.fontSize = attrs.fontSize * 0.7;
          next.baselineOffset = -attrs.fontSize * 0.18;
          applyStyle(next, [styles_ textStyleFor:@"subscript"], fontScale_);
          walk(output, node, next);
          break;
        }
        case NodeType::Spoiler:
          // Overlay + concealment land in M6; content renders styled now.
          walk(output, node, attrs);
          break;
        case NodeType::Image:
          append(output, toNSString(node->text), attrs);
          break;
        default:
          walk(output, node, attrs);
          break;
      }
    }
  }

  FMDStyleConfig *styles_;
  CGFloat fontScale_;
};

void renderBlock(
    const Node *node,
    InlineWalker &walker,
    NSMutableArray<NSAttributedString *> *output) {
  switch (node->type) {
    case NodeType::Paragraph:
    case NodeType::Heading:
      [output addObject:walker.renderBlockNode(node)];
      break;
    default: {
      if (!node->children.empty()) {
        for (const Node *child : node->children) {
          renderBlock(child, walker, output);
        }
      } else if (!node->text.empty()) {
        // Leaf blocks not yet implemented (code blocks arrive in M3).
        Node wrapper;
        wrapper.type = NodeType::Paragraph;
        Node text;
        text.type = NodeType::Text;
        text.text = node->text;
        wrapper.children.push_back(&text);
        [output addObject:walker.renderBlockNode(&wrapper)];
      }
      break;
    }
  }
}

} // namespace

@implementation FMDBlockRenderer

+ (NSArray<NSAttributedString *> *)renderMarkdown:(NSString *)markdown
                                           styles:(FMDStyleConfig *)styles
                                        fontScale:(CGFloat)fontScale {
  const auto document =
      fastmarkdown::parseMarkdown(std::string([markdown UTF8String] ?: ""));

  InlineWalker walker(styles, fontScale);
  NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray new];
  if (document->root != nullptr) {
    for (const Node *child : document->root->children) {
      renderBlock(child, walker, blocks);
    }
  }
  return blocks;
}

@end
