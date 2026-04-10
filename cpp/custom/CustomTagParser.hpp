#pragma once

#include "ASTNode.hpp"
#include <set>
#include <string>
#include <vector>

namespace markdown {

class CustomTagParser {
public:
  // Parse HTML-like custom tags from raw HTML text.
  // Returns parsed ASTNodes for recognized custom tags.
  // Returns empty vector if the HTML doesn't match any registered tag.
  static std::vector<ASTNode> parse(const std::string &html,
                                    const std::set<std::string> &registeredTags);

  // Parse a single HTML tag fragment. Returns true if valid tag found.
  // Used by MarkdownParser to detect opening/closing custom tags
  // delivered as separate MD_TEXT_HTML callbacks.
  static bool parseSingleTag(const std::string &html,
                             std::string &tagName,
                             std::map<std::string, std::string> &props,
                             bool &isSelfClosing, bool &isClosing);

private:
  // Parse a single tag: <TagName prop="value" /> or <TagName prop="value">
  // Returns true if successfully parsed, fills outNode.
  // Sets isSelfClosing to true for self-closing tags.
  // Sets isClosing to true for </TagName> close tags.
  static bool parseTag(const std::string &html, size_t &pos,
                       std::string &tagName,
                       std::map<std::string, std::string> &props,
                       bool &isSelfClosing, bool &isClosing);

  // Parse tag attributes: prop="value" prop='value' prop
  static void parseAttributes(const std::string &html, size_t &pos,
                               std::map<std::string, std::string> &props);

  // Skip whitespace
  static void skipWhitespace(const std::string &html, size_t &pos);

  // Read an identifier (tag name or attribute name)
  static std::string readIdentifier(const std::string &html, size_t &pos);

  // Read a quoted string value
  static std::string readQuotedValue(const std::string &html, size_t &pos);
};

} // namespace markdown
