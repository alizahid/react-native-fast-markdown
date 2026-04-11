#include "CustomTagParser.hpp"
#include <algorithm>
#include <cctype>

namespace markdown {

void CustomTagParser::skipWhitespace(const std::string &html, size_t &pos) {
  while (pos < html.size() && std::isspace(static_cast<unsigned char>(html[pos]))) {
    ++pos;
  }
}

std::string CustomTagParser::readIdentifier(const std::string &html,
                                            size_t &pos) {
  size_t start = pos;
  while (pos < html.size() &&
         (std::isalnum(static_cast<unsigned char>(html[pos])) ||
          html[pos] == '-' || html[pos] == '_' || html[pos] == '.')) {
    ++pos;
  }
  return html.substr(start, pos - start);
}

std::string CustomTagParser::readQuotedValue(const std::string &html,
                                             size_t &pos) {
  if (pos >= html.size())
    return "";

  char quote = html[pos];
  if (quote != '"' && quote != '\'')
    return "";

  ++pos; // skip opening quote
  size_t start = pos;
  while (pos < html.size() && html[pos] != quote) {
    ++pos;
  }
  std::string value = html.substr(start, pos - start);
  if (pos < html.size())
    ++pos; // skip closing quote
  return value;
}

void CustomTagParser::parseAttributes(
    const std::string &html, size_t &pos,
    std::map<std::string, std::string> &props) {
  while (pos < html.size()) {
    skipWhitespace(html, pos);

    // Check for end of tag
    if (pos >= html.size() || html[pos] == '>' || html[pos] == '/')
      break;

    // Read attribute name
    std::string name = readIdentifier(html, pos);
    if (name.empty())
      break;

    skipWhitespace(html, pos);

    // Check for = sign (attribute with value)
    if (pos < html.size() && html[pos] == '=') {
      ++pos; // skip =
      skipWhitespace(html, pos);

      if (pos < html.size() && (html[pos] == '"' || html[pos] == '\'')) {
        props[name] = readQuotedValue(html, pos);
      } else {
        // Unquoted value — read until whitespace or >
        size_t start = pos;
        while (pos < html.size() && !std::isspace(static_cast<unsigned char>(html[pos])) &&
               html[pos] != '>' && html[pos] != '/') {
          ++pos;
        }
        props[name] = html.substr(start, pos - start);
      }
    } else {
      // Boolean attribute (no value)
      props[name] = "true";
    }
  }
}

bool CustomTagParser::parseTag(const std::string &html, size_t &pos,
                               std::string &tagName,
                               std::map<std::string, std::string> &props,
                               bool &isSelfClosing, bool &isClosing) {
  isSelfClosing = false;
  isClosing = false;
  tagName.clear();
  props.clear();

  if (pos >= html.size() || html[pos] != '<')
    return false;

  ++pos; // skip <

  // Check for closing tag
  if (pos < html.size() && html[pos] == '/') {
    isClosing = true;
    ++pos;
  }

  skipWhitespace(html, pos);

  // Read tag name — must start with uppercase for custom tags
  tagName = readIdentifier(html, pos);
  if (tagName.empty())
    return false;

  if (!isClosing) {
    // Parse attributes
    parseAttributes(html, pos, props);
  }

  skipWhitespace(html, pos);

  // Check for self-closing />
  if (pos < html.size() && html[pos] == '/') {
    isSelfClosing = true;
    ++pos;
  }

  // Expect >
  if (pos < html.size() && html[pos] == '>') {
    ++pos;
    return true;
  }

  return false;
}

bool CustomTagParser::parseSingleTag(const std::string &html,
                                     std::string &tagName,
                                     std::map<std::string, std::string> &props,
                                     bool &isSelfClosing, bool &isClosing) {
  size_t pos = 0;
  skipWhitespace(html, pos);
  return parseTag(html, pos, tagName, props, isSelfClosing, isClosing);
}

bool CustomTagParser::parseTagAt(const std::string &html, size_t &pos,
                                 std::string &tagName,
                                 std::map<std::string, std::string> &props,
                                 bool &isSelfClosing, bool &isClosing) {
  return parseTag(html, pos, tagName, props, isSelfClosing, isClosing);
}

std::vector<ASTNode>
CustomTagParser::parse(const std::string &html,
                       const std::set<std::string> &registeredTags) {
  std::vector<ASTNode> result;

  size_t pos = 0;
  skipWhitespace(html, pos);

  if (pos >= html.size() || html[pos] != '<')
    return result;

  std::string tagName;
  std::map<std::string, std::string> props;
  bool isSelfClosing = false;
  bool isClosing = false;

  size_t tagStart = pos;
  if (!parseTag(html, pos, tagName, props, isSelfClosing, isClosing))
    return result;

  // Check if this is a registered custom tag
  if (registeredTags.find(tagName) == registeredTags.end())
    return result;

  if (isClosing) {
    // Closing tag — return empty (handled by the wrapping tag logic)
    return result;
  }

  ASTNode node(NodeType::CustomTag);
  node.tagName = tagName;
  node.tagProps = props;

  if (isSelfClosing) {
    result.push_back(std::move(node));
    return result;
  }

  // Wrapping tag: collect content until </TagName>
  // The content between open and close tags becomes the text content
  std::string closingTag = "</" + tagName + ">";
  size_t closePos = html.find(closingTag, pos);
  if (closePos != std::string::npos) {
    // Extract inner content as text
    std::string innerContent = html.substr(pos, closePos - pos);
    if (!innerContent.empty()) {
      ASTNode textChild(NodeType::Text);
      textChild.content = innerContent;
      node.children.push_back(std::move(textChild));
    }
  }

  result.push_back(std::move(node));
  return result;
}

} // namespace markdown
