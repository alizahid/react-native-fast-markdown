import { ScrollView, StyleSheet, Text, View } from 'react-native'
import {
  Markdown,
  type MarkdownBaseStyle,
  type MarkdownStyle,
} from 'react-native-markdown'

const sampleMarkdown = `\
# Styled Heading

This is a paragraph with **bold**, *italic*, and ~~strikethrough~~ text.

> A blockquote with a different style.

\`inline code\` looks different too.

\`\`\`
code block with
custom styling
\`\`\`

- List item one
- List item two
- List item three

[A styled link](https://example.com)

---

End of sample.
`

const defaultTheme: MarkdownStyle = {}

const darkTheme: MarkdownStyle = {
  paragraph: {
    color: '#e0e0e0',
  },
  heading1: {
    color: '#fff',
  },
  heading2: {
    color: '#f0f0f0',
  },
  strong: {
    color: '#fff',
  },
  emphasis: {
    color: '#ccc',
  },
  link: {
    color: '#6eb5ff',
  },
  code: {
    color: '#f8a4c8',
    backgroundColor: '#2a2a2a',
  },
  codeBlock: {
    color: '#e0e0e0',
    backgroundColor: '#1e1e1e',
  },
  blockquote: {
    backgroundColor: '#1e1e1e',
    borderLeftColor: '#6eb5ff',
    color: '#aaa',
  },
  listItem: {
    color: '#e0e0e0',
  },
  thematicBreak: {
    backgroundColor: '#444',
  },
}

const serifTheme: MarkdownStyle = {
  paragraph: {
    color: '#333',
  },
  heading1: {
    color: '#1a1a1a',
  },
  heading2: {
    color: '#222',
  },
  strong: {
    color: '#000',
  },
  emphasis: {
    color: '#555',
  },
  link: {
    color: '#8b0000',
  },
  code: {
    backgroundColor: '#f5f0e8',
    color: '#5c4033',
  },
  codeBlock: {
    backgroundColor: '#f5f0e8',
    color: '#5c4033',
  },
  blockquote: {
    borderLeftColor: '#8b0000',
    color: '#666',
  },
  listItem: {
    color: '#333',
  },
  thematicBreak: {
    backgroundColor: '#ccc',
  },
}

const themes: Array<{
  name: string
  styles: MarkdownStyle
  style?: MarkdownBaseStyle
}> = [
  {
    name: 'Default',
    styles: defaultTheme,
    style: {
      backgroundColor: '#fff',
    },
  },
  {
    name: 'Dark',
    styles: darkTheme,
    style: {
      backgroundColor: '#121212',
      color: 'rgb(206, 205, 195)',
    },
  },
  {
    name: 'Serif',
    styles: serifTheme,
    style: {
      backgroundColor: '#faf8f5',
    },
  },
]

export function StylingScreen() {
  return (
    <ScrollView contentContainerStyle={styles.content} style={styles.container}>
      {themes.map((theme) => (
        <View key={theme.name}>
          <Text style={styles.sectionLabel}>{theme.name.toUpperCase()}</Text>

          <Markdown style={[styles.card, theme.style]} styles={theme.styles}>
            {sampleMarkdown}
          </Markdown>
        </View>
      ))}
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f2f2f7',
  },
  content: {
    padding: 16,
    paddingBottom: 48,
  },
  sectionLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#666',
    marginBottom: 8,
    marginTop: 16,
    marginLeft: 4,
  },
  card: {
    borderRadius: 12,
    padding: 16,
  },
})
