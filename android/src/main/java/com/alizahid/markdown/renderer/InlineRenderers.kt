package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import android.text.Spanned
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_DECOR_COLOR
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_STRIKE
import com.alizahid.markdown.renderer.RenderContext.Companion.applyAttributes
import com.alizahid.markdown.renderer.RenderContext.Companion.mergeStyleAttrs
import com.alizahid.markdown.renderer.spans.LinkClickableSpan

/**
 * Inline renderers. Mirrors the *Renderer.m files in ios/renderer/:
 * parents merge + push their style and render children; ONLY leaf
 * emitters apply character spans, to exactly the run they append.
 */

object DocumentRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    ctx.renderChildren(node, into)
  }
}

object TextRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    if (node.content.isEmpty()) return
    val start = into.length
    into.append(node.content)
    applyAttributes(ctx.currentAttributes(), into, start, into.length)
  }
}

object SoftBreakRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val start = into.length
    into.append(' ')
    applyAttributes(ctx.currentAttributes(), into, start, into.length)
  }
}

object LineBreakRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val start = into.length
    into.append('\n')
    applyAttributes(ctx.currentAttributes(), into, start, into.length)
  }
}

object StrongRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    ctx.pushAttributes(
      mergeStyleAttrs(ctx.styleConfig.strong, ctx.currentAttributes(), defaultBold = true),
    )
    ctx.renderChildren(node, into)
    ctx.popAttributes()
  }
}

object EmphasisRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    ctx.pushAttributes(
      mergeStyleAttrs(ctx.styleConfig.emphasis, ctx.currentAttributes(), defaultItalic = true),
    )
    ctx.renderChildren(node, into)
    ctx.popAttributes()
  }
}

object StrikethroughRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.strikethrough
    val merged = mergeStyleAttrs(style, ctx.currentAttributes()).toMutableMap()
    // The strike trait is the whole point of this renderer — always on,
    // regardless of textDecorationLine. Color cascades
    // textDecorationColor → style color → text color (iOS
    // StrikethroughRenderer.m).
    merged[ATTR_STRIKE] = true
    (style.textDecorationColor ?: style.color)?.let { merged[ATTR_DECOR_COLOR] = it }
    ctx.pushAttributes(merged)
    ctx.renderChildren(node, into)
    ctx.popAttributes()
  }
}

object CodeRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    ctx.pushAttributes(
      mergeStyleAttrs(ctx.styleConfig.code, ctx.currentAttributes(), defaultMonospace = true),
    )
    if (node.content.isNotEmpty()) {
      val start = into.length
      into.append(node.content)
      applyAttributes(ctx.currentAttributes(), into, start, into.length)
    } else {
      ctx.renderChildren(node, into)
    }
    ctx.popAttributes()
  }
}

object LinkRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    ctx.pushAttributes(mergeStyleAttrs(ctx.styleConfig.link, ctx.currentAttributes()))
    val start = into.length
    if (node.children.isEmpty()) {
      // Autolinks: the URL is the visible text.
      into.append(node.linkUrl)
      applyAttributes(ctx.currentAttributes(), into, start, into.length)
    } else {
      ctx.renderChildren(node, into)
    }
    val end = into.length
    if (end > start) {
      into.setSpan(
        LinkClickableSpan(node.linkUrl, node.linkTitle, ctx.onLinkPress, ctx.onLinkLongPress),
        start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
      )
    }
    ctx.popAttributes()
  }
}
