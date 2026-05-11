package com.alizahid.markdown.view

import android.content.Context
import android.graphics.Color
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.Spanned
import com.alizahid.markdown.renderer.spans.MentionSpan

/**
 * Press overlay sitting on top of mention ranges. Same per-line-rect
 * computation as the spoiler overlay but with a smaller corner radius
 * and a transparent normal color (the mention's foreground colour comes
 * from the matching mentionUser/mentionChannel/mentionCommand style;
 * this overlay only provides a press indicator + tap hook).
 */
class MarkdownMentionOverlay(
  context: Context,
  private val host: MarkdownTextView,
) : MarkdownPressableOverlay(context) {

  data class Hit(val span: MentionSpan, val path: Path, val bounds: RectF)

  var onPress: ((MentionSpan) -> Unit)? = null

  private val hits = mutableListOf<Hit>()
  private val cornerRadiusPx: Float = 4f * context.resources.displayMetrics.density

  init {
    setColors(Color.TRANSPARENT, Color.argb(31, 0, 0, 0))
  }

  fun update() {
    val layout: Layout = host.layout ?: return
    val text = host.text as? Spanned ?: return
    val spans = text.getSpans(0, text.length, MentionSpan::class.java)
    hits.clear()
    if (spans.isEmpty()) {
      setShapePath(null)
      invalidate()
      return
    }
    val combined = Path()
    for (span in spans) {
      val s = text.getSpanStart(span)
      val e = text.getSpanEnd(span)
      if (s < 0 || e <= s) continue
      val rects = lineRects(layout, s, e)
      if (rects.isEmpty()) continue
      val p = shapePathForRects(rects, cornerRadiusPx)
      val bounds = RectF().also { p.computeBounds(it, true) }
      hits.add(Hit(span, p, bounds))
      combined.addPath(p)
    }
    setShapePath(combined)
    invalidate()
  }

  override fun onTap(x: Float, y: Float) {
    val hit = hits.firstOrNull { it.bounds.contains(x, y) } ?: return
    onPress?.invoke(hit.span)
  }

  private fun lineRects(layout: Layout, start: Int, end: Int): List<RectF> {
    val firstLine = layout.getLineForOffset(start)
    val lastLine = layout.getLineForOffset(end)
    val rects = mutableListOf<RectF>()
    for (line in firstLine..lastLine) {
      val lineStart = layout.getLineStart(line)
      val lineEnd = layout.getLineEnd(line)
      val s = maxOf(start, lineStart)
      val e = minOf(end, lineEnd)
      if (e <= s) continue
      val x1 = layout.getPrimaryHorizontal(s)
      val x2 = if (e == lineEnd && line < lastLine) layout.getLineRight(line) else layout.getPrimaryHorizontal(e)
      val top = layout.getLineTop(line).toFloat()
      val bottom = layout.getLineBottom(line).toFloat()
      rects.add(RectF(minOf(x1, x2), top, maxOf(x1, x2), bottom))
    }
    return rects
  }
}
