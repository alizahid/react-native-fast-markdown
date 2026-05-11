package com.alizahid.markdown.style

import com.alizahid.markdown.util.ColorConvert
import org.json.JSONObject

/**
 * Parses the JSON-serialized `MarkdownStyle` object received from JS into
 * a `StyleConfig`. Uses `org.json` (already on every Android build) so we
 * don't ship a deserialization dependency for what is essentially a flat
 * record per element. Color values arrive pre-processed by RN as
 * `"#RRGGBB"` / `"rgb(...)"` / `"rgba(...)"` / `Int`; `ColorConvert`
 * handles every form.
 *
 * **Density:** every length-like field (fontSize, padding, margin,
 * borders, radii, gap, width/height/maxWidth/maxHeight, lineHeight,
 * letterSpacing) is multiplied by `density` on read. RN's JS layer
 * sends values in dp; iOS treats them as points (visually equivalent).
 * Android needs them in raw pixels for `setTextSize(COMPLEX_UNIT_PX, …)`,
 * `setPadding(…)`, `Paint.strokeWidth = …`, etc. Multiplying once at
 * the boundary lets every downstream code path stay in a single unit.
 */
internal object StyleDeserializer {

  fun parse(json: String, density: Float): StyleConfig {
    val root = try {
      JSONObject(json)
    } catch (_: Throwable) {
      return StyleConfig()
    }
    val cfg = StyleConfig()
    cfg.base = parseElement(root.optJSONObject("base"), density)
    cfg.paragraph = parseElement(root.optJSONObject("paragraph"), density)
    cfg.heading1 = parseElement(root.optJSONObject("heading1"), density)
    cfg.heading2 = parseElement(root.optJSONObject("heading2"), density)
    cfg.heading3 = parseElement(root.optJSONObject("heading3"), density)
    cfg.heading4 = parseElement(root.optJSONObject("heading4"), density)
    cfg.heading5 = parseElement(root.optJSONObject("heading5"), density)
    cfg.heading6 = parseElement(root.optJSONObject("heading6"), density)
    cfg.blockquote = parseElement(root.optJSONObject("blockquote"), density)
    cfg.codeBlock = parseElement(root.optJSONObject("codeBlock"), density)
    cfg.list = parseElement(root.optJSONObject("list"), density)
    cfg.listItem = parseElement(root.optJSONObject("listItem"), density)
    cfg.listBullet = parseElement(root.optJSONObject("listBullet"), density)
    cfg.thematicBreak = parseElement(root.optJSONObject("thematicBreak"), density)
    cfg.image = parseElement(root.optJSONObject("image"), density)
    cfg.table = parseElement(root.optJSONObject("table"), density)
    cfg.tableRow = parseElement(root.optJSONObject("tableRow"), density)
    cfg.tableHeaderRow = parseElement(root.optJSONObject("tableHeaderRow"), density)
    cfg.tableCell = parseElement(root.optJSONObject("tableCell"), density)
    cfg.tableHeaderCell = parseElement(root.optJSONObject("tableHeaderCell"), density)
    cfg.strong = parseElement(root.optJSONObject("strong"), density)
    cfg.emphasis = parseElement(root.optJSONObject("emphasis"), density)
    cfg.strikethrough = parseElement(root.optJSONObject("strikethrough"), density)
    cfg.code = parseElement(root.optJSONObject("code"), density)
    cfg.link = parseElement(root.optJSONObject("link"), density)
    cfg.mentionUser = parseElement(root.optJSONObject("mentionUser"), density)
    cfg.mentionChannel = parseElement(root.optJSONObject("mentionChannel"), density)
    cfg.mentionCommand = parseElement(root.optJSONObject("mentionCommand"), density)
    cfg.spoiler = parseElement(root.optJSONObject("spoiler"), density)
    cfg.superscript = parseElement(root.optJSONObject("superscript"), density)
    return cfg
  }

