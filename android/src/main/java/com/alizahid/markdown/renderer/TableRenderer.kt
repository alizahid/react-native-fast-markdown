package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.NodeType
import com.alizahid.markdown.renderer.RenderContext.Companion.applyAttributes

/**
 * Text fallback for tables rendered inline (e.g. nested inside a
 * blockquote — top-level tables get the dedicated MarkdownTableView in
 * MarkdownView.buildTableSegment). Mirrors ios/renderer/TableRenderer.m:
 * cells separated by ` | `, rows on their own line.
 */
object TableRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    when (node.type) {
      NodeType.TableRow -> {
        appendWithAttrs(into, "| ", ctx)
        for (cell in node.children) {
          if (cell.type == NodeType.TableCell) {
            ctx.renderChildren(cell, into)
          }
          appendWithAttrs(into, " | ", ctx)
        }
        appendWithAttrs(into, "\n", ctx)
      }
      else -> ctx.renderChildren(node, into)
    }
  }

  private fun appendWithAttrs(into: SpannableStringBuilder, text: String, ctx: RenderContext) {
    val start = into.length
    into.append(text)
    applyAttributes(ctx.currentAttributes(), into, start, into.length)
  }
}
