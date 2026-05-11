package com.alizahid.markdown.style

/**
 * Per-element style registry. Mirrors `StyleConfig` in
 * ios/styles/StyleConfig.h. All fields default to an empty ElementStyle
 * so renderers can always call `styleForXxx` without null-checks.
 */
class StyleConfig {
  var base: ElementStyle = ElementStyle()

  var paragraph: ElementStyle = ElementStyle()
  var heading1: ElementStyle = ElementStyle()
  var heading2: ElementStyle = ElementStyle()
  var heading3: ElementStyle = ElementStyle()
  var heading4: ElementStyle = ElementStyle()
  var heading5: ElementStyle = ElementStyle()
  var heading6: ElementStyle = ElementStyle()
  var blockquote: ElementStyle = ElementStyle()
  var codeBlock: ElementStyle = ElementStyle()
  var list: ElementStyle = ElementStyle()
  var listItem: ElementStyle = ElementStyle()
  var listBullet: ElementStyle = ElementStyle()
  var thematicBreak: ElementStyle = ElementStyle()
  var image: ElementStyle = ElementStyle()

  var table: ElementStyle = ElementStyle()
  var tableRow: ElementStyle = ElementStyle()
  var tableHeaderRow: ElementStyle = ElementStyle()
  var tableCell: ElementStyle = ElementStyle()
  var tableHeaderCell: ElementStyle = ElementStyle()

  var strong: ElementStyle = ElementStyle()
  var emphasis: ElementStyle = ElementStyle()
  var strikethrough: ElementStyle = ElementStyle()
  var code: ElementStyle = ElementStyle()
  var link: ElementStyle = ElementStyle()

  var mentionUser: ElementStyle = ElementStyle()
  var mentionChannel: ElementStyle = ElementStyle()
  var mentionCommand: ElementStyle = ElementStyle()

  var spoiler: ElementStyle = ElementStyle()
  var superscript: ElementStyle = ElementStyle()

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
    /**
     * `density` should be `Context.resources.displayMetrics.density` —
     * every length-like field in the JSON is multiplied by it on read
     * so downstream code can stay in raw pixels.
     */
    fun fromJson(json: String?, density: Float): StyleConfig =
      if (json.isNullOrEmpty()) StyleConfig() else StyleDeserializer.parse(json, density)
  }
}
