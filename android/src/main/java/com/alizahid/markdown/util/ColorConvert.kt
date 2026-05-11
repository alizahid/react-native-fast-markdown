package com.alizahid.markdown.util

import android.graphics.Color

/**
 * RN serializes processed colors as either an `Int` (most common —
 * `processColor()` output is an unsigned 32-bit ARGB) or a CSS string
 * like `"#RRGGBB"`, `"#RRGGBBAA"`, `"rgb(r,g,b)"`, `"rgba(r,g,b,a)"`.
 * We accept anything JSON might surface.
 */
object ColorConvert {

  fun fromJsonValue(value: Any?): Int? = when (value) {
    null -> null
    is Int -> value
    is Long -> value.toInt()
    is Double -> value.toInt()
    is Number -> value.toInt()
    is String -> fromString(value)
    else -> null
  }

  fun fromString(s: String): Int? {
    val v = s.trim()
    if (v.isEmpty()) return null
    if (v.startsWith("#")) return runCatching { Color.parseColor(v) }.getOrNull()
    if (v.startsWith("rgb")) return parseRgb(v)
    return runCatching { Color.parseColor(v) }.getOrNull()
  }

  private fun parseRgb(s: String): Int? {
    val open = s.indexOf('(')
    val close = s.indexOf(')')
    if (open < 0 || close < 0 || close <= open) return null
    val parts = s.substring(open + 1, close).split(',').map { it.trim() }
    if (parts.size < 3) return null
    val r = parts[0].toIntOrNull() ?: return null
    val g = parts[1].toIntOrNull() ?: return null
    val b = parts[2].toIntOrNull() ?: return null
    val a = if (parts.size >= 4) {
      val af = parts[3].toFloatOrNull() ?: return null
      (af.coerceIn(0f, 1f) * 255f).toInt()
    } else 255
    return Color.argb(a, r, g, b)
  }
}
