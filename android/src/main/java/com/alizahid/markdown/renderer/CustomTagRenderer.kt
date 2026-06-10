package com.alizahid.markdown.renderer

import android.text.SpannableStringBuilder
import android.text.Spanned
import com.alizahid.markdown.parser.AstNode
import com.alizahid.markdown.renderer.RenderContext.Companion.applyAttributes
import com.alizahid.markdown.renderer.RenderContext.Companion.mergeStyleAttrs
import com.alizahid.markdown.renderer.spans.MentionSpan
import com.alizahid.markdown.renderer.spans.SpoilerMarkerSpan
import com.alizahid.markdown.renderer.spans.SuperscriptScaleSpan
import com.alizahid.markdown.style.ElementStyle

/**
 * Custom-tag dispatcher. Recognises the three mention tags + Spoiler +
 * Superscript; unknown tags fall through to their children. Mirrors
 * ios/renderer/CustomTagRenderer.m.
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
      SPOILER_TAG -> renderSpoiler(node, into, ctx)
      SUPERSCRIPT_TAG -> renderSuperscript(node, into, ctx)
      else -> ctx.renderChildren(node, into)
    }
  }

  private fun renderMention(
    node: AstNode, type: String, prefix: String,
    style: ElementStyle,
    into: SpannableStringBuilder, ctx: RenderContext,
  ) {
    val tagProps = node.tagProps
    val id = tagProps["id"] ?: ""
    val name = tagProps["name"] ?: ""
    val extras = tagProps.filterKeys { it != "id" && it != "name" }

    // Display the prefix plus the name (or id as a fallback when name is
    // missing — typical for command mentions like `/help`).
    val label = name.ifEmpty { id }

    val start = into.length
    into.append(prefix).append(label)
    applyAttributes(mergeStyleAttrs(style, ctx.currentAttributes()), into, start, into.length)
    into.setSpan(MentionSpan(type, id, name, extras), start, into.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
  }

  private fun renderSpoiler(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    // Character offset as a stable ID so reveal state persists across
    // re-renders of the same markdown (mirrors iOS "spoiler_%lu").
    val spoilerId = "spoiler_${into.length}"
    val start = into.length
    ctx.renderChildren(node, into)
    if (into.length > start) {
      into.setSpan(
        SpoilerMarkerSpan(spoilerId, isBlock = false),
        start, into.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
      )
    }
  }

  private fun renderSuperscript(node: AstNode, into: SpannableStringBuilder, ctx: RenderContext) {
    ctx.pushAttributes(mergeStyleAttrs(ctx.styleConfig.superscript, ctx.currentAttributes()))
    val start = into.length
    ctx.renderChildren(node, into)
    val end = into.length
    if (end > start) {
      // Applied after the children's size spans, so the 0.7 scale
      // multiplies whatever size each run resolved to — mirrors Core
      // Text's kCTSuperscriptAttributeName fallback behavior.
      into.setSpan(SuperscriptScaleSpan(), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
    ctx.popAttributes()
  }
}
