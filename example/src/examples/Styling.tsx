import { ScrollView, StyleSheet, Text, View } from 'react-native'
import { Markdown } from 'react-native-markdown'
import type { MarkdownStyle } from 'react-native-markdown'

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
    fontSize: 16,
    lineHeight: 26,
  },
  heading1: {
    color: '#fff',
    fontSize: 30,
    fontWeight: 'bold',
  },
  heading2: {
    color: '#f0f0f0',
    fontSize: 24,
    fontWeight: '600',
  },
  strong: {
    color: '#fff',
    fontWeight: 'bold',
  },
  emphasis: {
    color: '#ccc',
    fontStyle: 'italic',
  },
  link: {
    color: '#6eb5ff',
  },
  code: {
    color: '#f8a4c8',
    backgroundColor: '#2a2a2a',
    fontFamily: 'Menlo',
    fontSize: 14,
  },
  codeBlock: {
    color: '#e0e0e0',
    backgroundColor: '#1e1e1e',
    fontFamily: 'Menlo',
    fontSize: 13,
    borderRadius: 8,
    padding: 16,
  },
  blockquote: {
    borderLeftColor: '#6eb5ff',
    borderLeftWidth: 4,
    color: '#aaa',
    fontStyle: 'italic',
  },
  listItem: {
    color: '#e0e0e0',
    fontSize: 16,
  },
  thematicBreak: {
    backgroundColor: '#444',
    height: 1,
    marginVertical: 20,
  },
}

const serifTheme: MarkdownStyle = {
  paragraph: {
    fontFamily: 'Georgia',
    fontSize: 18,
    lineHeight: 30,
    color: '#333',
  },
  heading1: {
    fontFamily: 'Georgia',
    fontSize: 36,
    fontWeight: 'bold',
    color: '#1a1a1a',
  },
  heading2: {
    fontFamily: 'Georgia',
    fontSize: 28,
    fontWeight: '600',
    color: '#222',
  },
  strong: {
    fontWeight: 'bold',
    color: '#000',
  },
  emphasis: {
    fontStyle: 'italic',
    color: '#555',
  },
  link: {
    color: '#8b0000',
  },
  code: {
    fontFamily: 'Courier',
    fontSize: 16,
    backgroundColor: '#f5f0e8',
    color: '#5c4033',
  },
  codeBlock: {
    fontFamily: 'Courier',
    fontSize: 15,
    backgroundColor: '#f5f0e8',
    color: '#5c4033',
    borderRadius: 4,
    padding: 16,
  },
  blockquote: {
    fontFamily: 'Georgia',
    fontStyle: 'italic',
    borderLeftColor: '#8b0000',
    borderLeftWidth: 3,
    color: '#666',
  },
  listItem: {
    fontFamily: 'Georgia',
    fontSize: 18,
    color: '#333',
  },
  thematicBreak: {
    backgroundColor: '#ccc',
    height: 1,
    marginVertical: 24,
  },
}

const compactTheme: MarkdownStyle = {
  paragraph: {
    fontSize: 13,
    lineHeight: 18,
    color: '#444',
  },
  heading1: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#111',
  },
  heading2: {
    fontSize: 17,
    fontWeight: '600',
    color: '#222',
  },
  strong: {
    fontWeight: '700',
  },
  code: {
    fontSize: 12,
    backgroundColor: '#eef',
    color: '#336',
  },
  codeBlock: {
    fontSize: 11,
    backgroundColor: '#f0f0ff',
    color: '#336',
    padding: 8,
    borderRadius: 4,
  },
  blockquote: {
    borderLeftColor: '#99f',
    borderLeftWidth: 2,
    fontSize: 13,
    color: '#666',
  },
  link: {
    color: '#2563eb',
  },
  listItem: {
    fontSize: 13,
  },
  thematicBreak: {
    backgroundColor: '#ddd',
    height: 1,
    marginVertical: 8,
  },
}

const themes: Array<{
  name: string
  style: MarkdownStyle
  background: string
}> = [
  { name: 'Default', style: defaultTheme, background: '#fff' },
  { name: 'Dark', style: darkTheme, background: '#121212' },
  { name: 'Serif', style: serifTheme, background: '#faf8f5' },
  { name: 'Compact', style: compactTheme, background: '#fff' },
]

export function StylingScreen() {
  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
    >
      {themes.map((theme) => (
        <View key={theme.name}>
          <Text style={styles.sectionLabel}>
            {theme.name.toUpperCase()}
          </Text>
          <View
            style={[
              styles.card,
              { backgroundColor: theme.background },
            ]}
          >
            <Markdown markdownStyle={theme.style}>
              {sampleMarkdown}
            </Markdown>
          </View>
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
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
})
