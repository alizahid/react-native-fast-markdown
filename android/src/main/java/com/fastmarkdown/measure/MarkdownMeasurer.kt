package com.fastmarkdown.measure

import android.content.res.Resources
import com.fastmarkdown.render.ContentCache
import com.fastmarkdown.style.StyleConfig

/**
 * Called from the C++ shadow node (via JNI) on the Fabric layout thread.
 * Receives dp, works in px, returns dp.
 */
object MarkdownMeasurer {
  @JvmName("measure")
  fun measure(markdown: ByteArray, stylesJson: ByteArray, maxWidth: Float, fontScale: Float): Float {
    val markdownString = String(markdown, Charsets.UTF_8)
    val stylesString = String(stylesJson, Charsets.UTF_8)

    val density = Resources.getSystem().displayMetrics.density
    val styles = StyleConfig.from(stylesString)
    val content = ContentCache.get(markdownString, stylesString, fontScale)

    val horizontalPadding = styles.paddingLeft + styles.paddingRight
    val contentWidthPx = ((maxWidth - horizontalPadding) * density).toInt()
    if (contentWidthPx <= 0) {
      return 0f
    }

    val layout = content.layoutFor(contentWidthPx)
    return layout.totalHeight / density
  }
}
