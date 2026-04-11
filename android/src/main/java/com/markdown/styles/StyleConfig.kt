package com.markdown.styles

import android.graphics.Color
import android.graphics.Typeface
import org.json.JSONObject

data class ElementStyle(
    // Text
    val fontSize: Float = 0f,
    val fontWeight: String? = null,
    val fontStyle: String? = null,
    val fontFamily: String? = null,
    val lineHeight: Float = 0f,
    val textDecorationLine: String? = null,
    val textAlign: String? = null,
    val color: Int? = null,

    // View (container)
    val backgroundColor: Int? = null,

    // Padding
    val padding: Float = 0f,
    val paddingHorizontal: Float = 0f,
    val paddingVertical: Float = 0f,
    val paddingTop: Float = 0f,
    val paddingBottom: Float = 0f,
    val paddingLeft: Float = 0f,
    val paddingRight: Float = 0f,

    // Margin
    val marginVertical: Float = 0f,

    // Border
    val borderColor: Int? = null,
    val borderWidth: Float = 0f,
    val borderRadius: Float = 0f,
    val borderLeftColor: Int? = null,
    val borderLeftWidth: Float = 0f,
    val borderRightColor: Int? = null,
    val borderRightWidth: Float = 0f,
    val borderTopColor: Int? = null,
    val borderTopWidth: Float = 0f,
    val borderBottomColor: Int? = null,
    val borderBottomWidth: Float = 0f,

    // Size
    val height: Float = 0f,
    val width: Float = 0f,
) {
    fun resolveTypeface(): Typeface {
        val base = when (fontFamily) {
            "monospace", "Menlo" -> Typeface.MONOSPACE
            "serif" -> Typeface.SERIF
            else -> Typeface.DEFAULT
        }

        val style = when {
            fontWeight == "bold" && fontStyle == "italic" -> Typeface.BOLD_ITALIC
            fontWeight == "bold" || fontWeight == "600" || fontWeight == "700" -> Typeface.BOLD
            fontStyle == "italic" -> Typeface.ITALIC
            else -> Typeface.NORMAL
        }

        return Typeface.create(base, style)
    }

    fun resolvedFontSize(): Float = if (fontSize > 0) fontSize else 16f

    companion object {
        fun fromJSON(json: JSONObject?): ElementStyle {
            if (json == null) return ElementStyle()
            return ElementStyle(
                fontSize = json.optDouble("fontSize", 0.0).toFloat(),
                fontWeight = json.optString("fontWeight", null),
                fontStyle = json.optString("fontStyle", null),
                fontFamily = json.optString("fontFamily", null),
                lineHeight = json.optDouble("lineHeight", 0.0).toFloat(),
                textDecorationLine = json.optString("textDecorationLine", null),
                textAlign = json.optString("textAlign", null),
                color = parseColor(json.opt("color")),
                backgroundColor = parseColor(json.opt("backgroundColor")),
                padding = json.optDouble("padding", 0.0).toFloat(),
                paddingHorizontal = json.optDouble("paddingHorizontal", 0.0).toFloat(),
                paddingVertical = json.optDouble("paddingVertical", 0.0).toFloat(),
                paddingTop = json.optDouble("paddingTop", 0.0).toFloat(),
                paddingBottom = json.optDouble("paddingBottom", 0.0).toFloat(),
                paddingLeft = json.optDouble("paddingLeft", 0.0).toFloat(),
                paddingRight = json.optDouble("paddingRight", 0.0).toFloat(),
                marginVertical = json.optDouble("marginVertical", 0.0).toFloat(),
                borderColor = parseColor(json.opt("borderColor")),
                borderWidth = json.optDouble("borderWidth", 0.0).toFloat(),
                borderRadius = json.optDouble("borderRadius", 0.0).toFloat(),
                borderLeftColor = parseColor(json.opt("borderLeftColor")),
                borderLeftWidth = json.optDouble("borderLeftWidth", 0.0).toFloat(),
                borderRightColor = parseColor(json.opt("borderRightColor")),
                borderRightWidth = json.optDouble("borderRightWidth", 0.0).toFloat(),
                borderTopColor = parseColor(json.opt("borderTopColor")),
                borderTopWidth = json.optDouble("borderTopWidth", 0.0).toFloat(),
                borderBottomColor = parseColor(json.opt("borderBottomColor")),
                borderBottomWidth = json.optDouble("borderBottomWidth", 0.0).toFloat(),
                height = json.optDouble("height", 0.0).toFloat(),
                width = json.optDouble("width", 0.0).toFloat(),
            )
        }

        private fun parseColor(value: Any?): Int? {
            return when (value) {
                is Number -> value.toInt()
                is String -> try { Color.parseColor(value) } catch (_: Exception) { null }
                else -> null
            }
        }
    }
}

