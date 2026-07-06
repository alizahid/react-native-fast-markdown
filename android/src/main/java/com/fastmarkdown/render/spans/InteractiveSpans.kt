package com.fastmarkdown.render.spans

/** Data-only marker spans; hit-testing and drawing live in BlockTextView. */
class LinkSpan(val url: String)

class SpoilerSpan(
  val id: Int,
  /** Run font, for measuring glyph ink bounds at draw time. */
  val typeface: android.graphics.Typeface?,
  val textSizePx: Float,
)

/**
 * Hides unrevealed spoiler text (the ink-hugging cover doesn't blanket the
 * glyphs). Self-describing so views can reconcile against the spannable
 * itself — content is cached and shared across recycled views, so span
 * bookkeeping must not live in view state.
 */
class SpoilerHidingSpan(
  val id: Int,
) : android.text.style.ForegroundColorSpan(android.graphics.Color.TRANSPARENT)
