package com.fastmarkdown.render

import android.content.res.Resources
import android.util.LruCache
import com.fastmarkdown.FastMarkdownNative
import com.fastmarkdown.style.StyleConfig

/**
 * Shared parse/render cache. The Fabric measurer populates it on the layout
 * thread; the mounted view reads the same entry on the main thread, so a
 * mount never re-parses.
 */
object ContentCache {
  private data class Key(val markdown: String, val stylesJson: String, val fontScale: Float)

  private val cache = object : LruCache<Key, RenderedContent>(64) {}

  fun get(markdown: String, stylesJson: String, fontScale: Float): RenderedContent {
    val key = Key(markdown, stylesJson, fontScale)
    synchronized(cache) {
      cache.get(key)?.let { return it }
    }

    val density = Resources.getSystem().displayMetrics.density
    val styles = StyleConfig.from(stylesJson)
    val root = FastMarkdownNative.parseMarkdown(markdown)
    val blocks = SpannableRenderer.render(root, styles, density, fontScale)
    val content = RenderedContent(
      blocks = blocks,
      gapPx = styles.gap * density,
      verticalPaddingPx = (styles.paddingTop + styles.paddingBottom) * density,
    )

    synchronized(cache) {
      cache.put(key, content)
    }
    return content
  }
}
