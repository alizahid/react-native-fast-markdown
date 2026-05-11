package com.alizahid.markdown.renderer

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.NodeType
import com.alizahid.markdown.style.ElementStyle
import com.alizahid.markdown.style.StyleConfig
import com.alizahid.markdown.util.TypefaceResolver

/**
 * Per-render state. Mirrors ios/renderer/RenderContext. The attribute
 * stack tracks inherited inline styling for nested spans (e.g. a `<strong>`
 * inside a `<em>` inside a heading) — each renderer pushes its style on
 * entry and pops on exit; spans get applied to the range they covered
 * with the resolved (top-of-stack) attributes.
 *
 * Static entry points are thread-safe so the shadow-thread measurer and
 * the main-thread view path can share rendering logic.
 */
class RenderContext(
  @JvmField val styleConfig: StyleConfig,
  @JvmField val customTags: Set<String>,
) {

  // Callbacks — wired up by MarkdownView during runtime rendering.
  // The measurer leaves them null.
  var onLinkPress: ((url: String, title: String) -> Unit)? = null
  var onLinkLongPress: ((url: String, title: String) -> Unit)? = null
  var onMentionPress: ((payload: Map<String, String>) -> Unit)? = null

  // Block state
  var listDepth: Int = 0
  var orderedListIndex: Int = 0
  var currentListIsOrdered: Boolean = false
  var currentListMaxMarkerDigits: Int = 1
  var isInsideBlockquote: Boolean = false
  var isInsideCodeBlock: Boolean = false

  // Attribute stack: each frame is a snapshot of inherited attrs.
  // Top of stack is `currentAttributes()`.
  private val stack = ArrayDeque<MutableMap<String, Any?>>()

  fun pushAttributes(attrs: Map<String, Any?>) {
    val top = if (stack.isEmpty()) mutableMapOf() else stack.last().toMutableMap()
    top.putAll(attrs)
    stack.addLast(top)
  }

  fun popAttributes() {
    if (stack.isNotEmpty()) stack.removeLast()
  }

  fun currentAttributes(): Map<String, Any?> =
    if (stack.isEmpty()) emptyMap() else stack.last()

  fun renderChildren(node: AstNode, into: SpannableStringBuilder) {
    for (child in node.children) {
      val r = RendererFactory.forType(child.type)
      r?.render(child, into, this)
    }
  }

  companion object {

    /**
     * Renders one block AST node to a Spanned. Trims trailing newline.
     * Thread-safe — used by both the runtime view and the measurer.
     */
    fun renderNodeToSpanned(
      node: AstNode,
      styleConfig: StyleConfig,
      customTags: Set<String>,
      inheritedAttrs: Map<String, Any?>? = null,
    ): Spanned {
      val ctx = RenderContext(styleConfig, customTags)
      val baseAttrs = inheritedAttrs ?: baseAttributesFromStyleConfig(styleConfig)
      ctx.pushAttributes(baseAttrs)
      val out = SpannableStringBuilder()
      val r = RendererFactory.forType(node.type)
      r?.render(node, out, ctx)
      // Trim a single trailing newline if present
      val len = out.length
      if (len > 0 && out[len - 1] == '\n') out.delete(len - 1, len)
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
      val baseAttrs = inheritedAttrs ?: baseAttributesFromStyleConfig(styleConfig)
      ctx.pushAttributes(baseAttrs)
      val out = SpannableStringBuilder()
      val r = RendererFactory.forType(NodeType.ListItem)
      r?.render(item, out, ctx)
      val len = out.length
      if (len > 0 && out[len - 1] == '\n') out.delete(len - 1, len)
      return out
    }

    /**
     * Builds the root attribute dictionary from a style config's base —
     * font + color + paragraph alignment. Mirrors iOS
     * `+baseAttributesFromStyleConfig:`.
     */
    fun baseAttributesFromStyleConfig(cfg: StyleConfig): Map<String, Any?> {
      val attrs = mutableMapOf<String, Any?>()
      val base = cfg.base
      val tf = TypefaceResolver.resolve(base, Typeface.DEFAULT)
      attrs[ATTR_TYPEFACE] = tf
      if (!base.fontSize.isNaN() && base.fontSize > 0) {
        attrs[ATTR_FONT_SIZE] = base.fontSize
      }
      base.color?.let { attrs[ATTR_COLOR] = it }
      if (!base.lineHeight.isNaN() && base.lineHeight > 0) {
        attrs[ATTR_LINE_HEIGHT] = base.lineHeight
      }
      base.textAlign?.let { attrs[ATTR_ALIGN] = it }
      return attrs
    }

    // Attribute keys — used as plain string keys in the stack maps.
    const val ATTR_TYPEFACE = "tf"
    const val ATTR_FONT_SIZE = "fs"
    const val ATTR_COLOR = "color"
    const val ATTR_LINE_HEIGHT = "lh"
    const val ATTR_ALIGN = "align"

    /**
     * Detects an "image-only" paragraph child — used by both the
     * renderer (to swap in a MarkdownImageView block) and the
     * measurer (to reserve image-block height instead of text). Mirrors
     * MarkdownView.imageOnlyParagraphChild.
     */
    fun imageOnlyParagraphChild(node: AstNode): AstNode? {
      if (node.type != NodeType.Paragraph) return null
      if (node.children.size != 1) return null
      val only = node.children[0]
      return if (only.type == NodeType.Image) only else null
    }

    fun resolveAttrs(
      style: ElementStyle?,
      inheritedAttrs: Map<String, Any?>,
    ): Map<String, Any?> {
      if (style == null) return inheritedAttrs
      val out = inheritedAttrs.toMutableMap()
      // font cascade
      val baseTf = inheritedAttrs[ATTR_TYPEFACE] as? Typeface ?: Typeface.DEFAULT
      out[ATTR_TYPEFACE] = TypefaceResolver.resolve(style, baseTf)
      if (!style.fontSize.isNaN() && style.fontSize > 0) out[ATTR_FONT_SIZE] = style.fontSize
      style.color?.let { out[ATTR_COLOR] = it }
      if (!style.lineHeight.isNaN() && style.lineHeight > 0) out[ATTR_LINE_HEIGHT] = style.lineHeight
      style.textAlign?.let { out[ATTR_ALIGN] = it }
      return out
    }
  }
}
