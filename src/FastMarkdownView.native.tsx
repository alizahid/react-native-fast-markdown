import { useMemo } from "react";
import type { NativeSyntheticEvent } from "react-native";

import NativeFastMarkdownView from "./FastMarkdownViewNativeComponent";
import {
  type MainStyle,
  serializeStyles,
  splitContainerStyle,
} from "./serializeStyles";
import type { FastMarkdownViewProps, MarkdownUrlEvent } from "./types";

export function FastMarkdownView({
  allowFontScaling,
  markdown,
  style,
  styles,
  images,
  onLinkPress,
  onLinkLongPress,
  onImagePress,
}: FastMarkdownViewProps) {
  const { hostStyle, main } = splitContainerStyle(style);

  const mainKey = JSON.stringify(main);
  const stylesJson = useMemo(
    () => serializeStyles(styles, JSON.parse(mainKey) as MainStyle),
    [styles, mainKey]
  );

  return (
    <NativeFastMarkdownView
      allowFontScaling={allowFontScaling}
      images={images}
      markdown={markdown}
      onImagePress={
        onImagePress
          ? (event: NativeSyntheticEvent<MarkdownUrlEvent>) =>
              onImagePress({ url: event.nativeEvent.url })
          : undefined
      }
      onLinkLongPress={
        onLinkLongPress
          ? (event: NativeSyntheticEvent<MarkdownUrlEvent>) =>
              onLinkLongPress({ url: event.nativeEvent.url })
          : undefined
      }
      onLinkPress={
        onLinkPress
          ? (event: NativeSyntheticEvent<MarkdownUrlEvent>) =>
              onLinkPress({ url: event.nativeEvent.url })
          : undefined
      }
      style={hostStyle}
      stylesJson={stylesJson}
    />
  );
}
