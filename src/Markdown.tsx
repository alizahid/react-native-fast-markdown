import { useMemo } from 'react'
import { type ViewProps } from 'react-native'
import MarkdownViewNative from './MarkdownNativeComponent'
import { normalizeMarkdownStyle } from './normalizeStyle'
import {
  type LinkPressEvent,
  type MarkdownStyle,
  type MentionPressEvent,
  type TaskListItemPressEvent,
} from './types'

export interface MarkdownProps extends ViewProps {
  /** Markdown string to render */
  children: string

  /** Registered custom HTML-like tag names */
  customTags?: Array<string>

  /** Custom styles for markdown elements */
  markdownStyle?: MarkdownStyle

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
  markdownStyle,
  customTags,
  onLinkPress,
  onLinkLongPress,
  onMentionPress,
  onTaskListItemPress,
  ...viewProps
}: MarkdownProps) {
  const serializedStyle = useMemo(
    () => normalizeMarkdownStyle(markdownStyle),
    [markdownStyle],
  )

  return (
    <MarkdownViewNative
      {...viewProps}
      customTags={customTags}
      markdown={children}
      markdownStyle={serializedStyle}
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
