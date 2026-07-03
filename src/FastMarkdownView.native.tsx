import { useMemo } from 'react';
import { StyleSheet, type NativeSyntheticEvent } from 'react-native';

import NativeFastMarkdownView from './FastMarkdownViewNativeComponent';
import { serializeStyles, type MainStyle } from './serializeStyles';
import type { FastMarkdownViewProps, MarkdownUrlEvent } from './types';

const MAIN_STYLE_KEYS = [
  'backgroundColor',
  'padding',
  'paddingLeft',
  'paddingRight',
  'paddingTop',
  'paddingBottom',
  'gap',
  // Base text styles: cascade into every text element via stylesJson.
  'fontSize',
  'fontWeight',
  'fontFamily',
  'color',
  'fontVariant',
  'textDecorationColor',
  'textDecorationLine',
  'textDecorationStyle',
] as const;

export function FastMarkdownView({
  markdown,
  style,
  styles,
  images,
  onLinkPress,
  onLinkLongPress,
  onImagePress,
}: FastMarkdownViewProps) {
  const flattened = StyleSheet.flatten(style) ?? {};

  // Content-affecting keys are measured natively, so they travel in
  // stylesJson; the remaining view styles pass through to the host view.
  const main: MainStyle = {};
  const hostStyle: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(flattened)) {
    if ((MAIN_STYLE_KEYS as readonly string[]).includes(key)) {
      main[key as keyof MainStyle] = value as never;
    } else {
      hostStyle[key] = value;
    }
  }

  const mainKey = JSON.stringify(main);
  const stylesJson = useMemo(
    () => serializeStyles(styles, JSON.parse(mainKey) as MainStyle),
    [styles, mainKey]
  );

  return (
    <NativeFastMarkdownView
      markdown={markdown}
      stylesJson={stylesJson}
      images={images}
      style={hostStyle}
      onLinkPress={
        onLinkPress
          ? (event: NativeSyntheticEvent<MarkdownUrlEvent>) =>
              onLinkPress({ url: event.nativeEvent.url })
          : undefined
      }
      onLinkLongPress={
        onLinkLongPress
          ? (event: NativeSyntheticEvent<MarkdownUrlEvent>) =>
              onLinkLongPress({ url: event.nativeEvent.url })
          : undefined
      }
      onImagePress={
        onImagePress
          ? (event: NativeSyntheticEvent<MarkdownUrlEvent>) =>
              onImagePress({ url: event.nativeEvent.url })
          : undefined
      }
    />
  );
}
