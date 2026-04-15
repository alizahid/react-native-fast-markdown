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
    // Tracks the current ancestry path in the AST.  Each pointer
    // lives in a DIFFERENT parent->children vector, so push_back on
    // the deepest level never invalidates shallower pointers.
    // INVARIANT: a pointer into vector V is always popped from the
    // stack before a new sibling is pushed to V.  This is guaranteed
    // by md4c's strict enter/leave nesting.
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
