import type { ColorValue, DimensionValue, TextStyle, ViewStyle } from 'react-native'

// --- Markdown Style ---

export interface MarkdownBlockquoteStyle extends TextStyle {
  borderLeftColor?: ColorValue
  borderLeftWidth?: number
}

export interface MarkdownCodeBlockStyle extends TextStyle {
  backgroundColor?: ColorValue
  borderRadius?: number
  padding?: number
}

export interface MarkdownCodeStyle extends TextStyle {
  backgroundColor?: ColorValue
  borderRadius?: number
  padding?: number
}

export interface MarkdownListItemStyle extends TextStyle {
  bulletColor?: ColorValue
  bulletSize?: number
}

export interface MarkdownTableStyle {
  borderColor?: ColorValue
  borderWidth?: number
  headerBackgroundColor?: ColorValue
  cellBackgroundColor?: ColorValue
  alternateRowBackgroundColor?: ColorValue
  cellPadding?: number
  headerTextStyle?: TextStyle
  cellTextStyle?: TextStyle
}

export interface MarkdownThematicBreakStyle {
  backgroundColor?: ColorValue
  height?: number
  marginVertical?: number
}

export interface MarkdownImageStyle {
  maxWidth?: DimensionValue
  borderRadius?: number
}

export interface MarkdownSpoilerStyle extends ViewStyle {
  revealedTextStyle?: TextStyle
  overlayColor?: ColorValue
  mode?: 'solid' | 'particles'
}

export interface MarkdownMentionStyle extends TextStyle {
  /** Text to prepend before the user name, e.g. "@" */
  prefix?: string
}

export interface MarkdownStyle {
  // Block elements
  heading1?: TextStyle
  heading2?: TextStyle
  heading3?: TextStyle
  heading4?: TextStyle
  heading5?: TextStyle
  heading6?: TextStyle
  paragraph?: TextStyle
  blockquote?: MarkdownBlockquoteStyle
  codeBlock?: MarkdownCodeBlockStyle
  listItem?: MarkdownListItemStyle
  table?: MarkdownTableStyle
  thematicBreak?: MarkdownThematicBreakStyle
  image?: MarkdownImageStyle

  // Inline elements
  strong?: TextStyle
  emphasis?: TextStyle
  strikethrough?: TextStyle
  underline?: TextStyle
  code?: MarkdownCodeStyle
  link?: TextStyle

  // Custom components
  mention?: MarkdownMentionStyle
  spoiler?: MarkdownSpoilerStyle

  // Extensible: any custom tag
  [key: string]: unknown
}

// --- Event Types ---

export interface LinkPressEvent {
  url: string
  title?: string
}

export interface MentionPressEvent {
  user: string
}

export interface TaskListItemPressEvent {
  index: number
  checked: boolean
}

// --- Editor State ---

export interface EditorStyleState {
  bold: boolean
  italic: boolean
  strikethrough: boolean
  underline: boolean
  code: boolean
  link: { url: string } | null
  heading: number | null
  list: 'ordered' | 'unordered' | null
}

// --- Editor Handle ---

export interface MarkdownInputHandle {
  focus(): void
  blur(): void
  setValue(markdown: string): void
  getMarkdown(): Promise<string>
  setSelection(start: number, end: number): void

  // Formatting toggles
  toggleBold(): void
  toggleItalic(): void
  toggleStrikethrough(): void
  toggleUnderline(): void
  toggleCode(): void

  // Block formatting
  toggleHeading(level: number): void
  toggleOrderedList(): void
  toggleUnorderedList(): void
  toggleBlockquote(): void

  // Links
  insertLink(url: string, text?: string): void
  removeLink(): void

  // Custom
  insertMention(user: string): void
  insertSpoiler(): void
  insertCustomTag(tag: string, props?: Record<string, string>): void
}
