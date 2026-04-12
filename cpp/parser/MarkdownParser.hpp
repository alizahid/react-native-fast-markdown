#pragma once

#include "ASTNode.hpp"
#include <set>
#include <string>

namespace markdown {

struct ParseOptions {
  bool enableTables = true;
  bool enableStrikethrough = true;
  bool enableTaskLists = true;
  bool enableAutolinks = true;
  bool enableLatexMath = false;
  std::set<std::string> customTags; // registered custom tag names
};

class MarkdownParser {
public:
  static ASTNode parse(const std::string &markdown,
                       const ParseOptions &options = {});

private:
  struct ParseContext {
    std::vector<ASTNode *> stack;
    ASTNode root;
    const ParseOptions *options = nullptr;
    std::string pendingHtml;
  };

  static int onEnterBlock(int blockType, void *detail, void *userdata);
  static int onLeaveBlock(int blockType, void *detail, void *userdata);
  static int onEnterSpan(int spanType, void *detail, void *userdata);
  static int onLeaveSpan(int spanType, void *detail, void *userdata);
  static int onText(int textType, const char *text, unsigned size,
                    void *userdata);

  static void applyBlockDetail(ASTNode &node, int blockType, void *detail);
  static void applySpanDetail(ASTNode &node, int spanType, void *detail);
  static void flushPendingHtml(ParseContext &ctx);
  static std::string attributeToString(const void *attr);
};

} // namespace markdown
