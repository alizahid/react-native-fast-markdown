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
    // Phase 3
    NodeType.List to ListRenderer,
    NodeType.ListItem to ListItemRenderer,
    NodeType.Blockquote to BlockquoteRenderer,
    NodeType.CodeBlock to CodeBlockRenderer,
    // ThematicBreak / Table* are rendered at the view layer (no
    // attributed-string output) — the buildSegment switch handles them.
    // Image stays as TextRenderer (alt text) for inline contexts;
    // block-level images go through MarkdownView.buildImageSegment.
    NodeType.Image to TextRenderer,
    // Phase 5
    NodeType.CustomTag to CustomTagRenderer,
  )

  fun forType(type: NodeType): NodeRenderer? = registry[type]
}
