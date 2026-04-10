#pragma once

#include <map>
#include <string>
#include <vector>

namespace markdown {

enum class NodeType {
  // Block elements
  Document,
  Paragraph,
  Heading,
  Blockquote,
  List,
  ListItem,
  CodeBlock,
  ThematicBreak,
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableCell,
  HtmlBlock,

  // Inline elements
  Text,
  SoftBreak,
  LineBreak,
  Code,
  Emphasis,
  Strong,
  Strikethrough,
  Link,
  Image,
  HtmlInline,
  Underline,

  // Custom components (parsed from HTML-like tags)
  CustomTag,
};

enum class ListType { Ordered, Unordered };

enum class TableAlign { Default, Left, Center, Right };

struct ASTNode {
  NodeType type = NodeType::Document;
  std::string content;

  // Block attributes
  int headingLevel = 0;         // 1-6 for headings
  ListType listType = ListType::Unordered;
  int listStart = 1;            // start number for ordered lists
  bool listTight = false;
  bool isTaskItem = false;
  bool taskChecked = false;
  std::string codeLanguage;     // language for code blocks
  TableAlign tableAlign = TableAlign::Default;
  int tableColumnCount = 0;

  // Inline attributes
  std::string linkUrl;
  std::string linkTitle;
  std::string imageSrc;
  std::string imageTitle;
  bool isAutolink = false;

  // Custom tag attributes
  std::string tagName;
  std::map<std::string, std::string> tagProps;

  // Children
  std::vector<ASTNode> children;

  // Task list index (assigned during rendering)
  int taskIndex = -1;

  ASTNode() = default;
  explicit ASTNode(NodeType t) : type(t) {}
};

} // namespace markdown
