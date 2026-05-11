package com.alizahid.markdown.renderer

import android.graphics.Typeface
import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.AbsoluteSizeSpan
import android.text.style.AlignmentSpan
import android.text.style.BackgroundColorSpan
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import android.text.style.TypefaceSpan
import android.text.style.UnderlineSpan
import com.alizahid.markdown.renderer.spans.CustomTypefaceSpan
import com.alizahid.markdown.renderer.spans.LetterSpacingSpan
import com.alizahid.markdown.renderer.spans.LineHeightSpan
import com.alizahid.markdown.style.ElementStyle

/**
 * Applies an ElementStyle's text and paragraph properties as spans
 * over `[start, end)`. Mirrors ios/renderer/StyleAttributes.
 *
 * Cascade rules match iOS:
 * - Font (family/weight/style): merged with the inherited typeface in
 *   the calling renderer via TypefaceResolver; pass the resolved
 *   Typeface in `resolvedTypeface`.
 * - Font size: AbsoluteSizeSpan when set.
 * - Color: ForegroundColorSpan.
 * - backgroundColor on inline elements (code, mention) maps to
 *   BackgroundColorSpan.
 * - letterSpacing: LetterSpacingSpan.
 * - lineHeight: LineHeightSpan (per-line replacement).
 * - textAlign: AlignmentSpan.Standard.
 * - textDecorationLine: UnderlineSpan / StrikethroughSpan; decoration
 *   colour applied via custom subclasses.
 */
object StyleAttributes {

  fun apply(
    style: ElementStyle?,
    into: SpannableStringBuilder,
    start: Int,
    end: Int,
    resolvedTypeface: Typeface?,
    resolvedFontSize: Float?,
  ) {
    if (style == null || start >= end) return
    val flags = Spanned.SPAN_EXCLUSIVE_EXCLUSIVE

    resolvedTypeface?.let {
      into.setSpan(CustomTypefaceSpan(it), start, end, flags)
    }
    resolvedFontSize?.let {
      if (it.isFinite() && it > 0f) {
        into.setSpan(AbsoluteSizeSpan(it.toInt(), false), start, end, flags)
      }
    }

    style.color?.let { into.setSpan(ForegroundColorSpan(it), start, end, flags) }
    style.backgroundColor?.let {
      into.setSpan(BackgroundColorSpan(it), start, end, flags)
    }

    if (!style.letterSpacing.isNaN() && style.letterSpacing != 0f) {
      into.setSpan(LetterSpacingSpan(style.letterSpacing), start, end, flags)
    }

    if (!style.lineHeight.isNaN() && style.lineHeight > 0f) {
      into.setSpan(LineHeightSpan(style.lineHeight.toInt()), start, end, flags)
    }

    style.textAlign?.let {
      val align = when (it) {
        "center" -> Layout.Alignment.ALIGN_CENTER
        "right" -> Layout.Alignment.ALIGN_OPPOSITE
        // Android has no built-in "justify" alignment until API 26's
        // JUSTIFICATION_MODE_INTER_WORD on TextView; we leave it as LEFT
        // here and the host TextView is configured to opt in to justify.
        else -> Layout.Alignment.ALIGN_NORMAL
      }
      into.setSpan(AlignmentSpan.Standard(align), start, end, flags)
    }

    style.textDecorationLine?.let { line ->
      val color = style.textDecorationColor
      if (line.contains("underline")) {
        into.setSpan(
          if (color != null) ColoredUnderlineSpan(color) else UnderlineSpan(),
          start, end, flags,
        )
      }
      if (line.contains("line-through")) {
        into.setSpan(
          if (color != null) ColoredStrikethroughSpan(color) else StrikethroughSpan(),
          start, end, flags,
        )
      }
    }
  }

  /**
   * Decorates the existing TypefaceSpan from the platform — sometimes
   * cheaper than building a full Typeface when only a family swap is
   * needed.
   */
  fun applyFontFamily(family: String, into: SpannableStringBuilder, start: Int, end: Int) {
    into.setSpan(TypefaceSpan(family), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
  }
}

internal class ColoredUnderlineSpan(private val color: Int) : UnderlineSpan() {
  override fun updateDrawState(ds: android.text.TextPaint) {
    super.updateDrawState(ds)
    ds.color = ds.color // keep text color
    // The platform draws underline with `linkColor` (or text color); we
    // adjust the underline color via reflection-free path: set `underlineColor`
    // when available (API 29+), else fall back to text color.
    runCatching { ds.underlineColor = color }
  }
}

internal class ColoredStrikethroughSpan(private val color: Int) : StrikethroughSpan() {
  override fun updateDrawState(ds: android.text.TextPaint) {
    super.updateDrawState(ds)
    // Android's strikethrough always uses the text color — to honor a
    // distinct decoration color we'd need a custom drawing span. For
    // now, swap the text colour at draw time so the line picks it up.
    ds.color = color
  }
}
