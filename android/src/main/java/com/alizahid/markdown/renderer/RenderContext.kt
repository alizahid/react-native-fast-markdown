package com.alizahid.markdown.renderer

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.AbsoluteSizeSpan
import android.text.style.BackgroundColorSpan
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import android.text.style.UnderlineSpan
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.NodeType
import com.alizahid.markdown.renderer.spans.CustomTypefaceSpan
import com.alizahid.markdown.renderer.spans.LetterSpacingSpan
import com.alizahid.markdown.style.ElementStyle
import com.alizahid.markdown.style.StyleConfig
import com.alizahid.markdown.util.TypefaceResolver

/**
 * Per-render state. Mirrors ios/renderer/RenderContext.
 *
 * Architecture (same as iOS): inline styling lives in the attribute
 * stack. Parent renderers (strong, emphasis, link, …) merge their style
 * into the inherited attributes, push, render children, pop — and never
 * apply character-style spans over their children's ranges. Leaf
 * emitters (text runs, code content, mention labels, autolink URLs)
 * apply the full resolved attribute set to exactly the run they append.
 * This is what lets `**bold *and italic* **` nest correctly — a parent
 * applying spans over the whole child range AFTER rendering would
 * override the inner runs' spans (later spans win at draw time).
 *
 * Paragraph-level properties (lineHeight, textAlign) are NOT carried on
 * the stack — block renderers apply them over their own block range,
 * mirroring iOS's NSParagraphStyle handling.
 */
