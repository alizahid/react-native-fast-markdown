#include <fbjni/fbjni.h>
#include <jni.h>

#include "ASTNode.hpp"
#include "MarkdownParser.hpp"

using namespace facebook::jni;
using namespace markdown;

namespace {

// Serialize AST to JSON for Kotlin consumption
std::string serializeNode(const ASTNode &node) {
  std::string json = "{";

  json += "\"type\":" + std::to_string(static_cast<int>(node.type));

  if (!node.content.empty()) {
    // Escape special characters in content
    std::string escaped;
    for (char c : node.content) {
      switch (c) {
      case '"':
        escaped += "\\\"";
        break;
      case '\\':
        escaped += "\\\\";
        break;
      case '\n':
        escaped += "\\n";
        break;
      case '\r':
        escaped += "\\r";
        break;
      case '\t':
        escaped += "\\t";
        break;
      default:
        escaped += c;
        break;
      }
    }
    json += ",\"content\":\"" + escaped + "\"";
  }

  if (node.headingLevel > 0)
    json += ",\"headingLevel\":" + std::to_string(node.headingLevel);
  if (node.type == NodeType::List)
    json += std::string(",\"ordered\":") +
            (node.listType == ListType::Ordered ? "true" : "false");
  if (node.listStart != 1)
    json += ",\"listStart\":" + std::to_string(node.listStart);
  if (node.listTight)
    json += ",\"listTight\":true";
  if (node.isTaskItem)
    json += ",\"isTask\":true";
  if (node.taskChecked)
    json += ",\"taskChecked\":true";
  if (!node.codeLanguage.empty())
    json += ",\"lang\":\"" + node.codeLanguage + "\"";
  if (node.tableAlign != TableAlign::Default)
    json += ",\"align\":" + std::to_string(static_cast<int>(node.tableAlign));
  if (node.tableColumnCount > 0)
    json += ",\"cols\":" + std::to_string(node.tableColumnCount);
  if (!node.linkUrl.empty())
    json += ",\"url\":\"" + node.linkUrl + "\"";
  if (!node.linkTitle.empty())
    json += ",\"title\":\"" + node.linkTitle + "\"";
  if (!node.imageSrc.empty())
    json += ",\"src\":\"" + node.imageSrc + "\"";
  if (!node.imageTitle.empty())
    json += ",\"imgTitle\":\"" + node.imageTitle + "\"";
  if (node.isAutolink)
    json += ",\"autolink\":true";
  if (!node.tagName.empty())
    json += ",\"tag\":\"" + node.tagName + "\"";

  if (!node.tagProps.empty()) {
    json += ",\"props\":{";
    bool first = true;
    for (const auto &pair : node.tagProps) {
      if (!first)
        json += ",";
      json += "\"" + pair.first + "\":\"" + pair.second + "\"";
      first = false;
    }
    json += "}";
  }

  if (!node.children.empty()) {
    json += ",\"children\":[";
    for (size_t i = 0; i < node.children.size(); i++) {
      if (i > 0)
        json += ",";
      json += serializeNode(node.children[i]);
    }
    json += "]";
  }

  json += "}";
  return json;
}

} // namespace

extern "C" {

JNIEXPORT jstring JNICALL
Java_com_markdown_parser_ParserBridge_nativeParse(JNIEnv *env, jobject,
                                                  jstring jMarkdown,
                                                  jstring jCustomTags,
                                                  jboolean tables,
                                                  jboolean strikethrough,
                                                  jboolean taskLists,
                                                  jboolean autolinks) {
  const char *markdownChars = env->GetStringUTFChars(jMarkdown, nullptr);
  std::string markdown(markdownChars);
  env->ReleaseStringUTFChars(jMarkdown, markdownChars);

  ParseOptions options;
  options.enableTables = tables;
  options.enableStrikethrough = strikethrough;
  options.enableTaskLists = taskLists;
  options.enableAutolinks = autolinks;

  // Parse custom tags
  if (jCustomTags) {
    const char *tagsChars = env->GetStringUTFChars(jCustomTags, nullptr);
    std::string tags(tagsChars);
    env->ReleaseStringUTFChars(jCustomTags, tagsChars);

    // Tags are comma-separated
    size_t pos = 0;
    while (pos < tags.size()) {
      size_t comma = tags.find(',', pos);
      if (comma == std::string::npos)
        comma = tags.size();
      std::string tag = tags.substr(pos, comma - pos);
      if (!tag.empty())
        options.customTags.insert(tag);
      pos = comma + 1;
    }
  }

  ASTNode ast = MarkdownParser::parse(markdown, options);
  std::string json = serializeNode(ast);

  return env->NewStringUTF(json.c_str());
}
}
