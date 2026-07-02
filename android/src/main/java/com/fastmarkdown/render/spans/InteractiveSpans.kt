package com.fastmarkdown.render.spans

/** Data-only marker spans; hit-testing and drawing live in BlockTextView. */
class LinkSpan(val url: String)

class SpoilerSpan(val id: Int)