class RenderContext(
  @JvmField val styleConfig: StyleConfig,
  @JvmField val customTags: Set<String>,
) {

  // Callbacks — wired up by MarkdownView during runtime rendering.
  // The measurer leaves them null.
  var onLinkPress: ((url: String, title: String) -> Unit)? = null
  var onLinkLongPress: ((url: String, title: String) -> Unit)? = null

  // Block state
  var listDepth: Int = 0
  var orderedListIndex: Int = 0
  var currentListIsOrdered: Boolean = false
  var currentListMaxMarkerDigits: Int = 0
  var isInsideBlockquote: Boolean = false
  var isInsideCodeBlock: Boolean = false

  private val stack = ArrayDeque<Map<String, Any?>>()

  fun pushAttributes(attrs: Map<String, Any?>) {
    val merged = if (stack.isEmpty()) attrs.toMutableMap()
    else stack.last().toMutableMap().apply { putAll(attrs) }
    stack.addLast(merged)
  }

  fun popAttributes() {
    if (stack.isNotEmpty()) stack.removeLast()
  }

  fun currentAttributes(): Map<String, Any?> =
    if (stack.isEmpty()) emptyMap() else stack.last()

  fun renderChildren(node: AstNode, into: SpannableStringBuilder) {
    for (child in node.children) {
      RendererFactory.forType(child.type)?.render(child, into, this)
    }
  }

  companion object {

    // Attribute keys for the inline-style stack.
    const val ATTR_TYPEFACE = "tf"
    const val ATTR_FONT_SIZE = "fs"          // Float, raw px
    const val ATTR_COLOR = "color"           // Int
    const val ATTR_BG = "bg"                 // Int — inline highlight
    const val ATTR_LETTER_SPACING = "ls"     // Float, raw px
    const val ATTR_UNDERLINE = "ul"          // Boolean
    const val ATTR_STRIKE = "strike"         // Boolean
    const val ATTR_DECOR_COLOR = "decor"     // Int — underline + strike color

    /**
     * Renders one block AST node to a Spanned. Trims trailing newlines.
     * Thread-safe — used by both the runtime view and the measurer.
     */
    fun renderNodeToSpanned(
      node: AstNode,
      styleConfig: StyleConfig,
      customTags: Set<String>,
      inheritedAttrs: Map<String, Any?>? = null,
    ): Spanned {
      val ctx = RenderContext(styleConfig, customTags)
      ctx.pushAttributes(inheritedAttrs ?: baseAttributesFromStyleConfig(styleConfig))
      val out = SpannableStringBuilder()
      RendererFactory.forType(node.type)?.render(node, out, ctx)
      trimTrailingNewlines(out)
      return out
    }

    fun renderListItemContent(
      item: AstNode,
      isOrdered: Boolean,
      orderedIndex: Int,
      maxMarkerDigits: Int,
      styleConfig: StyleConfig,
      customTags: Set<String>,
      inheritedAttrs: Map<String, Any?>? = null,
    ): Spanned {
      val ctx = RenderContext(styleConfig, customTags)
      ctx.currentListIsOrdered = isOrdered
      ctx.orderedListIndex = orderedIndex
      ctx.currentListMaxMarkerDigits = maxMarkerDigits
      ctx.listDepth = 1
      ctx.pushAttributes(inheritedAttrs ?: baseAttributesFromStyleConfig(styleConfig))
      val out = SpannableStringBuilder()
      RendererFactory.forType(NodeType.ListItem)?.render(item, out, ctx)
      trimTrailingNewlines(out)
      return out
    }

    private fun trimTrailingNewlines(out: SpannableStringBuilder) {
      var end = out.length
      while (end > 0 && out[end - 1] == '\n') end--
      if (end < out.length) out.delete(end, out.length)
    }

    /**
     * Root attribute dictionary from the style config's base: font +
     * size + color. Mirrors iOS `+baseAttributesFromStyleConfig:` —
     * note lineHeight/textAlign are deliberately absent (applied
     * per-block by ParagraphRenderer etc. to avoid clipping headings).
     */
    fun baseAttributesFromStyleConfig(cfg: StyleConfig): Map<String, Any?> {
      val attrs = mutableMapOf<String, Any?>()
      val base = cfg.base
      attrs[ATTR_TYPEFACE] = TypefaceResolver.resolve(base, Typeface.DEFAULT)
      if (!base.fontSize.isNaN() && base.fontSize > 0) attrs[ATTR_FONT_SIZE] = base.fontSize
      base.color?.let { attrs[ATTR_COLOR] = it }
      return attrs
    }

    /**
     * Merges an ElementStyle over inherited attributes, producing the
     * dictionary a renderer pushes for its children. Mirrors iOS
     * `applyStyle:toAttrs:` plus the bold/italic default-trait logic
     * from Strong/EmphasisRenderer.m:
     *
     * - defaultBold/defaultItalic add the trait to the CURRENT font
     *   unless the style explicitly sets fontWeight/fontStyle/fontFamily
     *   (then the style's exact font wins).
     * - defaultMonospace swaps the family to monospace unless the style
     *   sets fontFamily (code / codeBlock default).
     */
    fun mergeStyleAttrs(
      style: ElementStyle?,
      inherited: Map<String, Any?>,
      defaultBold: Boolean = false,
      defaultItalic: Boolean = false,
      defaultMonospace: Boolean = false,
    ): Map<String, Any?> {
      val out = inherited.toMutableMap()
      val baseTf = inherited[ATTR_TYPEFACE] as? Typeface ?: Typeface.DEFAULT

      var tf = if (style != null) TypefaceResolver.resolve(style, baseTf) else baseTf
      if (defaultBold && style?.fontWeight == null && style?.fontFamily == null) {
        tf = Typeface.create(tf, tf.style or Typeface.BOLD)
      }
      if (defaultItalic && style?.fontStyle == null && style?.fontFamily == null) {
        tf = Typeface.create(tf, tf.style or Typeface.ITALIC)
      }
      if (defaultMonospace && style?.fontFamily == null) {
        tf = Typeface.create(Typeface.MONOSPACE, tf.style)
      }
      out[ATTR_TYPEFACE] = tf

      if (style == null) return out

      if (!style.fontSize.isNaN() && style.fontSize > 0) out[ATTR_FONT_SIZE] = style.fontSize
      style.color?.let { out[ATTR_COLOR] = it }
      style.backgroundColor?.let { out[ATTR_BG] = it }
      if (!style.letterSpacing.isNaN() && style.letterSpacing != 0f) {
        out[ATTR_LETTER_SPACING] = style.letterSpacing
      }
      style.textDecorationLine?.let { line ->
        if (line.contains("underline")) out[ATTR_UNDERLINE] = true
        if (line.contains("line-through")) out[ATTR_STRIKE] = true
        style.textDecorationColor?.let { out[ATTR_DECOR_COLOR] = it }
      }
      return out
    }

    /**
     * Applies an attribute dictionary as character-style spans over
     * `[start, end)`. Called by LEAF emitters only, for exactly the run
     * they appended — the Android equivalent of passing the attrs dict
     * to `[NSAttributedString initWithString:attributes:]`.
     */
    fun applyAttributes(
      attrs: Map<String, Any?>,
      into: SpannableStringBuilder,
      start: Int,
      end: Int,
    ) {
      if (start >= end) return
      val flags = Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
      (attrs[ATTR_TYPEFACE] as? Typeface)?.let {
        into.setSpan(CustomTypefaceSpan(it), start, end, flags)
      }
      (attrs[ATTR_FONT_SIZE] as? Float)?.let {
        if (it.isFinite() && it > 0f) {
          into.setSpan(AbsoluteSizeSpan(it.toInt(), false), start, end, flags)
        }
      }
      (attrs[ATTR_COLOR] as? Int)?.let {
        into.setSpan(ForegroundColorSpan(it), start, end, flags)
      }
      (attrs[ATTR_BG] as? Int)?.let {
        into.setSpan(BackgroundColorSpan(it), start, end, flags)
      }
      (attrs[ATTR_LETTER_SPACING] as? Float)?.let {
        into.setSpan(LetterSpacingSpan(it), start, end, flags)
      }
      val decorColor = attrs[ATTR_DECOR_COLOR] as? Int
      if (attrs[ATTR_UNDERLINE] == true) {
        into.setSpan(
          if (decorColor != null) ColoredUnderlineSpan(decorColor) else UnderlineSpan(),
          start, end, flags,
        )
      }
      if (attrs[ATTR_STRIKE] == true) {
        into.setSpan(
          if (decorColor != null) ColoredStrikethroughSpan(decorColor) else StrikethroughSpan(),
          start, end, flags,
        )
      }
    }

    /**
     * Detects an "image-only" paragraph child — used by both the
     * renderer (to swap in a MarkdownImageView block) and the measurer
     * (to reserve image-block height instead of text). Mirrors
     * MarkdownView.imageOnlyParagraphChild: exactly one Image child,
     * everything else whitespace text or soft/hard breaks.
     */
    fun imageOnlyParagraphChild(node: AstNode): AstNode? {
      if (node.type != NodeType.Paragraph) return null
      var imageChild: AstNode? = null
      for (child in node.children) {
        when (child.type) {
          NodeType.Image -> {
            if (imageChild != null) return null
            imageChild = child
          }
          NodeType.Text -> if (child.content.isNotBlank()) return null
          NodeType.SoftBreak, NodeType.LineBreak -> Unit
          else -> return null
        }
      }
      return imageChild
    }
  }
}
