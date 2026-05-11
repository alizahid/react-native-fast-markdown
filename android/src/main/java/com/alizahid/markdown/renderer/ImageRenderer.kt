package com.alizahid.markdown.renderer

import android.graphics.Color
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.NodeType

/**
 * Inline image fallback. Block-level images (paragraph with single
 * Image child) are diverted to MarkdownImageView at the view layer
 * (see MarkdownView.buildImageSegment); this renderer covers the
 * inline case — appends "[alt]" with a muted color so the user knows
 * something was there. Mirrors ios/renderer/ImageRenderer.m.
 */
object ImageRenderer : NodeRenderer {
  // Approximation of iOS [UIColor secondaryLabelColor] in light mode
  // (#3C3C432A → 0x3C * 0.6 alpha against white ≈ this gray).
  private val secondaryLabelColor: Int = Color.argb(0x99, 0x3C, 0x3C, 0x43)

  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val altText = buildString {
      for (child in node.children) {
        if (child.type == NodeType.Text) append(child.content)
      }
    }
    val display = if (altText.isEmpty()) "[Image]" else "[$altText]"
    val start = into.length
    into.append(display)
    into.append('\n')
    val end = into.length
    into.setSpan(
      ForegroundColorSpan(secondaryLabelColor), start, end,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
  }
}
