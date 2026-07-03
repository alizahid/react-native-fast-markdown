#include "EditorRuns.h"

#include <algorithm>
#include <set>

#include "Ast.h"
#include "AstToMarkdown.h"
#include "Parser.h"

namespace fastmarkdown {

namespace {

// Outer-to-inner nesting order when marks overlap. Inline code is innermost
// because markdown cannot format inside a code span; the serializer emits
// code content verbatim.
constexpr uint32_t kNestingOrder[] = {
    MarkSpoiler,
    MarkBold,
    MarkItalic,
    MarkStrikethrough,
    MarkSuperscript,
    MarkSubscript,
    MarkInlineCode,
};

NodeType nodeTypeForMark(uint32_t mark) {
  switch (mark) {
    case MarkBold:
      return NodeType::Bold;
    case MarkItalic:
      return NodeType::Italic;
    case MarkStrikethrough:
      return NodeType::Strikethrough;
    case MarkSpoiler:
      return NodeType::Spoiler;
    case MarkSuperscript:
      return NodeType::Superscript;
    case MarkSubscript:
      return NodeType::Subscript;
    default:
      return NodeType::InlineCode;
  }
}

uint32_t markForNodeType(NodeType type) {
  switch (type) {
    case NodeType::Bold:
      return MarkBold;
    case NodeType::Italic:
      return MarkItalic;
    case NodeType::Strikethrough:
      return MarkStrikethrough;
    case NodeType::InlineCode:
      return MarkInlineCode;
    case NodeType::Spoiler:
      return MarkSpoiler;
    case NodeType::Superscript:
      return MarkSuperscript;
    case NodeType::Subscript:
      return MarkSubscript;
    default:
      return 0;
  }
}

// Maps every UTF-16 code-unit offset to a byte offset in the UTF-8 text.
// Index i holds the byte position where UTF-16 unit i starts; the final
// entry is text.size().
std::vector<size_t> utf16ToByteTable(const std::string& text) {
  std::vector<size_t> table;
  table.reserve(text.size() + 1);
  size_t i = 0;
  while (i < text.size()) {
    const auto byte = static_cast<unsigned char>(text[i]);
    size_t charLen = 1;
    size_t utf16Len = 1;
    if (byte >= 0xF0) {
      charLen = 4;
      utf16Len = 2; // surrogate pair
    } else if (byte >= 0xE0) {
      charLen = 3;
    } else if (byte >= 0xC0) {
      charLen = 2;
    }
    for (size_t u = 0; u < utf16Len; u++) {
      table.push_back(i);
    }
    i += charLen;
  }
  table.push_back(text.size());
  return table;
}

size_t utf16Length(const char* data, size_t size) {
  size_t length = 0;
  size_t i = 0;
  while (i < size) {
    const auto byte = static_cast<unsigned char>(data[i]);
    if (byte >= 0xF0) {
      length += 2;
      i += 4;
    } else if (byte >= 0xE0) {
      length += 1;
      i += 3;
    } else if (byte >= 0xC0) {
      length += 1;
      i += 2;
    } else {
      length += 1;
      i += 1;
    }
  }
  return length;
}

struct Segment {
  std::string text;
  uint32_t flags = 0;
};

// Builds inline nodes for a paragraph's segments. The mark whose run
// extends over the most upcoming segments wraps them (ties broken by
// kNestingOrder), which keeps overlapping runs nested instead of producing
// adjacent close/open delimiter runs that merge when re-parsed. Inline code
// never wraps other marks (markdown cannot format inside a code span), so
// it only groups exact-equal flag segments and stays innermost.
void buildInlineNodes(
    MarkdownDocument& document,
    Node* parent,
    const std::vector<Segment>& segments,
    size_t begin,
    size_t end,
    uint32_t handled) {
  const auto extentOf = [&](size_t from, uint32_t mark) {
    size_t j = from;
    while (j < end && (segments[j].flags & ~handled & mark) != 0) {
      j++;
    }
    return j - from;
  };

  size_t i = begin;
  while (i < end) {
    const uint32_t flags = segments[i].flags & ~handled;
    if (flags == 0) {
      Node* text = document.arena.alloc(NodeType::Text);
      text->text = segments[i].text;
      parent->children.push_back(text);
      i++;
      continue;
    }
    uint32_t mark = 0;
    size_t extent = 0;
    for (const uint32_t candidate : kNestingOrder) {
      if (candidate == MarkInlineCode || (flags & candidate) == 0) {
        continue;
      }
      const size_t candidateExtent = extentOf(i, candidate);
      if (candidateExtent > extent) {
        mark = candidate;
        extent = candidateExtent;
      }
    }
    if (mark == 0) {
      Node* code = document.arena.alloc(NodeType::InlineCode);
      size_t j = i;
      while (j < end && (segments[j].flags & ~handled) == flags) {
        code->text += segments[j].text;
        j++;
      }
      parent->children.push_back(code);
      i = j;
    } else {
      Node* wrapper = document.arena.alloc(nodeTypeForMark(mark));
      parent->children.push_back(wrapper);
      buildInlineNodes(document, wrapper, segments, i, i + extent, handled | mark);
      i += extent;
    }
  }
}

void collectStyledText(
    const Node* node,
    StyledText& out,
    uint32_t activeFlags,
    bool& atBlockStart);

void collectStyledChildren(
    const Node* node,
    StyledText& out,
    uint32_t activeFlags,
    bool& atBlockStart) {
  for (const Node* child : node->children) {
    collectStyledText(child, out, activeFlags, atBlockStart);
  }
}

void appendMarkedText(StyledText& out, const std::string& text, uint32_t flags) {
  if (text.empty()) {
    return;
  }
  const auto start = static_cast<uint32_t>(utf16Length(out.text.data(), out.text.size()));
  out.text += text;
  if (flags != 0) {
    const auto end = start + static_cast<uint32_t>(utf16Length(text.data(), text.size()));
    if (!out.runs.empty() && out.runs.back().flags == flags &&
        out.runs.back().end == start) {
      out.runs.back().end = end;
    } else {
      out.runs.push_back({start, end, flags});
    }
  }
}

void beginStyledBlock(StyledText& out, bool& atBlockStart) {
  if (!atBlockStart && !out.text.empty()) {
    out.text += '\n';
  }
  atBlockStart = true;
}

void collectStyledText(
    const Node* node,
    StyledText& out,
    uint32_t activeFlags,
    bool& atBlockStart) {
  const uint32_t mark = markForNodeType(node->type);
  if (mark != 0 && node->type != NodeType::InlineCode) {
    collectStyledChildren(node, out, activeFlags | mark, atBlockStart);
    return;
  }
  switch (node->type) {
    case NodeType::Text:
      appendMarkedText(out, node->text, activeFlags);
      break;
    case NodeType::SoftBreak:
    case NodeType::HardBreak:
      out.text += '\n';
      break;
    case NodeType::InlineCode:
      appendMarkedText(out, node->text, activeFlags | MarkInlineCode);
      break;
    case NodeType::Image:
      appendMarkedText(out, node->text, activeFlags);
      break;
    case NodeType::CodeBlock: {
      beginStyledBlock(out, atBlockStart);
      std::string content = node->text;
      if (!content.empty() && content.back() == '\n') {
        content.pop_back();
      }
      out.text += content;
      atBlockStart = false;
      break;
    }
    case NodeType::Paragraph:
    case NodeType::Heading:
    case NodeType::ListItem:
    case NodeType::TableRow:
      beginStyledBlock(out, atBlockStart);
      collectStyledChildren(node, out, activeFlags, atBlockStart);
      atBlockStart = false;
      break;
    case NodeType::TableCell:
      if (!atBlockStart && !out.text.empty() && out.text.back() != '\n') {
        out.text += ' ';
      }
      collectStyledChildren(node, out, activeFlags, atBlockStart);
      break;
    case NodeType::ThematicBreak:
      break;
    default:
      collectStyledChildren(node, out, activeFlags, atBlockStart);
      break;
  }
}

} // namespace

std::string markdownFromStyledText(
    const std::string& text,
    const std::vector<StyledRun>& runs) {
  const std::vector<size_t> toByte = utf16ToByteTable(text);
  const auto utf16Size = static_cast<uint32_t>(toByte.size() - 1);

  // Emphasis delimiters cannot open before or close after whitespace
  // (flanking rules), so runs are trimmed inward past edge spaces — the
  // spaces fall outside as plain text. Code-only runs keep their spaces:
  // the code-span serializer pads them instead.
  const auto isEdgeSpace = [&](uint32_t offset) {
    const char c = text[toByte[offset]];
    return c == ' ' || c == '\t';
  };
  std::vector<StyledRun> trimmed;
  trimmed.reserve(runs.size());
  for (StyledRun run : runs) {
    run.start = std::min(run.start, utf16Size);
    run.end = std::min(run.end, utf16Size);
    if ((run.flags & ~MarkInlineCode) != 0) {
      while (run.start < run.end && isEdgeSpace(run.start)) {
        run.start++;
      }
      while (run.end > run.start && isEdgeSpace(run.end - 1)) {
        run.end--;
      }
    }
    if (run.start < run.end) {
      trimmed.push_back(run);
    }
  }

  // Split at every run edge and newline so each piece has constant flags.
  std::set<uint32_t> cuts = {0, utf16Size};
  for (const StyledRun& run : trimmed) {
    cuts.insert(run.start);
    cuts.insert(run.end);
  }
  for (uint32_t u = 0; u < utf16Size; u++) {
    if (text[toByte[u]] == '\n') {
      cuts.insert(u);
      cuts.insert(u + 1);
    }
  }

  MarkdownDocument document;
  Node* root = document.arena.alloc(NodeType::Document);
  document.root = root;

  std::vector<Segment> line;
  auto flushLine = [&]() {
    if (!line.empty()) {
      Node* paragraph = document.arena.alloc(NodeType::Paragraph);
      root->children.push_back(paragraph);
      buildInlineNodes(document, paragraph, line, 0, line.size(), 0);
    }
    line.clear();
  };

  auto it = cuts.begin();
  uint32_t prev = *it;
  for (++it; it != cuts.end(); ++it) {
    const uint32_t next = *it;
    const std::string piece =
        text.substr(toByte[prev], toByte[next] - toByte[prev]);
    if (piece == "\n") {
      flushLine();
    } else if (!piece.empty()) {
      uint32_t flags = 0;
      for (const StyledRun& run : trimmed) {
        if (run.start <= prev && next <= run.end) {
          flags |= run.flags;
        }
      }
      line.push_back({piece, flags});
    }
    prev = next;
  }
  flushLine();

  return astToMarkdown(root);
}

StyledText styledTextFromMarkdown(const std::string& markdown) {
  auto document = parseMarkdown(markdown);
  StyledText out;
  bool atBlockStart = true;
  if (document->root != nullptr) {
    collectStyledChildren(document->root, out, 0, atBlockStart);
  }
  return out;
}

} // namespace fastmarkdown
