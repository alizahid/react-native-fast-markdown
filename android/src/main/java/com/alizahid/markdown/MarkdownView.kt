package com.alizahid.markdown

import android.content.Context
import android.view.ViewGroup
import com.alizahid.markdown.events.MarkdownEventDispatcher
import com.alizahid.markdown.jni.MarkdownParserJni
import com.alizahid.markdown.measure.MeasurementCache
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.parser.NodeType
import com.alizahid.markdown.renderer.RenderContext
import com.alizahid.markdown.style.StyleConfig
import com.alizahid.markdown.view.MarkdownBlockView
import com.alizahid.markdown.view.MarkdownSegmentStack
import com.alizahid.markdown.view.MarkdownTableLayout
import com.alizahid.markdown.view.MarkdownTableView
import com.alizahid.markdown.view.MarkdownTextView
import com.alizahid.markdown.parser.ListType
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.views.view.ReactViewGroup

/**
 * Top-level Fabric component view. Owns a MarkdownSegmentStack child
 * that holds one view per top-level block. On every prop change we
 * reparse + rebuild the segments; the MeasurementCache keeps re-renders
 * fast.
 *
 * Phase 2: renders Paragraph + Heading; everything else is dropped.
 * Phase 3+ broadens the segment-building switch.
 */
class MarkdownView(context: Context) : ReactViewGroup(context) {

  private val outer = MarkdownBlockView(context)
  private val stack = MarkdownSegmentStack(context)

  private var currentMarkdown: String = ""
  private var currentStyles: String? = null
  private var currentCustomTags: Set<String> = emptySet()
  private var currentImagesKey: String = ""

  /** Set by MarkdownViewManager.updateState — used to trigger remeasure. */
  var stateWrapper: StateWrapper? = null

  private var measureRevision: Int = 0

