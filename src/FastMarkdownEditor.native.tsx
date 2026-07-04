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
  if (typeof processed !== "number") {
    if (__DEV__) {
      console.warn(
        "react-native-fast-markdown: platform colors (PlatformColor/" +
          "DynamicColorIOS) are not supported for editor color props and " +
          "were ignored. Use a static color instead."
      );
    }
    return 0;
  }
  // 0 (fully transparent) is the "unset" sentinel, so nudge a real
  // transparent to the nearest representable value; `| 0` keeps the value
  // inside the Int32 codegen contract on iOS.
  return processed === 0 ? 0x01_00_00_00 | 0 : processed | 0;
}

export function FastMarkdownEditor({
  allowFontScaling,
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
  // maxHeight is native-managed: autogrow caps there and the editor
  // scrolls internally past it, so Yoga must not clamp on top.
  const { maxHeight, ...editorHostStyle } = hostStyle;
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
      insertMarkdown: (markdown: string) => {
        if (nativeRef.current) {
          Commands.insertMarkdown(nativeRef.current, markdown);
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
        // Seed with the value being set so getMarkdown() never reports the
        // pre-setValue document; native re-emits its canonical serialization
        // right after.
        markdownRef.current = markdown;
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

  // The native side never inserts pasted content itself: it reports the
  // clipboard here, and unless the app's onPaste calls preventDefault()
  // synchronously, the default insertion happens via insertMarkdown.
  const handlePaste = useCallback(
    (
      event: NativeSyntheticEvent<{
        images: readonly MarkdownImageData[];
        text: string;
      }>
    ) => {
      const { images, text } = event.nativeEvent;
      let prevented = false;
      onPaste?.({
        images: images.length > 0 ? [...images] : undefined,
        preventDefault: () => {
          prevented = true;
        },
        text: text.length > 0 ? text : undefined,
      });
      if (!prevented && text.length > 0 && nativeRef.current) {
        Commands.insertMarkdown(nativeRef.current, text);
      }
    },
    [onPaste]
  );

  return (
    <NativeFastMarkdownEditor
      allowFontScaling={allowFontScaling}
      autoCapitalize={autoCapitalize}
      autoCorrect={autoCorrect}
      autoFocus={autoFocus}
      cursorColor={processedColor(cursorColor)}
      defaultValue={defaultValue}
      editable={editable}
      maxHeight={typeof maxHeight === "number" ? maxHeight : 0}
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
        onChangeState
          ? (event) => {
              // Copy the declared fields so consumers never see the raw
              // nativeEvent extras (target, etc.).
              const state = event.nativeEvent;
              onChangeState({
                headingLevel: state.headingLevel,
                isBlockQuote: state.isBlockQuote,
                isBold: state.isBold,
                isCodeBlock: state.isCodeBlock,
                isInlineCode: state.isInlineCode,
                isItalic: state.isItalic,
                isOrderedList: state.isOrderedList,
                isSpoiler: state.isSpoiler,
                isStrikethrough: state.isStrikethrough,
                isSubscript: state.isSubscript,
                isSuperscript: state.isSuperscript,
                isUnorderedList: state.isUnorderedList,
              });
            }
          : undefined
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
      onEditorPaste={handlePaste}
      placeholder={placeholder}
      placeholderTextColor={processedColor(placeholderTextColor)}
      ref={nativeRef}
      scrollEnabled={scrollEnabled}
      selectionColor={processedColor(selectionColor)}
      style={editorHostStyle}
      stylesJson={stylesJson}
    />
  );
}
