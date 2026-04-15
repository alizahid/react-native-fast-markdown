import { useCallback, useMemo, useState } from 'react'
import {
  Alert,
  FlatList,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native'
import {
  type EditorStyleState,
  MarkdownEditor,
  type MentionTrigger,
  useMarkdownEditor,
} from 'react-native-fast-markdown'

const initialMarkdown = `\
**Hello** *world*! This is a ~~demo~~ of the markdown editor.

Try selecting text and using the toolbar below.
`

const mockUsers = [
  { id: 'u_james', name: 'James' },
  { id: 'u_sarah', name: 'Sarah' },
  { id: 'u_alex', name: 'Alex' },
  { id: 'u_emma', name: 'Emma' },
]

const mockChannels = [
  { id: 'c_general', name: 'general' },
  { id: 'c_random', name: 'random' },
  { id: 'c_dev', name: 'dev' },
]

const mockCommands = [
  { id: 'deploy', name: 'deploy' },
  { id: 'status', name: 'status' },
  { id: 'help', name: 'help' },
]

function ToolbarButton({
  label,
  active,
  onPress,
}: {
  label: string
  active?: boolean
  onPress: () => void
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[styles.toolbarBtn, active && styles.toolbarBtnActive]}
    >
      <Text
        style={[styles.toolbarBtnText, active && styles.toolbarBtnTextActive]}
      >
        {label}
      </Text>
    </Pressable>
  )
}

