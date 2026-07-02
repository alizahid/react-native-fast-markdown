package com.fastmarkdown.style

import org.json.JSONObject

/**
 * Parsed stylesJson with defaults. M1 covers the main container section and
 * default text sizing; per-element styling lands in M2.
 */
class StyleConfig private constructor(private val json: JSONObject) {
  private val main: JSONObject? = json.optJSONObject("main")

  val gap: Float = main.optFloatOr("gap", 12f)
  val paddingLeft: Float = main.optFloatOr("paddingLeft", 0f)
  val paddingRight: Float = main.optFloatOr("paddingRight", 0f)
  val paddingTop: Float = main.optFloatOr("paddingTop", 0f)
  val paddingBottom: Float = main.optFloatOr("paddingBottom", 0f)
  val backgroundColor: Int? = main.optColor("backgroundColor")

  /** Font size (dp) for a heading level 1-6 or body text (level 0). */
  fun fontSize(headingLevel: Int): Float = when (headingLevel) {
    1 -> 32f
    2 -> 26f
    3 -> 22f
    4 -> 18f
    5 -> 16f
    6 -> 14f
    else -> 16f
  }

  companion object {
    private val cache = HashMap<String, StyleConfig>()

    fun from(stylesJson: String): StyleConfig {
      synchronized(cache) {
        cache[stylesJson]?.let { return it }
        val config = StyleConfig(
          runCatching { JSONObject(stylesJson.ifEmpty { "{}" }) }.getOrElse { JSONObject() }
        )
        if (cache.size > 16) {
          cache.clear()
        }
        cache[stylesJson] = config
        return config
      }
    }

    private fun JSONObject?.optFloatOr(key: String, fallback: Float): Float {
      val value = this?.optDouble(key) ?: return fallback
      return if (value.isNaN()) fallback else value.toFloat()
    }

    private fun JSONObject?.optColor(key: String): Int? {
      if (this == null || !has(key)) {
        return null
      }
      val value = optLong(key, Long.MIN_VALUE)
      return if (value == Long.MIN_VALUE) null else value.toInt()
    }
  }
}
