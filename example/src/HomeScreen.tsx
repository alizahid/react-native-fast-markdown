import { type NativeStackScreenProps } from '@react-navigation/native-stack'
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native'
import { type RootStackParamList } from './App'

type Props = NativeStackScreenProps<RootStackParamList, 'Home'>

const examples = [
  {
    key: 'BasicRenderer' as const,
    title: 'Basic Rendering',
    description: 'Headings, paragraphs, emphasis, links, images, code',
  },
  {
    key: 'GFMFeatures' as const,
    title: 'GFM Features',
    description: 'Tables, task lists, strikethrough, autolinks',
  },
  {
    key: 'CustomComponents' as const,
    title: 'Custom Components',
    description: 'Mentions, spoilers, and custom HTML-like tags',
  },
  {
    key: 'Styling' as const,
    title: 'Custom Styling',
    description: 'Themed markdown with custom fonts and colors',
  },
  {
    key: 'Editor' as const,
    title: 'Markdown Editor',
    description: 'Rich text editor with formatting toolbar',
  },
  {
    key: 'Performance' as const,
    title: 'Performance',
    description: 'Hundreds of markdown items in a scrollable list',
  },
]

export function HomeScreen({ navigation }: Props) {
  return (
    <FlatList
      contentContainerStyle={styles.list}
      data={examples}
      ItemSeparatorComponent={() => <View style={styles.separator} />}
      renderItem={({ item }) => (
        <Pressable
          onPress={() => navigation.navigate(item.key)}
          style={({ pressed }) => [styles.item, pressed && styles.itemPressed]}
        >
          <Text style={styles.title}>{item.title}</Text>
          <Text style={styles.description}>{item.description}</Text>
        </Pressable>
      )}
    />
  )
}

const styles = StyleSheet.create({
  list: {
    padding: 16,
  },
  separator: {
    height: 1,
    backgroundColor: '#e5e5e5',
  },
  item: {
    paddingVertical: 16,
    paddingHorizontal: 4,
  },
  itemPressed: {
    opacity: 0.6,
  },
  title: {
    fontSize: 17,
    fontWeight: '600',
    color: '#111',
  },
  description: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
})
