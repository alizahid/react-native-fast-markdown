import { type TextStyle, type ViewStyle } from 'react-native'

// --- Style type building blocks ---

/** Standard React Native ViewStyle properties supported on block-level
 *  markdown elements. Applied to a container view that wraps the block. */
export type MarkdownViewStyle = Pick<
  ViewStyle,
  | 'backgroundColor'
  | 'borderBottomColor'
  | 'borderBottomLeftRadius'
  | 'borderBottomRightRadius'
  | 'borderBottomWidth'
  | 'borderColor'
  | 'borderCurve'
  | 'borderLeftColor'
  | 'borderLeftWidth'
  | 'borderRadius'
  | 'borderRightColor'
  | 'borderRightWidth'
  | 'borderStyle'
  | 'borderTopColor'
  | 'borderTopLeftRadius'
  | 'borderTopRightRadius'
  | 'borderTopWidth'
  | 'borderWidth'
  | 'gap'
  | 'margin'
  | 'marginBottom'
  | 'marginHorizontal'
  | 'marginLeft'
  | 'marginRight'
  | 'marginTop'
  | 'marginVertical'
  | 'padding'
  | 'paddingBottom'
  | 'paddingHorizontal'
  | 'paddingLeft'
  | 'paddingRight'
  | 'paddingTop'
  | 'paddingVertical'
>

/** Standard React Native TextStyle properties supported on text and
 *  block-level elements. Applied via attributed string attributes. */
export type MarkdownTextStyle = Pick<
  TextStyle,
  | 'color'
  | 'fontFamily'
  | 'fontSize'
  | 'fontStyle'
  | 'fontWeight'
  | 'letterSpacing'
  | 'lineHeight'
  | 'textAlign'
  | 'textDecorationColor'
  | 'textDecorationLine'
  | 'textDecorationStyle'
>

/** Block-level style: accepts both ViewStyle (for the container)
 *  and TextStyle (for the text inside). */
export type MarkdownBlockStyle = MarkdownViewStyle & MarkdownTextStyle

// --- Markdown Style ---

// biome-ignore assist/source/useSortedInterfaceMembers: go away
export interface MarkdownStyle {
  // Block elements (accept both view + text)
  paragraph?: MarkdownBlockStyle
  heading1?: MarkdownBlockStyle
  heading2?: MarkdownBlockStyle
  heading3?: MarkdownBlockStyle
  heading4?: MarkdownBlockStyle
  heading5?: MarkdownBlockStyle
  heading6?: MarkdownBlockStyle
  blockquote?: MarkdownBlockStyle
  codeBlock?: MarkdownBlockStyle
  list?: MarkdownBlockStyle
  listItem?: MarkdownBlockStyle

  // Block elements with no text content
  thematicBreak?: MarkdownViewStyle
  image?: MarkdownViewStyle

  // Tables
  table?: MarkdownViewStyle
  tableRow?: MarkdownViewStyle
  tableHeaderRow?: MarkdownViewStyle
  tableCell?: MarkdownBlockStyle
  tableHeaderCell?: MarkdownBlockStyle

  // Inline / text-only elements
  strong?: MarkdownTextStyle
  emphasis?: MarkdownTextStyle
  strikethrough?: MarkdownTextStyle
  underline?: MarkdownTextStyle
  code?: MarkdownTextStyle
  link?: MarkdownTextStyle
  mention?: MarkdownTextStyle
  listBullet?: MarkdownTextStyle

  // Special
  spoiler?: MarkdownViewStyle

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
