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
import com.alizahid.markdown.view.MarkdownImageSizeCache
import com.alizahid.markdown.view.MarkdownImageView
import com.alizahid.markdown.view.MarkdownMentionOverlay
import com.alizahid.markdown.view.MarkdownPressableOverlay
import com.alizahid.markdown.view.MarkdownSegmentStack
import com.alizahid.markdown.view.MarkdownSpoilerOverlay
import com.alizahid.markdown.view.MarkdownTableLayout
import com.alizahid.markdown.view.MarkdownTableView
import com.alizahid.markdown.view.MarkdownTextView
import com.alizahid.markdown.parser.ListType
import com.alizahid.markdown.renderer.spans.MentionSpan
import com.alizahid.markdown.renderer.spans.SpoilerMarkerSpan
import android.graphics.Color
import android.util.Size
import android.widget.FrameLayout
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
  private var propImageSizes: Map<String, Size> = emptyMap()

  /** Set by MarkdownViewManager.updateState — used to trigger remeasure. */
  var stateWrapper: StateWrapper? = null

  private var measureRevision: Int = 0

  private val imageSizeListener: (String) -> Unit = { _ -> markNeedsRemeasure() }

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
    propImageSizes = parsePropImageSizes(value)
    rebuild()
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    MarkdownImageSizeCache.addListener(imageSizeListener)
  }

  override fun onDetachedFromWindow() {
    MarkdownImageSizeCache.removeListener(imageSizeListener)
    super.onDetachedFromWindow()
  }

  /**
   * On ACTION_DOWN, walk descendants to see if any "interactive" view
   * (link span, mention/spoiler overlay, image, scrollable table) sits
   * under the touch point. If so, ask ancestors not to intercept the
   * touch so a parent `<Pressable>` doesn't swallow it. Mirrors iOS
   * MarkdownTouchBlockingRecognizer.
   */
  override fun onInterceptTouchEvent(ev: android.view.MotionEvent): Boolean {
    if (ev.actionMasked == android.view.MotionEvent.ACTION_DOWN) {
      if (touchHitsInteractive(this, ev.x.toInt(), ev.y.toInt())) {
        parent?.requestDisallowInterceptTouchEvent(true)
      }
    }
    return false
  }

  private fun touchHitsInteractive(root: android.view.View, x: Int, y: Int): Boolean {
    val hit = android.graphics.Rect()
    return walkHit(root, x, y, hit)
  }

  private fun walkHit(v: android.view.View, x: Int, y: Int, hit: android.graphics.Rect): Boolean {
    if (v is MarkdownPressableOverlay) return true
    if (v is MarkdownSpoilerOverlay) return true
    if (v is MarkdownMentionOverlay) return true
    if (v is MarkdownImageView) return true
    if (v is MarkdownTableView) return v.canScrollHorizontally(1) || v.canScrollHorizontally(-1)
    if (v is MarkdownTextView) {
      val span = linkSpanAt(v, x, y)
      if (span) return true
    }
    if (v is ViewGroup) {
      for (i in 0 until v.childCount) {
        val child = v.getChildAt(i)
        child.getHitRect(hit)
        if (hit.contains(x, y)) {
          if (walkHit(child, x - child.left, y - child.top, hit)) return true
        }
      }
    }
    return false
  }

  private fun linkSpanAt(tv: MarkdownTextView, x: Int, y: Int): Boolean {
    val layout = tv.layout ?: return false
    val xx = (x - tv.totalPaddingLeft + tv.scrollX).coerceAtLeast(0)
    val yy = (y - tv.totalPaddingTop + tv.scrollY).coerceAtLeast(0)
    if (xx > layout.width || yy > layout.height) return false
    val line = layout.getLineForVertical(yy)
    val offset = layout.getOffsetForHorizontal(line, xx.toFloat())
    val text = tv.text as? android.text.Spanned ?: return false
    val spans = text.getSpans(offset, offset, com.alizahid.markdown.renderer.spans.LinkClickableSpan::class.java)
    return spans.isNotEmpty()
  }

  private fun rebuild() {
    val ast = MarkdownParserJni.parse(currentMarkdown, currentCustomTags) ?: return
    val cfg = StyleConfig.fromJson(currentStyles)

    // Apply outer block style (base)
    outer.setElementStyle(cfg.base)
    stack.spacing = cfg.base.gap.takeUnless { it.isNaN() }?.toInt() ?: 0

    stack.removeAllViews()
    for (child in ast.children) {
      val seg = buildSegment(child, cfg, inheritedAttrs = null) ?: continue
      stack.addView(seg, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
    }
  }

  /**
   * `inheritedAttrs` cascades parent-block text styling (e.g. a
   * blockquote's color/fontStyle) into children. Pass `null` at the
   * top level — RenderContext.baseAttributesFromStyleConfig is used.
   */
  private fun buildSegment(
    node: AstNode,
    cfg: StyleConfig,
    inheritedAttrs: Map<String, Any?>?,
  ): android.view.View? {
    // `![alt](url)` on its own line parses as Paragraph { Image } —
    // render it as a real MarkdownImageView block (Glide-backed) instead
    // of flattening through the attributed-string pipeline. Mirrors iOS
    // MarkdownView.imageOnlyParagraphChild.
    RenderContext.imageOnlyParagraphChild(node)?.let { imageNode ->
      return buildImageSegment(imageNode, cfg)
    }
    return when (node.type) {
      NodeType.Blockquote -> buildBlockquoteSegment(node, cfg, inheritedAttrs)
      NodeType.List -> buildListSegment(node, cfg, inheritedAttrs)
      NodeType.Table -> buildTableSegment(node, cfg)
      NodeType.ThematicBreak -> buildThematicBreakSegment(cfg)
      // Everything else — paragraph, heading, codeBlock, CustomTag at
      // top level (e.g. a standalone <Spoiler>…</Spoiler>), even
      // unrecognised types — falls through to the text-block path.
      // Mirrors iOS addSegmentForNode's `else` branch.
      else -> buildTextSegment(node, cfg, inheritedAttrs)
    }
  }

  private fun buildImageSegment(imageNode: AstNode, cfg: StyleConfig): android.view.View {
    val style = cfg.image
    val url = imageNode.imageSrc
    val sizes = MarkdownImageView.pickStyleSizes(style)
    val fallbackW = sizes[0]
    val fallbackH = if (sizes[1] > 0) sizes[1] else 200
    val maxW = sizes[2]
    val maxH = sizes[3]
    val propSize = propImageSizes[url]

    val iv = MarkdownImageView(
      context, url, propSize, fallbackW, fallbackH, maxW, maxH, style.objectFit,
    )
    iv.onPress = { pressedUrl, w, h ->
      MarkdownEventDispatcher.dispatchImagePress(this, pressedUrl, w, h)
    }
    val block = MarkdownBlockView(context).apply {
      setElementStyle(style)
      setHuggingContent(true)
    }
    val m = style.resolvedMarginInsets()
    val lp = ViewGroup.MarginLayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT,
      ViewGroup.LayoutParams.WRAP_CONTENT,
    )
    lp.setMargins(m.left, m.top, m.right, m.bottom)
    block.layoutParams = lp
    block.setContent(iv)
    return block
  }

  private fun buildBlockquoteSegment(
    node: AstNode, cfg: StyleConfig, inheritedAttrs: Map<String, Any?>?,
  ): android.view.View {
    val style = cfg.blockquote
    val inner = MarkdownSegmentStack(context).apply {
      spacing = style.gap.takeUnless { it.isNaN() }?.toInt() ?: 0
    }
    // Cascade blockquote text style into children. Mirrors iOS
    // addBlockquoteSegment's childAttrsFrozen.
    val parentAttrs = inheritedAttrs ?: RenderContext.baseAttributesFromStyleConfig(cfg)
    val childAttrs = RenderContext.resolveAttrs(style, parentAttrs)
    for (child in node.children) {
      val seg = buildSegment(child, cfg, childAttrs) ?: continue
      inner.addView(seg, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
    }
    return wrapInBlock(inner, style)
  }

  private fun buildListSegment(
    node: AstNode, cfg: StyleConfig, inheritedAttrs: Map<String, Any?>?,
  ): android.view.View {
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
      val spanned = RenderContext.renderListItemContent(
        child, isOrdered, index, maxDigits, cfg, currentCustomTags,
        inheritedAttrs = inheritedAttrs,
      )
      val container = textContainerWithOverlays(tv.apply { text = spanned }, spanned, cfg)
      inner.addView(wrapInBlock(container, cfg.listItem),
        ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
      if (isOrdered) index++
    }
    return wrapInBlock(inner, listStyle)
  }

  private fun buildTableSegment(node: AstNode, cfg: StyleConfig): android.view.View {
    val outerWidth = (width.takeIf { it > 0 } ?: resources.displayMetrics.widthPixels)
    // Subtract base margin/padding/borders + table wrapper margin/padding/
    // borders so the table sees the same inner width the measurer reserved.
    // Matches iOS addTableSegment.
    val bm = cfg.base.resolvedMarginInsets(); val bp = cfg.base.resolvedPaddingInsets(); val bb = cfg.base.resolvedBorderWidths()
    val tableStyle = cfg.table
    val tm = tableStyle.resolvedMarginInsets(); val tp = tableStyle.resolvedPaddingInsets(); val tb = tableStyle.resolvedBorderWidths()
    val innerWidth = (outerWidth -
      bm.left - bm.right - bp.left - bp.right - bb.left - bb.right -
      tm.left - tm.right - tp.left - tp.right - tb.left - tb.right).coerceAtLeast(0)
    val layout = MarkdownTableLayout.compute(node, cfg, currentCustomTags, innerWidth)
    val table = MarkdownTableView(context, layout, cfg)
    return wrapInBlock(table, tableStyle)
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

  private fun buildTextSegment(
    node: AstNode, cfg: StyleConfig, inheritedAttrs: Map<String, Any?>?,
  ): android.view.View {
    val style = when (node.type) {
      NodeType.Heading -> cfg.styleForHeadingLevel(node.headingLevel)
      NodeType.CodeBlock -> cfg.codeBlock
      NodeType.Paragraph -> cfg.paragraph
      else -> cfg.paragraph
    }
    val tv = makeTextView(style, cfg)
    // Use the same thread-safe rendering helper the measurer uses so
    // runtime + measurement produce identical output for the same
    // inputs. inheritedAttrs cascades parent block styling (e.g. a
    // blockquote's color) into this segment.
    val sb = android.text.SpannableStringBuilder(
      RenderContext.renderNodeToSpanned(node, cfg, currentCustomTags, inheritedAttrs),
    )

    // If this top-level segment is a block-level CustomTag (e.g. a
    // `<Spoiler>…</Spoiler>` on its own line), stamp every existing
    // spoiler span with `isBlock = true` so the overlay draws a solid
    // rectangle instead of a staircase polygon. Mirrors iOS
    // MarkdownSpoilerIsBlockKey flow.
    if (node.type == NodeType.CustomTag) {
      val existing = sb.getSpans(0, sb.length, SpoilerMarkerSpan::class.java)
      for (sp in existing) {
        val s = sb.getSpanStart(sp); val e = sb.getSpanEnd(sp); val f = sb.getSpanFlags(sp)
        sb.removeSpan(sp)
        sb.setSpan(SpoilerMarkerSpan(sp.id, isBlock = true), s, e, f)
      }
    }

    tv.text = sb
    // textContainerWithOverlays rebinds LinkClickableSpans so they
    // dispatch through this view — the static RenderContext helper
    // builds them without view-side callbacks.
    val container = textContainerWithOverlays(tv, sb, cfg)
    return wrapInBlock(container, style)
  }

  private fun rebindLinkSpans(sb: android.text.SpannableStringBuilder) {
    val spans = sb.getSpans(0, sb.length, com.alizahid.markdown.renderer.spans.LinkClickableSpan::class.java)
    for (old in spans) {
      val s = sb.getSpanStart(old); val e = sb.getSpanEnd(old); val f = sb.getSpanFlags(old)
      sb.removeSpan(old)
      sb.setSpan(
        com.alizahid.markdown.renderer.spans.LinkClickableSpan(
          old.url, old.title,
          { url, title -> MarkdownEventDispatcher.dispatchLinkPress(this, url, title) },
          { url, title -> MarkdownEventDispatcher.dispatchLinkLongPress(this, url, title) },
        ),
        s, e, f,
      )
    }
  }

  /**
   * Wraps a MarkdownTextView in a FrameLayout that also hosts spoiler /
   * mention overlays. Overlays subscribe to the text view's
   * onLayoutChanged callback so they recompute glyph rects after layout.
   *
   * Also rebinds any LinkClickableSpans so they dispatch onLinkPress /
   * onLinkLongPress through this view's event dispatcher — the static
   * RenderContext helper builds spans without view-side callbacks.
   */
  private fun textContainerWithOverlays(
    tv: MarkdownTextView,
    content: android.text.Spanned,
    cfg: StyleConfig,
  ): android.view.View {
    if (content is android.text.SpannableStringBuilder) rebindLinkSpans(content)
    val hasSpoilers = content.getSpans(0, content.length, SpoilerMarkerSpan::class.java).isNotEmpty()
    val hasMentions = content.getSpans(0, content.length, MentionSpan::class.java).isNotEmpty()
    if (!hasSpoilers && !hasMentions) return tv

    val frame = FrameLayout(context)
    frame.addView(tv, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT))

    if (hasSpoilers) {
      val color = cfg.spoiler.backgroundColor ?: Color.argb(255, 60, 60, 60)
      val radius = if (!cfg.spoiler.borderRadius.isNaN() && cfg.spoiler.borderRadius > 0) cfg.spoiler.borderRadius else 4f
      val overlay = MarkdownSpoilerOverlay(context, tv, color, radius)
      frame.addView(overlay, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
      tv.onLayoutChanged = { overlay.update() }
    }
    if (hasMentions) {
      val overlay = MarkdownMentionOverlay(context, tv).apply {
        onPress = { span ->
          val propsJson = mentionPropsToJson(span)
          MarkdownEventDispatcher.dispatchMentionPress(this@MarkdownView, span.type, span.id, span.name, propsJson)
        }
      }
      frame.addView(overlay, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
      val previous = tv.onLayoutChanged
      tv.onLayoutChanged = { previous?.invoke(); overlay.update() }
    }
    return frame
  }

  private fun mentionPropsToJson(span: MentionSpan): String {
    if (span.props.isEmpty()) return "{}"
    val obj = org.json.JSONObject()
    for ((k, v) in span.props) obj.put(k, v)
    return obj.toString()
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

  private fun parsePropImageSizes(value: ReadableArray?): Map<String, Size> {
    if (value == null) return emptyMap()
    val out = mutableMapOf<String, Size>()
    for (i in 0 until value.size()) {
      val item = value.getMap(i) ?: continue
      val url = item.getString("url") ?: continue
      val w = item.getDouble("width").toInt()
      val h = item.getDouble("height").toInt()
      if (w > 0 && h > 0) out[url] = Size(w, h)
    }
    return out
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
