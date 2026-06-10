package com.alizahid.markdown.renderer

import android.graphics.Color
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.NodeType
import com.alizahid.markdown.renderer.RenderContext.Companion.applyAttributes

/**
 * Inline image fallback. Block-level images (paragraph with a single
 * Image child) are diverted to MarkdownImageView at the view layer; this
 * renderer covers inline images — appends "[alt]" in a muted color so
 * the reader knows something was there. Mirrors
 * ios/renderer/ImageRenderer.m.
 */
object ImageRenderer : NodeRenderer {
  // Approximation of iOS [UIColor secondaryLabelColor] (light mode).
  private val SECONDARY_LABEL_COLOR = Color.argb(0x99, 0x3C, 0x3C, 0x43)

  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val altText = buildString {
      for (child in node.children) {
        if (child.type == NodeType.Text) append(child.content)
      }
    }
    val display = if (altText.isEmpty()) "[Image]" else "[$altText]"

    val start = into.length
    into.append(display).append('\n')
    val end = into.length
    applyAttributes(ctx.currentAttributes(), into, start, end)
    // Muted color set AFTER the inherited attrs so it wins — mirrors the
    // iOS attrs dict overriding NSForegroundColorAttributeName.
    into.setSpan(ForegroundColorSpan(SECONDARY_LABEL_COLOR), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
  }
}
