#include "AstToMarkdown.h"

#include <algorithm>
#include <cctype>
#include <string>
#include <vector>

namespace fastmarkdown {

namespace {

// ---------------------------------------------------------------------------
// Inline serialization
// ---------------------------------------------------------------------------

// Characters that are always escaped inside text runs: everything our
// parser (md4c + the pre-pass + the inline-extensions scanner) can
// interpret mid-line.
bool needsInlineEscape(char c) {
  switch (c) {
    case '\\':
    case '`':
    case '*':
    case '_':
    case '~':
    case '|':
    case '^':
    case '[':
    case ']':
    case '!':
      return true;
    default:
      return false;
  }
}

// Block-level constructs only bite at the start of a line.
bool needsLineStartEscape(char c) {
  switch (c) {
    case '#':
    case '>':
    case '-':
    case '+':
    case '=':
      return true;
    default:
      return false;
  }
}

struct InlineWriter {
  std::string out;
  bool atLineStart = true;
  // True right after a closing star-emphasis delimiter. A star OPEN written
  // there would merge close+open into one delimiter run and fail to
  // re-parse; open-open runs like ***(em+strong) are fine.
  bool tailIsStarClose = false;

  void raw(const std::string& value) {
    out += value;
    if (!value.empty()) {
      atLineStart = value.back() == '\n';
      tailIsStarClose = false;
    }
  }

