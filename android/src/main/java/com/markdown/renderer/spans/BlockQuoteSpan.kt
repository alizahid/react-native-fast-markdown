package com.markdown.renderer.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.style.LeadingMarginSpan
import android.text.style.LineBackgroundSpan

/**
 * Renders a blockquote with a colored vertical bar on the left edge
 * and optional background fill. Replaces the unicode box-drawing
 * character approach with proper Canvas drawing.
 */
class BlockQuoteSpan(
    private val barColor: Int,
    private val barWidth: Float = 3f,
    private val gapWidth: Float = 8f,
    private val backgroundColor: Int? = null,
    private val nestingLevel: Int = 0,
) : LeadingMarginSpan, LineBackgroundSpan {

    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    override fun getLeadingMargin(first: Boolean): Int {
        return (barWidth + gapWidth).toInt()
    }

    override fun drawLeadingMargin(
        c: Canvas, p: Paint, x: Int, dir: Int,
        top: Int, baseline: Int, bottom: Int,
        text: CharSequence, start: Int, end: Int,
        first: Boolean, layout: Layout,
    ) {
        // Draw the vertical bar
        barPaint.color = barColor
        val barLeft = x.toFloat() + (nestingLevel * (barWidth + gapWidth))
        c.drawRect(
            barLeft,
            top.toFloat(),
            barLeft + barWidth,
            bottom.toFloat(),
            barPaint,
        )
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
        if (backgroundColor != null) {
            bgPaint.color = backgroundColor
            canvas.drawRect(
                left.toFloat(),
                top.toFloat(),
                right.toFloat(),
                bottom.toFloat(),
                bgPaint,
            )
        }
    }
}
