package com.alizahid.markdown.renderer

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_COLOR
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_FONT_SIZE
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_TYPEFACE
import com.alizahid.markdown.renderer.spans.CodeBackgroundSpan
import com.alizahid.markdown.renderer.spans.LinkClickableSpan
import com.alizahid.markdown.renderer.spans.MonospaceTypefaceSpan
import com.alizahid.markdown.style.ElementStyle
import com.alizahid.markdown.util.TypefaceResolver

/**
 * Inline / leaf renderers — emit text into the SpannableStringBuilder
 * and apply style spans over the range they produced. Mirrors the
 * individual *Renderer.m files in ios/renderer/. Block-level renderers
 * (paragraph, heading, list, table, ...) live in BlockRenderers.kt.
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
    applyCurrentAttributes(ctx, into, start, into.length)
  }
}

object SoftBreakRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    into.append(' ')
  }
}

object LineBreakRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    into.append('\n')
  }
}

// HtmlBlock / HtmlInline are no longer mapped in RendererFactory —
// iOS doesn't register them either; their raw content stays invisible
// (custom tags are routed via CustomTagRenderer, not this path).

object StrongRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.strong
    val attrs = ctx.currentAttributes()
    val resolvedAttrs = applyStyleToAttrs(ctx, style, attrs, defaultBold = true)
    ctx.pushAttributes(resolvedAttrs)
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    // Apply the resolved style as spans over the produced range. The
    // children only apply *their* inner styles; the strong's typeface/
    // color is the bold cascade reflected via attrs.
    StyleAttributes.apply(
      style, into, start, end,
      resolvedAttrs[ATTR_TYPEFACE] as? Typeface,
      resolvedAttrs[ATTR_FONT_SIZE] as? Float,
    )
    ctx.popAttributes()
  }
}

object EmphasisRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.emphasis
    val attrs = ctx.currentAttributes()
    val resolvedAttrs = applyStyleToAttrs(ctx, style, attrs, defaultItalic = true)
    ctx.pushAttributes(resolvedAttrs)
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    StyleAttributes.apply(
      style, into, start, end,
      resolvedAttrs[ATTR_TYPEFACE] as? Typeface,
      resolvedAttrs[ATTR_FONT_SIZE] as? Float,
    )
    ctx.popAttributes()
  }
}

object StrikethroughRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.strikethrough
    val attrs = ctx.currentAttributes()
    val resolvedAttrs = applyStyleToAttrs(ctx, style, attrs)
    ctx.pushAttributes(resolvedAttrs)
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    StyleAttributes.apply(
      style, into, start, end,
      resolvedAttrs[ATTR_TYPEFACE] as? Typeface,
      resolvedAttrs[ATTR_FONT_SIZE] as? Float,
    )
    // Strike trait is the whole point of this renderer — always draw it,
    // regardless of whether the style's textDecorationLine was set.
    // Color falls back through textDecorationColor → text color (matches
    // iOS: `strikeColor = style.textDecorationColor ?: style.color`).
    val strikeColor = style.textDecorationColor ?: style.color
    val span = if (strikeColor != null) ColoredStrikethroughSpan(strikeColor)
    else android.text.style.StrikethroughSpan()
    into.setSpan(span, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    ctx.popAttributes()
  }
}

object CodeRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.code
    val start = into.length
    if (node.content.isNotEmpty()) {
      into.append(node.content)
    } else {
      ctx.renderChildren(node, into)
    }
    val end = into.length
    val attrs = ctx.currentAttributes()
    val resolvedAttrs = applyStyleToAttrs(ctx, style, attrs)
    StyleAttributes.apply(
      style, into, start, end,
      resolvedAttrs[ATTR_TYPEFACE] as? Typeface,
      resolvedAttrs[ATTR_FONT_SIZE] as? Float,
    )
    // Always set monospace if no family override; mirrors iOS default.
    if (style.fontFamily == null) {
      into.setSpan(MonospaceTypefaceSpan(), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
    // Background tint via custom span so wrapping lines all carry it.
    style.backgroundColor?.let {
      into.setSpan(CodeBackgroundSpan(it), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
  }
}

object LinkRenderer : NodeRenderer {
  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.link
    val attrs = ctx.currentAttributes()
    val resolvedAttrs = applyStyleToAttrs(ctx, style, attrs)
    ctx.pushAttributes(resolvedAttrs)
    val start = into.length
    if (node.children.isEmpty()) {
      // Autolinks: use the URL as the visible text.
      into.append(node.linkUrl)
    } else {
      ctx.renderChildren(node, into)
    }
    val end = into.length
    StyleAttributes.apply(
      style, into, start, end,
      resolvedAttrs[ATTR_TYPEFACE] as? Typeface,
      resolvedAttrs[ATTR_FONT_SIZE] as? Float,
    )
    into.setSpan(
      LinkClickableSpan(node.linkUrl, node.linkTitle, ctx.onLinkPress, ctx.onLinkLongPress),
      start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
    ctx.popAttributes()
  }
}

// --- helpers ---

private fun applyStyleToAttrs(
  ctx: RenderContext,
  style: ElementStyle,
  inheritedAttrs: Map<String, Any?>,
  defaultBold: Boolean = false,
  defaultItalic: Boolean = false,
): Map<String, Any?> {
  val out = inheritedAttrs.toMutableMap()
  val baseTf = inheritedAttrs[ATTR_TYPEFACE] as? Typeface ?: Typeface.DEFAULT

  // Apply default bold/italic if the style doesn't override.
  val effectiveStyle = if (defaultBold || defaultItalic) {
    if ((defaultBold && style.fontWeight == null && style.fontFamily == null) ||
      (defaultItalic && style.fontStyle == null && style.fontFamily == null)) {
      val merged = ElementStyle().apply {
        // Copy fields we care about
        color = style.color; fontFamily = style.fontFamily; fontSize = style.fontSize
        fontStyle = style.fontStyle; fontWeight = style.fontWeight
        letterSpacing = style.letterSpacing; lineHeight = style.lineHeight
        textAlign = style.textAlign; textDecorationColor = style.textDecorationColor
        textDecorationLine = style.textDecorationLine; textDecorationStyle = style.textDecorationStyle
        backgroundColor = style.backgroundColor
      }
      if (defaultBold && merged.fontWeight == null && merged.fontFamily == null) merged.fontWeight = "bold"
      if (defaultItalic && merged.fontStyle == null && merged.fontFamily == null) merged.fontStyle = "italic"
      merged
    } else style
  } else style

  out[ATTR_TYPEFACE] = TypefaceResolver.resolve(effectiveStyle, baseTf)
  if (!effectiveStyle.fontSize.isNaN() && effectiveStyle.fontSize > 0) {
    out[ATTR_FONT_SIZE] = effectiveStyle.fontSize
  }
  effectiveStyle.color?.let { out[ATTR_COLOR] = it }
  return out
}

internal fun applyCurrentAttributes(
  ctx: RenderContext,
  into: SpannableStringBuilder,
  start: Int,
  end: Int,
) {
  if (start >= end) return
  val attrs = ctx.currentAttributes()
  val tf = attrs[ATTR_TYPEFACE] as? Typeface
  val fs = attrs[ATTR_FONT_SIZE] as? Float
  val color = attrs[ATTR_COLOR] as? Int
  val flags = Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
  if (tf != null) into.setSpan(com.alizahid.markdown.renderer.spans.CustomTypefaceSpan(tf), start, end, flags)
  if (fs != null && fs.isFinite() && fs > 0f) {
    into.setSpan(android.text.style.AbsoluteSizeSpan(fs.toInt(), false), start, end, flags)
  }
  if (color != null) into.setSpan(android.text.style.ForegroundColorSpan(color), start, end, flags)
}
