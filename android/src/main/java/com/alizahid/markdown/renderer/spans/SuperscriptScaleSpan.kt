package com.alizahid.markdown.renderer.spans

import android.graphics.Paint
import android.text.TextPaint
import android.text.style.MetricAffectingSpan

/**
 * Manual superscript that mirrors iOS Core Text's
 * kCTSuperscriptAttributeName *fallback path* — scale down the text
 * and lift the baseline. Android has no built-in OpenType "sups"
 * variant lookup so this is the rendering for every font.
 *
 * Defaults match common heuristics: 70% of original size, baseline
 * shifted up by 0.4 × ascent.
 */
class SuperscriptScaleSpan(
  private val sizeRatio: Float = 0.7f,
  private val baselineShiftRatio: Float = 0.4f,
) : MetricAffectingSpan() {

  override fun updateDrawState(ds: TextPaint) = apply(ds)
  override fun updateMeasureState(p: TextPaint) = apply(p)

  private fun apply(p: Paint) {
    val originalSize = p.textSize
    val originalAscent = p.ascent()
    p.textSize = originalSize * sizeRatio
    p.baselineShift -= (originalAscent * baselineShiftRatio).toInt()
  }
}
