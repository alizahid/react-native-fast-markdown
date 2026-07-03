#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace fastmarkdown {

// Inline mark bits carried by editor styled runs. Mirrored by the native
// editors (FMDEditorMarks attribute on iOS, EditorMarkSpan on Android).
enum EditorMark : uint32_t {
  MarkBold = 1u << 0,
  MarkItalic = 1u << 1,
  MarkStrikethrough = 1u << 2,
  MarkInlineCode = 1u << 3,
  MarkSpoiler = 1u << 4,
  MarkSuperscript = 1u << 5,
  MarkSubscript = 1u << 6,
};

// A contiguous marked range over the editor's text. Offsets are UTF-16 code
// units (NSRange / Spannable indices), converted internally.
struct StyledRun {
  uint32_t start = 0;
  uint32_t end = 0;
  uint32_t flags = 0;
};

struct StyledText {
  std::string text;
  std::vector<StyledRun> runs;
};

// Serializes the editor's text + mark runs to markdown. Every newline in
// `text` is a paragraph break (the editor model). Overlapping runs are
// nested by a fixed outer-to-inner mark order; inline-code content is
// emitted verbatim (markdown cannot format inside code spans).
std::string markdownFromStyledText(
    const std::string& text,
    const std::vector<StyledRun>& runs);

// Parses markdown and flattens it to editor text + mark runs (the inverse
// of markdownFromStyledText for the inline subset; block structure beyond
// paragraphs flattens the same way as plainTextFromMarkdown).
StyledText styledTextFromMarkdown(const std::string& markdown);

} // namespace fastmarkdown
