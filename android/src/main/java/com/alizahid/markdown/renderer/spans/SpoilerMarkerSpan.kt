package com.alizahid.markdown.renderer.spans

/**
 * Marker span carried over a spoiler range — invisible on its own; the
 * MarkdownSpoilerOverlay reads these spans + their range bounds to
 * decide where to draw the cover and which reveal-state to track.
 *
 * The `id` is a stable hash derived from offset + content so re-renders
 * with the same source preserve the user's reveal state (mirrors iOS
 * MarkdownSpoilerRangeKey).
 */
class SpoilerMarkerSpan(val id: String, val isBlock: Boolean)
