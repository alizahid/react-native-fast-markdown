#import "FMDBlockRenderer.h"

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

UIFont *fontWithTraits(CGFloat size, bool bold, bool italic) {
  UIFontDescriptorSymbolicTraits traits = 0;
  if (bold) {
    traits |= UIFontDescriptorTraitBold;
  }
  if (italic) {
    traits |= UIFontDescriptorTraitItalic;
  }
  UIFont *base = [UIFont systemFontOfSize:size];
  if (traits == 0) {
    return base;
  }
  UIFontDescriptor *descriptor =
      [base.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
  return descriptor != nil ? [UIFont fontWithDescriptor:descriptor size:size] : base;
}

void appendInlines(
    NSMutableAttributedString *output,
    const Node *parent,
    CGFloat fontSize,
    bool bold,
    bool italic) {
  for (const Node *node : parent->children) {
    switch (node->type) {
      case NodeType::Text:
      case NodeType::InlineCode: {
        NSDictionary *attributes = @{
          NSFontAttributeName : fontWithTraits(fontSize, bold, italic),
          NSForegroundColorAttributeName : UIColor.blackColor,
        };
        NSAttributedString *run =
            [[NSAttributedString alloc] initWithString:toNSString(node->text)
                                            attributes:attributes];
        [output appendAttributedString:run];
        break;
      }
      case NodeType::SoftBreak:
      case NodeType::HardBreak: {
        NSString *separator = node->type == NodeType::HardBreak ? @"\n" : @" ";
        NSDictionary *attributes = @{
          NSFontAttributeName : fontWithTraits(fontSize, bold, italic),
        };
        [output appendAttributedString:[[NSAttributedString alloc] initWithString:separator
                                                                        attributes:attributes]];
        break;
      }
      case NodeType::Bold:
        appendInlines(output, node, fontSize, true, italic);
        break;
      case NodeType::Italic:
        appendInlines(output, node, fontSize, bold, true);
        break;
      case NodeType::Image: {
        NSDictionary *attributes = @{
          NSFontAttributeName : fontWithTraits(fontSize, bold, italic),
          NSForegroundColorAttributeName : UIColor.blackColor,
        };
        [output appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:toNSString(node->text)
                                               attributes:attributes]];
        break;
      }
      default:
        appendInlines(output, node, fontSize, bold, italic);
        break;
    }
  }
}

void renderBlock(
    const Node *node,
    FMDStyleConfig *styles,
    CGFloat fontScale,
    NSMutableArray<NSAttributedString *> *output) {
  switch (node->type) {
    case NodeType::Paragraph: {
      NSMutableAttributedString *text = [NSMutableAttributedString new];
      appendInlines(text, node, [styles fontSizeForHeadingLevel:0] * fontScale, false, false);
      [output addObject:text];
      break;
    }
    case NodeType::Heading: {
      NSMutableAttributedString *text = [NSMutableAttributedString new];
      appendInlines(
          text, node, [styles fontSizeForHeadingLevel:node->level] * fontScale, true, false);
      [output addObject:text];
      break;
    }
    default: {
      // Other block types land in M3+; render nested content meanwhile so
      // nothing is silently dropped.
      if (!node->children.empty()) {
        for (const Node *child : node->children) {
          renderBlock(child, styles, fontScale, output);
        }
      } else if (!node->text.empty()) {
        NSDictionary *attributes = @{
          NSFontAttributeName :
              fontWithTraits([styles fontSizeForHeadingLevel:0] * fontScale, false, false),
          NSForegroundColorAttributeName : UIColor.blackColor,
        };
        [output addObject:[[NSAttributedString alloc] initWithString:toNSString(node->text)
                                                          attributes:attributes]];
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

  NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray new];
  if (document->root != nullptr) {
    for (const Node *child : document->root->children) {
      renderBlock(child, styles, fontScale, blocks);
    }
  }
  return blocks;
}

@end
