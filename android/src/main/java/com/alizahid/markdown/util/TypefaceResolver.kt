package com.alizahid.markdown.util

import android.graphics.Typeface
import android.os.Build
import com.alizahid.markdown.style.ElementStyle
import java.util.concurrent.ConcurrentHashMap

/**
 * Builds a `Typeface` matching an ElementStyle's font* properties,
 * cascaded over a base typeface. Mirrors iOS `resolvedFontWithBase:`.
 *
 * API 28+ lets us pick fine-grained weight (100–900); older devices
 * fall back to BOLD/NORMAL toggling.
 */
object TypefaceResolver {

  private data class Key(
    val family: String?,
    val weight: Int,
    val italic: Boolean,
    val baseId: Int,
  )

  private val cache = ConcurrentHashMap<Key, Typeface>()

  fun resolve(
    style: ElementStyle,
    base: Typeface? = Typeface.DEFAULT,
  ): Typeface {
    val baseTf = base ?: Typeface.DEFAULT
    val weight = weightFromString(style.fontWeight, baseTf)
    val italic = when (style.fontStyle) {
      "italic" -> true
      "normal" -> false
      else -> baseTf.isItalic
    }
    val family = style.fontFamily

    val key = Key(family, weight, italic, System.identityHashCode(baseTf))
    cache[key]?.let { return it }

    val familyTf: Typeface = if (family != null) {
      Typeface.create(family, Typeface.NORMAL)
    } else baseTf

    val out: Typeface = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      Typeface.create(familyTf, weight, italic)
    } else {
      val style2 = when {
        weight >= 600 && italic -> Typeface.BOLD_ITALIC
        weight >= 600 -> Typeface.BOLD
        italic -> Typeface.ITALIC
        else -> Typeface.NORMAL
      }
      Typeface.create(familyTf, style2)
    }
    cache[key] = out
    return out
  }

  fun weightFromString(value: String?, base: Typeface): Int {
    if (value == null) {
      return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) base.weight
      else if (base.isBold) 700 else 400
    }
    return when (value) {
      "bold", "700" -> 700
      "normal", "400" -> 400
      "100" -> 100
      "200" -> 200
      "300" -> 300
      "500" -> 500
      "600" -> 600
      "800" -> 800
      "900" -> 900
      else -> value.toIntOrNull() ?: 400
    }
  }
}
