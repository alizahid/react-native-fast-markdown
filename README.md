# react-native-fast-markdown

Fast, fully native markdown viewer for React Native (iOS + Android, New Architecture).

- **One native Fabric view** — markdown is parsed natively with [md4c](https://github.com/mity/md4c) and rendered as attributed text (TextKit on iOS, StaticLayout/Spannable on Android). No WebView, no JS-side layout, no nested `<Text>` trees.
- **Self-sizing** — the component measures its own height on the Fabric layout thread with a custom C++ shadow node, so it behaves like `<Text>` in any layout, list, or scroll view.
- **Built for lists** — parse and layout results are cached and shared between measurement and mounting; views recycle cleanly in FlatList / FlashList / LegendList.
- **Deeply styleable** — a typed, per-element styles API with cascading text styles, box styles, and regex-based mention variants.

## Supported markdown

Headings, paragraphs, images, GFM tables (horizontal scroll with intelligently sized columns), spoilers (Reddit `>!text!<` **and** Discord `||text||`), superscript (`^sup^`, Reddit `^word` and `^(multi word)`), subscript (`~sub~`), bold / italic / strikethrough, ordered + unordered lists (nested), links, mentions, inline code, code blocks (horizontally scrolling, monospace), block quotes, and thematic breaks.

## Installation

```sh
npm install react-native-fast-markdown
cd ios && pod install
```

Requires React Native 0.86+ with the New Architecture (Fabric).

## Usage

```tsx
import { FastMarkdownView, type MarkdownStyles } from 'react-native-fast-markdown';

const styles: MarkdownStyles = {
  paragraph: { fontSize: 16, color: '#1F2937' },
  link: { color: '#2563EB', textDecorationLine: 'underline' },
  mention: {
    fontWeight: '600',
    variants: {
      '^users://': { color: '#DB2777' },
      '^channels://': { color: '#059669' },
    },
  },
  spoiler: { backgroundColor: '#374151', borderRadius: 4 },
};

<FastMarkdownView
  markdown={'Hello **world**, ping [@ali](users://ali)!'}
  styles={styles}
  style={{ padding: 16, gap: 12 }}
  onLinkPress={({ url }) => Linking.openURL(url)}
/>;
```

## Props

| Prop | Type | Description |
| --- | --- | --- |
| `markdown` | `string` | The markdown source. |
| `style` | `MarkdownContainerStyle` | Main container style: `backgroundColor`, `padding`/`padding{Left,Right,Top,Bottom}`, `gap` (spacing between blocks), plus base text styles (`fontSize`, `fontWeight`, `fontFamily`, `color`, `fontVariant`, `textDecoration*`) that cascade into every text element unless overridden per-element via `styles`. Element builtins survive the cascade: heading sizes/weight stay unless `headings.hN` overrides, and code blocks keep their monospace font unless `codeBlock` overrides. For outer layout (margin, width, flex), wrap the viewer in a `View`. |
| `styles` | `MarkdownStyles` | Per-element styles (below). Hoist to module scope or memoize. |
| `images` | `{ url, width, height }[]` | Pre-sizing data. Listed images lay out at their final size immediately — zero layout shift. Unlisted images render a styled 100×100 placeholder, then grow when loaded. |
| `onLinkPress` | `({ url }) => void` | Link or mention tapped. Mentions arrive with their scheme (e.g. `users://ali`). |
| `onLinkLongPress` | `({ url }) => void` | Link long-pressed. |
| `onImagePress` | `({ url }) => void` | Image tapped. |

## Styling

Two shared shapes compose every element style:

**Text** — `fontSize`, `fontWeight`, `fontFamily`, `color`, `fontVariant`, `textDecorationColor`, `textDecorationLine`, `textDecorationStyle`

**Layout** — `backgroundColor`, `padding` (+ per-side), `borderRadius`, `borderCurve` (iOS), `borderColor`/`borderWidth` (+ per-side)

| Key | Accepts | Notes |
| --- | --- | --- |
| `headings.h1`–`h6` | text | Defaults: 32/26/22/18/16/14, bold. Do **not** inherit `paragraph`. |
| `paragraph` | text | Base for body text; inline styles cascade on top. |
| `bold`, `italic`, `strikethrough` | text | |
| `link` | text | Default: system blue. |
| `mention` | text + `variants` | `variants` maps a regex (tested against the link URL, longest pattern first) to a style. A link matching any variant is a mention. |
| `inlineCode` | text + `backgroundColor`, `borderRadius`, `padding(Left/Right)` | Default: monospace on 8% black. |
| `superscript`, `subscript` | text | Default: 0.7x size with baseline shift. |
| `spoiler` | `backgroundColor`, `borderRadius`, `borderCurve` | The tap-to-reveal cover — one contiguous polygon even across line wraps. |
| `codeBlock` | text + layout | Default: monospace 14, 8% black, radius 6, padding 12. Long lines scroll horizontally. |
| `blockQuote` | text + layout | Text styles cascade into quoted content. Default: 3pt left border. |
| `list` | `marginLeft` | |
| `listMarker` | `width`, `marginLeft`, `color` | Fixed-width marker column (default 24). |
| `listItem` | text | Cascades into item content. |
| `image` | `borderRadius`, `backgroundColor`, `height`, `maxHeight` | `backgroundColor` shows while loading. |
| `table` | layout + `minColumnWidth`, `maxColumnWidth` | Column widths clamp to `[44, 320]` by default. |
| `tableRow` | layout | Default: 1pt bottom-border separator. |
| `tableCell` | text + `padding*` | Header cells default bold. |

### Tables

Each column gets its natural (unwrapped) width, clamped to `[minColumnWidth, maxColumnWidth]`. If the table fits the container, the surplus is distributed proportionally so it fills the line; if not, columns keep their readable widths and the table scrolls horizontally.

### Mentions

Mentions are plain markdown links with custom schemes — `[@ali](users://ali)`, `[#general](channels://general)` — classified by the `mention.variants` regexes and styled accordingly. Presses arrive through `onLinkPress`; branch on the URL scheme.

## Using in lists

Rendering hundreds of viewers in FlatList / FlashList / LegendList is a first-class use case:

- Hoist `styles` (and `images` when static) to module scope — every item then shares one parsed native style config.
- Parse + layout are cached natively and computed on the Fabric layout thread, so scrolling never parses markdown on the main thread.
- Views reset correctly when recycled, and in-flight image requests are owned by URL, not by views.
- Wrapping items in `Pressable` works: taps on links, mentions, and spoilers are claimed by the markdown view; taps on plain text reach your `Pressable`.

```tsx
const renderItem = ({ item }) => (
  <Pressable onPress={() => openPost(item)}>
    <FastMarkdownView markdown={item.body} styles={styles} onLinkPress={openLink} />
  </Pressable>
);
```

## Platform notes & limitations

- New Architecture (Fabric) only; React Native 0.86+.
- `textDecorationStyle`/`textDecorationColor` render fully on iOS; Android draws plain underline/strikethrough.
- `borderCurve: 'continuous'` is iOS-only.
- `fontVariant` supports `tabular-nums`, `proportional-nums`, `oldstyle-nums`, `lining-nums`, `small-caps` (font support required).
- Font scaling (`allowFontScaling`) is not applied yet; text renders at the sizes you specify.
- Spoilers and inline formatting inside link labels stay literal; spoilers inside table cells are unsupported (the `|` delimiter conflicts).
- Code blocks render plain monospace (no syntax highlighting).

## License

MIT
