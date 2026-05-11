package com.alizahid.markdown.measure

import android.util.Size
import androidx.collection.LruCache

/**
 * Thread-safe LRU memoization of (markdown + styles + customTags +
 * propImageSizes + width) → measured Size. Image size discovery flushes
 * the whole cache wholesale, so revision counters need not be in the key.
 *
 * Mirrors ios/utils/MeasurementCache. 512 entries is large enough for
 * typical scrollable lists of conversations.
 */
object MeasurementCache {
  private val cache = LruCache<String, Size>(512)

  fun get(key: String): Size? = cache.get(key)
  fun put(key: String, size: Size) { cache.put(key, size) }
  fun clear() { cache.evictAll() }
}
