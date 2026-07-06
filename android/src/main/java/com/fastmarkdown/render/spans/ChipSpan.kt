package com.fastmarkdown.render.spans

/**
 * Data-only marker for a drawn run background ("chip"): BlockTextView fills
 * a rounded rect behind the run, sized from the run's real font metrics so
 * ascenders and descenders are always covered (TextPaint.bgColor and
 * NSBackgroundColor both misalign under custom line heights).
 */
class ChipSpan(
  val color: Int,
  val radiusPx: Float,
  val padLeftPx: Float,
  val padRightPx: Float,
  /** Height of a capital H in the run's font, from Paint.getTextBounds. */
  val capHeightPx: Float,
  /** Positive, from Paint.FontMetrics. */
  val descentPx: Float,
  val baselineShiftPx: Int,
)
