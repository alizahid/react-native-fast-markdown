package com.alizahid.markdown.view

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Region
import android.view.MotionEvent
import android.view.View
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.min

/**
 * Base for overlay views that need a shape-confined hit area and a
 * press-color fade. Mirrors ios/views/MarkdownPressableOverlayView.
 *
 * The interesting part is `shapePathForRects`: it builds a clockwise
 * staircase polygon around stacked per-line rects, smoothing every
 * vertex (convex AND concave) with a quadratic bezier. The same routine
 * powers spoiler outlines, mention chips, and any future overlay that
 * needs to follow text contour.
 */
open class MarkdownPressableOverlay(context: Context) : View(context) {

  protected var shapePath: Path? = null
    set(value) {
      field = value
      hitRegionDirty = true
      invalidate()
    }
  protected var normalColor: Int = Color.TRANSPARENT
  protected var pressedColor: Int = Color.argb(31, 0, 0, 0)

  private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val hitRegion = Region()
  private var hitRegionDirty = true
  private var downX: Float = 0f
  private var downY: Float = 0f
  private var pressed: Boolean = false

  init {
    setWillNotDraw(false)
  }

  fun setColors(normal: Int, pressed: Int) {
    normalColor = normal
    pressedColor = pressed
    invalidate()
  }

  override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
    super.onSizeChanged(w, h, oldw, oldh)
    hitRegionDirty = true
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    val path = shapePath
    fillPaint.color = if (pressed) pressedColor else normalColor
    if (path != null) {
      canvas.drawPath(path, fillPaint)
    } else if (width > 0 && height > 0) {
      canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), fillPaint)
    }
  }

  override fun onTouchEvent(event: MotionEvent): Boolean {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        if (!isPointInShape(event.x.toInt(), event.y.toInt())) return false
        downX = event.x; downY = event.y
        pressed = true
        invalidate()
        return true
      }
      MotionEvent.ACTION_MOVE -> {
        if (!isPointInShape(event.x.toInt(), event.y.toInt())) {
          pressed = false
          invalidate()
        }
      }
      MotionEvent.ACTION_UP -> {
        val wasPressed = pressed
        pressed = false
        invalidate()
        if (wasPressed && isPointInShape(event.x.toInt(), event.y.toInt())) {
          onTap(event.x, event.y)
        }
        return true
      }
      MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_OUTSIDE -> {
        pressed = false
        invalidate()
      }
    }
    return super.onTouchEvent(event)
  }

  /** Subclasses override to dispatch their tap event. */
  protected open fun onTap(x: Float, y: Float) {}

  private fun isPointInShape(x: Int, y: Int): Boolean {
    val path = shapePath ?: return x in 0..width && y in 0..height
    if (hitRegionDirty) {
      val clip = Region(0, 0, width.coerceAtLeast(1), height.coerceAtLeast(1))
      hitRegion.setPath(path, clip)
      hitRegionDirty = false
    }
    return hitRegion.contains(x, y)
  }

  companion object {

    /**
     * Builds a Path tracing the clockwise outline of `rects` (stacked
     * top to bottom, each representing one line of text). Every vertex
     * is smoothed with a quadratic bezier whose radius is clamped to
     * half the shorter adjacent segment, so concave staircase corners
     * curve inward naturally.
     *
     * `rects` must be in the overlay's local coordinate space (i.e.
     * already translated so the union bounding box starts at 0,0).
     */
    fun shapePathForRects(rects: List<RectF>, radius: Float): Path {
      val path = Path()
      if (rects.isEmpty()) return path
      if (rects.size == 1) {
        path.addRoundRect(rects[0], radius, radius, Path.Direction.CW)
        return path
      }

      val vertices = mutableListOf<PointF>()

      val r0 = rects[0]
      vertices.add(PointF(r0.left, r0.top))
      vertices.add(PointF(r0.right, r0.top))

      // Right side walk top → bottom; emit a horizontal step whenever
      // the next line's right edge differs.
      for (i in 0 until rects.size - 1) {
        val curr = rects[i]
        val next = rects[i + 1]
        vertices.add(PointF(curr.right, curr.bottom))
        if (abs(next.right - curr.right) > 0.5f) {
          vertices.add(PointF(next.right, curr.bottom))
        }
      }

      val rLast = rects.last()
      vertices.add(PointF(rLast.right, rLast.bottom))
      vertices.add(PointF(rLast.left, rLast.bottom))

      // Left side walk bottom → top with mirror-image steps.
      for (i in rects.size - 1 downTo 1) {
        val curr = rects[i]
        val prev = rects[i - 1]
        vertices.add(PointF(curr.left, curr.top))
        if (abs(prev.left - curr.left) > 0.5f) {
          vertices.add(PointF(prev.left, curr.top))
        }
      }

      val n = vertices.size
      if (radius <= 0f || n < 3) {
        path.moveTo(vertices[0].x, vertices[0].y)
        for (i in 1 until n) path.lineTo(vertices[i].x, vertices[i].y)
        path.close()
        return path
      }

      for (i in 0 until n) {
        val prev = vertices[(i + n - 1) % n]
        val curr = vertices[i]
        val next = vertices[(i + 1) % n]
        addRoundedVertex(path, prev, curr, next, radius, isFirst = i == 0)
      }
      path.close()
      return path
    }

    private fun addRoundedVertex(
      path: Path, prev: PointF, curr: PointF, next: PointF,
      radius: Float, isFirst: Boolean,
    ) {
      val d1 = hypot((curr.x - prev.x).toDouble(), (curr.y - prev.y).toDouble()).toFloat()
      val d2 = hypot((next.x - curr.x).toDouble(), (next.y - curr.y).toDouble()).toFloat()
      val r = min(radius, min(d1 * 0.5f, d2 * 0.5f))
      val t1 = if (d1 > 0f) r / d1 else 0f
      val t2 = if (d2 > 0f) r / d2 else 0f
      val inX = curr.x - (curr.x - prev.x) * t1
      val inY = curr.y - (curr.y - prev.y) * t1
      val outX = curr.x + (next.x - curr.x) * t2
      val outY = curr.y + (next.y - curr.y) * t2
      if (isFirst) path.moveTo(inX, inY) else path.lineTo(inX, inY)
      path.quadTo(curr.x, curr.y, outX, outY)
    }

    /**
     * Brightness-shifted pressed color, mirroring iOS's
     * MarkdownSpoilerPressedColor — adjusts HSV value by ±0.15 with
     * polarity flipping based on the source brightness so very-dark
     * colors lighten on press and light colors darken.
     */
    fun pressedColorFor(base: Int): Int {
      val hsv = FloatArray(3)
      Color.colorToHSV(base, hsv)
      hsv[2] = if (hsv[2] > 0.5f) (hsv[2] - 0.15f).coerceAtLeast(0f)
      else (hsv[2] + 0.15f).coerceAtMost(1f)
      val rgb = Color.HSVToColor(hsv)
      val a = Color.alpha(base)
      return Color.argb(a, Color.red(rgb), Color.green(rgb), Color.blue(rgb))
    }
  }
}
