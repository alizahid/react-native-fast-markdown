package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.ListType
import com.alizahid.markdown.parser.NodeType

/**
 * When a List is rendered inline into an attributed string (e.g. nested
 * inside a blockquote), this renderer drives the per-item state. Mirrors
 * ios/renderer/ListRenderer.m.
 *
 * Top-level lists are typically built at the view layer
 * (MarkdownView.buildSegment) so each item gets its own MarkdownBlockView
 * — but this path supports the inline case too.
 */
object ListRenderer : NodeRenderer {

  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val savedDepth = ctx.listDepth
    val savedIndex = ctx.orderedListIndex
    val savedOrdered = ctx.currentListIsOrdered
    val savedMaxDigits = ctx.currentListMaxMarkerDigits

    val isOrdered = node.listType == ListType.Ordered
    ctx.listDepth = savedDepth + 1
    ctx.orderedListIndex = if (isOrdered) maxOf(1, node.listStart) else 0
    ctx.currentListIsOrdered = isOrdered

    if (isOrdered) {
      val itemCount = node.children.count { it.type == NodeType.ListItem }
      val lastNumber = maxOf(1, ctx.orderedListIndex + itemCount - 1)
      var digits = 1
      var v = lastNumber
      while (v >= 10) { digits++; v /= 10 }
      ctx.currentListMaxMarkerDigits = digits
    } else {
      ctx.currentListMaxMarkerDigits = 0
    }

    ctx.renderChildren(node, into)

    ctx.listDepth = savedDepth
    ctx.orderedListIndex = savedIndex
    ctx.currentListIsOrdered = savedOrdered
    ctx.currentListMaxMarkerDigits = savedMaxDigits
  }
}