data class StyleConfig(
    /** Base text style — applies to all text unless overridden */
    val text: ElementStyle = ElementStyle(),
    val heading1: ElementStyle = ElementStyle(),
    val heading2: ElementStyle = ElementStyle(),
    val heading3: ElementStyle = ElementStyle(),
    val heading4: ElementStyle = ElementStyle(),
    val heading5: ElementStyle = ElementStyle(),
    val heading6: ElementStyle = ElementStyle(),
    val paragraph: ElementStyle = ElementStyle(),
    val strong: ElementStyle = ElementStyle(),
    val emphasis: ElementStyle = ElementStyle(),
    val strikethrough: ElementStyle = ElementStyle(),
    val underline: ElementStyle = ElementStyle(),
    val code: ElementStyle = ElementStyle(),
    val codeBlock: ElementStyle = ElementStyle(),
    val link: ElementStyle = ElementStyle(),
    val blockquote: ElementStyle = ElementStyle(),
    val listItem: ElementStyle = ElementStyle(),
    val listBullet: ElementStyle = ElementStyle(),
    val table: ElementStyle = ElementStyle(),
    val tableRow: ElementStyle = ElementStyle(),
    val tableHeaderRow: ElementStyle = ElementStyle(),
    val tableCell: ElementStyle = ElementStyle(),
    val tableHeaderCell: ElementStyle = ElementStyle(),
    val thematicBreak: ElementStyle = ElementStyle(),
    val image: ElementStyle = ElementStyle(),
    val mention: ElementStyle = ElementStyle(),
    val spoiler: ElementStyle = ElementStyle(),
) {
    fun styleForHeadingLevel(level: Int): ElementStyle = when (level) {
        1 -> heading1
        2 -> heading2
        3 -> heading3
        4 -> heading4
        5 -> heading5
        6 -> heading6
        else -> heading1
    }

    companion object {
        fun fromJSON(json: String?): StyleConfig {
            if (json.isNullOrEmpty()) return StyleConfig()
            return try {
                val obj = JSONObject(json)
                StyleConfig(
                    text = ElementStyle.fromJSON(obj.optJSONObject("text")),
                    heading1 = ElementStyle.fromJSON(obj.optJSONObject("heading1")),
                    heading2 = ElementStyle.fromJSON(obj.optJSONObject("heading2")),
                    heading3 = ElementStyle.fromJSON(obj.optJSONObject("heading3")),
                    heading4 = ElementStyle.fromJSON(obj.optJSONObject("heading4")),
                    heading5 = ElementStyle.fromJSON(obj.optJSONObject("heading5")),
                    heading6 = ElementStyle.fromJSON(obj.optJSONObject("heading6")),
                    paragraph = ElementStyle.fromJSON(obj.optJSONObject("paragraph")),
                    strong = ElementStyle.fromJSON(obj.optJSONObject("strong")),
                    emphasis = ElementStyle.fromJSON(obj.optJSONObject("emphasis")),
                    strikethrough = ElementStyle.fromJSON(obj.optJSONObject("strikethrough")),
                    underline = ElementStyle.fromJSON(obj.optJSONObject("underline")),
                    code = ElementStyle.fromJSON(obj.optJSONObject("code")),
                    codeBlock = ElementStyle.fromJSON(obj.optJSONObject("codeBlock")),
                    link = ElementStyle.fromJSON(obj.optJSONObject("link")),
                    blockquote = ElementStyle.fromJSON(obj.optJSONObject("blockquote")),
                    listItem = ElementStyle.fromJSON(obj.optJSONObject("listItem")),
                    listBullet = ElementStyle.fromJSON(obj.optJSONObject("listBullet")),
                    table = ElementStyle.fromJSON(obj.optJSONObject("table")),
                    tableRow = ElementStyle.fromJSON(obj.optJSONObject("tableRow")),
                    tableHeaderRow = ElementStyle.fromJSON(obj.optJSONObject("tableHeaderRow")),
                    tableCell = ElementStyle.fromJSON(obj.optJSONObject("tableCell")),
                    tableHeaderCell = ElementStyle.fromJSON(obj.optJSONObject("tableHeaderCell")),
                    thematicBreak = ElementStyle.fromJSON(obj.optJSONObject("thematicBreak")),
                    image = ElementStyle.fromJSON(obj.optJSONObject("image")),
                    mention = ElementStyle.fromJSON(obj.optJSONObject("mention")),
                    spoiler = ElementStyle.fromJSON(obj.optJSONObject("spoiler")),
                )
            } catch (_: Exception) {
                StyleConfig()
            }
        }
    }
}
