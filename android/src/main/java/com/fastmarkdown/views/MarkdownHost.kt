package com.fastmarkdown.views

/** Callbacks from block views up to the host component view. */
interface MarkdownHost {
  fun onImageIntrinsicSize(url: String, widthDp: Float, heightDp: Float)
  fun isSpoilerRevealed(id: Int): Boolean
  fun toggleSpoiler(id: Int)
  fun onLinkPress(url: String)
  fun onLinkLongPress(url: String)
  fun onImagePress(url: String)
}
