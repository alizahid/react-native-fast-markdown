package com.fastmarkdown.style

import com.fastmarkdown.style.TextStyleSpec.Companion.optColor
import java.util.regex.Pattern
import org.json.JSONObject

class MentionVariant(val pattern: Pattern, val style: TextStyleSpec?)

/**
 * Parsed stylesJson with defaults, cached per JSON string.
 */
class StyleConfig private constructor(private val root: JSONObject) {
  private val main: JSONObject? = root.optJSONObject("main")
  private val textStyles = HashMap<String, TextStyleSpec?>()

  val gap: Float = main.optFloatOr("gap", 12f)
  val paddingLeft: Float = main.optFloatOr("paddingLeft", 0f)
  val paddingRight: Float = main.optFloatOr("paddingRight", 0f)
  val paddingTop: Float = main.optFloatOr("paddingTop", 0f)
  val paddingBottom: Float = main.optFloatOr("paddingBottom", 0f)
  val backgroundColor: Int? = main?.optColor("backgroundColor")

  /** Ordered longest-pattern-first; a link whose URL matches is a mention. */
  val mentionVariants: List<MentionVariant> = buildList {
    val variants = root.optJSONObject("mention")?.optJSONArray("variants") ?: return@buildList
    for (i in 0 until variants.length()) {
      val pair = variants.optJSONArray(i) ?: continue
      val patternString = pair.optString(0, "")
      if (patternString.isEmpty()) {
        continue
      }
      val pattern = runCatching { Pattern.compile(patternString) }.getOrNull() ?: continue
      add(MentionVariant(pattern, TextStyleSpec.from(pair.optJSONObject(1))))
    }
  }

  /** User style for an element key; null when not provided. */
  fun textStyleFor(key: String): TextStyleSpec? {
    synchronized(textStyles) {
      if (textStyles.containsKey(key)) {
        return textStyles[key]
      }
      val style = TextStyleSpec.from(root.optJSONObject(key))
      textStyles[key] = style
      return style
    }
  }

  /** Built-in default font size (dp) for heading level 1-6 or body (0). */
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
  }
}
