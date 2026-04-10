import { useCallback, useState } from 'react'
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native'
import { MarkdownInput, useMarkdownInput } from 'react-native-markdown'
import type { EditorStyleState } from 'react-native-markdown'

const initialMarkdown = `\
**Hello** *world*! This is a ~~demo~~ of the markdown editor.

Try selecting text and using the toolbar below.
`

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
      style={[styles.toolbarBtn, active && styles.toolbarBtnActive]}
      onPress={onPress}
    >
      <Text
        style={[
          styles.toolbarBtnText,
          active && styles.toolbarBtnTextActive,
        ]}
      >
        {label}
      </Text>
    </Pressable>
  )
}

export function EditorScreen() {
  const editor = useMarkdownInput()
  const [styleState, setStyleState] = useState<EditorStyleState>({
    bold: false,
    italic: false,
    strikethrough: false,
    underline: false,
    code: false,
    link: null,
    heading: null,
    list: null,
  })
  const [markdown, setMarkdown] = useState(initialMarkdown)

  const handleChangeState = useCallback(
    (state: EditorStyleState) => {
      setStyleState(state)
    },
    []
  )

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

  return (
    <View style={styles.container}>
      <ScrollView
        style={styles.editorContainer}
        contentContainerStyle={styles.editorContent}
        keyboardDismissMode="interactive"
      >
        <Text style={styles.label}>EDITOR</Text>
        <View style={styles.editorCard}>
          <MarkdownInput
            ref={editor.ref}
            defaultValue={initialMarkdown}
            placeholder="Type some markdown..."
            style={styles.input}
            onChangeState={handleChangeState}
            onChangeMarkdown={setMarkdown}
            autoFocus
          />
        </View>

        <Text style={styles.label}>PREVIEW</Text>
        <View style={styles.previewCard}>
          <Text style={styles.previewText}>{markdown}</Text>
        </View>
      </ScrollView>

      <View style={styles.toolbar}>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.toolbarContent}
        >
          <ToolbarButton
            label="B"
            active={styleState.bold}
            onPress={editor.toggleBold}
          />
          <ToolbarButton
            label="I"
            active={styleState.italic}
            onPress={editor.toggleItalic}
          />
          <ToolbarButton
            label="S"
            active={styleState.strikethrough}
            onPress={editor.toggleStrikethrough}
          />
          <ToolbarButton
            label="U"
            active={styleState.underline}
            onPress={editor.toggleUnderline}
          />
          <ToolbarButton
            label="<>"
            active={styleState.code}
            onPress={editor.toggleCode}
          />

          <View style={styles.toolbarSep} />

          <ToolbarButton
            label="H1"
            active={styleState.heading === 1}
            onPress={() => editor.toggleHeading(1)}
          />
          <ToolbarButton
            label="H2"
            active={styleState.heading === 2}
            onPress={() => editor.toggleHeading(2)}
          />
          <ToolbarButton
            label="H3"
            active={styleState.heading === 3}
            onPress={() => editor.toggleHeading(3)}
          />

          <View style={styles.toolbarSep} />

          <ToolbarButton
            label="UL"
            active={styleState.list === 'unordered'}
            onPress={editor.toggleUnorderedList}
          />
          <ToolbarButton
            label="OL"
            active={styleState.list === 'ordered'}
            onPress={editor.toggleOrderedList}
          />
          <ToolbarButton
            label="BQ"
            onPress={editor.toggleBlockquote}
          />
          <ToolbarButton
            label="Link"
            active={styleState.link !== null}
            onPress={handleInsertLink}
          />

          <View style={styles.toolbarSep} />

          <ToolbarButton
            label="@"
            onPress={() => editor.insertMention('Ali')}
          />
          <ToolbarButton
            label="Show MD"
            onPress={handleShowMarkdown}
          />
        </ScrollView>
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f2f2f7',
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
    fontSize: 16,
    lineHeight: 24,
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
  toolbar: {
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#e5e5e5',
    paddingBottom: 34, // safe area
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
})
