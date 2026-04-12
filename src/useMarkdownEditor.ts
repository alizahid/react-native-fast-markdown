import { useCallback, useRef } from 'react'
import { type MarkdownEditorHandle } from './types'

export function useMarkdownEditor() {
  const ref = useRef<MarkdownEditorHandle>(null)

  const focus = useCallback(() => ref.current?.focus(), [])
  const blur = useCallback(() => ref.current?.blur(), [])
  const setValue = useCallback(
    (markdown: string) => ref.current?.setValue(markdown),
    [],
  )
  const getMarkdown = useCallback(
    () => ref.current?.getMarkdown() ?? Promise.resolve(''),
    [],
  )
  const setSelection = useCallback(
    (start: number, end: number) => ref.current?.setSelection(start, end),
    [],
  )
  const toggleBold = useCallback(() => ref.current?.toggleBold(), [])
  const toggleItalic = useCallback(() => ref.current?.toggleItalic(), [])
  const toggleStrikethrough = useCallback(
    () => ref.current?.toggleStrikethrough(),
    [],
  )
  const toggleCode = useCallback(() => ref.current?.toggleCode(), [])
  const toggleHeading = useCallback(
    (level: number) => ref.current?.toggleHeading(level),
    [],
  )
  const toggleOrderedList = useCallback(
    () => ref.current?.toggleOrderedList(),
    [],
  )
  const toggleUnorderedList = useCallback(
    () => ref.current?.toggleUnorderedList(),
    [],
  )
  const insertLink = useCallback(
    (url: string, text?: string) => ref.current?.insertLink(url, text),
    [],
  )
  const removeLink = useCallback(() => ref.current?.removeLink(), [])
  const insertMention = useCallback(
    (trigger: string, label: string, props: Record<string, string>) =>
      ref.current?.insertMention(trigger, label, props),
    [],
  )
  const insertSpoiler = useCallback(() => ref.current?.insertSpoiler(), [])
  const insertCustomTag = useCallback(
    (tag: string, props?: Record<string, string>) =>
      ref.current?.insertCustomTag(tag, props),
    [],
  )

  return {
    ref,
    focus,
    blur,
    setValue,
    getMarkdown,
    setSelection,
    toggleBold,
    toggleItalic,
    toggleStrikethrough,
    toggleCode,
    toggleHeading,
    toggleOrderedList,
    toggleUnorderedList,
    insertLink,
    removeLink,
    insertMention,
    insertSpoiler,
    insertCustomTag,
  }
}
