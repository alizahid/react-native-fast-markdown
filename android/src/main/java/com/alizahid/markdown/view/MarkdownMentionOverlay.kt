package com.alizahid.markdown.view

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Region
import android.text.Layout
import android.text.Spanned
import android.view.MotionEvent
import android.view.View
import com.alizahid.markdown.renderer.spans.MentionSpan
import kotlin.math.max
import kotlin.math.min

/**
 * Press overlay for mention ranges. One overlay shape per mention span,
 * mirroring iOS MarkdownMentionOverlay. Visual style (color, etc.)
 * comes from the matching mention ElementStyle; this view only adds a
 * dark press tint and dispatches `onPress` with the mention payload.
 */
class MarkdownMentionOverlay(
  context: Context,
  private val host: MarkdownTextView,
) : View(context) {

  var onPress: ((MentionSpan) -> Unit)? = null

  private val cornerRadius: Float = 4f * context.resources.displayMetrics.density
  private val padding: Float = 2f * context.resources.displayMetrics.density
  private val pressedColor: Int = Color.argb(31, 0, 0, 0)

  private val shapes = mutableListOf<Shape>()
  private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private var activeShape: Shape? = null

  private var cachedWidth: Int = -1
  private var cachedTextHash: Int = 0
  private var cachedTextLength: Int = 0

  init {
    setWillNotDraw(false)
  }

  fun update() {
    val width = host.width
    if (width <= 0) return
    val layout: Layout = host.layout ?: return
    val text = host.text as? Spanned ?: run {
      shapes.clear(); invalidate(); return
    }
    val spans = text.getSpans(0, text.length, MentionSpan::class.java)
    if (spans.isEmpty()) {
      shapes.clear()
      cachedWidth = width; cachedTextHash = text.hashCode(); cachedTextLength = text.length
      invalidate(); return
    }
    if (width == cachedWidth && text.hashCode() == cachedTextHash && text.length == cachedTextLength) {
      return
    }
    cachedWidth = width
    cachedTextHash = text.hashCode()
    cachedTextLength = text.length

    shapes.clear()
    for (span in spans) {
      val s = text.getSpanStart(span); val e = text.getSpanEnd(span)
      if (s < 0 || e <= s) continue
      val perLine = lineRectsFor(layout, s, e)
      if (perLine.isEmpty()) continue
      perLine.sortBy { it.top }
      for (i in 0 until perLine.size - 1) {
        val next = perLine[i + 1]
        if (next.top > perLine[i].bottom) perLine[i].bottom = next.top
      }
      val bounds = RectF(perLine[0])
      for (r in perLine) bounds.union(r)
      val localRects = perLine.map {
        RectF(it.left - bounds.left, it.top - bounds.top,
              it.right - bounds.left, it.bottom - bounds.top)
      }
      val path = MarkdownPressableOverlay.shapePathForRects(localRects, cornerRadius)
      val region = Region().apply {
        setPath(path, Region(0, 0, bounds.width().toInt() + 1, bounds.height().toInt() + 1))
      }
      shapes.add(Shape(span = span, bounds = bounds, path = path, region = region))
    }
    invalidate()
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    val active = activeShape ?: return
    val saved = canvas.save()
    canvas.translate(active.bounds.left, active.bounds.top)
    fillPaint.color = pressedColor
    canvas.drawPath(active.path, fillPaint)
    canvas.restoreToCount(saved)
  }

  private val touchSlop: Int = android.view.ViewConfiguration.get(context).scaledTouchSlop
  private var downX: Float = 0f
  private var downY: Float = 0f

  override fun onTouchEvent(event: MotionEvent): Boolean {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        val hit = shapeAt(event.x, event.y) ?: return false
        downX = event.x; downY = event.y
        activeShape = hit
        invalidate()
        // Don't pre-emptively block ancestor intercept — that breaks
        // scrolling when a finger lands on a mention.
        return true
      }
      MotionEvent.ACTION_MOVE -> {
        if (activeShape != null) {
          val moved = kotlin.math.abs(event.x - downX) > touchSlop ||
            kotlin.math.abs(event.y - downY) > touchSlop
          if (moved || shapeAt(event.x, event.y) !== activeShape) {
            activeShape = null
            invalidate()
            return false
          }
        }
      }
      MotionEvent.ACTION_UP -> {
        val hit = activeShape
        activeShape = null
        invalidate()
        if (hit != null && shapeAt(event.x, event.y) === hit) {
          onPress?.invoke(hit.span)
          return true
        }
      }
      MotionEvent.ACTION_CANCEL -> {
        activeShape = null
        invalidate()
      }
    }
    return false
  }

  private fun shapeAt(x: Float, y: Float): Shape? {
    for (shape in shapes) {
      if (!shape.bounds.contains(x, y)) continue
      val lx = (x - shape.bounds.left).toInt()
      val ly = (y - shape.bounds.top).toInt()
      if (shape.region.contains(lx, ly)) return shape
    }
    return null
  }

  /**
   * Per-line rects derived from Paint ascent/descent (not Layout line
   * top/bottom — those include inter-line leading). 2dp padding around
   * the glyph rects, matching iOS kMentionPadding.
   */
  private fun lineRectsFor(layout: Layout, start: Int, end: Int): MutableList<RectF> {
    val firstLine = layout.getLineForOffset(start)
    val lastLine = layout.getLineForOffset(end)
    val paint: Paint = host.paint
    val ascent = paint.ascent()
    val descent = paint.descent()
    val rects = mutableListOf<RectF>()
    for (line in firstLine..lastLine) {
      val lineStart = layout.getLineStart(line)
      val lineEnd = layout.getLineEnd(line)
      val s = max(start, lineStart)
      val e = min(end, lineEnd)
      if (e <= s) continue
      val x1 = layout.getPrimaryHorizontal(s)
      val x2 = if (e == lineEnd && line < lastLine) layout.getLineRight(line)
      else layout.getPrimaryHorizontal(e)
      val baseline = layout.getLineBaseline(line).toFloat()
      val top = baseline + ascent - padding
      val bottom = baseline + descent + padding
      val left = min(x1, x2) - padding
      val right = max(x1, x2) + padding
      rects.add(RectF(left, top, right, bottom))
    }
    return rects
  }

  private class Shape(
    val span: MentionSpan,
    val bounds: RectF,
    val path: Path,
    val region: Region,
  )
}
