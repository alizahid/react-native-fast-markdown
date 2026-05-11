package com.alizahid.markdown.style

import android.graphics.Color
import android.graphics.Rect

/**
 * Per-element style. Mirrors `MarkdownElementStyle` in
 * ios/styles/StyleConfig.h field-for-field. All fields default to "unset"
 * so the cascade rules can detect what was explicitly provided.
 *
 * - Numeric size fields use `Float.NaN` for "unset" (mirrors iOS's
 *   `0`-as-unset for most, except that 0 is a legal value for borders).
 * - Color fields use `null` for unset.
 */
class ElementStyle {
  // --- Text ---
  var color: Int? = null
  var fontFamily: String? = null
  var fontSize: Float = Float.NaN
  var fontStyle: String? = null
  var fontWeight: String? = null
  var letterSpacing: Float = Float.NaN
  var lineHeight: Float = Float.NaN
  var textAlign: String? = null
  var textDecorationColor: Int? = null
  var textDecorationLine: String? = null
  var textDecorationStyle: String? = null

  // --- View ---
  var backgroundColor: Int? = null

  // Layout
  var gap: Float = Float.NaN
  var width: Float = Float.NaN
  var height: Float = Float.NaN
  var maxWidth: Float = Float.NaN
  var maxHeight: Float = Float.NaN

  // Image-only
  var objectFit: String? = null

  // Margin
  var margin: Float = Float.NaN
  var marginTop: Float = Float.NaN
  var marginBottom: Float = Float.NaN
  var marginLeft: Float = Float.NaN
  var marginRight: Float = Float.NaN
  var marginHorizontal: Float = Float.NaN
  var marginVertical: Float = Float.NaN

  // Padding
  var padding: Float = Float.NaN
  var paddingTop: Float = Float.NaN
  var paddingBottom: Float = Float.NaN
  var paddingLeft: Float = Float.NaN
  var paddingRight: Float = Float.NaN
  var paddingHorizontal: Float = Float.NaN
  var paddingVertical: Float = Float.NaN

  // Border widths
  var borderWidth: Float = Float.NaN
  var borderTopWidth: Float = Float.NaN
  var borderBottomWidth: Float = Float.NaN
  var borderLeftWidth: Float = Float.NaN
  var borderRightWidth: Float = Float.NaN

  // Border colors
  var borderColor: Int? = null
  var borderTopColor: Int? = null
  var borderBottomColor: Int? = null
  var borderLeftColor: Int? = null
  var borderRightColor: Int? = null

  // Border radii
  var borderRadius: Float = Float.NaN
  var borderTopLeftRadius: Float = Float.NaN
  var borderTopRightRadius: Float = Float.NaN
  var borderBottomLeftRadius: Float = Float.NaN
  var borderBottomRightRadius: Float = Float.NaN

  // Border style
  var borderStyle: String? = null

  // ---- Resolved helpers (mirror iOS resolvedPaddingInsets etc.) ----

  fun resolvedPaddingInsets(): Rect = resolveInsets(
    base = padding,
    horizontal = paddingHorizontal,
    vertical = paddingVertical,
    top = paddingTop,
    bottom = paddingBottom,
    left = paddingLeft,
    right = paddingRight,
  )

  fun resolvedMarginInsets(): Rect = resolveInsets(
    base = margin,
    horizontal = marginHorizontal,
    vertical = marginVertical,
    top = marginTop,
    bottom = marginBottom,
    left = marginLeft,
    right = marginRight,
  )

  fun resolvedBorderWidths(): Rect = Rect(
    pickSize(borderLeftWidth, borderWidth),
    pickSize(borderTopWidth, borderWidth),
    pickSize(borderRightWidth, borderWidth),
    pickSize(borderBottomWidth, borderWidth),
  )

  fun resolvedBorderColorForEdge(edge: Edge): Int =
    when (edge) {
      Edge.Top -> borderTopColor ?: borderColor ?: Color.BLACK
      Edge.Right -> borderRightColor ?: borderColor ?: Color.BLACK
      Edge.Bottom -> borderBottomColor ?: borderColor ?: Color.BLACK
      Edge.Left -> borderLeftColor ?: borderColor ?: Color.BLACK
    }

  /**
   * Returns the 8-value FloatArray expected by Path.addRoundRect /
   * GradientDrawable.setCornerRadii: [topLeftX, topLeftY, topRightX,
   * topRightY, bottomRightX, bottomRightY, bottomLeftX, bottomLeftY].
   */
  fun resolvedRadiiForCorners(): FloatArray {
    val tl = orZero(borderTopLeftRadius, borderRadius)
    val tr = orZero(borderTopRightRadius, borderRadius)
    val br = orZero(borderBottomRightRadius, borderRadius)
    val bl = orZero(borderBottomLeftRadius, borderRadius)
    return floatArrayOf(tl, tl, tr, tr, br, br, bl, bl)
  }

  fun hasAnyBorder(): Boolean {
    val r = resolvedBorderWidths()
    return r.left != 0 || r.top != 0 || r.right != 0 || r.bottom != 0
  }

  fun hasAnyRadius(): Boolean =
    (!borderRadius.isNaN() && borderRadius > 0f) ||
    (!borderTopLeftRadius.isNaN() && borderTopLeftRadius > 0f) ||
    (!borderTopRightRadius.isNaN() && borderTopRightRadius > 0f) ||
    (!borderBottomLeftRadius.isNaN() && borderBottomLeftRadius > 0f) ||
    (!borderBottomRightRadius.isNaN() && borderBottomRightRadius > 0f)

  fun hasNonUniformBorders(): Boolean {
    val r = resolvedBorderWidths()
    if (r.left != r.top || r.left != r.right || r.left != r.bottom) return true
    val c = listOf(
      borderTopColor ?: borderColor,
      borderRightColor ?: borderColor,
      borderBottomColor ?: borderColor,
      borderLeftColor ?: borderColor,
    )
    return c.distinct().size > 1
  }

  enum class Edge { Top, Right, Bottom, Left }

  private fun resolveInsets(
    base: Float, horizontal: Float, vertical: Float,
    top: Float, bottom: Float, left: Float, right: Float,
  ): Rect {
    val t = if (!top.isNaN()) top else if (!vertical.isNaN()) vertical else if (!base.isNaN()) base else 0f
    val b = if (!bottom.isNaN()) bottom else if (!vertical.isNaN()) vertical else if (!base.isNaN()) base else 0f
    val l = if (!left.isNaN()) left else if (!horizontal.isNaN()) horizontal else if (!base.isNaN()) base else 0f
    val r = if (!right.isNaN()) right else if (!horizontal.isNaN()) horizontal else if (!base.isNaN()) base else 0f
    return Rect(l.toInt(), t.toInt(), r.toInt(), b.toInt())
  }

  private fun pickSize(specific: Float, fallback: Float): Int =
    when {
      !specific.isNaN() -> specific.toInt()
      !fallback.isNaN() -> fallback.toInt()
      else -> 0
    }

  private fun orZero(specific: Float, fallback: Float): Float =
    when {
      !specific.isNaN() -> specific
      !fallback.isNaN() -> fallback
      else -> 0f
    }
}
