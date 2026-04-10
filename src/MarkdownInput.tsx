import React, { forwardRef, useCallback, useMemo } from 'react'
import { type ColorValue, type ViewProps } from 'react-native'
import MarkdownInputViewNative, {
  Commands,
} from './MarkdownInputNativeComponent'
import { normalizeMarkdownStyle } from './normalizeStyle'
import {
  type EditorStyleState,
  type MarkdownInputHandle,
  type MarkdownStyle,
} from './types'

export interface MarkdownInputProps extends ViewProps {
  /** Auto-capitalize behavior */
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters'

  /** Whether to auto-focus on mount */
  autoFocus?: boolean

  /** Cursor color */
  cursorColor?: ColorValue

  /** Registered custom HTML-like tag names */
  customTags?: Array<string>
  /** Initial markdown content */
  defaultValue?: string

  /** Whether the input is editable */
  editable?: boolean

  /** Custom styles for markdown elements */
  markdownStyle?: MarkdownStyle

  /** Whether the input supports multiple lines */
  multiline?: boolean

  /** Called when input loses focus */
  onBlur?: () => void

  /** Called when markdown output changes */
  onChangeMarkdown?: (markdown: string) => void

  /** Called when selection changes */
  onChangeSelection?: (selection: { start: number; end: number }) => void

  /** Called when formatting state at cursor changes */
  onChangeState?: (state: EditorStyleState) => void

  /** Called when raw text changes */
  onChangeText?: (text: string) => void

  /** Called when input receives focus */
  onFocus?: () => void

  /** Called when a URL is detected in text */
  onLinkDetected?: (url: string) => void

  /** Called when user triggers a mention query (e.g. types @) */
  onMentionQuery?: (query: string) => void

  /** Placeholder text */
  placeholder?: string

  /** Placeholder text color */
  placeholderTextColor?: ColorValue

  /** Whether scrolling is enabled */
  scrollEnabled?: boolean

  /** Selection highlight color */
  selectionColor?: ColorValue
}

export const MarkdownInput = forwardRef<
  MarkdownInputHandle,
  MarkdownInputProps
