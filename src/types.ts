import { type TextStyle, type ViewStyle } from 'react-native'

// --- Markdown Style ---
//
// All style keys use standard React Native TextStyle or ViewStyle.
// No custom props (like cellPadding, bulletColor, etc.) — use the
// standard equivalents (padding on tableCell, color on listBullet).

export interface MarkdownStyle {
  /** Base text style — applies to all text unless overridden.
   *  Use this for global font, color, line height, etc. */
  text?: TextStyle

  // Block elements
  blockquote?: TextStyle
  code?: TextStyle
  codeBlock?: TextStyle
  emphasis?: TextStyle
  heading1?: TextStyle
  heading2?: TextStyle
  heading3?: TextStyle
  heading4?: TextStyle
  heading5?: TextStyle
  heading6?: TextStyle
  image?: ViewStyle
  link?: TextStyle
  listItem?: TextStyle
  /** Bullet/number character style for list items */
  listBullet?: TextStyle
  paragraph?: TextStyle
  strikethrough?: TextStyle
  strong?: TextStyle

  // Tables
  /** Outer table container (scroll view) */
  table?: ViewStyle
  /** Body row style */
  tableRow?: ViewStyle
  /** Header row style (overrides tableRow for the header row) */
  tableHeaderRow?: ViewStyle
  /** Body cell style — view and text props both apply */
  tableCell?: TextStyle
  /** Header cell style (overrides tableCell for header cells) */
  tableHeaderCell?: TextStyle

  thematicBreak?: ViewStyle
  underline?: TextStyle

  // Custom components
  mention?: TextStyle
  spoiler?: ViewStyle

  // Extensible: any custom tag
  [key: string]: unknown
}

// --- Event Types ---

export interface LinkPressEvent {
  title?: string
  url: string
}

export interface MentionPressEvent {
  user: string
}

export interface TaskListItemPressEvent {
  checked: boolean
  index: number
}

// --- Editor State ---

export interface EditorStyleState {
  bold: boolean
  code: boolean
  heading: number | null
  italic: boolean
  link: { url: string } | null
  list: 'ordered' | 'unordered' | null
  strikethrough: boolean
  underline: boolean
}

// --- Editor Handle ---

export interface MarkdownInputHandle {
  blur(): void
  focus(): void
  getMarkdown(): Promise<string>
  insertCustomTag(tag: string, props?: Record<string, string>): void

  // Links
  insertLink(url: string, text?: string): void

  // Custom
  insertMention(user: string): void
  insertSpoiler(): void
  removeLink(): void
  setSelection(start: number, end: number): void
  setValue(markdown: string): void
  toggleBlockquote(): void

  // Formatting toggles
  toggleBold(): void
  toggleCode(): void

  // Block formatting
  toggleHeading(level: number): void
  toggleItalic(): void
  toggleOrderedList(): void
  toggleStrikethrough(): void
  toggleUnderline(): void
  toggleUnorderedList(): void
}
