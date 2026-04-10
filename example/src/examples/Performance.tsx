import { useMemo } from 'react'
import { FlatList, StyleSheet, Text, View } from 'react-native'
import { Markdown } from 'react-native-markdown'
import type { MarkdownStyle } from 'react-native-markdown'

const templates = [
  `**Message from user:** Hello everyone! Check out this [link](https://example.com). What do you think?`,

  `# Quick Update
We shipped the new feature today. Here's what changed:
- Improved performance
- Fixed the login bug
- Added dark mode`,

  `Here's some code I wrote:
\`\`\`js
const sum = (a, b) => a + b
\`\`\`
Pretty simple, right?`,

  `> "The only way to do great work is to love what you do."
> -- Steve Jobs`,

  `| Name | Role |
|------|------|
| Ali | Engineer |
| Sarah | Designer |`,

  `Things to do today:
- [x] Review PRs
- [x] Ship hotfix
- [ ] Write docs
- [ ] Plan sprint`,

  `Just a simple message with **bold** and *italic* and a mention <Mention user="Ali" />`,

  `Some inline \`code\` and a ~~strikethrough~~ word.

And a second paragraph with [another link](https://example.com).`,

  `### Heading Three
Normal paragraph text below the heading. This demonstrates how headings and paragraphs interact.`,

  `1. First ordered item
2. Second ordered item
3. Third ordered item

With a paragraph after the list.`,
]

function generateItems(count: number) {
  const items = []
  for (let i = 0; i < count; i++) {
    items.push({
      id: String(i),
      markdown: templates[i % templates.length]!,
      author: ['Ali', 'Sarah', 'James', 'Emma', 'Noah'][i % 5]!,
      time: `${Math.floor(Math.random() * 12) + 1}:${String(Math.floor(Math.random() * 60)).padStart(2, '0')} ${Math.random() > 0.5 ? 'AM' : 'PM'}`,
    })
  }
  return items
}

const markdownStyle: MarkdownStyle = {
  paragraph: { fontSize: 15, lineHeight: 22 },
  heading1: { fontSize: 20, fontWeight: 'bold' },
  heading2: { fontSize: 18, fontWeight: '600' },
  heading3: { fontSize: 16, fontWeight: '600' },
  code: { fontSize: 13, backgroundColor: '#f0f0f0' },
  codeBlock: { fontSize: 12, backgroundColor: '#f5f5f5', padding: 8, borderRadius: 6 },
}

function MessageItem({
  item,
}: {
  item: { id: string; markdown: string; author: string; time: string }
}) {
  return (
    <View style={styles.messageRow}>
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>
          {item.author.charAt(0)}
        </Text>
      </View>
      <View style={styles.messageBubble}>
        <View style={styles.messageHeader}>
          <Text style={styles.authorText}>{item.author}</Text>
          <Text style={styles.timeText}>{item.time}</Text>
        </View>
        <Markdown
          markdownStyle={markdownStyle}
          customTags={['Mention']}
        >
          {item.markdown}
        </Markdown>
      </View>
    </View>
  )
}

export function PerformanceScreen() {
  const data = useMemo(() => generateItems(500), [])

  return (
    <View style={styles.container}>
      <View style={styles.banner}>
        <Text style={styles.bannerText}>
          500 markdown messages in a FlatList
        </Text>
      </View>
      <FlatList
        data={data}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => <MessageItem item={item} />}
        initialNumToRender={10}
        maxToRenderPerBatch={5}
        windowSize={5}
        getItemLayout={undefined}
        contentContainerStyle={styles.listContent}
      />
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f2f2f7',
  },
  banner: {
    backgroundColor: '#007aff',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  bannerText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
    textAlign: 'center',
  },
  listContent: {
    padding: 12,
  },
  messageRow: {
    flexDirection: 'row',
    marginBottom: 12,
    alignItems: 'flex-start',
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#007aff',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
    marginTop: 2,
  },
  avatarText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
  messageBubble: {
    flex: 1,
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.04,
    shadowRadius: 2,
    elevation: 1,
  },
  messageHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  authorText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#111',
  },
  timeText: {
    fontSize: 12,
    color: '#999',
  },
})
