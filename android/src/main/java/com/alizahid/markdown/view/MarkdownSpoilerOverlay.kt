package com.alizahid.markdown.view

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ObjectAnimator
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
import com.alizahid.markdown.renderer.spans.SpoilerMarkerSpan
import kotlin.math.max
import kotlin.math.min

/**
 * Cover overlay drawn on top of a MarkdownTextView. One overlay child
 * view per spoiler id, mirroring iOS MarkdownSpoilerOverlay — so tapping
 * one spoiler only fades that spoiler's shape, leaving the others
 * covered. Shape is a staircase polygon built via
 * MarkdownPressableOverlay.shapePathForRects so multi-line ranges follow
 * the text contour.
 *
 * Per-line rects are derived from the host TextView's Paint metrics
 * (ascent + descent) rather than the Layout's line top/bottom, which
 * include inter-line leading and would leave asymmetric whitespace
 * above each row. iOS uses the same font-metric-derived bounds.
 */
class MarkdownSpoilerOverlay(
  context: Context,
  private val host: MarkdownTextView,
  private val fillColor: Int,
  private val cornerRadius: Float,
) : View(context) {

  private val pressedColor: Int = MarkdownPressableOverlay.pressedColorFor(fillColor)
  private val padding: Float = 2f * context.resources.displayMetrics.density
  private val revealedIds = mutableSetOf<String>()
  private val children = mutableListOf<SpoilerShape>()

  // Touch state
  private var activeShape: SpoilerShape? = null
  private var downX: Float = 0f
  private var downY: Float = 0f

  // Skip rebuilds when nothing meaningful changed.
  private var cachedWidth: Int = -1
  private var cachedTextHash: Int = 0
  private var cachedTextLength: Int = 0

  private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)

  init {
    setWillNotDraw(false)
  }

  /** Recomputes shapes from the host's current Layout + Spanned. */
  fun update() {
    val width = host.width
    if (width <= 0) return
    val layout: Layout = host.layout ?: return
    val text = host.text as? Spanned ?: run {
      children.clear(); invalidate(); return
    }
    val spans = text.getSpans(0, text.length, SpoilerMarkerSpan::class.java)
    if (spans.isEmpty()) {
      children.clear(); cachedWidth = width; cachedTextHash = text.hashCode(); cachedTextLength = text.length
      invalidate(); return
    }
    if (width == cachedWidth && text.hashCode() == cachedTextHash && text.length == cachedTextLength) {
      return
    }
    cachedWidth = width
    cachedTextHash = text.hashCode()
    cachedTextLength = text.length

    // Group spans by id (block-level spoilers can also be split across
    // multiple ranges in unusual cases — we union them per id).
    val byId = mutableMapOf<String, MutableList<Pair<SpoilerMarkerSpan, IntRange>>>()
    for (span in spans) {
      val s = text.getSpanStart(span); val e = text.getSpanEnd(span)
      if (s < 0 || e <= s) continue
      byId.getOrPut(span.id) { mutableListOf() }.add(span to (s until e))
    }

    children.clear()
    for ((id, ranges) in byId) {
      val isBlock = ranges.first().first.isBlock
      val perLine = mutableListOf<RectF>()
      for ((_, range) in ranges) {
        perLine.addAll(lineRectsFor(layout, range.first, range.last + 1))
      }
      if (perLine.isEmpty()) continue
      val finalRects = if (isBlock) {
        val u = RectF(perLine[0])
        for (r in perLine) u.union(r)
        mutableListOf(u)
      } else {
        // Sort by y and extend each rect's bottom down to the next rect's top
        // so adjacent lines visually connect through inter-line leading.
        perLine.sortBy { it.top }
        for (i in 0 until perLine.size - 1) {
          val next = perLine[i + 1]
          if (next.top > perLine[i].bottom) perLine[i].bottom = next.top
        }
        perLine
      }

      val bounds = RectF(finalRects[0])
      for (r in finalRects) bounds.union(r)

      val localRects = finalRects.map {
        RectF(it.left - bounds.left, it.top - bounds.top,
              it.right - bounds.left, it.bottom - bounds.top)
      }
      val path = MarkdownPressableOverlay.shapePathForRects(localRects, cornerRadius)
      val region = Region().apply {
        setPath(path, Region(0, 0, bounds.width().toInt() + 1, bounds.height().toInt() + 1))
      }
      children.add(
        SpoilerShape(
          id = id,
          bounds = bounds,
          path = path,
          region = region,
          alpha = if (revealedIds.contains(id)) 0f else 1f,
        ),
      )
    }
    invalidate()
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    for (shape in children) {
      val isActive = shape === activeShape
      if (shape.alpha <= 0f && !isActive) continue
      fillPaint.color = if (isActive) pressedColor else fillColor
      val saved = canvas.save()
      canvas.translate(shape.bounds.left, shape.bounds.top)
      val a = (shape.alpha.coerceIn(0f, 1f) * 255f).toInt()
      fillPaint.alpha = a
      canvas.drawPath(shape.path, fillPaint)
      canvas.restoreToCount(saved)
    }
  }

  private val touchSlop: Int = android.view.ViewConfiguration.get(context).scaledTouchSlop

  override fun onTouchEvent(event: MotionEvent): Boolean {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        val hit = shapeAt(event.x, event.y) ?: return false
        if (revealedIds.contains(hit.id)) return false
        downX = event.x; downY = event.y
        activeShape = hit
        invalidate()
        // Don't pre-emptively block ancestor intercept — that breaks
        // scrolling. We commit to the press on UP only when the touch
        // hasn't moved past slop.
        return true
      }
      MotionEvent.ACTION_MOVE -> {
        // Cancel the pending press the moment the user scrolls past
        // slop OR drags off the shape.
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
          revealedIds.add(hit.id)
          animateRevealFor(hit)
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

  private fun shapeAt(x: Float, y: Float): SpoilerShape? {
    for (shape in children) {
      if (!shape.bounds.contains(x, y)) continue
      val lx = (x - shape.bounds.left).toInt()
      val ly = (y - shape.bounds.top).toInt()
      if (shape.region.contains(lx, ly)) return shape
    }
    return null
  }

  private fun animateRevealFor(shape: SpoilerShape) {
    val anim = ObjectAnimator.ofFloat(1f, 0f).apply {
      duration = 250
      addUpdateListener {
        shape.alpha = it.animatedValue as Float
        invalidate()
      }
      addListener(object : AnimatorListenerAdapter() {
        override fun onAnimationEnd(a: Animator) {
          shape.alpha = 0f
          invalidate()
        }
      })
    }
    anim.start()
  }

  /**
   * Per-line rects for `[start, end)` in the host's Layout. Uses Paint
   * ascent/descent for vertical bounds (tight to glyph extents, no
   * inter-line leading) plus 2dp horizontal/vertical padding — mirrors
   * iOS kSpoilerPadding.
   */
  private fun lineRectsFor(layout: Layout, start: Int, end: Int): List<RectF> {
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

  private class SpoilerShape(
    val id: String,
    val bounds: RectF,
    val path: Path,
    val region: Region,
    var alpha: Float,
  )
}
