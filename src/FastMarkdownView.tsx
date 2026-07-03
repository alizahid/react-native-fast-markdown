import {
  Text,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import type { FastMarkdownViewProps } from './types';

// Non-native (web) fallback: renders the raw markdown as plain text.
export function FastMarkdownView({ markdown, style }: FastMarkdownViewProps) {
  return (
    <View style={style as StyleProp<ViewStyle>}>
      <Text>{markdown}</Text>
    </View>
  );
}
