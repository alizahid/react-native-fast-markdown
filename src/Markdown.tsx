import { useCallback, useMemo, useState } from 'react'
import { StyleSheet, type StyleProp, type ViewProps } from 'react-native'
import MarkdownViewNative from './MarkdownNativeComponent'
import { normalizeMarkdownStyle } from './normalizeStyle'
import {
  type LinkPressEvent,
  type MarkdownBlockStyle,
  type MarkdownStyle,
  type MentionPressEvent,
  type TaskListItemPressEvent,
} from './types'

export interface MarkdownProps extends Omit<ViewProps, 'style'> {
  /** Markdown string to render */
  children: string

  /** Registered custom HTML-like tag names */
  customTags?: Array<string>

  /** Custom styles for markdown elements */
  styles?: MarkdownStyle

  /** Style applied to the markdown container. Accepts both ViewStyle
   *  (padding, background, borders, gap between blocks) and TextStyle
   *  (default font, color, lineHeight inherited by all text). */
  style?: StyleProp<MarkdownBlockStyle>

  /** Called when a link is long pressed */
  onLinkLongPress?: (event: LinkPressEvent) => void

  /** Called when a link is pressed */
  onLinkPress?: (event: LinkPressEvent) => void

  /** Called when a mention is pressed */
  onMentionPress?: (event: MentionPressEvent) => void

  /** Called when a task list checkbox is pressed */
  onTaskListItemPress?: (event: TaskListItemPressEvent) => void
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
    const flatStyle = StyleSheet.flatten(style) ?? {}
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

  const [height, setHeight] = useState<number | undefined>(undefined)

  const handleContentSizeChange = useCallback(
    (e: { nativeEvent: { width: number; height: number } }) => {
      setHeight(e.nativeEvent.height)
    },
    [],
  )

  return (
    <MarkdownViewNative
      {...viewProps}
      customTags={customTags}
      markdown={children}
      styles={serializedStyles}
      style={height === undefined ? undefined : { height }}
      onContentSizeChange={handleContentSizeChange}
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
          ? (e) => onMentionPress({ user: e.nativeEvent.user })
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
    />
  )
}
