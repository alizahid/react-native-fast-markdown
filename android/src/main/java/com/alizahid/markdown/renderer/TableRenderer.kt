package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.NodeType

/**
 * Text fallback for tables when rendered inline (e.g. nested inside a
 * blockquote — top-level tables go through the dedicated table view
 * in MarkdownView.buildTableSegment). Mirrors
 * ios/renderer/TableRenderer.m: cells separated by ` | `, rows
 * separated by newlines.
 */
object TableRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    when (node.type) {
      NodeType.Table, NodeType.TableHead, NodeType.TableBody -> ctx.renderChildren(node, into)

      NodeType.TableRow -> {
        into.append("| ")
        for (cell in node.children) {
          if (cell.type == NodeType.TableCell) {
            ctx.renderChildren(cell, into)
          }
          into.append(" | ")
        }
        into.append('\n')
      }

      NodeType.TableCell -> ctx.renderChildren(node, into)

      else -> ctx.renderChildren(node, into)
    }
  }
}
