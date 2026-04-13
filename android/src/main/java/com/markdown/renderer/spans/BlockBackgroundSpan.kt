package com.markdown.renderer.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.style.LeadingMarginSpan
import android.text.style.LineBackgroundSpan

/**
 * Draws a background fill, optional borders, and optional rounded
 * corners behind a range of text. Used for code blocks and other
 * block elements that need box-model styling.
 *
 * Implements both LineBackgroundSpan (for drawing) and
 * LeadingMarginSpan (for left/right padding so text doesn't touch
 * the block edges).
 */
class BlockBackgroundSpan(
    private val backgroundColor: Int,
    private val borderRadius: Float = 0f,
    private val paddingLeft: Float = 0f,
    private val paddingRight: Float = 0f,
    private val paddingTop: Float = 0f,
    private val paddingBottom: Float = 0f,
    private val borderLeftWidth: Float = 0f,
    private val borderLeftColor: Int = 0,
    private val borderTopWidth: Float = 0f,
    private val borderTopColor: Int = 0,
    private val borderRightWidth: Float = 0f,
    private val borderRightColor: Int = 0,
    private val borderBottomWidth: Float = 0f,
    private val borderBottomColor: Int = 0,
) : LineBackgroundSpan, LeadingMarginSpan {

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = backgroundColor
    }

    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
    }

    private val rect = RectF()
    private val clipPath = Path()

    override fun getLeadingMargin(first: Boolean): Int {
        return (paddingLeft + borderLeftWidth).toInt()
    }

    override fun drawLeadingMargin(
        c: Canvas, p: Paint, x: Int, dir: Int,
        top: Int, baseline: Int, bottom: Int,
        text: CharSequence, start: Int, end: Int,
        first: Boolean, layout: Layout,
    ) {
        // Drawing handled in drawBackground
    }

    override fun drawBackground(
        canvas: Canvas,
        paint: Paint,
        left: Int,
        right: Int,
        top: Int,
        baseline: Int,
        bottom: Int,
        text: CharSequence,
        start: Int,
        end: Int,
        lineNumber: Int,
    ) {
        // Determine if this is the first/last line of the span
        val spannable = text as? android.text.Spanned ?: return
        val spanStart = spannable.getSpanStart(this)
        val spanEnd = spannable.getSpanEnd(this)

        val isFirstLine = start <= spanStart
        val isLastLine = end >= spanEnd

        // Extend the rect to include padding
        val drawLeft = left.toFloat() - paddingLeft - borderLeftWidth
        val drawRight = right.toFloat() + paddingRight + borderRightWidth
        val drawTop = if (isFirstLine) top.toFloat() - paddingTop - borderTopWidth else top.toFloat()
        val drawBottom = if (isLastLine) bottom.toFloat() + paddingBottom + borderBottomWidth else bottom.toFloat()

        rect.set(drawLeft, drawTop, drawRight, drawBottom)

        // Draw background fill
        if (borderRadius > 0f && (isFirstLine || isLastLine)) {
            // For single-line blocks or first/last lines, use rounded corners
            if (isFirstLine && isLastLine) {
                canvas.drawRoundRect(rect, borderRadius, borderRadius, fillPaint)
            } else if (isFirstLine) {
                drawTopRoundRect(canvas, rect, borderRadius, fillPaint)
            } else {
                drawBottomRoundRect(canvas, rect, borderRadius, fillPaint)
            }
        } else {
            canvas.drawRect(rect, fillPaint)
        }

        // Draw borders
        drawBorders(canvas, rect, isFirstLine, isLastLine)
    }

    private fun drawBorders(canvas: Canvas, box: RectF, isFirst: Boolean, isLast: Boolean) {
        // Left border
        if (borderLeftWidth > 0f) {
            borderPaint.color = borderLeftColor
            borderPaint.strokeWidth = borderLeftWidth
            val x = box.left + borderLeftWidth / 2f
            canvas.drawLine(x, box.top, x, box.bottom, borderPaint)
        }

        // Right border
        if (borderRightWidth > 0f) {
            borderPaint.color = borderRightColor
            borderPaint.strokeWidth = borderRightWidth
            val x = box.right - borderRightWidth / 2f
            canvas.drawLine(x, box.top, x, box.bottom, borderPaint)
        }

        // Top border (only on first line)
        if (isFirst && borderTopWidth > 0f) {
            borderPaint.color = borderTopColor
            borderPaint.strokeWidth = borderTopWidth
            val y = box.top + borderTopWidth / 2f
            canvas.drawLine(box.left, y, box.right, y, borderPaint)
        }

        // Bottom border (only on last line)
        if (isLast && borderBottomWidth > 0f) {
            borderPaint.color = borderBottomColor
            borderPaint.strokeWidth = borderBottomWidth
            val y = box.bottom - borderBottomWidth / 2f
            canvas.drawLine(box.left, y, box.right, y, borderPaint)
        }
    }

    private fun drawTopRoundRect(canvas: Canvas, rect: RectF, radius: Float, paint: Paint) {
        clipPath.reset()
        clipPath.addRoundRect(
            rect.left, rect.top, rect.right, rect.bottom,
            floatArrayOf(radius, radius, radius, radius, 0f, 0f, 0f, 0f),
            Path.Direction.CW,
        )
        canvas.save()
        canvas.clipPath(clipPath)
        canvas.drawRect(rect, paint)
        canvas.restore()
    }

    private fun drawBottomRoundRect(canvas: Canvas, rect: RectF, radius: Float, paint: Paint) {
        clipPath.reset()
        clipPath.addRoundRect(
            rect.left, rect.top, rect.right, rect.bottom,
            floatArrayOf(0f, 0f, 0f, 0f, radius, radius, radius, radius),
            Path.Direction.CW,
        )
        canvas.save()
        canvas.clipPath(clipPath)
        canvas.drawRect(rect, paint)
        canvas.restore()
    }
}
