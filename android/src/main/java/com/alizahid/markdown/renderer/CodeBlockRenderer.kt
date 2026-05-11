package com.alizahid.markdown.renderer

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_FONT_SIZE
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_TYPEFACE
import com.alizahid.markdown.renderer.RenderContext.Companion.resolveAttrs
import com.alizahid.markdown.renderer.spans.MonospaceTypefaceSpan

/**
 * Fenced code block. The block view (MarkdownView builds it) draws the
 * background tint / border / radius — this renderer fills the attributed
 * string with the monospaced code text. Mirrors
 * ios/renderer/CodeBlockRenderer.m.
 */
object CodeBlockRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.codeBlock
    val wasInside = ctx.isInsideCodeBlock
    ctx.isInsideCodeBlock = true
    val resolved = resolveAttrs(style, ctx.currentAttributes())
    ctx.pushAttributes(resolved)

    val start = into.length
    if (node.content.isNotEmpty()) {
      into.append(node.content.trimEnd('\n'))
    } else {
      ctx.renderChildren(node, into)
    }
    val end = into.length

    StyleAttributes.apply(
      style, into, start, end,
      resolved[ATTR_TYPEFACE] as? Typeface,
      resolved[ATTR_FONT_SIZE] as? Float,
    )
    if (style.fontFamily == null) {
      into.setSpan(MonospaceTypefaceSpan(), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
    ctx.popAttributes()
    ctx.isInsideCodeBlock = wasInside
  }
}
