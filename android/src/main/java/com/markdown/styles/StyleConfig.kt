package com.markdown.styles

import android.content.Context
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
    val letterSpacing: Float = 0f,
    val textDecorationLine: String? = null,
    val textDecorationColor: Int? = null,
    val textDecorationStyle: String? = null,
    val textAlign: String? = null,
    val color: Int? = null,

    // View (container)
    val backgroundColor: Int? = null,

    // Layout
    val gap: Float = 0f,
    val width: Float = 0f,
    val height: Float = 0f,
    val maxWidth: Float = 0f,
    val maxHeight: Float = 0f,

    // Padding
    val padding: Float = 0f,
    val paddingHorizontal: Float = 0f,
    val paddingVertical: Float = 0f,
    val paddingTop: Float = 0f,
    val paddingBottom: Float = 0f,
    val paddingLeft: Float = 0f,
    val paddingRight: Float = 0f,

    // Margin
    val margin: Float = 0f,
    val marginHorizontal: Float = 0f,
    val marginVertical: Float = 0f,
    val marginTop: Float = 0f,
    val marginBottom: Float = 0f,
    val marginLeft: Float = 0f,
    val marginRight: Float = 0f,

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

    /** Resolve typeface cascading over a base typeface. */
    fun resolveTypefaceWithBase(base: Typeface?): Typeface {
        val family = when (fontFamily) {
            "monospace", "Menlo" -> Typeface.MONOSPACE
            "serif" -> Typeface.SERIF
            null, "" -> base ?: Typeface.DEFAULT
            else -> base ?: Typeface.DEFAULT
        }

        val isBold = fontWeight == "bold" || fontWeight == "600" || fontWeight == "700"
        val isItalic = fontStyle == "italic"

        // If neither weight nor style is set, preserve the base style
        if (!isBold && !isItalic && fontWeight == null && fontStyle == null) {
            return if (fontFamily != null && fontFamily.isNotEmpty()) family else (base ?: Typeface.DEFAULT)
        }

        val style = when {
            isBold && isItalic -> Typeface.BOLD_ITALIC
            isBold -> Typeface.BOLD
            isItalic -> Typeface.ITALIC
            else -> Typeface.NORMAL
        }

        return Typeface.create(family, style)
    }

    fun resolvedFontSize(): Float = if (fontSize > 0) fontSize else 16f

    // --- Padding resolution (cascade: specific > directional > general) ---

    fun resolvedPaddingTop(): Float = when {
        paddingTop > 0f -> paddingTop
        paddingVertical > 0f -> paddingVertical
        padding > 0f -> padding
        else -> 0f
    }

    fun resolvedPaddingBottom(): Float = when {
        paddingBottom > 0f -> paddingBottom
        paddingVertical > 0f -> paddingVertical
        padding > 0f -> padding
        else -> 0f
    }

    fun resolvedPaddingLeft(): Float = when {
        paddingLeft > 0f -> paddingLeft
        paddingHorizontal > 0f -> paddingHorizontal
        padding > 0f -> padding
        else -> 0f
    }

    fun resolvedPaddingRight(): Float = when {
        paddingRight > 0f -> paddingRight
        paddingHorizontal > 0f -> paddingHorizontal
        padding > 0f -> padding
        else -> 0f
    }

    // --- Margin resolution (same cascade) ---

    fun resolvedMarginTop(): Float = when {
        marginTop > 0f -> marginTop
        marginVertical > 0f -> marginVertical
        margin > 0f -> margin
        else -> 0f
    }

    fun resolvedMarginBottom(): Float = when {
        marginBottom > 0f -> marginBottom
        marginVertical > 0f -> marginVertical
        margin > 0f -> margin
        else -> 0f
    }

    fun resolvedMarginLeft(): Float = when {
        marginLeft > 0f -> marginLeft
        marginHorizontal > 0f -> marginHorizontal
        margin > 0f -> margin
        else -> 0f
    }

    fun resolvedMarginRight(): Float = when {
        marginRight > 0f -> marginRight
        marginHorizontal > 0f -> marginHorizontal
        margin > 0f -> margin
        else -> 0f
    }

    // --- Border resolution (cascade: specific > general) ---

    fun resolvedBorderTopWidth(): Float =
        if (borderTopWidth > 0f) borderTopWidth else borderWidth

    fun resolvedBorderBottomWidth(): Float =
        if (borderBottomWidth > 0f) borderBottomWidth else borderWidth

    fun resolvedBorderLeftWidth(): Float =
        if (borderLeftWidth > 0f) borderLeftWidth else borderWidth

    fun resolvedBorderRightWidth(): Float =
        if (borderRightWidth > 0f) borderRightWidth else borderWidth

    fun resolvedBorderTopColor(): Int? =
        borderTopColor ?: borderColor

    fun resolvedBorderBottomColor(): Int? =
        borderBottomColor ?: borderColor

    fun resolvedBorderLeftColor(): Int? =
        borderLeftColor ?: borderColor

    fun resolvedBorderRightColor(): Int? =
        borderRightColor ?: borderColor

    fun hasAnyBorder(): Boolean =
        resolvedBorderTopWidth() > 0f || resolvedBorderBottomWidth() > 0f ||
            resolvedBorderLeftWidth() > 0f || resolvedBorderRightWidth() > 0f

    companion object {
        fun fromJSON(json: JSONObject?): ElementStyle {
            if (json == null) return ElementStyle()
            return ElementStyle(
                fontSize = json.optDouble("fontSize", 0.0).toFloat(),
                fontWeight = optStringOrNull(json, "fontWeight"),
                fontStyle = optStringOrNull(json, "fontStyle"),
                fontFamily = optStringOrNull(json, "fontFamily"),
                lineHeight = json.optDouble("lineHeight", 0.0).toFloat(),
                letterSpacing = json.optDouble("letterSpacing", 0.0).toFloat(),
                textDecorationLine = optStringOrNull(json, "textDecorationLine"),
                textDecorationColor = parseColor(json.opt("textDecorationColor")),
                textDecorationStyle = optStringOrNull(json, "textDecorationStyle"),
                textAlign = optStringOrNull(json, "textAlign"),
                color = parseColor(json.opt("color")),
                backgroundColor = parseColor(json.opt("backgroundColor")),
                gap = json.optDouble("gap", 0.0).toFloat(),
                width = json.optDouble("width", 0.0).toFloat(),
                height = json.optDouble("height", 0.0).toFloat(),
                maxWidth = json.optDouble("maxWidth", 0.0).toFloat(),
                maxHeight = json.optDouble("maxHeight", 0.0).toFloat(),
                padding = json.optDouble("padding", 0.0).toFloat(),
                paddingHorizontal = json.optDouble("paddingHorizontal", 0.0).toFloat(),
                paddingVertical = json.optDouble("paddingVertical", 0.0).toFloat(),
                paddingTop = json.optDouble("paddingTop", 0.0).toFloat(),
                paddingBottom = json.optDouble("paddingBottom", 0.0).toFloat(),
                paddingLeft = json.optDouble("paddingLeft", 0.0).toFloat(),
                paddingRight = json.optDouble("paddingRight", 0.0).toFloat(),
                margin = json.optDouble("margin", 0.0).toFloat(),
                marginHorizontal = json.optDouble("marginHorizontal", 0.0).toFloat(),
                marginVertical = json.optDouble("marginVertical", 0.0).toFloat(),
                marginTop = json.optDouble("marginTop", 0.0).toFloat(),
                marginBottom = json.optDouble("marginBottom", 0.0).toFloat(),
                marginLeft = json.optDouble("marginLeft", 0.0).toFloat(),
                marginRight = json.optDouble("marginRight", 0.0).toFloat(),
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
            )
        }

        private fun optStringOrNull(json: JSONObject, key: String): String? {
            return if (json.has(key) && !json.isNull(key)) json.optString(key) else null
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
    val base: ElementStyle = ElementStyle(),
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
    val code: ElementStyle = ElementStyle(),
    val codeBlock: ElementStyle = ElementStyle(),
    val link: ElementStyle = ElementStyle(),
    val blockquote: ElementStyle = ElementStyle(),
    val list: ElementStyle = ElementStyle(),
    val listItem: ElementStyle = ElementStyle(),
    val listBullet: ElementStyle = ElementStyle(),
    val table: ElementStyle = ElementStyle(),
    val tableRow: ElementStyle = ElementStyle(),
    val tableHeaderRow: ElementStyle = ElementStyle(),
    val tableCell: ElementStyle = ElementStyle(),
    val tableHeaderCell: ElementStyle = ElementStyle(),
    val thematicBreak: ElementStyle = ElementStyle(),
    val image: ElementStyle = ElementStyle(),
    val mentionUser: ElementStyle = ElementStyle(),
    val mentionChannel: ElementStyle = ElementStyle(),
    val mentionCommand: ElementStyle = ElementStyle(),
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
                    base = ElementStyle.fromJSON(obj.optJSONObject("base")),
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
                    code = ElementStyle.fromJSON(obj.optJSONObject("code")),
                    codeBlock = ElementStyle.fromJSON(obj.optJSONObject("codeBlock")),
                    link = ElementStyle.fromJSON(obj.optJSONObject("link")),
                    blockquote = ElementStyle.fromJSON(obj.optJSONObject("blockquote")),
                    list = ElementStyle.fromJSON(obj.optJSONObject("list")),
                    listItem = ElementStyle.fromJSON(obj.optJSONObject("listItem")),
                    listBullet = ElementStyle.fromJSON(obj.optJSONObject("listBullet")),
                    table = ElementStyle.fromJSON(obj.optJSONObject("table")),
                    tableRow = ElementStyle.fromJSON(obj.optJSONObject("tableRow")),
                    tableHeaderRow = ElementStyle.fromJSON(obj.optJSONObject("tableHeaderRow")),
                    tableCell = ElementStyle.fromJSON(obj.optJSONObject("tableCell")),
                    tableHeaderCell = ElementStyle.fromJSON(obj.optJSONObject("tableHeaderCell")),
                    thematicBreak = ElementStyle.fromJSON(obj.optJSONObject("thematicBreak")),
                    image = ElementStyle.fromJSON(obj.optJSONObject("image")),
                    mentionUser = ElementStyle.fromJSON(obj.optJSONObject("mentionUser")),
                    mentionChannel = ElementStyle.fromJSON(obj.optJSONObject("mentionChannel")),
                    mentionCommand = ElementStyle.fromJSON(obj.optJSONObject("mentionCommand")),
                    spoiler = ElementStyle.fromJSON(obj.optJSONObject("spoiler")),
                )
            } catch (_: Exception) {
                StyleConfig()
            }
        }
    }
}
