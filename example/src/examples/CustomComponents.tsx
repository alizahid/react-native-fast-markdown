import { Alert, ScrollView, StyleSheet, Text, View } from 'react-native'
import { Markdown } from 'react-native-markdown'

const mentionsMarkdown = `\
## Mentions

Hey <Mention user="Ali" />, have you seen the latest changes?

I think <Mention user="Sarah" /> and <Mention user="James" /> should review the PR.
`

const spoilersMarkdown = `\
## Spoilers

The movie ends with <Spoiler>the hero 😅 saving the world the hero 😅 saving the world the hero 😅 saving the world the hero 😅 saving the world</Spoiler> which was unexpected.

Here's a bigger spoiler:

<Spoiler>
The entire plot twist is that the narrator was unreliable the whole time.
None of the events actually happened as described.
</Spoiler>
`

const mixedMarkdown = `\
## Mixed Content

Here's a message with **bold text**, a [link](https://example.com), and a mention <Mention user="Ali" /> all in one paragraph.

> <Mention user="Sarah" /> said: "Check out <Spoiler>the secret feature</Spoiler> in the latest release!"

### Custom Tags in Lists

- Assigned to <Mention user="James" />
- Contains <Spoiler>hidden details</Spoiler>
- Regular list item with **formatting**
`

export function CustomComponentsScreen() {
  return (
    <ScrollView contentContainerStyle={styles.content} style={styles.container}>
      <Text style={styles.sectionLabel}>MENTIONS</Text>
      <View style={styles.card}>
        <Markdown
          customTags={['Mention', 'Spoiler']}
          onMentionPress={(event) => {
            Alert.alert('Mention pressed', `User: ${event.user}`)
          }}
        >
          {mentionsMarkdown}
        </Markdown>
      </View>

      <Text style={styles.sectionLabel}>SPOILERS</Text>
      <View style={styles.card}>
        <Markdown customTags={['Mention', 'Spoiler']}>
          {spoilersMarkdown}
        </Markdown>
      </View>

      <Text style={styles.sectionLabel}>MIXED CONTENT</Text>
      <View style={styles.card}>
        <Markdown
          customTags={['Mention', 'Spoiler']}
          onLinkPress={(event) => {
            Alert.alert('Link pressed', event.url)
          }}
          onMentionPress={(event) => {
            Alert.alert('Mention pressed', `User: ${event.user}`)
          }}
        >
          {mixedMarkdown}
        </Markdown>
      </View>
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
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
})