export function EditorScreen() {
  const editor = useMarkdownEditor()
  const [styleState, setStyleState] = useState<EditorStyleState>({
    bold: false,
    italic: false,
    strikethrough: false,
    code: false,
    link: null,
    heading: null,
    list: null,
  })
  const [markdown, setMarkdown] = useState(initialMarkdown)

  // Mention state
  const [mentionTrigger, setMentionTrigger] = useState<MentionTrigger | null>(
    null,
  )
  const [mentionQuery, setMentionQuery] = useState('')

  const handleChangeState = useCallback((state: EditorStyleState) => {
    setStyleState(state)
  }, [])

  const handleInsertLink = useCallback(() => {
    if (styleState.link) {
      editor.removeLink()
    } else {
      editor.insertLink('https://example.com', 'Example Link')
    }
  }, [editor, styleState.link])

  const handleShowMarkdown = useCallback(async () => {
    const md = await editor.getMarkdown()
    Alert.alert('Markdown Output', md || '(empty)')
  }, [editor])

  // Mention suggestions
  const suggestions = useMemo(() => {
    if (!mentionTrigger) {
      return []
    }

    const query = mentionQuery.toLowerCase()
    let items: Array<{ id: string; name: string }> = []

    if (mentionTrigger === '@') {
      items = mockUsers
    } else if (mentionTrigger === '#') {
      items = mockChannels
    } else if (mentionTrigger === '/') {
      items = mockCommands
    }

    if (query.length === 0) {
      return items
    }

    return items.filter((item) => item.name.toLowerCase().includes(query))
  }, [mentionTrigger, mentionQuery])

  const handleSelectMention = useCallback(
    (item: { id: string; name: string }) => {
      if (!mentionTrigger) {
        return
      }

      editor.insertMention(mentionTrigger, item.name, {
        id: item.id,
        name: item.name,
      })
      setMentionTrigger(null)
      setMentionQuery('')
    },
    [editor, mentionTrigger],
  )

  return (
    <View style={styles.container}>
      <View style={styles.toolbar}>
        <ScrollView
          contentContainerStyle={styles.toolbarContent}
          horizontal
          showsHorizontalScrollIndicator={false}
        >
          <ToolbarButton
            active={styleState.bold}
            label="B"
            onPress={editor.toggleBold}
          />
          <ToolbarButton
            active={styleState.italic}
            label="I"
            onPress={editor.toggleItalic}
          />
          <ToolbarButton
            active={styleState.strikethrough}
            label="S"
            onPress={editor.toggleStrikethrough}
          />
          <ToolbarButton
            active={styleState.code}
            label="`"
            onPress={editor.toggleCode}
          />

          <View style={styles.toolbarSep} />

          <ToolbarButton
            active={styleState.heading === 1}
            label="H1"
            onPress={() => editor.toggleHeading(1)}
          />
          <ToolbarButton
            active={styleState.heading === 2}
            label="H2"
            onPress={() => editor.toggleHeading(2)}
          />
          <ToolbarButton
            active={styleState.heading === 3}
            label="H3"
            onPress={() => editor.toggleHeading(3)}
          />

          <View style={styles.toolbarSep} />

          <ToolbarButton
            active={styleState.list === 'unordered'}
            label="UL"
            onPress={editor.toggleUnorderedList}
          />
          <ToolbarButton
            active={styleState.list === 'ordered'}
            label="OL"
            onPress={editor.toggleOrderedList}
          />
          <ToolbarButton
            active={styleState.link !== null}
            label="Link"
            onPress={handleInsertLink}
          />

          <View style={styles.toolbarSep} />

          <ToolbarButton label="Show MD" onPress={handleShowMarkdown} />
        </ScrollView>
      </View>

      <ScrollView
        contentContainerStyle={styles.editorContent}
        keyboardDismissMode="interactive"
        style={styles.editorContainer}
      >
        <Text style={styles.label}>EDITOR</Text>
        <View style={styles.editorCard}>
          <MarkdownEditor
            autoCapitalize="none"
            autoCorrect={false}
            autoFocus
            defaultValue={initialMarkdown}
            mentionTriggers={['@', '#', '/']}
            onChangeMarkdown={setMarkdown}
            onChangeState={handleChangeState}
            onMentionChange={({ trigger, query }) => {
              setMentionTrigger(trigger)
              setMentionQuery(query)
            }}
            onMentionEnd={() => {
              setMentionTrigger(null)
              setMentionQuery('')
            }}
            onMentionStart={(trigger) => {
              setMentionTrigger(trigger)
              setMentionQuery('')
            }}
            placeholder="Type some markdown..."
            ref={editor.ref}
            style={styles.input}
          />

          {mentionTrigger && suggestions.length > 0 && (
            <View style={styles.suggestionsContainer}>
              <FlatList
                data={suggestions}
                keyboardShouldPersistTaps="always"
                keyExtractor={(item) => item.id}
                renderItem={({ item }) => (
                  <Pressable
                    onPress={() => handleSelectMention(item)}
                    style={styles.suggestionItem}
                  >
                    <Text style={styles.suggestionTrigger}>
                      {mentionTrigger}
                    </Text>
                    <Text style={styles.suggestionText}>{item.name}</Text>
                  </Pressable>
                )}
              />
            </View>
          )}
        </View>

        <Text style={styles.label}>PREVIEW</Text>
        <View style={styles.previewCard}>
          <Text style={styles.previewText}>{markdown}</Text>
        </View>
      </ScrollView>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f2f2f7',
  },
  toolbar: {
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e5e5e5',
  },
  toolbarContent: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 6,
  },
  toolbarSep: {
    width: 1,
    backgroundColor: '#e5e5e5',
    marginHorizontal: 4,
  },
  toolbarBtn: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    backgroundColor: '#f2f2f7',
  },
  toolbarBtnActive: {
    backgroundColor: '#007aff',
  },
  toolbarBtnText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
  },
  toolbarBtnTextActive: {
    color: '#fff',
  },
  editorContainer: {
    flex: 1,
  },
  editorContent: {
    padding: 16,
    paddingBottom: 32,
  },
  label: {
    fontSize: 13,
    fontWeight: '600',
    color: '#666',
    marginBottom: 8,
    marginTop: 16,
    marginLeft: 4,
  },
  editorCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  input: {
    minHeight: 180,
    padding: 16,
  },
  suggestionsContainer: {
    borderTopWidth: 1,
    borderTopColor: '#e5e5e5',
    maxHeight: 160,
  },
  suggestionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    gap: 4,
  },
  suggestionTrigger: {
    fontSize: 14,
    color: '#999',
  },
  suggestionText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#333',
  },
  previewCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  previewText: {
    fontSize: 13,
    fontFamily: 'Menlo',
    color: '#555',
    lineHeight: 20,
  },
})
