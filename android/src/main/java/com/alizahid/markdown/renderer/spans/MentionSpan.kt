package com.alizahid.markdown.renderer.spans

/**
 * Carries the full mention payload across a mention range. The mention
 * overlay reads this when a tap hits the range and dispatches the
 * `onMentionPress` event with `{type, id, name, ...extras}`.
 *
 * Visual styling (color, background) comes from the matching
 * mentionUser/mentionChannel/mentionCommand ElementStyle applied
 * separately. This span is invisible — it only carries data.
 */
class MentionSpan(
  val type: String,    // "user" | "channel" | "command"
  val id: String,
  val name: String,
  val props: Map<String, String>,
)
