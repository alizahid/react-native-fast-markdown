package com.alizahid.markdown.renderer

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_FONT_SIZE
import com.alizahid.markdown.renderer.RenderContext.Companion.ATTR_TYPEFACE
import com.alizahid.markdown.renderer.RenderContext.Companion.resolveAttrs
import com.alizahid.markdown.renderer.spans.MentionSpan
import com.alizahid.markdown.renderer.spans.SpoilerMarkerSpan
import com.alizahid.markdown.renderer.spans.SuperscriptScaleSpan

/**
 * Custom-tag dispatcher. Recognises the three mention tags + Spoiler +
 * Superscript and applies appropriate spans; unknown tags fall through
 * to their children. Mirrors ios/renderer/CustomTagRenderer.m.
 */
object CustomTagRenderer : NodeRenderer {

  private const val USER_MENTION_TAG = "UserMention"
  private const val CHANNEL_MENTION_TAG = "ChannelMention"
  private const val COMMAND_TAG = "Command"
  private const val SPOILER_TAG = "Spoiler"
  private const val SUPERSCRIPT_TAG = "Superscript"

  override fun render(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    when (node.tagName) {
      USER_MENTION_TAG -> renderMention(node, "user", "@", ctx.styleConfig.mentionUser, into, ctx)
      CHANNEL_MENTION_TAG -> renderMention(node, "channel", "#", ctx.styleConfig.mentionChannel, into, ctx)
      COMMAND_TAG -> renderMention(node, "command", "/", ctx.styleConfig.mentionCommand, into, ctx)
      SPOILER_TAG -> renderSpoiler(node, into, ctx, isBlock = false)
      SUPERSCRIPT_TAG -> renderSuperscript(node, into, ctx)
      else -> renderGeneric(node, into, ctx)
    }
  }

  private fun renderMention(
    node: AstNode, type: String, prefix: String,
    style: com.alizahid.markdown.style.ElementStyle,
    into: SpannableStringBuilder, ctx: RenderContext,
  ) {
    val tagProps = node.tagProps
    val id = tagProps["id"] ?: ""
    val name = tagProps["name"] ?: ""
    val extras = tagProps.filterKeys { it != "id" && it != "name" }

    val label = name.ifEmpty { id }
    val displayText = "$prefix$label"

    val resolved = resolveAttrs(style, ctx.currentAttributes())
    val start = into.length
    into.append(displayText)
    val end = into.length
    StyleAttributes.apply(
      style, into, start, end,
      resolved[ATTR_TYPEFACE] as? Typeface,
      resolved[ATTR_FONT_SIZE] as? Float,
    )
    into.setSpan(MentionSpan(type, id, name, extras), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
  }

  /**
   * `renderSpoiler` is also called from `MarkdownView.buildSegment`
   * when a top-level segment is a CustomTag named Spoiler — in that
   * case the overlay is forced to be a solid rect rather than a
   * staircase polygon (mirrors iOS MarkdownSpoilerIsBlockKey logic).
   */
  internal fun renderSpoiler(
    node: AstNode, into: SpannableStringBuilder, ctx: RenderContext, isBlock: Boolean,
  ) {
    val spoilerId = stableId(into.length, node)
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    if (start == end) return
    into.setSpan(SpoilerMarkerSpan(spoilerId, isBlock), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
  }

  private fun renderSuperscript(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    val style = ctx.styleConfig.superscript
    val resolved = resolveAttrs(style, ctx.currentAttributes())
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    StyleAttributes.apply(
      style, into, start, end,
      resolved[ATTR_TYPEFACE] as? Typeface,
      resolved[ATTR_FONT_SIZE] as? Float,
    )
    into.setSpan(SuperscriptScaleSpan(), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
  }

  private fun renderGeneric(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    ctx.renderChildren(node, into)
  }

  private fun stableId(offset: Int, node: AstNode): String {
    // Hash on offset + tag name + child count to keep IDs stable
    // across re-renders of the same markdown source. Kotlin Long literals
    // are signed — express the splittable-hash constant via its
    // unsigned form so the bit pattern survives without overflow.
    var h = offset.toLong() xor 0x9E3779B97F4A7C15UL.toLong()
    h = h * 31 + node.tagName.hashCode()
    h = h * 31 + node.children.size
    return "sp_${(h and 0xFFFFFFFFFFFFL).toString(16)}"
  }
}
