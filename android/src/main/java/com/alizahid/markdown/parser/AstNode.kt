package com.alizahid.markdown.parser

/**
 * Mirrors `markdown::NodeType` in cpp/parser/ASTNode.hpp. Ordinal order
 * MUST stay in sync — JNI looks up values by ordinal.
 */
enum class NodeType {
  Document,
  Paragraph,
  Heading,
  Blockquote,
  List,
  ListItem,
  CodeBlock,
  ThematicBreak,
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableCell,
  HtmlBlock,
  Text,
  SoftBreak,
  LineBreak,
  Code,
  Emphasis,
  Strong,
  Strikethrough,
  Link,
  Image,
  HtmlInline,
  CustomTag,
}

enum class ListType {
  Ordered,
  Unordered,
}

enum class TableAlign {
  Default,
  Left,
  Center,
  Right,
}

/**
 * Kotlin mirror of `markdown::ASTNode`. Built directly in JNI; `@JvmField`
 * keeps field-id lookup paths cheap. Not a data class — child lists make
 * structural equality expensive and unnecessary.
 */
class AstNode(
  @JvmField val type: NodeType,
  @JvmField val content: String,
  @JvmField val headingLevel: Int,
  @JvmField val listType: ListType,
  @JvmField val listStart: Int,
  @JvmField val listTight: Boolean,
  @JvmField val codeLanguage: String,
  @JvmField val tableAlign: TableAlign,
  @JvmField val tableColumnCount: Int,
  @JvmField val linkUrl: String,
  @JvmField val linkTitle: String,
  @JvmField val imageSrc: String,
  @JvmField val imageTitle: String,
  @JvmField val isAutolink: Boolean,
  @JvmField val tagName: String,
  @JvmField val tagProps: Map<String, String>,
  @JvmField val children: List<AstNode>,
)
