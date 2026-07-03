import { useMemo, useRef } from "react";

import type { FastMarkdownEditorRef } from "./types";

/**
 * Convenience hook: a ref to pass to `<FastMarkdownEditor>` plus stable
 * callbacks for every editor command.
 *
 * ```tsx
 * const editor = useFastMarkdownEditor();
 * <FastMarkdownEditor ref={editor.ref} />
 * <Button onPress={editor.focus} />
 * ```
 */
export function useFastMarkdownEditor() {
  const ref = useRef<FastMarkdownEditorRef>(null);

  return useMemo(
    () => ({
      blur: () => ref.current?.blur(),
      focus: () => ref.current?.focus(),
      getMarkdown: (): Promise<string> =>
        ref.current?.getMarkdown() ?? Promise.resolve(""),
      ref,
      setSelection: (start: number, end: number) =>
        ref.current?.setSelection(start, end),
      setValue: (markdown: string) => ref.current?.setValue(markdown),
      toggleBlockQuote: () => ref.current?.toggleBlockQuote(),
      toggleBold: () => ref.current?.toggleBold(),
      toggleCode: () => ref.current?.toggleCode(),
      toggleCodeBlock: () => ref.current?.toggleCodeBlock(),
      toggleHeading: (level: number) => ref.current?.toggleHeading(level),
      toggleItalic: () => ref.current?.toggleItalic(),
      toggleOrderedList: () => ref.current?.toggleOrderedList(),
      toggleSpoiler: () => ref.current?.toggleSpoiler(),
      toggleStrikethrough: () => ref.current?.toggleStrikethrough(),
      toggleSubscript: () => ref.current?.toggleSubscript(),
      toggleSuperscript: () => ref.current?.toggleSuperscript(),
      toggleUnorderedList: () => ref.current?.toggleUnorderedList(),
    }),
    []
  );
}
