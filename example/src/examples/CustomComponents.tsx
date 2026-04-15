import { Alert, ScrollView, StyleSheet, Text, View } from 'react-native'
import { Markdown } from 'react-native-fast-markdown'

const mentionsMarkdown = `\
## Mentions

Hey <UserMention id="u_ali" name="Ali" foo="123" />, have you seen the latest changes in <ChannelMention id="c_release" name="release" />?

I think <UserMention id="u_sarah" name="Sarah" /> and <UserMention id="u_james" name="James" /> should review the PR. Try <Command id="review" /> to request a review.
`

const spoilersMarkdown = `\
## Spoilers

The movie ends with <Spoiler>the hero saving the world</Spoiler> which was unexpected.

Here's a bigger spoiler:

<Spoiler>
The entire plot twist is that the narrator was unreliable the whole time. None of the events actually happened as described.
</Spoiler>
`

const mixedMarkdown = `\
## Mixed Content

Here's a message with **bold text**, a [link](https://example.com), and a mention <UserMention id="u_ali" name="Ali" /> all in one paragraph.

> <UserMention id="u_sarah" name="Sarah" /> said: "Check out <Spoiler>the secret feature</Spoiler> in the latest release!"

### Custom Tags in Lists

- Assigned to <UserMention id="u_james" name="James" />
- Post in <ChannelMention id="c_general" name="general" />
- Run <Command id="deploy" />
- Contains <Spoiler>hidden details</Spoiler>
`

export function CustomComponentsScreen() {
  return (
    <ScrollView contentContainerStyle={styles.content} style={styles.container}>
      <Text style={styles.sectionLabel}>MENTIONS</Text>
      <View style={styles.card}>
        <Markdown
          onMentionPress={(event) => {
            Alert.alert('Mention pressed', JSON.stringify(event, null, 2))
          }}
        >
          {mentionsMarkdown}
        </Markdown>
      </View>

      <Text style={styles.sectionLabel}>SPOILERS</Text>
      <View style={styles.card}>
        <Markdown>{spoilersMarkdown}</Markdown>
      </View>

      <Text style={styles.sectionLabel}>MIXED CONTENT</Text>
      <View style={styles.card}>
        <Markdown
          onLinkPress={(event) => {
            Alert.alert('Link pressed', event.url)
          }}
          onMentionPress={(event) => {
            Alert.alert('Mention pressed', JSON.stringify(event, null, 2))
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
