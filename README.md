<p align="center">
  <img alt="react-native-fast-markdown" src="https://github.com/alizahid/react-native-fast-markdown/blob/main/.github/banner.png?raw=true" width="720">
</p>

<p align="center">
  High-performance native Markdown renderer and editor for React Native
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/react-native-fast-markdown"><img src="https://img.shields.io/npm/v/react-native-fast-markdown?color=A02F6F&label=npm" alt="npm"></a>
  <a href="https://github.com/alizahid/react-native-fast-markdown/blob/main/LICENSE"><img src="https://img.shields.io/npm/l/react-native-fast-markdown?color=668C0B" alt="license"></a>
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20Android-5E409D" alt="platform">
  <img src="https://img.shields.io/badge/architecture-Fabric-205EA6" alt="architecture">
</p>

---

All parsing and rendering happens on the native thread. No JavaScript layout, no `<Text>` nesting, no bridge traffic. Just a C++ markdown parser feeding native views directly.

## Features

- **Native rendering** - parsed and laid out entirely on the native thread
- **Rich editor** - full markdown editor with formatting toolbar support
- **GFM support** - tables, strikethrough, autolinks
- **Mentions** - `@user`, `#channel`, `/command` with live detection
- **Spoilers & superscript** - `||spoiler||`, Reddit-style `>!spoiler!<`, and `^super`
- **Markdown-aware paste** - pasted markdown is imported as rich text, pasted images are emitted to JS
- **Custom tags** - extensible HTML-like tag system
- **Deep styling** - per-element style customization
- **Image pre-sizing** - supply dimensions to eliminate layout shift
- **Fabric only** - built for the New Architecture (React Native >= 0.76)

## Installation

```sh
npm install react-native-fast-markdown
cd ios && pod install
```

> Requires React Native >= 0.76 with the New Architecture (Fabric) enabled.

### Android

Android requires `minSdk` 24 (Android 7.0) or newer. Image loading uses [Glide](https://github.com/bumptech/glide), pulled in automatically. No manual linking — autolinking discovers the Gradle module.

### Platform differences

- **Link long-press preview**: iOS shows the system webpage-preview popover for `http(s)` URLs and only emits `onLinkLongPress` for custom schemes. Android has no equivalent native popover, so `onLinkLongPress` fires for every URL — build your own preview UI when you need one.
- **Editor**: `MarkdownEditor` is currently iOS-only. The renderer (`Markdown`) is supported on both platforms.

## Quick start

### Renderer

```tsx
import { Markdown } from 'react-native-fast-markdown'

function Post() {
  return (
    <Markdown
      onLinkPress={({ url }) => Linking.openURL(url)}
      style={{ fontSize: 16, lineHeight: 24, gap: 12 }}
    >
      {`# Hello world

This is **bold**, *italic*, and ~~struck~~.

- Lists work
- [Links](https://example.com) too`}
    </Markdown>
  )
}
```

### Editor (iOS only)

> The editor is currently iOS-only. The renderer (`<Markdown>`) is supported on iOS and Android.

```tsx
import { MarkdownEditor, useMarkdownEditor } from 'react-native-fast-markdown'

