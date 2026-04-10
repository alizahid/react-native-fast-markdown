import {
  type ColorValue,
  type DimensionValue,
  type TextStyle,
  type ViewStyle,
} from 'react-native'

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
  alternateRowBackgroundColor?: ColorValue
  borderColor?: ColorValue
  borderWidth?: number
  cellBackgroundColor?: ColorValue
  cellPadding?: number
  cellTextStyle?: TextStyle
  headerBackgroundColor?: ColorValue
  headerTextStyle?: TextStyle
}

export interface MarkdownThematicBreakStyle {
  backgroundColor?: ColorValue
  height?: number
  marginVertical?: number
}

export interface MarkdownImageStyle {
  borderRadius?: number
  maxWidth?: DimensionValue
}

export interface MarkdownSpoilerStyle extends ViewStyle {
  mode?: 'solid' | 'particles'
  overlayColor?: ColorValue
  revealedTextStyle?: TextStyle
}

export interface MarkdownMentionStyle extends TextStyle {
  /** Text to prepend before the user name, e.g. "@" */
  prefix?: string
}

export interface MarkdownStyle {
  blockquote?: MarkdownBlockquoteStyle
  code?: MarkdownCodeStyle
  codeBlock?: MarkdownCodeBlockStyle
  emphasis?: TextStyle
  // Block elements
  heading1?: TextStyle
  heading2?: TextStyle
  heading3?: TextStyle
  heading4?: TextStyle
  heading5?: TextStyle
  heading6?: TextStyle
  image?: MarkdownImageStyle
  link?: TextStyle
  listItem?: MarkdownListItemStyle

  // Custom components
  mention?: MarkdownMentionStyle
  paragraph?: TextStyle
  spoiler?: MarkdownSpoilerStyle
  strikethrough?: TextStyle

  // Inline elements
  strong?: TextStyle
  table?: MarkdownTableStyle
  thematicBreak?: MarkdownThematicBreakStyle
  underline?: TextStyle

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
