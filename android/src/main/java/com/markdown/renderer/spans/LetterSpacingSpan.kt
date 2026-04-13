package com.markdown.renderer.spans

import android.text.TextPaint
import android.text.style.MetricAffectingSpan

/**
 * Sets letter spacing (tracking) on a text range.
 * Equivalent of iOS NSKernAttributeName.
 */
class LetterSpacingSpan(private val spacing: Float) : MetricAffectingSpan() {
    override fun updateMeasureState(textPaint: TextPaint) {
        textPaint.letterSpacing = spacing
    }

    override fun updateDrawState(tp: TextPaint) {
        tp.letterSpacing = spacing
    }
}
