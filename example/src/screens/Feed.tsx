import { useCallback, useState } from 'react';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';
import {
  FastMarkdownView,
  type MarkdownStyles,
} from 'react-native-fast-markdown';

// Hoisted per the FlashList/FlatList recipe: one styles object shared by
// every item so the native style config is parsed exactly once.
const styles: MarkdownStyles = {
  paragraph: { fontSize: 15, color: '#1F2937' },
  headings: { h2: { fontSize: 20, color: '#111827' } },
  link: { color: '#2563EB', textDecorationLine: 'underline' },
  mention: {
    fontWeight: '600',
    variants: {
      '^users://': { color: '#DB2777' },
      '^channels://': { color: '#059669' },
    },
  },
  inlineCode: { backgroundColor: '#F3F4F6', color: '#BE185D' },
  spoiler: { backgroundColor: '#374151', borderRadius: 4 },
  listItem: { fontSize: 15, color: '#1F2937' },
};

interface Post {
  id: string;
  markdown: string;
}

const SNIPPETS = [
  'Shipped a new build today. **Huge** improvement to startup time — thanks [@ali](users://ali)!',
  '## Release notes\n\n- faster parser\n- fixed `inline code` rendering\n- better spoilers: ||surprise||',
  'Does anyone know why `useMemo` re-runs here? See [the docs](https://reactjs.org) or ask in [#help](channels://help).',
  'Water is H~2~O and energy is E = mc^2 — physics^(still cool) in a feed cell.',
  '> The best way to predict the future is to invent it.\n\nClassic quote via [#quotes](channels://quotes).',
  'Long paragraph that wraps across multiple lines to give the recycler some variety in cell heights when scrolling quickly through the feed. It keeps going for a while so the measurement cache earns its keep.',
  '1. first\n2. second\n3. third\n\nOrdered lists inside a recycled cell.',
  'Mixed **bold**, _italic_, ~~strike~~, and a spoiler >!hidden in a card!< for testing.',
];

const POSTS: Post[] = Array.from({ length: 250 }, (_, index) => ({
  id: String(index),
  markdown: `**Post #${index + 1}**\n\n${SNIPPETS[index % SNIPPETS.length]}`,
}));

export function Feed() {
  const [lastPress, setLastPress] = useState('none yet');

  // Cards are wrapped in Pressable: taps on plain text hit the card, taps
  // on links/mentions/spoilers are claimed by the markdown view.
  const renderItem = useCallback(
    ({ item }: { item: Post }) => (
      <Pressable
        style={({ pressed }) => [sheet.card, pressed && sheet.cardPressed]}
        onPress={() => setLastPress(`card #${Number(item.id) + 1}`)}
      >
        <FastMarkdownView
          markdown={item.markdown}
          styles={styles}
          style={sheet.markdown}
          onLinkPress={({ url }) => setLastPress(`link ${url}`)}
        />
      </Pressable>
    ),
    []
  );

  return (
    <View style={sheet.container}>
      <View style={sheet.header}>
        <Text style={sheet.headerText}>last press: {lastPress}</Text>
      </View>
      <FlatList
        data={POSTS}
        keyExtractor={(item) => item.id}
        renderItem={renderItem}
        contentContainerStyle={sheet.list}
      />
    </View>
  );
}

const sheet = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F3F4F6',
  },
  header: {
    backgroundColor: '#111827',
    padding: 8,
  },
  headerText: {
    color: '#F9FAFB',
    fontSize: 12,
  },
  list: {
    gap: 10,
    padding: 12,
  },
  card: {
    backgroundColor: 'white',
    borderRadius: 12,
    elevation: 1,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.08,
    shadowRadius: 3,
  },
  cardPressed: {
    backgroundColor: '#EFF6FF',
  },
  markdown: {
    padding: 14,
    gap: 8,
  },
});
