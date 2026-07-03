#include "EditorText.h"

#include <vector>

#include "Ast.h"
#include "AstToMarkdown.h"
#include "Parser.h"

namespace fastmarkdown {

namespace {

void collectPlainText(const Node* node, std::string& out, bool& atBlockStart);

void collectChildren(const Node* node, std::string& out, bool& atBlockStart) {
  for (const Node* child : node->children) {
    collectPlainText(child, out, atBlockStart);
  }
}

void beginBlock(std::string& out, bool& atBlockStart) {
  if (!atBlockStart && !out.empty()) {
    out += '\n';
  }
  atBlockStart = true;
}

void endBlock(bool& atBlockStart) {
  atBlockStart = false;
}

void collectPlainText(const Node* node, std::string& out, bool& atBlockStart) {
  switch (node->type) {
    case NodeType::Text:
      out += node->text;
      break;
    case NodeType::SoftBreak:
    case NodeType::HardBreak:
      out += '\n';
      break;
    case NodeType::InlineCode:
      out += node->text;
      break;
    case NodeType::Image:
      out += node->text;
      break;
    case NodeType::CodeBlock: {
      beginBlock(out, atBlockStart);
      std::string content = node->text;
      if (!content.empty() && content.back() == '\n') {
        content.pop_back();
      }
      out += content;
      endBlock(atBlockStart);
      break;
    }
    case NodeType::Paragraph:
    case NodeType::Heading:
    case NodeType::ListItem:
    case NodeType::TableRow:
      beginBlock(out, atBlockStart);
      collectChildren(node, out, atBlockStart);
      endBlock(atBlockStart);
      break;
    case NodeType::TableCell:
      if (!atBlockStart && !out.empty() && out.back() != '\n') {
        out += ' ';
      }
      collectChildren(node, out, atBlockStart);
      break;
    case NodeType::ThematicBreak:
      break;
    default:
      collectChildren(node, out, atBlockStart);
      break;
  }
}

} // namespace

std::string markdownFromPlainText(const std::string& text) {
  MarkdownDocument document;
  Node* root = document.arena.alloc(NodeType::Document);
  document.root = root;

  // Editor model: every newline is a paragraph break (Enter = new
  // paragraph), so plain text round-trips stably through setValue.
  std::string line;
  auto flushLine = [&]() {
    if (!line.empty()) {
      Node* paragraph = document.arena.alloc(NodeType::Paragraph);
      root->children.push_back(paragraph);
      Node* textNode = document.arena.alloc(NodeType::Text);
      textNode->text = line;
      paragraph->children.push_back(textNode);
    }
    line.clear();
  };

  for (const char c : text) {
    if (c == '\n') {
      flushLine();
    } else {
      line += c;
    }
  }
  flushLine();

  return astToMarkdown(root);
}

std::string plainTextFromMarkdown(const std::string& markdown) {
  auto document = parseMarkdown(markdown);
  std::string out;
  bool atBlockStart = true;
  if (document->root != nullptr) {
    collectChildren(document->root, out, atBlockStart);
  }
  return out;
}

} // namespace fastmarkdown
