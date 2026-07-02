package com.fastmarkdown.render

import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint

/** One top-level markdown block ready for layout at any width. */
sealed class Block {
  class Text(val text: CharSequence, val paint: TextPaint) : Block()
}

/** Per-width layout results for one block list. */
class BlockLayout(
  val layouts: List<StaticLayout>,
  val totalHeight: Float,
)

/**
 * Parsed + spannable-rendered markdown, shared between the Fabric measurer
 * (layout thread) and the mounted view (main thread). Layouts are cached per
 * available width.
 */
class RenderedContent(val blocks: List<Block>, private val gapPx: Float, private val verticalPaddingPx: Float) {
  private val layoutCache = HashMap<Int, BlockLayout>()

  @Synchronized
  fun layoutFor(widthPx: Int): BlockLayout {
    layoutCache[widthPx]?.let { return it }

    val layouts = ArrayList<StaticLayout>(blocks.size)
    var height = verticalPaddingPx
    blocks.forEachIndexed { index, block ->
      when (block) {
        is Block.Text -> {
          val layout = StaticLayout.Builder
            .obtain(block.text, 0, block.text.length, block.paint, widthPx.coerceAtLeast(1))
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .build()
          layouts.add(layout)
          height += layout.height
        }
      }
      if (index < blocks.size - 1) {
        height += gapPx
      }
    }

    val result = BlockLayout(layouts, height)
    if (layoutCache.size > 4) {
      layoutCache.clear()
    }
    layoutCache[widthPx] = result
    return result
  }
}
