package com.alizahid.markdown.view

import android.util.Size
import androidx.collection.LruCache
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Process-wide URL → natural-size cache populated as MarkdownImageView
 * loads images via Glide. Listeners are notified when a NEW size is
 * inserted so MarkdownView can flush its measurement cache and bump the
 * Fabric state revision, triggering Yoga to remeasure with the now-known
 * height.
 *
 * Mirrors ios/views/MarkdownImageSizeCache. Pre-supplied dimensions in
 * the `images` prop bypass this cache entirely — they go straight to the
 * MarkdownImageView constructor.
 */
object MarkdownImageSizeCache {
  private val cache = LruCache<String, Size>(512)
  private val listeners = CopyOnWriteArrayList<(String) -> Unit>()

  fun get(url: String): Size? = if (url.isEmpty()) null else cache.get(url)

  fun put(url: String, size: Size) {
    if (url.isEmpty()) return
    val prev = cache.get(url)
    if (prev != null && prev == size) return
    cache.put(url, size)
    listeners.forEach { it(url) }
  }

  fun addListener(l: (String) -> Unit) { listeners.add(l) }
  fun removeListener(l: (String) -> Unit) { listeners.remove(l) }
}
