package com.alizahid.markdown.renderer.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.text.style.LineBackgroundSpan
import kotlin.math.max
import kotlin.math.min

/**
 * Paints a tinted background behind code spans for each line they cover.
 * Built as a LineBackgroundSpan so wrapped inline code keeps its tint
 * across every glyph row, not just the first line — mirrors the iOS
 * `NSBackgroundColorAttributeName` behaviour on `NSAttributedString`.
 */
class CodeBackgroundSpan(
  private val color: Int,
  private val cornerRadius: Float = 4f,
  private val horizontalPaddingPx: Float = 2f,
) : LineBackgroundSpan {
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = this@CodeBackgroundSpan.color }
  private val rect = RectF()

  override fun drawBackground(
    canvas: Canvas, paint: Paint,
    left: Int, right: Int, top: Int, baseline: Int, bottom: Int,
    text: CharSequence, start: Int, end: Int, lineNumber: Int,
  ) {
    val s = max(start, findSpanStart(text))
    val e = min(end, findSpanEnd(text))
    if (s >= e) return
    val measured = paint.measureText(text, s, e)
    val xStart = paint.measureText(text, start, s) + left.toFloat()
    rect.set(
      xStart - horizontalPaddingPx,
      top.toFloat(),
      xStart + measured + horizontalPaddingPx,
      bottom.toFloat(),
    )
    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, this.paint)
  }

  private fun findSpanStart(text: CharSequence): Int =
    if (text is android.text.Spanned) text.getSpanStart(this) else 0
  private fun findSpanEnd(text: CharSequence): Int =
    if (text is android.text.Spanned) text.getSpanEnd(this) else text.length
}
