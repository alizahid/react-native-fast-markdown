#include "MarkdownParser.hpp"
#include "CustomTagParser.hpp"
#include "md4c.h"
#include <cctype>
#include <stack>
#include <utility>

namespace markdown {

std::string MarkdownParser::attributeToString(const void *attrPtr) {
  if (!attrPtr)
    return "";
  const auto *attr = static_cast<const MD_ATTRIBUTE *>(attrPtr);
  if (!attr->text || attr->size == 0)
    return "";
  return std::string(attr->text, attr->size);
}

void MarkdownParser::applyBlockDetail(ASTNode &node, int blockType,
                                      void *detail) {
  switch (static_cast<MD_BLOCKTYPE>(blockType)) {
  case MD_BLOCK_H: {
    auto *d = static_cast<MD_BLOCK_H_DETAIL *>(detail);
    node.headingLevel = static_cast<int>(d->level);
    break;
  }
  case MD_BLOCK_UL: {
    auto *d = static_cast<MD_BLOCK_UL_DETAIL *>(detail);
    node.listType = ListType::Unordered;
    node.listTight = d->is_tight != 0;
    break;
  }
  case MD_BLOCK_OL: {
    auto *d = static_cast<MD_BLOCK_OL_DETAIL *>(detail);
    node.listType = ListType::Ordered;
    node.listStart = static_cast<int>(d->start);
    node.listTight = d->is_tight != 0;
    break;
  }
  case MD_BLOCK_LI: {
    auto *d = static_cast<MD_BLOCK_LI_DETAIL *>(detail);
    node.isTaskItem = d->is_task != 0;
    if (node.isTaskItem) {
      node.taskChecked = (d->task_mark == 'x' || d->task_mark == 'X');
    }
    break;
  }
  case MD_BLOCK_CODE: {
    auto *d = static_cast<MD_BLOCK_CODE_DETAIL *>(detail);
    node.codeLanguage = attributeToString(&d->lang);
    break;
  }
  case MD_BLOCK_TABLE: {
    auto *d = static_cast<MD_BLOCK_TABLE_DETAIL *>(detail);
    node.tableColumnCount = static_cast<int>(d->col_count);
    break;
  }
  case MD_BLOCK_TH:
  case MD_BLOCK_TD: {
    auto *d = static_cast<MD_BLOCK_TD_DETAIL *>(detail);
    switch (d->align) {
    case MD_ALIGN_LEFT:
      node.tableAlign = TableAlign::Left;
      break;
    case MD_ALIGN_CENTER:
      node.tableAlign = TableAlign::Center;
      break;
    case MD_ALIGN_RIGHT:
      node.tableAlign = TableAlign::Right;
      break;
    default:
      node.tableAlign = TableAlign::Default;
      break;
    }
    break;
  }
  default:
    break;
  }
}

void MarkdownParser::applySpanDetail(ASTNode &node, int spanType,
                                     void *detail) {
  switch (static_cast<MD_SPANTYPE>(spanType)) {
  case MD_SPAN_A: {
    auto *d = static_cast<MD_SPAN_A_DETAIL *>(detail);
    node.linkUrl = attributeToString(&d->href);
    node.linkTitle = attributeToString(&d->title);
    node.isAutolink = d->is_autolink != 0;
    break;
  }
  case MD_SPAN_IMG: {
    auto *d = static_cast<MD_SPAN_IMG_DETAIL *>(detail);
    node.imageSrc = attributeToString(&d->src);
    node.imageTitle = attributeToString(&d->title);
    break;
  }
  default:
    break;
  }
}

int MarkdownParser::onEnterBlock(int blockType, void *detail,
                                 void *userdata) {
  auto *ctx = static_cast<ParseContext *>(userdata);

  // Skip the top-level MD_BLOCK_DOC — we already have a Document root
  // on the stack. Adding another would create an unnecessary nesting.
  if (static_cast<MD_BLOCKTYPE>(blockType) == MD_BLOCK_DOC) {
    return 0;
  }

  // Skip MD_BLOCK_HTML entirely. We don't need an HtmlBlock node in
  // the AST — the text inside accumulates in ctx.pendingHtml and
  // flushPendingHtml (called from leaveBlock) parses it against the
  // registered custom tags, adding CustomTag or HtmlInline children
  // directly to the real parent on the stack. If we DID push an
  // HtmlBlock here, the parsed children would end up as its children
  // instead of the parent's, and HtmlBlock has no renderer so they
  // would never be shown.
  if (static_cast<MD_BLOCKTYPE>(blockType) == MD_BLOCK_HTML) {
    return 0;
  }

  NodeType type;
  switch (static_cast<MD_BLOCKTYPE>(blockType)) {
  case MD_BLOCK_DOC:
    type = NodeType::Document;
    break;
  case MD_BLOCK_QUOTE:
    type = NodeType::Blockquote;
    break;
  case MD_BLOCK_UL:
  case MD_BLOCK_OL:
    type = NodeType::List;
    break;
  case MD_BLOCK_LI:
    type = NodeType::ListItem;
    break;
  case MD_BLOCK_HR:
    type = NodeType::ThematicBreak;
    break;
  case MD_BLOCK_H:
    type = NodeType::Heading;
    break;
  case MD_BLOCK_CODE:
    type = NodeType::CodeBlock;
    break;
  case MD_BLOCK_HTML:
    type = NodeType::HtmlBlock;
    break;
  case MD_BLOCK_P:
    type = NodeType::Paragraph;
    break;
  case MD_BLOCK_TABLE:
    type = NodeType::Table;
    break;
  case MD_BLOCK_THEAD:
    type = NodeType::TableHead;
    break;
  case MD_BLOCK_TBODY:
    type = NodeType::TableBody;
    break;
  case MD_BLOCK_TR:
    type = NodeType::TableRow;
    break;
  case MD_BLOCK_TH:
  case MD_BLOCK_TD:
    type = NodeType::TableCell;
    break;
  default:
    type = NodeType::Paragraph;
    break;
  }

  ASTNode node(type);
  applyBlockDetail(node, blockType, detail);

  // Push onto the current parent's children
  ASTNode *parent = ctx->stack.back();
  parent->children.push_back(std::move(node));
  ctx->stack.push_back(&parent->children.back());

  return 0;
}

int MarkdownParser::onLeaveBlock(int blockType, void * /*detail*/,
                                 void *userdata) {
  auto *ctx = static_cast<ParseContext *>(userdata);

  // Matches the enter_block skip for MD_BLOCK_DOC
  if (static_cast<MD_BLOCKTYPE>(blockType) == MD_BLOCK_DOC) {
    flushPendingHtml(*ctx);
    return 0;
  }

  // Matches the enter_block skip for MD_BLOCK_HTML — flush the
  // buffered HTML text so any parsed custom tags / text attach to
  // the current real parent, but don't pop the stack (we never
  // pushed for this block).
  if (static_cast<MD_BLOCKTYPE>(blockType) == MD_BLOCK_HTML) {
    flushPendingHtml(*ctx);
    return 0;
  }

  flushPendingHtml(*ctx);
  if (ctx->stack.size() > 1) {
    ctx->stack.pop_back();
  }
  return 0;
}

int MarkdownParser::onEnterSpan(int spanType, void *detail, void *userdata) {
  auto *ctx = static_cast<ParseContext *>(userdata);

  NodeType type;
  switch (static_cast<MD_SPANTYPE>(spanType)) {
  case MD_SPAN_EM:
    type = NodeType::Emphasis;
    break;
  case MD_SPAN_STRONG:
    type = NodeType::Strong;
    break;
  case MD_SPAN_A:
    type = NodeType::Link;
    break;
  case MD_SPAN_IMG:
    type = NodeType::Image;
    break;
  case MD_SPAN_CODE:
    type = NodeType::Code;
    break;
  case MD_SPAN_DEL:
    type = NodeType::Strikethrough;
    break;
  case MD_SPAN_U:
    type = NodeType::Underline;
    break;
  default:
    type = NodeType::HtmlInline;
    break;
  }

  ASTNode node(type);
  applySpanDetail(node, spanType, detail);

  ASTNode *parent = ctx->stack.back();
  parent->children.push_back(std::move(node));
  ctx->stack.push_back(&parent->children.back());

  return 0;
}

int MarkdownParser::onLeaveSpan(int /*spanType*/, void * /*detail*/,
                                void *userdata) {
  auto *ctx = static_cast<ParseContext *>(userdata);
  if (ctx->stack.size() > 1) {
    ctx->stack.pop_back();
  }
  return 0;
}

static bool containsNonWhitespace(const std::string &s) {
  for (char c : s) {
    if (!std::isspace(static_cast<unsigned char>(c))) return true;
  }
  return false;
}

void MarkdownParser::flushPendingHtml(ParseContext &ctx) {
  if (ctx.pendingHtml.empty())
    return;

  const auto &customTags = ctx.options->customTags;

  // Walk the accumulated HTML. Inline HTML usually arrives one tag
  // at a time, in which case we go around this loop once — but a
  // block HTML (e.g. a multi-line <Spoiler>…</Spoiler>) buffers the
  // open tag, content, and close tag all together, and we need to
  // process each piece in order so none get lost.
  size_t pos = 0;
  while (pos < ctx.pendingHtml.size()) {
    size_t tagStart = ctx.pendingHtml.find('<', pos);

    // Emit any text that appears before the next tag.
    size_t textEnd =
        tagStart == std::string::npos ? ctx.pendingHtml.size() : tagStart;
    if (textEnd > pos) {
      std::string text = ctx.pendingHtml.substr(pos, textEnd - pos);
      if (containsNonWhitespace(text)) {
        // Trim the surrounding newlines that block-level HTML like
        // <Spoiler>\ncontent\n</Spoiler> wraps around its content —
        // otherwise they render as blank pseudo-lines. Internal
        // newlines are preserved so multi-line content still wraps.
        size_t first = text.find_first_not_of("\r\n");
        size_t last = text.find_last_not_of("\r\n");
        if (first != std::string::npos && last != std::string::npos) {
          text = text.substr(first, last - first + 1);
        }
        ASTNode textNode(NodeType::Text);
        textNode.content = std::move(text);
        ctx.stack.back()->children.push_back(std::move(textNode));
      }
      pos = textEnd;
    }

    if (tagStart == std::string::npos) break;

    // Try to parse the tag at `pos`.
    size_t saved = pos;
    std::string tagName;
    std::map<std::string, std::string> props;
    bool isSelfClosing = false;
    bool isClosing = false;

    if (!CustomTagParser::parseTagAt(ctx.pendingHtml, pos, tagName, props,
                                     isSelfClosing, isClosing)) {
      // Not a well-formed tag — emit the `<` as literal text and
      // keep walking.
      ASTNode textNode(NodeType::Text);
      textNode.content = "<";
      ctx.stack.back()->children.push_back(std::move(textNode));
      pos = saved + 1;
      continue;
    }

    if (customTags.count(tagName) > 0) {
      if (isClosing) {
        if (ctx.stack.size() > 1) {
          ASTNode *top = ctx.stack.back();
          if (top->type == NodeType::CustomTag && top->tagName == tagName) {
            ctx.stack.pop_back();
          }
        }
      } else if (isSelfClosing) {
        ASTNode node(NodeType::CustomTag);
        node.tagName = tagName;
        node.tagProps = props;
        ctx.stack.back()->children.push_back(std::move(node));
      } else {
        ASTNode node(NodeType::CustomTag);
        node.tagName = tagName;
        node.tagProps = props;
        ctx.stack.back()->children.push_back(std::move(node));
        ctx.stack.push_back(&ctx.stack.back()->children.back());
      }
    } else {
      // Unknown tag — emit as raw HTML inline so it's preserved.
      ASTNode htmlNode(NodeType::HtmlInline);
      htmlNode.content = ctx.pendingHtml.substr(saved, pos - saved);
      ctx.stack.back()->children.push_back(std::move(htmlNode));
    }
  }

  ctx.pendingHtml.clear();
}

int MarkdownParser::onText(int textType, const char *text, unsigned size,
                           void *userdata) {
  auto *ctx = static_cast<ParseContext *>(userdata);

  switch (static_cast<MD_TEXTTYPE>(textType)) {
  case MD_TEXT_BR: {
    ASTNode node(NodeType::LineBreak);
    ctx->stack.back()->children.push_back(std::move(node));
    break;
  }
  case MD_TEXT_SOFTBR: {
    ASTNode node(NodeType::SoftBreak);
    ctx->stack.back()->children.push_back(std::move(node));
    break;
  }
  case MD_TEXT_HTML: {
    // Accumulate HTML content — may arrive in multiple callbacks
    ctx->pendingHtml.append(text, size);
    break;
  }
  default: {
    // Flush any pending HTML before adding normal text
    flushPendingHtml(*ctx);

    ASTNode node(NodeType::Text);
    node.content = std::string(text, size);
    ctx->stack.back()->children.push_back(std::move(node));
    break;
  }
  }

  return 0;
}

ASTNode MarkdownParser::parse(const std::string &markdown,
                              const ParseOptions &options) {
  ParseContext ctx;
  ctx.root = ASTNode(NodeType::Document);
  ctx.stack.push_back(&ctx.root);
  ctx.options = &options;

  unsigned flags = 0;
  if (options.enableTables)
    flags |= MD_FLAG_TABLES;
  if (options.enableStrikethrough)
    flags |= MD_FLAG_STRIKETHROUGH;
  if (options.enableTaskLists)
    flags |= MD_FLAG_TASKLISTS;
  if (options.enableAutolinks)
    flags |= MD_FLAG_PERMISSIVEAUTOLINKS;
  if (options.enableUnderline)
    flags |= MD_FLAG_UNDERLINE;
  if (options.enableLatexMath)
    flags |= MD_FLAG_LATEXMATHSPANS;

  // We need HTML callbacks for custom tags — don't disable HTML
  // flags &= ~MD_FLAG_NOHTML;

  MD_PARSER parser = {};
  parser.abi_version = 0;
  parser.flags = flags;
  parser.enter_block =
      [](MD_BLOCKTYPE type, void *detail, void *userdata) -> int {
    return MarkdownParser::onEnterBlock(static_cast<int>(type), detail,
                                        userdata);
  };
  parser.leave_block =
      [](MD_BLOCKTYPE type, void *detail, void *userdata) -> int {
    return MarkdownParser::onLeaveBlock(static_cast<int>(type), detail,
                                        userdata);
  };
  parser.enter_span =
      [](MD_SPANTYPE type, void *detail, void *userdata) -> int {
    return MarkdownParser::onEnterSpan(static_cast<int>(type), detail,
                                       userdata);
  };
  parser.leave_span =
      [](MD_SPANTYPE type, void *detail, void *userdata) -> int {
    return MarkdownParser::onLeaveSpan(static_cast<int>(type), detail,
                                       userdata);
  };
  parser.text = [](MD_TEXTTYPE type, const MD_CHAR *text, MD_SIZE size,
                   void *userdata) -> int {
    return MarkdownParser::onText(static_cast<int>(type), text, size, userdata);
  };
  parser.debug_log = nullptr;
  parser.syntax = nullptr;

  md_parse(markdown.c_str(), static_cast<MD_SIZE>(markdown.size()), &parser,
           &ctx);

  // Flush any remaining HTML
  flushPendingHtml(ctx);

  return std::move(ctx.root);
}

} // namespace markdown
