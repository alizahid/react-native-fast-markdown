package com.fastmarkdown

import com.fastmarkdown.measure.MarkdownMeasurer
import com.fastmarkdown.parser.AstDecoder
import com.fastmarkdown.parser.MdNode

/**
 * JNI bridge into the shared C++ core. The natives are linked into the app's
 * `libappmodules.so` (loaded by React Native at startup), so no explicit
 * `System.loadLibrary` is required.
 */
object FastMarkdownNative {
  @Volatile private var installed = false

  fun ensureInstalled() {
    if (!installed) {
      synchronized(this) {
        if (!installed) {
          // libappmodules.so may not be loaded yet at package-construction
          // time; callers retry from later lifecycle points.
          installed = runCatching { installMeasurer(MarkdownMeasurer) }.isSuccess
        }
      }
    }
  }

  fun parseMarkdown(markdown: String): MdNode {
    return AstDecoder.decode(parse(markdown.toByteArray(Charsets.UTF_8)))
  }

  /** Editor: escaped markdown from the editor's plain-text content. */
  fun markdownFromText(text: String): String {
    return markdownFromPlainText(text.toByteArray(Charsets.UTF_8))
      .toString(Charsets.UTF_8)
  }

  /** Editor: markdown flattened to the editor's plain-text model. */
  fun textFromMarkdown(markdown: String): String {
    return plainTextFromMarkdown(markdown.toByteArray(Charsets.UTF_8))
      .toString(Charsets.UTF_8)
  }

  /** Decoded editor content: text, inline-mark runs, per-line blocks. */
  class EditorContent(
    val text: String,
    /** Flat `[start, end, flags]` triples in UTF-16 offsets. */
    val runs: IntArray,
    /** Flat `[type, level]` pairs, one per text line. */
    val lineBlocks: IntArray,
  )

  /**
   * Editor: markdown from text + inline-mark runs + per-line blocks. Runs
   * are flat `[start, end, flags]` triples in UTF-16 offsets (Spannable
   * indices); lineBlocks are `[type, level]` pairs per line.
   */
  fun markdownFromEditor(text: String, runs: IntArray, lineBlocks: IntArray): String {
    return markdownFromEditorContent(text.toByteArray(Charsets.UTF_8), runs, lineBlocks)
      .toString(Charsets.UTF_8)
  }

  /**
   * Editor: markdown parsed into editor content. The native payload is
   * `[int32 runCount][triples][int32 lineCount][pairs][utf8 text]`,
   * little-endian.
   */
  fun editorFromMarkdown(markdown: String): EditorContent {
    val bytes = editorFromMarkdownContent(markdown.toByteArray(Charsets.UTF_8))
    val buffer = java.nio.ByteBuffer.wrap(bytes).order(java.nio.ByteOrder.LITTLE_ENDIAN)
    val runs = IntArray(buffer.int * 3)
    for (i in runs.indices) {
      runs[i] = buffer.int
    }
    val lineBlocks = IntArray(buffer.int * 2)
    for (i in lineBlocks.indices) {
      lineBlocks[i] = buffer.int
    }
    val text = ByteArray(buffer.remaining())
    buffer.get(text)
    return EditorContent(text.toString(Charsets.UTF_8), runs, lineBlocks)
  }

  @JvmStatic private external fun parse(markdown: ByteArray): ByteArray

  @JvmStatic private external fun markdownFromPlainText(text: ByteArray): ByteArray

  @JvmStatic private external fun plainTextFromMarkdown(markdown: ByteArray): ByteArray

  @JvmStatic private external fun markdownFromEditorContent(
    text: ByteArray,
    runs: IntArray,
    lineBlocks: IntArray,
  ): ByteArray

  @JvmStatic private external fun editorFromMarkdownContent(markdown: ByteArray): ByteArray

  @JvmStatic private external fun installMeasurer(measurer: MarkdownMeasurer)
}
