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
  | 'height'
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
  | 'width'
>

/** Standard React Native TextStyle properties supported on text and
 *  block-level elements. Applied via attributed string attributes. */
export type MarkdownTextStyle = Pick<
  TextStyle,
  | 'backgroundColor'
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
  listBullet?: MarkdownTextStyle

  // Mentions — three trigger types, each with its own style
  userMention?: MarkdownTextStyle
  channelMention?: MarkdownTextStyle
  commandMention?: MarkdownTextStyle

  // Special
  spoiler?: MarkdownViewStyle
}

// --- Event Types ---

export interface LinkPressEvent {
  title?: string
  url: string
}

/** The three mention trigger types. `user` is `@`, `channel` is `#`,
 *  `command` is `/`. */
export type MentionType = 'user' | 'channel' | 'command'

/** Payload delivered to `onMentionPress`. `type`, `id` and `name`
 *  come from the tag's canonical attributes; any other attribute set
 *  on the source tag flows through as an extra string field on the
 *  same object.
 *
 *  The index signature includes `undefined` because `name` is
 *  optional — TypeScript requires every declared property type to
 *  be assignable to the index signature's value type, and an
 *  optional `string` is `string | undefined`. When you read an
 *  extra prop like `event.foo`, it'll type as `string | undefined`
 *  which is accurate: the tag may or may not have had that
 *  attribute. */
export interface MentionPressEvent {
  /** Which kind of mention was pressed. */
  type: MentionType
  /** The `id` attribute that was on the mention tag. */
  id: string
  /** The `name` attribute, if present (optional for commands). */
  name?: string
  /** Any other attribute set on the source tag. */
  [key: string]: string | undefined
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