function Compose() {
  const editor = useMarkdownEditor()

  return (
    <>
      <MarkdownEditor
        ref={editor.ref}
        defaultValue="Start typing..."
        onChangeMarkdown={(md) => console.log(md)}
        placeholder="Write something..."
        style={{ flex: 1, padding: 16 }}
      />

      <Toolbar
        onBold={editor.toggleBold}
        onItalic={editor.toggleItalic}
        onLink={() => editor.insertLink('https://example.com', 'Example')}
      />
    </>
  )
}
```

## API

### `<Markdown>`

Renders a markdown string as native views.

| Prop | Type | Description |
|---|---|---|
| `children` | `string` | Markdown string to render **(required)** |
| `style` | `MarkdownBaseStyle` | Container + cascading text style |
| `styles` | `MarkdownStyle` | Per-element style overrides |
| `images` | `MarkdownImageData[]` | Pre-supplied image dimensions to prevent layout shift |
| `customTags` | `string[]` | Registered custom HTML-like tag names |
| `onLinkPress` | `(event: LinkPressEvent) => void` | Link tapped |
| `onLinkLongPress` | `(event: LinkPressEvent) => void` | Link long-pressed |
| `onImagePress` | `(event: ImagePressEvent) => void` | Block image tapped |
| `onMentionPress` | `(event: MentionPressEvent) => void` | Mention tapped |

Also accepts all `ViewProps` (except `style`).

### `<MarkdownEditor>`

A rich text input that outputs markdown.

| Prop | Type | Default | Description |
|---|---|---|---|
| `defaultValue` | `string` | | Initial markdown content |
| `placeholder` | `string` | | Placeholder text |
| `placeholderTextColor` | `ColorValue` | | Placeholder color |
| `styles` | `MarkdownStyle` | | Per-element style overrides |
| `customTags` | `string[]` | | Registered custom tag names |
| `editable` | `boolean` | `true` | Whether input is editable |
| `multiline` | `boolean` | `true` | Allow multiple lines |
| `autoFocus` | `boolean` | `false` | Focus on mount |
| `autoCorrect` | `boolean` | `true` | Auto-correct text |
| `autoCapitalize` | `string` | `'sentences'` | `'none' \| 'sentences' \| 'words' \| 'characters'` |
| `scrollEnabled` | `boolean` | `true` | Allow scrolling |
| `cursorColor` | `ColorValue` | | Cursor color |
| `selectionColor` | `ColorValue` | | Selection highlight color |
| `mentionTriggers` | `MentionTrigger[]` | | Trigger characters (`'@'`, `'#'`, `'/'`) |

**Callbacks:**

| Prop | Type | Description |
|---|---|---|
| `onChangeMarkdown` | `(markdown: string) => void` | Markdown output changed |
| `onChangeText` | `(text: string) => void` | Raw text changed |
| `onChangeSelection` | `(selection: { start, end }) => void` | Selection changed |
| `onChangeState` | `(state: EditorStyleState) => void` | Formatting state at cursor changed |
| `onFocus` | `() => void` | Editor focused |
| `onBlur` | `() => void` | Editor blurred |
| `onLinkDetected` | `(url: string) => void` | URL detected in text |
| `onMentionStart` | `(trigger: MentionTrigger) => void` | User typed a trigger character |
| `onMentionChange` | `(event: { query, trigger }) => void` | Keystroke after trigger |
| `onMentionEnd` | `(trigger: MentionTrigger) => void` | Mention cancelled |
| `onPaste` | `(event: OnPasteEvent) => void` | Paste payload before insertion; call `event.preventDefault()` to reject default insertion |

Pasted text is inserted automatically unless `preventDefault()` is called, and is parsed as markdown before entering the editor. Pasted images are emitted as `{ url, width, height }[]` and are not inserted into the editor content.

### `useMarkdownEditor()`

Convenience hook that returns a `ref` and stable callbacks for all editor commands.

```tsx
const editor = useMarkdownEditor()

// Pass the ref
<MarkdownEditor ref={editor.ref} />

// Call methods directly
editor.toggleBold()
editor.insertLink('https://example.com', 'Example')
```

**Returned methods:**

| Method | Description |
|---|---|
| `ref` | Ref to pass to `<MarkdownEditor>` |
| `focus()` | Focus the editor |
| `blur()` | Blur the editor |
| `setValue(markdown)` | Set editor content |
| `getMarkdown()` | Get current markdown (`Promise<string>`) |
| `setSelection(start, end)` | Set text selection range |
| `toggleBold()` | Toggle **bold** |
| `toggleItalic()` | Toggle *italic* |
| `toggleStrikethrough()` | Toggle ~~strikethrough~~ |
| `toggleCode()` | Toggle `inline code` |
| `toggleSuperscript()` | Toggle superscript |
| `toggleSpoiler()` | Toggle spoiler formatting |
| `toggleHeading(level)` | Toggle heading (1-6) |
| `toggleBlockquote()` | Toggle block quote |
| `toggleCodeBlock(language?)` | Toggle fenced code block |
| `toggleOrderedList()` | Toggle numbered list |
| `toggleUnorderedList()` | Toggle bullet list |
| `insertLink(url, text?)` | Insert a link |
| `removeLink()` | Remove link at cursor |
| `insertMention(trigger, label, props)` | Insert a mention |
| `insertSpoiler()` | Insert a spoiler block |
| `insertCustomTag(tag, props?)` | Insert a custom tag |

## Styling

The `style` prop on `<Markdown>` sets container styles and cascading text defaults. The `styles` prop targets individual elements.

```tsx
<Markdown
  style={{
    // Container
    padding: 16,
    backgroundColor: '#1a1a2e',
    // Cascading text defaults
    color: '#e0e0e0',
    fontSize: 15,
    lineHeight: 22,
    gap: 12,
  }}
  styles={{
    heading1: { fontSize: 28, fontWeight: '700', color: '#fff' },
    heading2: { fontSize: 22, fontWeight: '600', color: '#fff' },
    code: { fontFamily: 'Menlo', backgroundColor: 'rgba(255,255,255,0.1)' },
    codeBlock: {
      fontFamily: 'Menlo',
      backgroundColor: 'rgba(255,255,255,0.06)',
      padding: 12,
      borderRadius: 8,
    },
    blockquote: {
      borderLeftWidth: 3,
      borderLeftColor: '#A02F6F',
      paddingLeft: 12,
      backgroundColor: 'rgba(160,47,111,0.08)',
    },
    link: { color: '#6fa1f2' },
    strong: { color: '#fff' },
    image: { borderRadius: 8, maxHeight: 300 },
  }}
>
  {content}
