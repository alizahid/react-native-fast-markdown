package com.alizahid.markdown.renderer

import com.alizahid.markdown.parser.NodeType

/**
 * Static lookup table: AST node type → renderer singleton.
 * Mirrors ios/renderer/RendererFactory. Renderers are stateless; per-render
 * state lives on the RenderContext.
 */
object RendererFactory {

  private val registry: Map<NodeType, NodeRenderer> = mapOf(
    NodeType.Document to DocumentRenderer,
    NodeType.Paragraph to ParagraphRenderer,
    NodeType.Heading to HeadingRenderer,
    NodeType.Text to TextRenderer,
    NodeType.SoftBreak to SoftBreakRenderer,
    NodeType.LineBreak to LineBreakRenderer,
    NodeType.Strong to StrongRenderer,
    NodeType.Emphasis to EmphasisRenderer,
    NodeType.Strikethrough to StrikethroughRenderer,
    NodeType.Code to CodeRenderer,
    NodeType.Link to LinkRenderer,
    NodeType.HtmlInline to HtmlPassThroughRenderer,
    NodeType.HtmlBlock to HtmlPassThroughRenderer,
    // Phase 3 wires up List, ListItem, Blockquote, CodeBlock, ThematicBreak, Table*
    // Phase 4 wires up Image
    // Phase 5 wires up CustomTag
  )

  fun forType(type: NodeType): NodeRenderer? = registry[type]
}
