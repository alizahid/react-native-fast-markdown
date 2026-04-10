package com.markdown.styles

import android.graphics.Color
import android.graphics.Typeface
import android.text.TextPaint
import org.json.JSONObject

data class ElementStyle(
    val fontSize: Float = 0f,
    val fontWeight: String? = null,
    val fontStyle: String? = null,
    val fontFamily: String? = null,
    val lineHeight: Float = 0f,
    val textDecorationLine: String? = null,
    val color: Int? = null,
    val backgroundColor: Int? = null,
    val padding: Float = 0f,
    val borderRadius: Float = 0f,
    val marginVertical: Float = 0f,
    val borderLeftColor: Int? = null,
    val borderLeftWidth: Float = 0f,
    val bulletColor: Int? = null,
    val borderColor: Int? = null,
    val borderWidth: Float = 0f,
    val headerBackgroundColor: Int? = null,
    val cellPadding: Float = 0f,
    val height: Float = 0f,
    val prefix: String? = null,
    val overlayColor: Int? = null,
    val mode: String? = null
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
                color = parseColor(json.opt("color")),
                backgroundColor = parseColor(json.opt("backgroundColor")),
                padding = json.optDouble("padding", 0.0).toFloat(),
                borderRadius = json.optDouble("borderRadius", 0.0).toFloat(),
                marginVertical = json.optDouble("marginVertical", 0.0).toFloat(),
                borderLeftColor = parseColor(json.opt("borderLeftColor")),
                borderLeftWidth = json.optDouble("borderLeftWidth", 0.0).toFloat(),
                bulletColor = parseColor(json.opt("bulletColor")),
                borderColor = parseColor(json.opt("borderColor")),
                borderWidth = json.optDouble("borderWidth", 0.0).toFloat(),
                headerBackgroundColor = parseColor(json.opt("headerBackgroundColor")),
                cellPadding = json.optDouble("cellPadding", 0.0).toFloat(),
                height = json.optDouble("height", 0.0).toFloat(),
                prefix = json.optString("prefix", null),
                overlayColor = parseColor(json.opt("overlayColor")),
                mode = json.optString("mode", null)
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
    val table: ElementStyle = ElementStyle(),
    val thematicBreak: ElementStyle = ElementStyle(),
    val image: ElementStyle = ElementStyle(),
    val mention: ElementStyle = ElementStyle(),
    val spoiler: ElementStyle = ElementStyle()
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
                    table = ElementStyle.fromJSON(obj.optJSONObject("table")),
                    thematicBreak = ElementStyle.fromJSON(obj.optJSONObject("thematicBreak")),
                    image = ElementStyle.fromJSON(obj.optJSONObject("image")),
                    mention = ElementStyle.fromJSON(obj.optJSONObject("mention")),
                    spoiler = ElementStyle.fromJSON(obj.optJSONObject("spoiler"))
                )
            } catch (_: Exception) {
                StyleConfig()
            }
        }
    }
}
