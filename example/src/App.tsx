import { ScrollView, StyleSheet } from 'react-native';
import { FastMarkdownView } from 'react-native-fast-markdown';

const MARKDOWN = `# Fast Markdown

This is the first paragraph rendered natively on both platforms. It wraps across multiple lines when the text is long enough to exceed the available width.

## Inline styles

Text with **bold**, _italic_, and **bold with _italic_ inside** runs.

### Self-sizing

The view measures its own height on the Fabric layout thread, so this content determines the component frame with no JavaScript layout.

Short final paragraph.`;

export default function App() {
  return (
    <ScrollView style={styles.container} contentInsetAdjustmentBehavior="automatic">
      <FastMarkdownView markdown={MARKDOWN} style={styles.markdown} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  markdown: {
    padding: 16,
    gap: 12,
  },
});
