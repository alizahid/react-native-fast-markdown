import {
  type Ref,
  useCallback,
  useImperativeHandle,
  useMemo,
  useRef,
} from "react";
import { type NativeSyntheticEvent, processColor } from "react-native";

import NativeFastMarkdownEditor, {
  Commands,
} from "./FastMarkdownEditorNativeComponent";
import {
  type MainStyle,
  serializeStyles,
  splitContainerStyle,
} from "./serializeStyles";
import type {
  FastMarkdownEditorProps,
  FastMarkdownEditorRef,
  MarkdownImageData,
  MarkdownSelection,
} from "./types";

type NativeEditor = React.ElementRef<typeof NativeFastMarkdownEditor>;

function processedColor(value: FastMarkdownEditorProps["cursorColor"]): number {
  if (value == null) {
    return 0;
  }
  const processed = processColor(value);
  return typeof processed === "number" ? processed : 0;
}

export function FastMarkdownEditor({
  autoCapitalize,
  autoCorrect,
  autoFocus,
  cursorColor,
  defaultValue,
  editable,
  mentionTriggers,
  multiline,
  onBlur,
  onChangeMarkdown,
  onChangeSelection,
  onChangeState,
  onChangeText,
  onFocus,
  onLinkDetected,
  onMentionChange,
  onMentionEnd,
  onMentionStart,
  onPaste,
  placeholder,
  placeholderTextColor,
  scrollEnabled,
  selectionColor,
  style,
  styles,
  ref,
}: FastMarkdownEditorProps & { ref?: Ref<FastMarkdownEditorRef> }) {
  const nativeRef = useRef<NativeEditor>(null);
  // getMarkdown resolves from the latest onEditorChangeMarkdown payload;
  // until the serializer emits (E1), plain text doubles as the markdown.
  const markdownRef = useRef<string | null>(null);
  const textRef = useRef<string>(defaultValue ?? "");

  const { hostStyle, main } = splitContainerStyle(style);
  const mainKey = JSON.stringify(main);
  const stylesJson = useMemo(
    () => serializeStyles(styles, JSON.parse(mainKey) as MainStyle),
    [styles, mainKey]
  );

  useImperativeHandle(
    ref,
    (): FastMarkdownEditorRef => ({
      blur: () => {
        if (nativeRef.current) {
          Commands.blur(nativeRef.current);
        }
      },
      focus: () => {
        if (nativeRef.current) {
          Commands.focus(nativeRef.current);
        }
      },
      getMarkdown: () =>
        Promise.resolve(markdownRef.current ?? textRef.current),
      insertLink: (url: string, label?: string) => {
        if (nativeRef.current) {
          Commands.insertLink(nativeRef.current, url, label ?? "");
        }
      },
      insertMention: (trigger: string, label: string, url: string) => {
        if (nativeRef.current) {
          Commands.insertMention(nativeRef.current, trigger, label, url);
        }
      },
      removeLink: () => {
        if (nativeRef.current) {
          Commands.removeLink(nativeRef.current);
        }
      },
      setSelection: (start: number, end: number) => {
        if (nativeRef.current) {
          Commands.setSelection(nativeRef.current, start, end);
        }
      },
      setValue: (markdown: string) => {
        markdownRef.current = null;
        textRef.current = markdown;
        if (nativeRef.current) {
          Commands.setValue(nativeRef.current, markdown);
        }
      },
      toggleBlockQuote: () => {
        if (nativeRef.current) {
          Commands.toggleBlockQuote(nativeRef.current);
        }
      },
      toggleBold: () => {
        if (nativeRef.current) {
          Commands.toggleBold(nativeRef.current);
        }
      },
      toggleCode: () => {
        if (nativeRef.current) {
          Commands.toggleCode(nativeRef.current);
        }
      },
      toggleCodeBlock: () => {
        if (nativeRef.current) {
          Commands.toggleCodeBlock(nativeRef.current);
        }
      },
      toggleHeading: (level: number) => {
        if (nativeRef.current) {
          Commands.toggleHeading(nativeRef.current, level);
        }
      },
      toggleItalic: () => {
        if (nativeRef.current) {
          Commands.toggleItalic(nativeRef.current);
        }
      },
      toggleOrderedList: () => {
        if (nativeRef.current) {
          Commands.toggleOrderedList(nativeRef.current);
        }
      },
      toggleSpoiler: () => {
        if (nativeRef.current) {
          Commands.toggleSpoiler(nativeRef.current);
        }
      },
      toggleStrikethrough: () => {
        if (nativeRef.current) {
          Commands.toggleStrikethrough(nativeRef.current);
        }
      },
      toggleSubscript: () => {
        if (nativeRef.current) {
          Commands.toggleSubscript(nativeRef.current);
        }
      },
      toggleSuperscript: () => {
        if (nativeRef.current) {
          Commands.toggleSuperscript(nativeRef.current);
        }
      },
      toggleUnorderedList: () => {
        if (nativeRef.current) {
          Commands.toggleUnorderedList(nativeRef.current);
        }
      },
    }),
    []
  );

  const handlePaste = useCallback(
    (
      event: NativeSyntheticEvent<{
        images: readonly MarkdownImageData[];
        text: string;
      }>
    ) => {
      if (!onPaste) {
        return;
      }
      const { images, text } = event.nativeEvent;
      onPaste({
        images: images.length > 0 ? [...images] : undefined,
        preventDefault: () => {
          // E5: suppresses the native default insertion.
        },
        text: text.length > 0 ? text : undefined,
      });
    },
    [onPaste]
  );

  return (
    <NativeFastMarkdownEditor
      autoCapitalize={autoCapitalize}
      autoCorrect={autoCorrect}
      autoFocus={autoFocus}
      cursorColor={processedColor(cursorColor)}
      defaultValue={defaultValue}
      editable={editable}
      mentionTriggers={mentionTriggers}
      multiline={multiline}
      onEditorBlur={onBlur ? () => onBlur() : undefined}
      onEditorChangeMarkdown={(
        event: NativeSyntheticEvent<{ markdown: string }>
      ) => {
        markdownRef.current = event.nativeEvent.markdown;
        onChangeMarkdown?.(event.nativeEvent.markdown);
      }}
      onEditorChangeSelection={
        onChangeSelection
          ? (event: NativeSyntheticEvent<MarkdownSelection>) =>
              onChangeSelection({
                end: event.nativeEvent.end,
                start: event.nativeEvent.start,
              })
          : undefined
      }
      onEditorChangeState={
        onChangeState ? (event) => onChangeState(event.nativeEvent) : undefined
      }
      onEditorChangeText={(event: NativeSyntheticEvent<{ text: string }>) => {
        textRef.current = event.nativeEvent.text;
        onChangeText?.(event.nativeEvent.text);
      }}
      onEditorFocus={onFocus ? () => onFocus() : undefined}
      onEditorLinkDetected={
        onLinkDetected
          ? (event: NativeSyntheticEvent<{ url: string }>) =>
              onLinkDetected({ url: event.nativeEvent.url })
          : undefined
      }
      onEditorMentionChange={
        onMentionChange
          ? (event) => onMentionChange(event.nativeEvent)
          : undefined
      }
      onEditorMentionEnd={
        onMentionEnd ? (event) => onMentionEnd(event.nativeEvent) : undefined
      }
      onEditorMentionStart={
        onMentionStart
          ? (event) => onMentionStart(event.nativeEvent)
          : undefined
      }
      onEditorPaste={onPaste ? handlePaste : undefined}
      placeholder={placeholder}
      placeholderTextColor={processedColor(placeholderTextColor)}
      ref={nativeRef}
      scrollEnabled={scrollEnabled}
      selectionColor={processedColor(selectionColor)}
      style={hostStyle}
      stylesJson={stylesJson}
    />
  );
}
