import { type StyleProp, Text, View, type ViewStyle } from "react-native";

import type { FastMarkdownViewProps } from "./types";

// Non-native (web) fallback: renders the raw markdown as plain text.
export function FastMarkdownView({
  allowFontScaling,
  markdown,
  style,
}: FastMarkdownViewProps) {
  return (
    <View style={style as StyleProp<ViewStyle>}>
      <Text allowFontScaling={allowFontScaling}>{markdown}</Text>
    </View>
  );
}
