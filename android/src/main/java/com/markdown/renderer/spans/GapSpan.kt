package com.markdown.renderer.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.style.ReplacementSpan

/**
 * Replaces the gap text (zero-width space + newline) with empty
 * vertical space of exactly [gapPx] pixels. Using ReplacementSpan
 * gives full control over the height — LineHeightSpan can be
 * overridden by other spans or font metrics.
 */
class GapSpan(private val gapPx: Int) : ReplacementSpan() {

    override fun getSize(
        paint: Paint,
        text: CharSequence,
        start: Int,
        end: Int,
        fm: Paint.FontMetricsInt?,
    ): Int {
        if (fm != null) {
            fm.top = -gapPx
            fm.ascent = -gapPx
            fm.descent = 0
            fm.bottom = 0
            fm.leading = 0
        }
        return 0 // zero width — the gap is vertical only
    }

    override fun draw(
        canvas: Canvas,
        text: CharSequence,
        start: Int,
        end: Int,
        x: Float,
        top: Int,
        y: Int,
        bottom: Int,
        paint: Paint,
    ) {
        // Nothing to draw — just empty space
    }
}