  void text(const std::string& value) {
    if (!value.empty()) {
      tailIsStarClose = false;
    }
    for (size_t i = 0; i < value.size(); i++) {
      const char c = value[i];
      if (c == '\n') {
        out += c;
        atLineStart = true;
        continue;
      }
      if (atLineStart) {
        if (needsLineStartEscape(c)) {
          out += '\\';
        } else if (std::isdigit(static_cast<unsigned char>(c))) {
          // "12. x" / "12) x" would open an ordered list.
          size_t j = i;
          while (j < value.size() && std::isdigit(static_cast<unsigned char>(value[j]))) {
            j++;
          }
          if (j < value.size() && (value[j] == '.' || value[j] == ')')) {
            out += value.substr(i, j - i);
            out += '\\';
            out += value[j];
            atLineStart = false;
            i = j;
            continue;
          }
        }
      }
      if (needsInlineEscape(c)) {
        out += '\\';
      }
      out += c;
      if (c != ' ') {
        atLineStart = false;
      }
    }
  }
};

size_t longestBacktickRun(const std::string& value) {
  size_t longest = 0;
  size_t run = 0;
  for (const char c : value) {
    run = c == '`' ? run + 1 : 0;
    longest = std::max(longest, run);
  }
  return longest;
}

void writeInlineCode(InlineWriter& writer, const std::string& content) {
  const std::string fence(longestBacktickRun(content) + 1, '`');
  const bool pad = !content.empty() &&
      (content.front() == '`' || content.back() == '`' || content.front() == ' ' ||
       content.back() == ' ');
  writer.raw(fence);
  if (pad) {
    writer.raw(" ");
  }
  writer.raw(content);
  if (pad) {
    writer.raw(" ");
  }
  writer.raw(fence);
}

void writeLinkDestination(InlineWriter& writer, const std::string& url) {
  const bool needsBrackets =
      url.find(' ') != std::string::npos || url.find('(') != std::string::npos ||
      url.find(')') != std::string::npos;
  if (needsBrackets) {
    writer.raw("<" + url + ">");
  } else {
    writer.raw(url);
  }
}

void writeInlineChildren(InlineWriter& writer, const Node* node);

void writeInlineNode(InlineWriter& writer, const Node* node) {
  switch (node->type) {
    case NodeType::Text:
      writer.text(node->text);
      break;
    case NodeType::SoftBreak:
      writer.raw("\n");
      break;
    case NodeType::HardBreak:
      writer.raw("\\\n");
      break;
    case NodeType::Bold: {
      // Stars by default ('_' cannot open/close emphasis intraword), but
      // flip to underscores when opening right after a star CLOSE: the
      // close+open delimiters would merge into one run and fail to
      // re-parse.
      const bool star = !writer.tailIsStarClose;
      writer.raw(star ? "**" : "__");
      writeInlineChildren(writer, node);
      writer.raw(star ? "**" : "__");
      writer.tailIsStarClose = star;
      break;
    }
    case NodeType::Italic: {
      const bool star = !writer.tailIsStarClose;
      writer.raw(star ? "*" : "_");
      writeInlineChildren(writer, node);
      writer.raw(star ? "*" : "_");
      writer.tailIsStarClose = star;
      break;
    }
    case NodeType::Strikethrough:
      writer.raw("~~");
      writeInlineChildren(writer, node);
      writer.raw("~~");
      break;
    case NodeType::Spoiler:
      writer.raw("||");
      writeInlineChildren(writer, node);
      writer.raw("||");
      break;
    case NodeType::Superscript: {
      // The caret-pair form cannot contain spaces; multi-word content uses
      // the Reddit paren form.
      InlineWriter content;
      content.atLineStart = false;
      writeInlineChildren(content, node);
      if (content.out.find(' ') != std::string::npos) {
        writer.raw("^(");
        writer.raw(content.out);
        writer.raw(")");
      } else {
        writer.raw("^");
        writer.raw(content.out);
        writer.raw("^");
      }
      break;
    }
    case NodeType::Subscript:
      writer.raw("~");
      writeInlineChildren(writer, node);
      writer.raw("~");
      break;
    case NodeType::InlineCode:
      writeInlineCode(writer, node->text);
      break;
    case NodeType::Link:
      // A link whose visible text IS its destination re-parses as a
      // permissive autolink, so emit the bare URL instead of the noisy
      // [url](url) form.
      if (node->children.size() == 1 &&
          node->children[0]->type == NodeType::Text &&
          node->children[0]->text == node->url &&
          (node->url.rfind("http://", 0) == 0 ||
           node->url.rfind("https://", 0) == 0)) {
        writer.raw(node->url);
        break;
      }
      writer.raw("[");
      writeInlineChildren(writer, node);
      writer.raw("](");
      writeLinkDestination(writer, node->url);
      writer.raw(")");
      break;
    case NodeType::Image:
      writer.raw("![");
      writer.text(node->text);
      writer.raw("](");
      writeLinkDestination(writer, node->url);
      writer.raw(")");
      break;
    default:
      writeInlineChildren(writer, node);
      break;
  }
}

void writeInlineChildren(InlineWriter& writer, const Node* node) {
  for (const Node* child : node->children) {
    writeInlineNode(writer, child);
  }
}

std::string inlineMarkdown(const Node* node) {
  InlineWriter writer;
  writeInlineChildren(writer, node);
  return writer.out;
}

std::vector<std::string> splitLines(const std::string& value) {
  std::vector<std::string> lines;
  std::string current;
  for (const char c : value) {
    if (c == '\n') {
      lines.push_back(current);
      current.clear();
    } else {
      current += c;
    }
  }
  lines.push_back(current);
  return lines;
}

// ---------------------------------------------------------------------------
// Block serialization: every block renders to lines; containers prefix them.
// ---------------------------------------------------------------------------

std::vector<std::string> blockLines(const Node* node);

bool isBlockNode(NodeType type) {
  switch (type) {
    case NodeType::Paragraph:
    case NodeType::Heading:
    case NodeType::BlockQuote:
    case NodeType::CodeBlock:
    case NodeType::List:
    case NodeType::Table:
    case NodeType::ThematicBreak:
      return true;
    default:
      return false;
  }
}

// Tight list items carry inline nodes directly (no paragraph wrapper);
// loose items carry blocks. Group runs of inline children into one
// paragraph-like run, blocks get blank-line separation.
std::vector<std::string> listItemLines(const Node* item) {
  std::vector<std::string> lines;
  InlineWriter inlineRun;
  bool wroteAny = false;
  bool lastWasInlineRun = false;

  auto appendLines = [&lines, &wroteAny](std::vector<std::string> next, bool blankBefore) {
    if (wroteAny && blankBefore) {
      lines.emplace_back();
    }
    for (auto& line : next) {
      lines.push_back(std::move(line));
    }
    wroteAny = true;
  };

  auto flushInline = [&inlineRun, &appendLines, &lastWasInlineRun]() {
    if (inlineRun.out.empty()) {
      return;
    }
    appendLines(splitLines(inlineRun.out), true);
    inlineRun = InlineWriter{};
    lastWasInlineRun = true;
  };

  for (const Node* child : item->children) {
    if (isBlockNode(child->type)) {
      flushInline();
      // No blank line after a tight item's inline run: it would turn the
      // list loose and wrap the run in a paragraph on re-parse.
      appendLines(blockLines(child), !lastWasInlineRun);
      lastWasInlineRun = false;
    } else {
      writeInlineNode(inlineRun, child);
    }
  }
  flushInline();

  if (lines.empty()) {
    lines.emplace_back();
  }
  return lines;
}

std::vector<std::string> childBlockLines(const Node* node) {
  std::vector<std::string> lines;
  bool first = true;
  for (const Node* child : node->children) {
    if (!first) {
      lines.emplace_back();
    }
    first = false;
    auto childLines = blockLines(child);
    lines.insert(lines.end(), childLines.begin(), childLines.end());
  }
  return lines;
}

std::vector<std::string> codeBlockLines(const Node* node) {
  std::string content = node->text;
  if (!content.empty() && content.back() == '\n') {
    content.pop_back();
  }
  const size_t fenceLength = std::max<size_t>(3, longestBacktickRun(content) + 1);
  const std::string fence(fenceLength, '`');

  std::vector<std::string> lines;
  lines.push_back(fence + node->url);
  for (auto& line : splitLines(content)) {
    lines.push_back(std::move(line));
  }
  lines.push_back(fence);
  return lines;
}

std::vector<std::string> listLines(const Node* node) {
  std::vector<std::string> lines;
  int index = node->startIndex;
  for (const Node* item : node->children) {
    if (item->type != NodeType::ListItem) {
      continue;
    }

    const std::string marker =
        node->ordered ? std::to_string(index) + ". " : std::string("- ");
    const std::string indent(marker.size(), ' ');

    auto itemLines = listItemLines(item);
    bool firstLine = true;
    for (auto& line : itemLines) {
      if (firstLine) {
        lines.push_back(marker + line);
        firstLine = false;
      } else if (line.empty()) {
        lines.emplace_back();
      } else {
        lines.push_back(indent + line);
      }
    }
    index++;
  }
  return lines;
}

std::string tableCellMarkdown(const Node* cell) {
  InlineWriter writer;
  writer.atLineStart = false;
  writeInlineChildren(writer, cell);
  return writer.out;
}

std::vector<std::string> tableLines(const Node* node) {
  std::vector<std::string> lines;
  const Node* headerRow = nullptr;
  std::vector<const Node*> bodyRows;
  for (const Node* row : node->children) {
    if (row->type != NodeType::TableRow) {
      continue;
    }
    if (row->level == 1 && headerRow == nullptr) {
      headerRow = row;
    } else {
      bodyRows.push_back(row);
    }
  }
  if (headerRow == nullptr) {
    return lines;
  }

  auto rowLine = [](const Node* row) {
    std::string line = "|";
    for (const Node* cell : row->children) {
      line += " " + tableCellMarkdown(cell) + " |";
    }
    return line;
  };

  lines.push_back(rowLine(headerRow));

  std::string separator = "|";
  for (const Node* cell : headerRow->children) {
    switch (static_cast<CellAlign>(cell->level)) {
      case CellAlign::Left:
        separator += " :-- |";
        break;
      case CellAlign::Center:
        separator += " :-: |";
        break;
      case CellAlign::Right:
        separator += " --: |";
        break;
      case CellAlign::Default:
        separator += " --- |";
        break;
    }
  }
  lines.push_back(separator);

  for (const Node* row : bodyRows) {
    lines.push_back(rowLine(row));
  }
  return lines;
}

std::vector<std::string> blockLines(const Node* node) {
  switch (node->type) {
    case NodeType::Paragraph:
      return splitLines(inlineMarkdown(node));

    case NodeType::Heading: {
      const int level = std::clamp<int>(node->level, 1, 6);
      InlineWriter writer;
      writer.atLineStart = false;
      writeInlineChildren(writer, node);
      return {std::string(level, '#') + " " + writer.out};
    }

    case NodeType::BlockQuote: {
      std::vector<std::string> lines;
      for (auto& line : childBlockLines(node)) {
        lines.push_back(line.empty() ? ">" : "> " + line);
      }
      return lines;
    }

    case NodeType::CodeBlock:
      return codeBlockLines(node);

    case NodeType::List:
      return listLines(node);

    case NodeType::Table:
      return tableLines(node);

    case NodeType::ThematicBreak:
      return {"---"};

    default:
      return splitLines(inlineMarkdown(node));
  }
}

} // namespace

std::string astToMarkdown(const Node* root) {
  if (root == nullptr) {
    return "";
  }
  const auto lines = childBlockLines(root);
  std::string out;
  for (size_t i = 0; i < lines.size(); i++) {
    if (i > 0) {
      out += '\n';
    }
    out += lines[i];
  }
  if (!out.empty()) {
    out += '\n';
  }
  return out;
}

} // namespace fastmarkdown
