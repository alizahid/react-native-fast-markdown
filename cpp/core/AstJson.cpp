#include "AstJson.h"

namespace fastmarkdown {

namespace {

const char* typeName(NodeType type) {
  switch (type) {
    case NodeType::Document: return "document";
    case NodeType::Heading: return "heading";
    case NodeType::Paragraph: return "paragraph";
    case NodeType::BlockQuote: return "blockQuote";
    case NodeType::CodeBlock: return "codeBlock";
    case NodeType::List: return "list";
    case NodeType::ListItem: return "listItem";
    case NodeType::Table: return "table";
    case NodeType::TableRow: return "tableRow";
    case NodeType::TableCell: return "tableCell";
    case NodeType::Image: return "image";
    case NodeType::ThematicBreak: return "thematicBreak";
    case NodeType::Text: return "text";
    case NodeType::SoftBreak: return "softBreak";
    case NodeType::HardBreak: return "hardBreak";
    case NodeType::Bold: return "bold";
    case NodeType::Italic: return "italic";
    case NodeType::Strikethrough: return "strikethrough";
    case NodeType::Link: return "link";
    case NodeType::InlineCode: return "inlineCode";
    case NodeType::Spoiler: return "spoiler";
    case NodeType::Superscript: return "superscript";
    case NodeType::Subscript: return "subscript";
  }
  return "unknown";
}

void appendEscaped(std::string& out, const std::string& value) {
  for (char c : value) {
    switch (c) {
      case '"': out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n"; break;
      case '\t': out += "\\t"; break;
      case '\r': out += "\\r"; break;
      default: out += c; break;
    }
  }
}

void write(std::string& out, const Node* node) {
  out += "{\"type\":\"";
  out += typeName(node->type);
  out += '"';
  if (!node->text.empty()) {
    out += ",\"text\":\"";
    appendEscaped(out, node->text);
    out += '"';
  }
  if (!node->url.empty()) {
    out += ",\"url\":\"";
    appendEscaped(out, node->url);
    out += '"';
  }
  if (node->level != 0) {
    out += ",\"level\":";
    out += std::to_string(node->level);
  }
  if (node->type == NodeType::List) {
    out += ",\"ordered\":";
    out += node->ordered ? "true" : "false";
    if (node->ordered && node->startIndex != 1) {
      out += ",\"start\":";
      out += std::to_string(node->startIndex);
    }
  }
  if (!node->children.empty()) {
    out += ",\"children\":[";
    for (size_t i = 0; i < node->children.size(); i++) {
      if (i > 0) {
        out += ',';
      }
      write(out, node->children[i]);
    }
    out += ']';
  }
  out += '}';
}

} // namespace

std::string astToJson(const Node* node) {
  std::string out;
  if (node != nullptr) {
    write(out, node);
  }
  return out;
}

} // namespace fastmarkdown
