import { useMemo } from 'react'
import {
  Alert,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native'
import { Markdown, type MarkdownStyle } from 'react-native-fast-markdown'

const templates = [
  '**Message from user:** Hello everyone! Check out this [link](https://example.com). What do you think?',

  `# Quick Update
We shipped the new feature today. Here's what changed:
- Improved >!performance!<
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

  `| Name | Role |
|------|------|
| Lorem ipsum dolor sit amet, consectetur adipiscing elit | Quisque condimentum leo eu consequat pulvinar |
| In venenatis libero nec condimentum iaculis | Quisque sit amet enim at lorem dictum tempor at ac tortor |`,

  `Things to do today:
- [x] Review PRs
- [x] Ship [hotfix](https://alizahid.dev)
- [ ] Write docs
- [ ] Plan sprint`,

  `Just a simple message with **bold** and *italic* and a mention <UserMention id="u_ali" name="Ali" />`,

  `Some inline \`code\` and a ~~strikethrough~~ word.

And a second paragraph with [another link](https://example.com).`,

  `### Heading Three
Normal paragraph text below the heading. This demonstrates how headings and paragraphs interact.`,

  `1. First ordered item
2. Second ordered item
3. Third ordered item

With a paragraph after the list.`,
]

interface MessageItem {
  author: string
  id: string
  markdown: string
  time: string
}

const authors = ['Ali', 'Sarah', 'James', 'Emma', 'Noah']

function generateItems(count: number) {
  const items: Array<MessageItem> = []
  for (let i = 0; i < count; i++) {
    items.push({
      id: String(i),
      markdown: templates[i % templates.length] ?? '',
      author: authors[i % authors.length] ?? 'Unknown',
      time: `${Math.floor(Math.random() * 12) + 1}:${String(Math.floor(Math.random() * 60)).padStart(2, '0')} ${Math.random() > 0.5 ? 'AM' : 'PM'}`,
    })
  }
  return items
}

const markdownStyles: MarkdownStyle = {
  paragraph: { fontSize: 15, lineHeight: 22 },
  heading1: { fontSize: 20, fontWeight: 'bold' },
  heading2: { fontSize: 18, fontWeight: '600' },
  heading3: { fontSize: 16, fontWeight: '600' },
  code: { fontSize: 13, backgroundColor: '#f0f0f0' },
  codeBlock: {
    fontSize: 12,
    backgroundColor: '#f5f5f5',
    padding: 8,
    borderRadius: 6,
  },
}

function MessageRow({ item }: { item: MessageItem }) {
  return (
    <Pressable
      onPress={() => {
        Alert.alert('Item', JSON.stringify(item, null, 2))
      }}
      style={styles.messageRow}
    >
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>{item.author.charAt(0)}</Text>
      </View>
      <View style={styles.messageBubble}>
        <View style={styles.messageHeader}>
          <Text style={styles.authorText}>{item.author}</Text>
          <Text style={styles.timeText}>{item.time}</Text>
        </View>
        <Markdown customTags={['Mention']} styles={markdownStyles}>
          {item.markdown}
        </Markdown>
      </View>
    </Pressable>
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
        contentContainerStyle={styles.listContent}
        data={data}
        getItemLayout={undefined}
        initialNumToRender={10}
        keyExtractor={(item) => item.id}
        maxToRenderPerBatch={5}
        renderItem={({ item }) => <MessageRow item={item} />}
        windowSize={5}
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
