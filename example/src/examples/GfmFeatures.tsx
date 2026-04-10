import { Alert, ScrollView, StyleSheet, View } from 'react-native'
import { Markdown } from 'react-native-markdown'

const tablesMarkdown = `\
## Tables

| Feature | iOS | Android |
|---------|:---:|:-------:|
| Renderer | Yes | Yes |
| Editor | Yes | Yes |
| Custom Tags | Yes | Yes |
| Tables | Yes | Yes |

### Right-aligned columns

| Name | Stars | Language |
|:-----|------:|:--------:|
| React Native | 120k | JavaScript |
| Flutter | 165k | Dart |
| SwiftUI | N/A | Swift |
`

const taskListMarkdown = `\
## Task Lists

- [x] Set up project structure
- [x] Implement markdown parser with md4c
- [x] Create native renderers
- [ ] Add syntax highlighting
- [ ] Write documentation
- [ ] Publish to npm
`

const autolinksMarkdown = `\
## Autolinks

URLs are automatically detected:

- https://github.com/alizahid/react-native-markdown
- www.example.com
- hello@example.com

Plain text with a link in the middle: visit https://example.com for more info.
`

const strikethroughMarkdown = `\
## Strikethrough

This text has ~~deleted words~~ in it.

~~Entire paragraph struck through.~~

Mix it with **bold ~~and struck~~** text.
`

export function GFMFeaturesScreen() {
  return (
    <ScrollView contentContainerStyle={styles.content} style={styles.container}>
      <Markdown>{tablesMarkdown}</Markdown>

      <View style={styles.divider} />

      <Markdown
        onTaskListItemPress={(event) => {
          Alert.alert(
            'Task toggled',
            `Item ${event.index}: ${event.checked ? 'checked' : 'unchecked'}`,
          )
        }}
      >
        {taskListMarkdown}
      </Markdown>

      <View style={styles.divider} />

      <Markdown
        onLinkPress={(event) => {
          Alert.alert('Autolink pressed', event.url)
        }}
      >
        {autolinksMarkdown}
      </Markdown>

      <View style={styles.divider} />

      <Markdown>{strikethroughMarkdown}</Markdown>
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  content: {
    padding: 16,
  },
  divider: {
    height: 1,
    backgroundColor: '#e5e5e5',
    marginVertical: 24,
  },
})
