import { ScrollView, StyleSheet } from 'react-native';
import {
  FastMarkdownView,
  type MarkdownStyles,
} from 'react-native-fast-markdown';

const MARKDOWN = `# Fast Markdown

Paragraph with **bold**, _italic_, ~~strikethrough~~, and **bold _italic_ nested** runs.

## Links & mentions

Visit [the docs](https://example.com/docs) or ping [@ali](users://ali) in [#general](channels://general).

### Code & science

Inline \`const x = 42\` code. Water is H~2~O, area is x^2^ and reddit^style sup with ^(multi word groups) too.

#### Spoilers (styling lands in M6)

Both ||discord style|| and >!reddit style!< parse already.

---

## Blocks

> A block quote with **bold** and a nested paragraph.
>
> Second paragraph inside the quote.

- unordered item one with enough text to wrap onto a second line eventually
- item two with \`inline code\`
  - nested child item
  - another nested child
- item three

1. ordered one
2. ordered two
3. ordered three

\`\`\`ts
function reallyLongFunctionName(parameter: string, another: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 1000));
}
\`\`\``;

const styles: MarkdownStyles = {
  headings: {
    h1: { color: '#111827' },
    h2: { color: '#1D4ED8' },
    h3: { color: '#047857', fontWeight: '600' },
  },
  paragraph: { fontSize: 16, color: '#1F2937' },
  bold: { color: '#B91C1C' },
  italic: { color: '#7C3AED' },
  strikethrough: { color: '#9CA3AF' },
  link: {
    color: '#2563EB',
    textDecorationLine: 'underline',
  },
  mention: {
    fontWeight: '600',
    variants: {
      '^users://': { color: '#DB2777' },
      '^channels://': { color: '#059669' },
    },
  },
  inlineCode: {
    fontFamily: 'Courier',
    color: '#BE185D',
    backgroundColor: '#FDF2F8',
  },
  superscript: { color: '#EA580C' },
  subscript: { color: '#0284C7' },
};

export default function App() {
  return (
    <ScrollView style={sheet.container} contentInsetAdjustmentBehavior="automatic">
      <FastMarkdownView markdown={MARKDOWN} styles={styles} style={sheet.markdown} />
    </ScrollView>
  );
}

const sheet = StyleSheet.create({
  container: {
    flex: 1,
  },
  markdown: {
    padding: 16,
    gap: 12,
  },
});