  init {
    outer.addView(
      stack,
      ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
      ),
    )
    addView(
      outer,
      LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT),
    )
  }

  fun setMarkdown(value: String?) {
    val next = value ?: ""
    if (next == currentMarkdown) return
    currentMarkdown = next
    rebuild()
  }

  fun setStyles(value: String?) {
    if (value == currentStyles) return
    currentStyles = value
    rebuild()
  }

  fun setCustomTags(value: ReadableArray?) {
    val set = mutableSetOf<String>()
    if (value != null) {
      for (i in 0 until value.size()) {
        value.getString(i)?.let { set.add(it) }
      }
    }
    if (set == currentCustomTags) return
    currentCustomTags = set
    rebuild()
  }

  fun setImages(value: ReadableArray?) {
    val key = buildImagesKey(value)
    if (key == currentImagesKey) return
    currentImagesKey = key
    rebuild()
  }

  private fun rebuild() {
    val ast = MarkdownParserJni.parse(currentMarkdown, currentCustomTags) ?: return
    val cfg = StyleConfig.fromJson(currentStyles)

    // Apply outer block style (base)
    outer.setElementStyle(cfg.base)
    stack.spacing = cfg.base.gap.takeUnless { it.isNaN() }?.toInt() ?: 0

    stack.removeAllViews()
    for (child in ast.children) {
      val seg = buildSegment(child, cfg) ?: continue
      stack.addView(seg, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
    }
  }

  private fun buildSegment(node: AstNode, cfg: StyleConfig): android.view.View? {
    return when (node.type) {
      NodeType.Paragraph, NodeType.Heading, NodeType.CodeBlock -> buildTextSegment(node, cfg)
      NodeType.Blockquote -> buildBlockquoteSegment(node, cfg)
      NodeType.List -> buildListSegment(node, cfg)
      NodeType.Table -> buildTableSegment(node, cfg)
      NodeType.ThematicBreak -> buildThematicBreakSegment(cfg)
      else -> null
    }
  }

  private fun buildBlockquoteSegment(node: AstNode, cfg: StyleConfig): android.view.View {
    val style = cfg.blockquote
    val inner = MarkdownSegmentStack(context).apply {
      spacing = style.gap.takeUnless { it.isNaN() }?.toInt() ?: 0
    }
    for (child in node.children) {
      val seg = buildSegment(child, cfg) ?: continue
      inner.addView(seg, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
    }
    return wrapInBlock(inner, style)
  }

  private fun buildListSegment(node: AstNode, cfg: StyleConfig): android.view.View {
    val isOrdered = node.listType == ListType.Ordered
    val listStyle = cfg.list
    val inner = MarkdownSegmentStack(context).apply {
      spacing = listStyle.gap.takeUnless { it.isNaN() }?.toInt() ?: 0
    }

    val itemCount = node.children.count { it.type == NodeType.ListItem }
    val startNumber = if (isOrdered) maxOf(1, node.listStart) else 0
    val lastNumber = maxOf(1, startNumber + itemCount - 1)
    var maxDigits = 1
    var v = lastNumber
    while (v >= 10) { maxDigits++; v /= 10 }

    var index = startNumber
    for (child in node.children) {
      if (child.type != NodeType.ListItem) continue
      val tv = makeTextView(cfg.listItem, cfg)
      val ctx = makeContext(cfg)
      ctx.pushAttributes(RenderContext.baseAttributesFromStyleConfig(cfg))
      val spanned = RenderContext.renderListItemContent(
        child, isOrdered, index, maxDigits, cfg, currentCustomTags,
      )
      tv.text = spanned
      inner.addView(wrapInBlock(tv, cfg.listItem),
        ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
      if (isOrdered) index++
    }
    return wrapInBlock(inner, listStyle)
  }

  private fun buildTableSegment(node: AstNode, cfg: StyleConfig): android.view.View {
    val maxW = width.takeIf { it > 0 } ?: resources.displayMetrics.widthPixels
    val layout = MarkdownTableLayout.compute(node, cfg, currentCustomTags, maxW)
    val table = MarkdownTableView(context, layout, cfg)
    return wrapInBlock(table, cfg.table)
  }

  private fun buildThematicBreakSegment(cfg: StyleConfig): android.view.View {
    val s = cfg.thematicBreak
    val v = android.view.View(context)
    val h = if (!s.height.isNaN() && s.height > 0) s.height.toInt() else 1
    val lp = ViewGroup.MarginLayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, h)
    v.layoutParams = lp
    s.backgroundColor?.let { v.setBackgroundColor(it) }
    return wrapInBlock(v, s)
  }

  private fun makeTextView(
    style: com.alizahid.markdown.style.ElementStyle,
    cfg: StyleConfig,
  ): MarkdownTextView {
    return MarkdownTextView(context).apply {
      val baseSize = pickFontSize(cfg, style)
      setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, baseSize)
    }
  }

  private fun makeContext(cfg: StyleConfig): RenderContext {
    return RenderContext(cfg, currentCustomTags).apply {
      onLinkPress = { url, title -> MarkdownEventDispatcher.dispatchLinkPress(this@MarkdownView, url, title) }
      onLinkLongPress = { url, title -> MarkdownEventDispatcher.dispatchLinkLongPress(this@MarkdownView, url, title) }
    }
  }

  private fun buildTextSegment(node: AstNode, cfg: StyleConfig): android.view.View {
    val style = when (node.type) {
      NodeType.Heading -> cfg.styleForHeadingLevel(node.headingLevel)
      NodeType.CodeBlock -> cfg.codeBlock
      else -> cfg.paragraph
    }
    val tv = makeTextView(style, cfg)
    val ctx = makeContext(cfg)
    ctx.pushAttributes(RenderContext.baseAttributesFromStyleConfig(cfg))
    val sb = android.text.SpannableStringBuilder()
    com.alizahid.markdown.renderer.RendererFactory.forType(node.type)?.render(node, sb, ctx)
    val len = sb.length
    if (len > 0 && sb[len - 1] == '\n') sb.delete(len - 1, len)
    tv.text = sb

    return wrapInBlock(tv, style)
  }

  private fun wrapInBlock(content: android.view.View, style: com.alizahid.markdown.style.ElementStyle): android.view.View {
    val block = MarkdownBlockView(context)
    block.setElementStyle(style)
    val m = style.resolvedMarginInsets()
    val lp = ViewGroup.MarginLayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT,
      ViewGroup.LayoutParams.WRAP_CONTENT,
    )
    lp.setMargins(m.left, m.top, m.right, m.bottom)
    block.layoutParams = lp
    block.setContent(content)
    return block
  }

  private fun pickFontSize(cfg: StyleConfig, style: com.alizahid.markdown.style.ElementStyle): Float {
    if (!style.fontSize.isNaN() && style.fontSize > 0) return style.fontSize
    if (!cfg.base.fontSize.isNaN() && cfg.base.fontSize > 0) return cfg.base.fontSize
    return 16f * resources.displayMetrics.scaledDensity
  }

  private fun buildImagesKey(value: ReadableArray?): String {
    if (value == null) return ""
    val sb = StringBuilder()
    for (i in 0 until value.size()) {
      val item = value.getMap(i) ?: continue
      sb.append(item.getString("url") ?: "")
      sb.append('|')
      sb.append(item.getDouble("width"))
      sb.append('|')
      sb.append(item.getDouble("height"))
      sb.append(';')
    }
    return sb.toString()
  }

  /**
   * Called by MarkdownImageSizeCache (Phase 4) when a new natural image
   * size is discovered. Flushes the measurement cache and bumps the
   * Fabric state revision so Yoga remeasures the view.
   */
  fun markNeedsRemeasure() {
    MeasurementCache.clear()
    val wrapper = stateWrapper ?: return
    measureRevision += 1
    val map = com.facebook.react.bridge.Arguments.createMap()
    map.putInt("revision", measureRevision)
    wrapper.updateState(map)
  }
}
