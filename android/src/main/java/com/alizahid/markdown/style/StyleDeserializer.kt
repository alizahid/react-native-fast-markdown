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
 */
internal object StyleDeserializer {

  fun parse(json: String): StyleConfig {
    val root = try {
      JSONObject(json)
    } catch (_: Throwable) {
      return StyleConfig()
    }
    val cfg = StyleConfig()
    cfg.base = parseElement(root.optJSONObject("base"))
    cfg.paragraph = parseElement(root.optJSONObject("paragraph"))
    cfg.heading1 = parseElement(root.optJSONObject("heading1"))
    cfg.heading2 = parseElement(root.optJSONObject("heading2"))
    cfg.heading3 = parseElement(root.optJSONObject("heading3"))
    cfg.heading4 = parseElement(root.optJSONObject("heading4"))
    cfg.heading5 = parseElement(root.optJSONObject("heading5"))
    cfg.heading6 = parseElement(root.optJSONObject("heading6"))
    cfg.blockquote = parseElement(root.optJSONObject("blockquote"))
    cfg.codeBlock = parseElement(root.optJSONObject("codeBlock"))
    cfg.list = parseElement(root.optJSONObject("list"))
    cfg.listItem = parseElement(root.optJSONObject("listItem"))
    cfg.listBullet = parseElement(root.optJSONObject("listBullet"))
    cfg.thematicBreak = parseElement(root.optJSONObject("thematicBreak"))
    cfg.image = parseElement(root.optJSONObject("image"))
    cfg.table = parseElement(root.optJSONObject("table"))
    cfg.tableRow = parseElement(root.optJSONObject("tableRow"))
    cfg.tableHeaderRow = parseElement(root.optJSONObject("tableHeaderRow"))
    cfg.tableCell = parseElement(root.optJSONObject("tableCell"))
    cfg.tableHeaderCell = parseElement(root.optJSONObject("tableHeaderCell"))
    cfg.strong = parseElement(root.optJSONObject("strong"))
    cfg.emphasis = parseElement(root.optJSONObject("emphasis"))
    cfg.strikethrough = parseElement(root.optJSONObject("strikethrough"))
    cfg.code = parseElement(root.optJSONObject("code"))
    cfg.link = parseElement(root.optJSONObject("link"))
    cfg.mentionUser = parseElement(root.optJSONObject("mentionUser"))
    cfg.mentionChannel = parseElement(root.optJSONObject("mentionChannel"))
    cfg.mentionCommand = parseElement(root.optJSONObject("mentionCommand"))
    cfg.spoiler = parseElement(root.optJSONObject("spoiler"))
    cfg.superscript = parseElement(root.optJSONObject("superscript"))
    return cfg
  }

  private fun parseElement(obj: JSONObject?): ElementStyle {
    val s = ElementStyle()
    if (obj == null) return s

    s.color = colorOf(obj, "color")
    s.fontFamily = stringOf(obj, "fontFamily")
    s.fontSize = floatOf(obj, "fontSize")
    s.fontStyle = stringOf(obj, "fontStyle")
    s.fontWeight = stringOf(obj, "fontWeight")
    s.letterSpacing = floatOf(obj, "letterSpacing")
    s.lineHeight = floatOf(obj, "lineHeight")
    s.textAlign = stringOf(obj, "textAlign")
    s.textDecorationColor = colorOf(obj, "textDecorationColor")
    s.textDecorationLine = stringOf(obj, "textDecorationLine")
    s.textDecorationStyle = stringOf(obj, "textDecorationStyle")

    s.backgroundColor = colorOf(obj, "backgroundColor")

    s.gap = floatOf(obj, "gap")
    s.width = floatOf(obj, "width")
    s.height = floatOf(obj, "height")
    s.maxWidth = floatOf(obj, "maxWidth")
    s.maxHeight = floatOf(obj, "maxHeight")
    s.objectFit = stringOf(obj, "objectFit")

    s.margin = floatOf(obj, "margin")
    s.marginTop = floatOf(obj, "marginTop")
    s.marginBottom = floatOf(obj, "marginBottom")
    s.marginLeft = floatOf(obj, "marginLeft")
    s.marginRight = floatOf(obj, "marginRight")
    s.marginHorizontal = floatOf(obj, "marginHorizontal")
    s.marginVertical = floatOf(obj, "marginVertical")

    s.padding = floatOf(obj, "padding")
    s.paddingTop = floatOf(obj, "paddingTop")
    s.paddingBottom = floatOf(obj, "paddingBottom")
    s.paddingLeft = floatOf(obj, "paddingLeft")
    s.paddingRight = floatOf(obj, "paddingRight")
    s.paddingHorizontal = floatOf(obj, "paddingHorizontal")
    s.paddingVertical = floatOf(obj, "paddingVertical")

    s.borderWidth = floatOf(obj, "borderWidth")
    s.borderTopWidth = floatOf(obj, "borderTopWidth")
    s.borderBottomWidth = floatOf(obj, "borderBottomWidth")
    s.borderLeftWidth = floatOf(obj, "borderLeftWidth")
    s.borderRightWidth = floatOf(obj, "borderRightWidth")

    s.borderColor = colorOf(obj, "borderColor")
    s.borderTopColor = colorOf(obj, "borderTopColor")
    s.borderBottomColor = colorOf(obj, "borderBottomColor")
    s.borderLeftColor = colorOf(obj, "borderLeftColor")
    s.borderRightColor = colorOf(obj, "borderRightColor")

    s.borderRadius = floatOf(obj, "borderRadius")
    s.borderTopLeftRadius = floatOf(obj, "borderTopLeftRadius")
    s.borderTopRightRadius = floatOf(obj, "borderTopRightRadius")
    s.borderBottomLeftRadius = floatOf(obj, "borderBottomLeftRadius")
    s.borderBottomRightRadius = floatOf(obj, "borderBottomRightRadius")

    s.borderStyle = stringOf(obj, "borderStyle")

    return s
  }

  private fun stringOf(obj: JSONObject, key: String): String? =
    if (obj.isNull(key)) null else obj.optString(key, "").ifEmpty { null }

  private fun floatOf(obj: JSONObject, key: String): Float =
    if (obj.isNull(key) || !obj.has(key)) Float.NaN else obj.optDouble(key, Double.NaN).toFloat()

  private fun colorOf(obj: JSONObject, key: String): Int? {
    if (obj.isNull(key) || !obj.has(key)) return null
    return ColorConvert.fromJsonValue(obj.opt(key))
  }
}
