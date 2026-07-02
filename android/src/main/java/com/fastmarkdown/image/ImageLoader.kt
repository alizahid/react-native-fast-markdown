package com.fastmarkdown.image

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * Dependency-free image pipeline: request de-duplication, memory LRU,
 * disk cache, and downsampled decode. Requests are owned by URL, not by
 * views — recycling a view only detaches its listener.
 */
object ImageLoader {
  private const val DISK_CACHE_DIR = "fastmarkdown_images"
  private const val DISK_CACHE_LIMIT_BYTES = 100L * 1024 * 1024
  private const val MAX_DECODE_DIMENSION = 2048

  private val executor = Executors.newFixedThreadPool(3)
  private val mainHandler = Handler(Looper.getMainLooper())

  private val memoryCache = object : LruCache<String, Bitmap>(
    ((Runtime.getRuntime().maxMemory() / 8).coerceAtMost(64L * 1024 * 1024)).toInt(),
  ) {
    override fun sizeOf(key: String, value: Bitmap): Int = value.byteCount
  }

  private val inFlight = HashMap<String, MutableList<(Bitmap?) -> Unit>>()

  fun cached(url: String): Bitmap? = memoryCache.get(url)

  /** Callback fires on the main thread; null on failure. */
  fun load(context: Context, url: String, callback: (Bitmap?) -> Unit) {
    memoryCache.get(url)?.let {
      callback(it)
      return
    }

    val appContext = context.applicationContext
    synchronized(inFlight) {
      val listeners = inFlight[url]
      if (listeners != null) {
        listeners.add(callback)
        return
      }
      inFlight[url] = mutableListOf(callback)
    }

    executor.execute {
      val bitmap = runCatching { fetch(appContext, url) }.getOrNull()
      if (bitmap != null) {
        memoryCache.put(url, bitmap)
      }
      val listeners = synchronized(inFlight) { inFlight.remove(url) } ?: emptyList()
      mainHandler.post {
        for (listener in listeners) {
          listener(bitmap)
        }
      }
    }
  }

  private fun fetch(context: Context, url: String): Bitmap? {
    val file = diskFile(context, url)
    if (!file.exists()) {
      download(url, file)
    }
    if (!file.exists()) {
      return null
    }
    file.setLastModified(System.currentTimeMillis())
    return decode(file)
  }

  private fun download(url: String, target: File) {
    target.parentFile?.mkdirs()
    val temp = File(target.path + ".tmp")
    val connection = URL(url).openConnection() as HttpURLConnection
    try {
      connection.connectTimeout = 15000
      connection.readTimeout = 30000
      connection.instanceFollowRedirects = true
      if (connection.responseCode in 200..299) {
        connection.inputStream.use { input ->
          temp.outputStream().use { output -> input.copyTo(output) }
        }
        temp.renameTo(target)
        trimDiskCache(target.parentFile)
      }
    } finally {
      connection.disconnect()
      temp.delete()
    }
  }

  private fun decode(file: File): Bitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
      return null
    }
    var sample = 1
    while (
      bounds.outWidth / (sample * 2) >= MAX_DECODE_DIMENSION ||
      bounds.outHeight / (sample * 2) >= MAX_DECODE_DIMENSION
    ) {
      sample *= 2
    }
    val options = BitmapFactory.Options().apply { inSampleSize = sample }
    return BitmapFactory.decodeFile(file.path, options)
  }

  private fun diskFile(context: Context, url: String): File {
    val digest = MessageDigest.getInstance("SHA-256")
      .digest(url.toByteArray(Charsets.UTF_8))
      .joinToString("") { "%02x".format(it) }
    return File(File(context.cacheDir, DISK_CACHE_DIR), digest)
  }

  private fun trimDiskCache(dir: File?) {
    val files = dir?.listFiles() ?: return
    var total = files.sumOf { it.length() }
    if (total <= DISK_CACHE_LIMIT_BYTES) {
      return
    }
    for (file in files.sortedBy { it.lastModified() }) {
      total -= file.length()
      file.delete()
      if (total <= DISK_CACHE_LIMIT_BYTES) {
        break
      }
    }
  }
}
