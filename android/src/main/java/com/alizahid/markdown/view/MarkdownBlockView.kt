package com.alizahid.markdown.view

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import android.widget.FrameLayout
import com.alizahid.markdown.style.ElementStyle

/**
 * Container that draws an ElementStyle's view properties (background,
 * border per side, corner radii) and applies its padding/margin. Mirrors
 * ios/views/MarkdownBlockView.
 *
 * Phase 2 supports uniform borders + uniform radii. Phase 3 extends with
 * per-side widths/colors and per-corner radii via the Path-based path
 * (when `style.hasNonUniformBorders()`).
 */
class MarkdownBlockView(context: Context) : FrameLayout(context) {

  private var elementStyle: ElementStyle? = null
  private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
  private val clipPath = Path()
  private val tmpRect = RectF()
  private var huggingContent: Boolean = false

  fun setHuggingContent(hug: Boolean) {
    huggingContent = hug
  }

  fun setElementStyle(style: ElementStyle?) {
    elementStyle = style
    applyInsets()
    invalidate()
  }

  fun setContent(view: View) {
    removeAllViews()
    addView(view, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
  }

  private fun applyInsets() {
    val s = elementStyle ?: return
    val p = s.resolvedPaddingInsets()
    setPadding(p.left, p.top, p.right, p.bottom)
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    // hugging content: shrink width to first child's measured width
    if (huggingContent && childCount > 0) {
      val child = getChildAt(0)
      val cw = child.measuredWidth + paddingLeft + paddingRight
      val h = measuredHeight
      setMeasuredDimension(cw, h)
    }
  }

  override fun draw(canvas: Canvas) {
    val s = elementStyle
    if (s != null) {
      val w = width.toFloat()
      val h = height.toFloat()
      val radii = s.resolvedRadiiForCorners()
      val anyRadius = radii.any { it > 0f }
      tmpRect.set(0f, 0f, w, h)

      // Clip rounded background area
      if (anyRadius) {
        clipPath.reset()
        clipPath.addRoundRect(tmpRect, radii, Path.Direction.CW)
      }

      s.backgroundColor?.let { color ->
        bgPaint.color = color
        if (anyRadius) {
          canvas.drawPath(clipPath, bgPaint)
        } else {
          canvas.drawRect(tmpRect, bgPaint)
        }
      }
    }

    super.draw(canvas)

    if (s != null) {
      drawBorders(canvas, s)
    }
  }

  private fun drawBorders(canvas: Canvas, s: ElementStyle) {
    val widths = s.resolvedBorderWidths()
    if (widths.left == 0 && widths.top == 0 && widths.right == 0 && widths.bottom == 0) return

    val w = width.toFloat()
    val h = height.toFloat()

    if (!s.hasNonUniformBorders()) {
      val bw = widths.left.toFloat()
      if (bw <= 0f) return
      borderPaint.strokeWidth = bw
      borderPaint.color = s.resolvedBorderColorForEdge(ElementStyle.Edge.Top)
      val half = bw / 2f
      val rect = RectF(half, half, w - half, h - half)
      val radii = s.resolvedRadiiForCorners()
      if (radii.any { it > 0f }) {
        val path = Path().apply { addRoundRect(rect, radii, Path.Direction.CW) }
        canvas.drawPath(path, borderPaint)
      } else {
        canvas.drawRect(rect, borderPaint)
      }
      return
    }

    // Non-uniform: draw each side independently.
    val sides = listOf(
      Side(0f, 0f, w, 0f, widths.top.toFloat(), s.resolvedBorderColorForEdge(ElementStyle.Edge.Top)),
      Side(w, 0f, w, h, widths.right.toFloat(), s.resolvedBorderColorForEdge(ElementStyle.Edge.Right)),
      Side(0f, h, w, h, widths.bottom.toFloat(), s.resolvedBorderColorForEdge(ElementStyle.Edge.Bottom)),
      Side(0f, 0f, 0f, h, widths.left.toFloat(), s.resolvedBorderColorForEdge(ElementStyle.Edge.Left)),
    )
    for (side in sides) {
      if (side.width <= 0f) continue
      borderPaint.color = side.color
      borderPaint.strokeWidth = side.width
      val half = side.width / 2f
      val x1 = if (side.x1 == 0f) side.x1 + half else if (side.x1 == w) side.x1 - half else side.x1
      val y1 = if (side.y1 == 0f) side.y1 + half else if (side.y1 == h) side.y1 - half else side.y1
      val x2 = if (side.x2 == 0f) side.x2 + half else if (side.x2 == w) side.x2 - half else side.x2
      val y2 = if (side.y2 == 0f) side.y2 + half else if (side.y2 == h) side.y2 - half else side.y2
      canvas.drawLine(x1, y1, x2, y2, borderPaint)
    }
  }

  private data class Side(
    val x1: Float, val y1: Float, val x2: Float, val y2: Float,
    val width: Float, val color: Int,
  )
}