>(function MarkdownInput(
  {
    defaultValue,
    placeholder,
    placeholderTextColor,
    markdownStyle,
    customTags,
    editable = true,
    multiline = true,
    autoFocus = false,
    scrollEnabled = true,
    autoCapitalize = 'sentences',
    cursorColor,
    selectionColor,
    onChangeText,
    onChangeMarkdown,
    onChangeSelection,
    onChangeState,
    onLinkDetected,
    onMentionQuery,
    onFocus,
    onBlur,
    ...viewProps
  },
  ref,
) {
  const nativeRef =
    React.useRef<React.ElementRef<typeof MarkdownInputViewNative>>(null)

  const serializedStyle = useMemo(
    () => normalizeMarkdownStyle(markdownStyle),
    [markdownStyle],
  )

  // Expose imperative handle
  React.useImperativeHandle(
    ref,
    () => ({
      focus() {
        if (nativeRef.current) {
          Commands.focus(nativeRef.current)
        }
      },
      blur() {
        if (nativeRef.current) {
          Commands.blur(nativeRef.current)
        }
      },
      setValue(value: string) {
        if (nativeRef.current) {
          Commands.setValue(nativeRef.current, value)
        }
      },
      getMarkdown() {
        // This will be resolved via a native callback
        return new Promise<string>((resolve) => {
          // For now, trigger a state read from native
          if (nativeRef.current) {
            Commands.setValue(nativeRef.current, '')
          }
          resolve('')
        })
      },
      setSelection(start: number, end: number) {
        if (nativeRef.current) {
          Commands.setSelection(nativeRef.current, start, end)
        }
      },
      toggleBold() {
        if (nativeRef.current) {
          Commands.toggleBold(nativeRef.current)
        }
      },
      toggleItalic() {
        if (nativeRef.current) {
          Commands.toggleItalic(nativeRef.current)
        }
      },
      toggleStrikethrough() {
        if (nativeRef.current) {
          Commands.toggleStrikethrough(nativeRef.current)
        }
      },
      toggleUnderline() {
        if (nativeRef.current) {
          Commands.toggleUnderline(nativeRef.current)
        }
      },
      toggleCode() {
        if (nativeRef.current) {
          Commands.toggleCode(nativeRef.current)
        }
      },
      toggleHeading(level: number) {
        if (nativeRef.current) {
          Commands.toggleHeading(nativeRef.current, level)
        }
      },
      toggleOrderedList() {
        if (nativeRef.current) {
          Commands.toggleOrderedList(nativeRef.current)
        }
      },
      toggleUnorderedList() {
        if (nativeRef.current) {
          Commands.toggleUnorderedList(nativeRef.current)
        }
      },
      toggleBlockquote() {
        if (nativeRef.current) {
          Commands.toggleBlockquote(nativeRef.current)
        }
      },
      insertLink(url: string, text?: string) {
        if (nativeRef.current) {
          Commands.insertLink(nativeRef.current, url, text ?? '')
        }
      },
      removeLink() {
        if (nativeRef.current) {
          Commands.removeLink(nativeRef.current)
        }
      },
      insertMention(user: string) {
        if (nativeRef.current) {
          Commands.insertMention(nativeRef.current, user)
        }
      },
      insertSpoiler() {
        if (nativeRef.current) {
          Commands.insertSpoiler(nativeRef.current)
        }
      },
      insertCustomTag(tag: string, props?: Record<string, string>) {
        if (nativeRef.current) {
          Commands.insertCustomTag(
            nativeRef.current,
            tag,
            JSON.stringify(props ?? {}),
          )
        }
      },
    }),
    [],
  )

  const handleChangeState = useCallback(
    (e: {
      nativeEvent: {
        bold: boolean
        italic: boolean
        strikethrough: boolean
        underline: boolean
        code: boolean
        linkUrl: string
        heading: number
        list: string
      }
    }) => {
      onChangeState?.({
        bold: e.nativeEvent.bold,
        italic: e.nativeEvent.italic,
        strikethrough: e.nativeEvent.strikethrough,
        underline: e.nativeEvent.underline,
        code: e.nativeEvent.code,
        link: e.nativeEvent.linkUrl ? { url: e.nativeEvent.linkUrl } : null,
        heading: e.nativeEvent.heading > 0 ? e.nativeEvent.heading : null,
        list:
          e.nativeEvent.list === 'ordered' || e.nativeEvent.list === 'unordered'
            ? e.nativeEvent.list
            : null,
      })
    },
    [onChangeState],
  )

  return (
    <MarkdownInputViewNative
      {...viewProps}
      autoCapitalize={autoCapitalize}
      autoFocus={autoFocus}
      cursorColor={cursorColor ? String(cursorColor) : undefined}
      customTags={customTags}
      defaultValue={defaultValue}
      editable={editable}
      markdownStyle={serializedStyle}
      multiline={multiline}
      onChangeMarkdown={
        onChangeMarkdown
          ? (e) => onChangeMarkdown(e.nativeEvent.markdown)
          : undefined
      }
      onChangeSelection={
        onChangeSelection
          ? (e) =>
              onChangeSelection({
                start: e.nativeEvent.start,
                end: e.nativeEvent.end,
              })
          : undefined
      }
      onChangeState={onChangeState ? handleChangeState : undefined}
      onChangeText={
        onChangeText ? (e) => onChangeText(e.nativeEvent.text) : undefined
      }
      onEditorBlur={onBlur ? () => onBlur() : undefined}
      onEditorFocus={onFocus ? () => onFocus() : undefined}
      onLinkDetected={
        onLinkDetected ? (e) => onLinkDetected(e.nativeEvent.url) : undefined
      }
      onMentionQuery={
        onMentionQuery ? (e) => onMentionQuery(e.nativeEvent.query) : undefined
      }
      placeholder={placeholder}
      placeholderTextColor={
        placeholderTextColor ? String(placeholderTextColor) : undefined
      }
      ref={nativeRef}
      scrollEnabled={scrollEnabled}
      selectionColor={selectionColor ? String(selectionColor) : undefined}
    />
  )
})
