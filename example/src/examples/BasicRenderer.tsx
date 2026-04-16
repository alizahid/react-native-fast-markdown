import { Alert, ScrollView, StyleSheet } from 'react-native'
import { Markdown } from 'react-native-fast-markdown'

const basicMarkdown = `\
# Hello, Markdown!

This is a **bold** statement with *italic* emphasis and some ~~strikethrough~~ text.

## Reddit stuff

This line has >!spoilers!< inside it.

This line has ^superscript or ^(superscript with spaces) inside it.

## Links & Images

Here's a [link to GitHub](https://github.com) and an autolink: https://example.com

GIPHY

![](giphy|MDJ9IbxxvDUQM)

![](giphy|MDJ9IbxxvDUQM|downsized)

![](https://media.giphy.com/media/MDJ9IbxxvDUQM/giphy.gif)

Large image

![A placeholder image](https://picsum.photos/2000/2000)

Medium image

![A placeholder image](https://picsum.photos/600/300)

Small image

![A placeholder image](https://picsum.photos/100/100)

## Code

Inline code: \`console.log("hello")\`

\`\`\`typescript
function greet(name: string): string {
  return \`Hello, \${name}!\`
}

console.log(greet("World"))
\`\`\`

---

## Blockquotes

> "The best way to predict the future is to invent it."
>
> -- Alan Kay

## Lists

### Unordered

- First item
- Second item
  - Nested item
  - Another nested item
- Third item

### Ordered

1. Step one
2. Step two
3. Step three

---

That's the basics! Check out the other examples for more features.
`

export function BasicRendererScreen() {
  return (
    <ScrollView contentContainerStyle={styles.content} style={styles.container}>
      <Markdown
        onImagePress={(event) => {
          Alert.alert('Image', JSON.stringify(event, null, 2))
        }}
        onLinkPress={(event) => {
          Alert.alert('Link pressed', event.url)
        }}
      >
        {basicMarkdown}
      </Markdown>
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
})