</Markdown>
```

### Style types

| Key | Type | Applies to |
|---|---|---|
| `paragraph` | `MarkdownParagraphStyle` | Paragraph blocks |
| `heading1` - `heading6` | `MarkdownHeadingStyle` | Heading levels |
| `blockquote` | `MarkdownBlockquoteStyle` | Blockquotes (supports `gap`) |
| `codeBlock` | `MarkdownCodeBlockStyle` | Fenced code blocks |
| `list` | `MarkdownListStyle` | List container (supports `gap`) |
| `listItem` | `MarkdownListItemStyle` | Individual list items |
| `listBullet` | `MarkdownListBulletStyle` | Bullet/number markers |
| `image` | `MarkdownImageStyle` | Block images (`maxWidth`, `maxHeight`, `objectFit`) |
| `thematicBreak` | `MarkdownThematicBreakStyle` | Horizontal rules |
| `table` | `MarkdownTableStyle` | Table container |
| `tableRow` | `MarkdownTableRowStyle` | Table rows |
| `tableHeaderRow` | `MarkdownTableRowStyle` | Header row |
| `tableCell` | `MarkdownTableCellStyle` | Table cells |
| `tableHeaderCell` | `MarkdownTableCellStyle` | Header cells |
| `link` | `MarkdownLinkStyle` | Inline links |
| `code` | `MarkdownCodeStyle` | Inline code |
| `mentionUser` | `MarkdownMentionStyle` | @mentions |
| `mentionChannel` | `MarkdownMentionStyle` | #channels |
| `mentionCommand` | `MarkdownMentionStyle` | /commands |
| `strong` | `MarkdownStrongStyle` | Bold text |
| `emphasis` | `MarkdownEmphasisStyle` | Italic text |
| `strikethrough` | `MarkdownStrikethroughStyle` | Strikethrough text |
| `superscript` | `MarkdownSuperscriptStyle` | Superscript text |
| `spoiler` | `MarkdownSpoilerStyle` | Spoiler overlay (`backgroundColor`, `borderRadius`) |

## Event types

```typescript
interface LinkPressEvent {
  url: string
  title?: string
}

interface ImagePressEvent {
  url: string
  width: number
  height: number
}

interface MentionPressEvent {
  id: string
  name?: string
  type: 'user' | 'channel' | 'command'
  [key: string]: string | undefined // extra tag attributes
}

interface OnPasteEvent {
  readonly defaultPrevented: boolean
  text?: string
  images?: { url: string; height: number; width: number }[]
  preventDefault(): void
}

interface EditorStyleState {
  bold: boolean
  italic: boolean
  strikethrough: boolean
  code: boolean
  spoiler: boolean
  superscript: boolean
  blockquote: boolean
  codeBlock: boolean
  heading: number | null
  link: { url: string } | null
  list: 'ordered' | 'unordered' | null
}
```

## Supported syntax

### Renderer

| Syntax | Example |
|---|---|
| Headings | `# H1` through `###### H6` |
| Bold | `**bold**` |
| Italic | `*italic*` |
| Strikethrough | `~~deleted~~` |
| Links | `[text](url)` |
| Images | `![alt](url)` |
| Inline code | `` `code` `` |
| Code blocks | ```` ```lang ```` |
| Blockquotes | `> quote` |
| Ordered lists | `1. item` |
| Unordered lists | `- item` |
| Tables | GFM pipe tables |
| Horizontal rules | `---` |
| Autolinks | `https://example.com` |
| Spoilers | `||hidden||`, `>!hidden!<` |
| Superscript | `^word` or `^(words)` |
| Mentions | `<UserMention id="1" name="Ali" />`, `<ChannelMention id="1" name="general" />`, `<Command id="giphy" />` |

### Editor

The editor is a visual rich-text editor. It imports supported markdown into rich text, lets users edit the visual content, and exports markdown through `onChangeMarkdown`.

| Feature | Markdown/API |
|---|---|
| Headings | `# H1` through `###### H6`, `toggleHeading(level)` |
| Bold | `**bold**`, `toggleBold()` |
| Italic | `*italic*`, `toggleItalic()` |
| Strikethrough | `~~deleted~~`, `toggleStrikethrough()` |
| Spoilers | `||hidden||`, `toggleSpoiler()`, `insertSpoiler()` |
| Superscript | `^word` or `^(words)`, `toggleSuperscript()` |
| Mentions | `insertMention('@' \| '#' \| '/', label, props)` |
| Autolinks | `https://example.com` |
| Links | `[text](url)`, `insertLink(url, text?)`, `removeLink()` |
| Inline code | `` `code` ``, `toggleCode()` |
| Code blocks | Fenced code blocks, `toggleCodeBlock()` |
| Blockquotes | `> quote`, `toggleBlockquote()` |
| Ordered lists | `1. item`, `toggleOrderedList()` |
| Unordered lists | `- item`, `toggleUnorderedList()` |
| Paste | Markdown text is formatted on paste; images are emitted via `onPaste` |

Renderer-only syntax such as tables, block images, and horizontal rules is not currently editable inside `<MarkdownEditor>`.

## Sponsors

[<img alt="Duet" src="https://github.com/alizahid/react-native-fast-markdown/blob/main/.github/duet.png?raw=true" width="128">](https://duet.so)

## License

MIT
