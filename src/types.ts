import { type TextStyle, type ViewStyle } from 'react-native'

// --- Style building blocks ---

/** Every block-level element in markdown goes through
 *  MarkdownBlockView on the native side, which reads exactly this
 *  set of view-style props: background, border widths + colors
 *  (uniform + per-side), border radius (uniform + per-corner),
 *  margin, padding, and explicit width / height overrides. */
export type MarkdownBlockViewStyle = Pick<
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

/** Full text-style surface applied via StyleAttributes.applyStyle
 *  on the native side: font (family, size, style, weight), color,
 *  inline background highlight, kerning, text decoration, line
 *  height, and alignment. Elements whose renderer calls applyStyle
 *  accept this entire surface. */
export type MarkdownInlineTextStyle = Pick<
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

// --- Per-element styles ---

/** Outer `<Markdown style={...}>` style. The root block view reads
 *  the full MarkdownBlockViewStyle surface; `gap` sets the vertical
 *  spacing between top-level blocks. A reduced subset of text props
 *  cascades down to every nested block: `color`, `fontFamily`,
 *  `fontSize`, `fontStyle`, `fontWeight`, `lineHeight`, `textAlign`.
 *  Other text props (kerning, decoration, inline background) need
 *  to be set on the individual element style instead. */
export type MarkdownBaseStyle = MarkdownBlockViewStyle & {
  gap?: number
} & Pick<
    TextStyle,
    | 'color'
    | 'fontFamily'
    | 'fontSize'
    | 'fontStyle'
    | 'fontWeight'
    | 'lineHeight'
    | 'textAlign'
  >

/** Paragraph — a block-level run of text. Supports the full block
 *  view surface (background, borders, radius, margin, padding) plus
 *  the full inline text set. */
export type MarkdownParagraphStyle = MarkdownBlockViewStyle &
  MarkdownInlineTextStyle

/** Heading levels 1 through 6. Same surface as paragraph; each
 *  level has its own style key and the renderer picks the right
 *  one. */
export type MarkdownHeadingStyle = MarkdownBlockViewStyle &
  MarkdownInlineTextStyle

/** Blockquote. Same surface as paragraph plus `gap` for the
 *  vertical spacing between nested children — the blockquote is a
 *  container that can hold multiple paragraphs / lists / code
 *  blocks. Text props on the blockquote style cascade down into
 *  those children. */
export type MarkdownBlockquoteStyle = MarkdownBlockViewStyle &
  MarkdownInlineTextStyle & {
    gap?: number
  }

/** Fenced code block. Block view surface plus the full inline text
 *  set — the block's text runs through the same attributed-string
 *  pipeline so `fontFamily` lets you swap in a monospaced font and
 *  `backgroundColor` on the block view gives it the classic tinted
 *  look. */
export type MarkdownCodeBlockStyle = MarkdownBlockViewStyle &
  MarkdownInlineTextStyle

/** Outer list container. Only block view props plus `gap` (the
 *  vertical spacing between list items) apply here — text props on
 *  the list style itself are NOT read. Use `listItem` or
 *  `listBullet` to style the item text or the marker. */
export type MarkdownListStyle = MarkdownBlockViewStyle & {
  gap?: number
}

/** List item. Wraps a single marker + content pair. Block view
 *  surface plus the full inline text set for the item's content
 *  text. */
export type MarkdownListItemStyle = MarkdownBlockViewStyle &
  MarkdownInlineTextStyle

/** The bullet or numbered marker on each list item. The marker is
 *  rendered as a prefix string inside the attributed content of
 *  the item, so only text-style props apply. */
export type MarkdownListBulletStyle = MarkdownInlineTextStyle

/** Block-level image (`![alt](url)` on its own line). Block view
 *  surface plus image-specific sizing constraints. Text props are
 *  not read — images don't render any text. */
export type MarkdownImageStyle = MarkdownBlockViewStyle & {
  /** Hard cap on the block height. When the natural size would
   *  exceed this, the block (and image inside) scale down
   *  proportionally. */
  maxHeight?: number
  /** Hard cap on the block width. Same semantics as `maxHeight`. */
  maxWidth?: number
  /** How the image fills the reserved rect when `maxWidth` /
   *  `maxHeight` produce a box whose aspect ratio differs from the
   *  image's natural aspect ratio.
   *
   *  - `cover` (default): the block is sized to (maxWidth,
   *    maxHeight) exactly and the image scales to fill, cropping
   *    whatever overflows.
   *  - `contain`: the block shrinks to the image's natural aspect
   *    ratio fitted within the max box. No cropping, no empty
   *    space. */
  objectFit?: 'contain' | 'cover'
}

/** Horizontal rule. Block view surface — `height` sets the line
 *  thickness and `backgroundColor` sets the line color. There's
 *  no text. */
export type MarkdownThematicBreakStyle = MarkdownBlockViewStyle

/** Outer table container. Only the block view surface applies
 *  here — the wrapping background, border, corner radius, padding
 *  and margin. Internal cell grid lines are driven by the
 *  `tableCell` border, not this style. */
export type MarkdownTableStyle = MarkdownBlockViewStyle

