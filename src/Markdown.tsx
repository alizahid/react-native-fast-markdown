import { useMemo } from 'react'
import { type StyleProp, StyleSheet, type ViewProps } from 'react-native'
import MarkdownViewNative from './MarkdownNativeComponent'
import { normalizeMarkdownStyle } from './normalizeStyle'
import {
  type LinkPressEvent,
  type MarkdownBlockStyle,
  type MarkdownStyle,
  type MentionPressEvent,
  type MentionType,
  type TaskListItemPressEvent,
} from './types'

export interface MarkdownProps extends Omit<ViewProps, 'style'> {
  /** Markdown string to render */
  children: string

  /** Registered custom HTML-like tag names */
  customTags?: Array<string>

  /** Called when a link is long pressed */
  onLinkLongPress?: (event: LinkPressEvent) => void

  /** Called when a link is pressed */
  onLinkPress?: (event: LinkPressEvent) => void

  /** Called when a mention is pressed */
  onMentionPress?: (event: MentionPressEvent) => void

  /** Called when a task list checkbox is pressed */
  onTaskListItemPress?: (event: TaskListItemPressEvent) => void

  /** Style applied to the markdown container. Accepts both ViewStyle
   *  (padding, background, borders, gap between blocks) and TextStyle
   *  (default font, color, lineHeight inherited by all text). */
  style?: StyleProp<MarkdownBlockStyle>

  /** Custom styles for markdown elements */
  styles?: MarkdownStyle
}

export function Markdown({
  children,
  styles: markdownStyles,
  customTags,
  style,
  onLinkPress,
  onLinkLongPress,
  onMentionPress,
  onTaskListItemPress,
  ...viewProps
}: MarkdownProps) {
  // Merge the style prop into styles as the internal `base` key.
  // The `style` prop is the user-facing way to set default text styles
  // (color, fontSize, etc.) and outer container styles (padding,
  // backgroundColor, borders, gap between blocks) for the whole markdown.
  const effectiveStyle = useMemo(() => {
    const flatStyle = StyleSheet.flatten([
      {
        color: 'rgb(16, 15, 15)',
        fontSize: 14,
        lineHeight: 20,
        gap: 8,
      },
      style,
    ])

    if (Object.keys(flatStyle).length === 0 && !markdownStyles) {
      return
    }

    return {
      ...markdownStyles,
      base: flatStyle,
    } as MarkdownStyle
  }, [markdownStyles, style])

  const serializedStyles = useMemo(
    () => normalizeMarkdownStyle(effectiveStyle),
    [effectiveStyle],
  )

  return (
    <MarkdownViewNative
      {...viewProps}
      customTags={customTags}
      markdown={children}
      onLinkLongPress={
        onLinkLongPress
          ? (e) =>
              onLinkLongPress({
                url: e.nativeEvent.url,
                title: e.nativeEvent.title,
              })
          : undefined
      }
      onLinkPress={
        onLinkPress
          ? (e) =>
              onLinkPress({
                url: e.nativeEvent.url,
                title: e.nativeEvent.title,
              })
          : undefined
      }
      onMentionPress={
        onMentionPress
          ? (e) => {
              let extras: Record<string, string> = {}
              try {
                extras = e.nativeEvent.mentionProps
                  ? JSON.parse(e.nativeEvent.mentionProps)
                  : {}
              } catch {
                extras = {}
              }
              // Flatten: extras first, then the canonical fields on
              // top so id/name/type always win over any extra prop
              // that happens to share those names.
              onMentionPress({
                ...extras,
                type: e.nativeEvent.mentionType as MentionType,
                id: e.nativeEvent.mentionId,
                name: e.nativeEvent.mentionName || undefined,
              })
            }
          : undefined
      }
      onTaskListItemPress={
        onTaskListItemPress
          ? (e) =>
              onTaskListItemPress({
                index: e.nativeEvent.index,
                checked: e.nativeEvent.checked,
              })
          : undefined
      }
      styles={serializedStyles}
    />
  )
}
