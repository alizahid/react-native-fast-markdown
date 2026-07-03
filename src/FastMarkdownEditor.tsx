import { type Ref, useImperativeHandle, useRef } from "react";
import { type StyleProp, TextInput, type TextStyle } from "react-native";

import type { FastMarkdownEditorProps, FastMarkdownEditorRef } from "./types";

// Non-native (web) fallback: a plain multiline text input over raw markdown.
export function FastMarkdownEditor({
  autoCapitalize,
  autoCorrect,
  autoFocus,
  defaultValue,
  editable,
  multiline = true,
  onBlur,
  onChangeMarkdown,
  onChangeText,
  onFocus,
  placeholder,
  placeholderTextColor,
  style,
  ref,
}: FastMarkdownEditorProps & { ref?: Ref<FastMarkdownEditorRef> }) {
  const inputRef = useRef<React.ComponentRef<typeof TextInput>>(null);
  const textRef = useRef(defaultValue ?? "");

  useImperativeHandle(
    ref,
    (): FastMarkdownEditorRef => ({
      blur: () => inputRef.current?.blur(),
      focus: () => inputRef.current?.focus(),
      getMarkdown: () => Promise.resolve(textRef.current),
      insertLink: () => undefined,
      insertMention: () => undefined,
      removeLink: () => undefined,
      setSelection: () => {
        // Not supported in the web fallback.
      },
      setValue: (markdown: string) => {
        textRef.current = markdown;
        inputRef.current?.setNativeProps({ text: markdown });
      },
      // Formatting toggles are not supported in the web fallback (raw
      // markdown).
      toggleBlockQuote: () => undefined,
      toggleBold: () => undefined,
      toggleCode: () => undefined,
      toggleCodeBlock: () => undefined,
      toggleHeading: () => undefined,
      toggleItalic: () => undefined,
      toggleOrderedList: () => undefined,
      toggleSpoiler: () => undefined,
      toggleStrikethrough: () => undefined,
      toggleSubscript: () => undefined,
      toggleSuperscript: () => undefined,
      toggleUnorderedList: () => undefined,
    }),
    []
  );

  return (
    <TextInput
      autoCapitalize={autoCapitalize}
      autoCorrect={autoCorrect}
      autoFocus={autoFocus}
      defaultValue={defaultValue}
      editable={editable}
      multiline={multiline}
      onBlur={onBlur}
      onChangeText={(text) => {
        textRef.current = text;
        onChangeText?.(text);
        onChangeMarkdown?.(text);
      }}
      onFocus={onFocus}
      placeholder={placeholder}
      placeholderTextColor={placeholderTextColor}
      ref={inputRef}
      style={style as StyleProp<TextStyle>}
    />
  );
}