/** Table row. Only `backgroundColor` is read — everything else
 *  (borders, padding, text) is set via `tableCell` or
 *  `tableHeaderCell`. */
export type MarkdownTableRowStyle = Pick<ViewStyle, 'backgroundColor'>

/** Table cell. Uniform border (per-side borders aren't supported
 *  on cells), padding, background — plus the cell text's font,
 *  color, and alignment. Inline formatting inside the cell (bold,
 *  emphasis, links, …) still flows through the inline renderers. */
export type MarkdownTableCellStyle = Pick<
  ViewStyle,
  | 'backgroundColor'
  | 'borderColor'
  | 'borderWidth'
  | 'padding'
  | 'paddingBottom'
  | 'paddingHorizontal'
  | 'paddingLeft'
  | 'paddingRight'
  | 'paddingTop'
  | 'paddingVertical'
> &
  Pick<
    TextStyle,
    'color' | 'fontFamily' | 'fontSize' | 'fontStyle' | 'fontWeight' | 'textAlign'
  >

/** Inline link. Full text surface — color, font, decoration,
 *  inline background. View-style props (padding, borders, …) don't
 *  apply to inline runs. */
export type MarkdownLinkStyle = MarkdownInlineTextStyle

/** Inline code span. Full text surface — set `backgroundColor` to
 *  get the classic inline code tint and `fontFamily` to switch to
 *  a monospaced font. */
export type MarkdownCodeStyle = MarkdownInlineTextStyle

/** Mention span. Three mention types share the same surface:
 *  `mentionUser` (@), `mentionChannel` (#), `mentionCommand` (/).
 *  Full text surface — the press overlay is a separate view that
 *  doesn't read any style props. */
export type MarkdownMentionStyle = MarkdownInlineTextStyle

/** Bold / strong span. Only `color` is read — the renderer derives
 *  the bold trait from whatever font is currently in effect and
 *  layers the color on top. */
export type MarkdownStrongStyle = Pick<TextStyle, 'color'>

/** Italic / emphasis span. Only `color` is read — the renderer
 *  derives the italic trait from the current font. */
export type MarkdownEmphasisStyle = Pick<TextStyle, 'color'>

/** Strikethrough span. Only `color` is read — both the glyphs and
 *  the strike line pick up the same color. */
export type MarkdownStrikethroughStyle = Pick<TextStyle, 'color'>

/** Spoiler overlay. Only `backgroundColor` (the overlay fill) and
 *  `borderRadius` (the overlay corner radius) are read — the
 *  spoiler is drawn as a single coloured shape on top of its text
 *  range, not as a block view. */
export type MarkdownSpoilerStyle = Pick<
  ViewStyle,
  'backgroundColor' | 'borderRadius'
>

// --- Markdown Style ---

// biome-ignore assist/source/useSortedInterfaceMembers: go away
export interface MarkdownStyle {
  // Block-level text content
  paragraph?: MarkdownParagraphStyle
  heading1?: MarkdownHeadingStyle
  heading2?: MarkdownHeadingStyle
  heading3?: MarkdownHeadingStyle
  heading4?: MarkdownHeadingStyle
  heading5?: MarkdownHeadingStyle
  heading6?: MarkdownHeadingStyle
  blockquote?: MarkdownBlockquoteStyle
  codeBlock?: MarkdownCodeBlockStyle

  // Lists
  list?: MarkdownListStyle
  listItem?: MarkdownListItemStyle
  listBullet?: MarkdownListBulletStyle

  // Block-level with no text content
  image?: MarkdownImageStyle
  thematicBreak?: MarkdownThematicBreakStyle

  // Tables
  table?: MarkdownTableStyle
  tableRow?: MarkdownTableRowStyle
  tableHeaderRow?: MarkdownTableRowStyle
  tableCell?: MarkdownTableCellStyle
  tableHeaderCell?: MarkdownTableCellStyle

  // Inline — full text styling
  link?: MarkdownLinkStyle
  code?: MarkdownCodeStyle
  mentionUser?: MarkdownMentionStyle
  mentionChannel?: MarkdownMentionStyle
  mentionCommand?: MarkdownMentionStyle

  // Inline — color-only (bold / italic / strikethrough traits are
  // derived from the token itself, not from this style)
  strong?: MarkdownStrongStyle
  emphasis?: MarkdownEmphasisStyle
  strikethrough?: MarkdownStrikethroughStyle

  // Special
  spoiler?: MarkdownSpoilerStyle
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
  /** The `id` attribute that was on the mention tag. */
  id: string
  /** The `name` attribute, if present (optional for commands). */
  name?: string
  /** Which kind of mention was pressed. */
  type: MentionType
  /** Any other attribute set on the source tag. */
  [key: string]: string | undefined
}

export interface TaskListItemPressEvent {
  checked: boolean
  index: number
}

/** Pre-supplied image metadata passed to `<Markdown images={...}>`.
 *  When the renderer encounters a block-level `![alt](url)` whose
 *  url matches one of these entries, it reserves the supplied
 *  width / height during measurement — no layout shift when the
 *  image finishes loading. */
export interface MarkdownImageData {
  url: string
  width: number
  height: number
}

export interface ImagePressEvent {
  url: string
  width: number
  height: number
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
