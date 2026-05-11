package com.alizahid.markdown.renderer

import com.alizahid.markdown.parser.NodeType

/**
 * Static lookup table: AST node type → renderer singleton. Mirrors
 * ios/renderer/RendererFactory.m. Renderers are stateless — per-render
 * state lives on the RenderContext.
 *
 * Block-level nodes (Blockquote, List, Table, ThematicBreak) ALSO have
 * a renderer entry so they degrade gracefully when rendered inline
 * (e.g. nested inside a CustomTag); top-level use goes through
 * MarkdownView.buildSegment which builds dedicated views.
 *
 * HtmlBlock / HtmlInline are intentionally absent — iOS has no entry
 * either; unknown HTML falls back to no-op (its raw content stays
 * invisible).
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
    NodeType.CodeBlock to CodeBlockRenderer,
    NodeType.Link to LinkRenderer,
    NodeType.List to ListRenderer,
    NodeType.ListItem to ListItemRenderer,
    NodeType.Blockquote to BlockquoteRenderer,
    NodeType.Image to ImageRenderer,
    NodeType.Table to TableRenderer,
    NodeType.TableHead to TableRenderer,
    NodeType.TableBody to TableRenderer,
    NodeType.TableRow to TableRenderer,
    NodeType.TableCell to TableRenderer,
    NodeType.CustomTag to CustomTagRenderer,
  )

  fun forType(type: NodeType): NodeRenderer? = registry[type]
}
