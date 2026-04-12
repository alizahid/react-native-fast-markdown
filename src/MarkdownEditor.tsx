import React, { forwardRef, useCallback, useMemo } from 'react'
import { type ColorValue, StyleSheet, type ViewProps } from 'react-native'
import MarkdownEditorViewNative, {
  Commands,
} from './MarkdownEditorNativeComponent'
import { normalizeMarkdownStyle } from './normalizeStyle'
import {
  type EditorStyleState,
  type MarkdownEditorHandle,
  type MarkdownStyle,
  type MentionTrigger,
} from './types'

export interface MarkdownEditorProps extends ViewProps {
  /** Auto-capitalize behavior */
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters'

  /** Whether to auto-correct text */
  autoCorrect?: boolean

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

  /** Trigger characters that activate mention detection (e.g. ['@', '#', '/']) */
  mentionTriggers?: Array<MentionTrigger>

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

  /** Called on each keystroke after a trigger — update suggestions */
  onMentionChange?: (event: {
    query: string
    trigger: MentionTrigger
  }) => void

  /** Called when mention is cancelled — hide suggestions */
  onMentionEnd?: (trigger: MentionTrigger) => void

  /** Called when user types a trigger character — show suggestions */
  onMentionStart?: (trigger: MentionTrigger) => void

  /** Placeholder text */
  placeholder?: string

  /** Placeholder text color */
  placeholderTextColor?: ColorValue

  /** Whether scrolling is enabled */
  scrollEnabled?: boolean

  /** Selection highlight color */
  selectionColor?: ColorValue

  /** Custom styles for markdown elements */
  styles?: MarkdownStyle
}

export const MarkdownEditor = forwardRef<
  MarkdownEditorHandle,
  MarkdownEditorProps
>(function MarkdownEditor(
  {
    defaultValue,
    placeholder,
    placeholderTextColor,
    styles: markdownStyles,
    customTags,
    editable = true,
    multiline = true,
    autoFocus = false,
    autoCorrect = true,
    scrollEnabled = true,
    autoCapitalize = 'sentences',
    cursorColor,
    selectionColor,
    onChangeText,
    onChangeMarkdown,
    onChangeSelection,
    onChangeState,
    onLinkDetected,
    mentionTriggers,
    onMentionStart,
    onMentionChange,
    onMentionEnd,
    onFocus,
    onBlur,
    ...viewProps
  },
  ref,
) {
  const nativeRef =
    React.useRef<React.ElementRef<typeof MarkdownEditorViewNative>>(null)

  // Split the style prop: text properties go into the markdown
  // styles as the `base` key (same as the renderer), layout
  // properties stay on the native view's style prop.
  const { style, ...restViewProps } = viewProps

  // biome-ignore lint/complexity/noExcessiveCognitiveComplexity: go away
  const { textStyle, layoutStyle, contentPadding } = useMemo(() => {
    const flat = StyleSheet.flatten(style) || {}
    const text: Record<string, unknown> = {
      color: 'rgb(16, 15, 15)',
      fontSize: 14,
      lineHeight: 20,
    }
    const layout: Record<string, unknown> = {}

    // Extract padding for textContainerInset
    let padTop = 0
    let padRight = 0
    let padBottom = 0
    let padLeft = 0

    for (const [key, value] of Object.entries(flat)) {
      if (textPropNames.has(key)) {
        text[key] = value
      } else if (key === 'padding' && typeof value === 'number') {
        padTop = padRight = padBottom = padLeft = value
      } else if (key === 'paddingHorizontal' && typeof value === 'number') {
        padLeft = padRight = value
      } else if (key === 'paddingVertical' && typeof value === 'number') {
        padTop = padBottom = value
      } else if (key === 'paddingTop' && typeof value === 'number') {
        padTop = value
      } else if (key === 'paddingRight' && typeof value === 'number') {
        padRight = value
      } else if (key === 'paddingBottom' && typeof value === 'number') {
        padBottom = value
      } else if (key === 'paddingLeft' && typeof value === 'number') {
        padLeft = value
      } else {
        layout[key] = value
      }
    }

    return {
      textStyle: text,
      layoutStyle: layout,
      contentPadding: { padTop, padRight, padBottom, padLeft },
    }
  }, [style])

  const effectiveStyle = useMemo(() => {
    return {
      ...markdownStyles,
      base: textStyle,
    } as MarkdownStyle
  }, [markdownStyles, textStyle])

  const serializedStyles = useMemo(
    () => normalizeMarkdownStyle(effectiveStyle),
    [effectiveStyle],
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
      insertMention(
        trigger: string,
        label: string,
        props: Record<string, string>,
      ) {
        if (nativeRef.current) {
          Commands.insertMention(
            nativeRef.current,
            trigger,
            label,
            JSON.stringify(props),
          )
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
    <MarkdownEditorViewNative
      {...restViewProps}
      autoCapitalize={autoCapitalize}
      autoCorrect={autoCorrect}
      autoFocus={autoFocus}
      contentInsetBottom={contentPadding.padBottom}
      contentInsetLeft={contentPadding.padLeft}
      contentInsetRight={contentPadding.padRight}
      contentInsetTop={contentPadding.padTop}
      cursorColor={cursorColor ? String(cursorColor) : undefined}
      customTags={customTags}
      defaultValue={defaultValue}
      editable={editable}
      mentionTriggers={mentionTriggers}
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
      onMentionChange={
        onMentionChange
          ? (e) =>
              onMentionChange({
                trigger: e.nativeEvent.trigger as MentionTrigger,
                query: e.nativeEvent.query,
              })
          : undefined
      }
      onMentionEnd={
        onMentionEnd
          ? (e) => onMentionEnd(e.nativeEvent.trigger as MentionTrigger)
          : undefined
      }
      onMentionStart={
        onMentionStart
          ? (e) => onMentionStart(e.nativeEvent.trigger as MentionTrigger)
          : undefined
      }
      placeholder={placeholder}
      placeholderTextColor={
        placeholderTextColor ? String(placeholderTextColor) : undefined
      }
      ref={nativeRef}
      scrollEnabled={scrollEnabled}
      selectionColor={selectionColor ? String(selectionColor) : undefined}
      style={layoutStyle}
      styles={serializedStyles}
    />
  )
})

const textPropNames = new Set([
  'color',
  'fontFamily',
  'fontSize',
  'fontStyle',
  'fontWeight',
  'gap',
  'letterSpacing',
  'lineHeight',
  'textAlign',
  'textDecorationColor',
  'textDecorationLine',
  'textDecorationStyle',
])
