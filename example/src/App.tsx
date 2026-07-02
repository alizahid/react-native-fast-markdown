import { useState } from 'react';
import { Platform, Pressable, SafeAreaView, StatusBar, StyleSheet, Text, View } from 'react-native';

import { Feed } from './screens/Feed';
import { KitchenSink } from './screens/KitchenSink';
import { Playground } from './screens/Playground';

const TABS = ['Kitchen Sink', 'Playground', 'Feed'] as const;

type Tab = (typeof TABS)[number];

export default function App() {
  const [tab, setTab] = useState<Tab>('Kitchen Sink');

  return (
    <SafeAreaView style={sheet.container}>
      <View style={sheet.tabs}>
        {TABS.map((name) => (
          <Pressable
            key={name}
            style={[sheet.tab, tab === name && sheet.tabActive]}
            onPress={() => setTab(name)}
          >
            <Text style={tab === name ? sheet.tabTextActive : sheet.tabText}>
              {name}
            </Text>
          </Pressable>
        ))}
      </View>
      {tab === 'Kitchen Sink' && <KitchenSink />}
      {tab === 'Playground' && <Playground />}
      {tab === 'Feed' && <Feed />}
    </SafeAreaView>
  );
}

const sheet = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'white',
    paddingTop: Platform.OS === 'android' ? (StatusBar.currentHeight ?? 0) : 0,
  },
  tabs: {
    flexDirection: 'row',
    gap: 6,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  tab: {
    borderRadius: 8,
    backgroundColor: '#F3F4F6',
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  tabActive: {
    backgroundColor: '#111827',
  },
  tabText: {
    color: '#374151',
    fontSize: 13,
  },
  tabTextActive: {
    color: 'white',
    fontSize: 13,
  },
});