  private fun parseElement(obj: JSONObject?, density: Float): ElementStyle {
    val s = ElementStyle()
    if (obj == null) return s

    s.color = colorOf(obj, "color")
    s.fontFamily = stringOf(obj, "fontFamily")
    s.fontSize = dpOf(obj, "fontSize", density)
    s.fontStyle = stringOf(obj, "fontStyle")
    s.fontWeight = stringOf(obj, "fontWeight")
    s.letterSpacing = dpOf(obj, "letterSpacing", density)
    s.lineHeight = dpOf(obj, "lineHeight", density)
    s.textAlign = stringOf(obj, "textAlign")
    s.textDecorationColor = colorOf(obj, "textDecorationColor")
    s.textDecorationLine = stringOf(obj, "textDecorationLine")
    s.textDecorationStyle = stringOf(obj, "textDecorationStyle")

    s.backgroundColor = colorOf(obj, "backgroundColor")

    s.gap = dpOf(obj, "gap", density)
    s.width = dpOf(obj, "width", density)
    s.height = dpOf(obj, "height", density)
    s.maxWidth = dpOf(obj, "maxWidth", density)
    s.maxHeight = dpOf(obj, "maxHeight", density)
    s.objectFit = stringOf(obj, "objectFit")

    s.margin = dpOf(obj, "margin", density)
    s.marginTop = dpOf(obj, "marginTop", density)
    s.marginBottom = dpOf(obj, "marginBottom", density)
    s.marginLeft = dpOf(obj, "marginLeft", density)
    s.marginRight = dpOf(obj, "marginRight", density)
    s.marginHorizontal = dpOf(obj, "marginHorizontal", density)
    s.marginVertical = dpOf(obj, "marginVertical", density)

    s.padding = dpOf(obj, "padding", density)
    s.paddingTop = dpOf(obj, "paddingTop", density)
    s.paddingBottom = dpOf(obj, "paddingBottom", density)
    s.paddingLeft = dpOf(obj, "paddingLeft", density)
    s.paddingRight = dpOf(obj, "paddingRight", density)
    s.paddingHorizontal = dpOf(obj, "paddingHorizontal", density)
    s.paddingVertical = dpOf(obj, "paddingVertical", density)

    s.borderWidth = dpOf(obj, "borderWidth", density)
    s.borderTopWidth = dpOf(obj, "borderTopWidth", density)
    s.borderBottomWidth = dpOf(obj, "borderBottomWidth", density)
    s.borderLeftWidth = dpOf(obj, "borderLeftWidth", density)
    s.borderRightWidth = dpOf(obj, "borderRightWidth", density)

    s.borderColor = colorOf(obj, "borderColor")
    s.borderTopColor = colorOf(obj, "borderTopColor")
    s.borderBottomColor = colorOf(obj, "borderBottomColor")
    s.borderLeftColor = colorOf(obj, "borderLeftColor")
    s.borderRightColor = colorOf(obj, "borderRightColor")

    s.borderRadius = dpOf(obj, "borderRadius", density)
    s.borderTopLeftRadius = dpOf(obj, "borderTopLeftRadius", density)
    s.borderTopRightRadius = dpOf(obj, "borderTopRightRadius", density)
    s.borderBottomLeftRadius = dpOf(obj, "borderBottomLeftRadius", density)
    s.borderBottomRightRadius = dpOf(obj, "borderBottomRightRadius", density)

    s.borderStyle = stringOf(obj, "borderStyle")

    return s
  }

  private fun stringOf(obj: JSONObject, key: String): String? =
    if (obj.isNull(key)) null else obj.optString(key, "").ifEmpty { null }

  /** Reads a length value from JSON and multiplies by `density` (dp → px). */
  private fun dpOf(obj: JSONObject, key: String, density: Float): Float {
    if (obj.isNull(key) || !obj.has(key)) return Float.NaN
    val v = obj.optDouble(key, Double.NaN)
    if (v.isNaN()) return Float.NaN
    return (v * density).toFloat()
  }

  private fun colorOf(obj: JSONObject, key: String): Int? {
    if (obj.isNull(key) || !obj.has(key)) return null
    return ColorConvert.fromJsonValue(obj.opt(key))
  }
}
