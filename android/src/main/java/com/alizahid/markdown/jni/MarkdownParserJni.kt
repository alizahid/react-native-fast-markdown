package com.alizahid.markdown.jni

import com.alizahid.markdown.parser.AstNode

/**
 * Kotlin facade over the C++ markdown parser. Loads the native library
 * lazily on first call. The native method returns a fully-constructed
 * Kotlin AST tree — no JSON round-trip.
 */
object MarkdownParserJni {

  init {
    System.loadLibrary("markdown_jni")
  }

  @JvmStatic
  external fun nativeParse(markdown: String, customTags: Array<String>): AstNode?

  fun parse(markdown: String, customTags: Set<String> = emptySet()): AstNode? {
    return nativeParse(markdown, customTags.toTypedArray())
  }
}
