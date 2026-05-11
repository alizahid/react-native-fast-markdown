package com.alizahid.markdown.renderer.spans

import android.graphics.Paint
import android.text.TextPaint
import android.text.style.MetricAffectingSpan

/**
 * RN `letterSpacing` is expressed in points; Android's
 * `Paint.setLetterSpacing` takes em units (multiplier of text size).
 * Convert at draw time so the value tracks dynamic font size.
 */
class LetterSpacingSpan(private val pixels: Float) : MetricAffectingSpan() {
  override fun updateDrawState(ds: TextPaint) = apply(ds)
  override fun updateMeasureState(p: TextPaint) = apply(p)
  private fun apply(p: Paint) {
    val ts = p.textSize
    if (ts > 0f) p.letterSpacing = pixels / ts
  }
}
