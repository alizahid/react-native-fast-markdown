import type { ColorValue, StyleProp, ViewStyle } from 'react-native';

export type FontVariant =
  | 'small-caps'
  | 'oldstyle-nums'
  | 'lining-nums'
  | 'tabular-nums'
  | 'proportional-nums'
  | 'stylistic-one'
  | 'stylistic-two'
  | 'stylistic-three'
  | 'stylistic-four'
  | 'stylistic-five'
  | 'stylistic-six'
  | 'stylistic-seven'
  | 'stylistic-eight'
  | 'stylistic-nine'
  | 'stylistic-ten'
  | 'stylistic-eleven'
  | 'stylistic-twelve'
  | 'stylistic-thirteen'
  | 'stylistic-fourteen'
  | 'stylistic-fifteen'
  | 'stylistic-sixteen'
  | 'stylistic-seventeen'
  | 'stylistic-eighteen'
  | 'stylistic-nineteen'
  | 'stylistic-twenty';

export type FontWeight =
  | 'normal'
  | 'bold'
  | '100'
  | '200'
  | '300'
  | '400'
  | '500'
  | '600'
  | '700'
  | '800'
  | '900'
  | 100
  | 200
  | 300
  | 400
  | 500
  | 600
  | 700
  | 800
  | 900;

/**
 * Text styling shared by every text-bearing markdown element.
 */
export interface MarkdownTextStyle {
  fontSize?: number;
  fontWeight?: FontWeight;
  fontFamily?: string;
  color?: ColorValue;
  fontVariant?: FontVariant[];
  textDecorationColor?: ColorValue;
  /**
   * Android renders `underline` and `line-through` natively; decoration
   * color/style on Android are drawn for links and mentions, best-effort
   * elsewhere.
   */
  textDecorationLine?:
    | 'none'
    | 'underline'
    | 'line-through'
    | 'underline line-through';
  textDecorationStyle?: 'solid' | 'double' | 'dotted' | 'dashed';
}

/**
 * Box styling shared by every block-level markdown element.
 */
export interface MarkdownLayoutStyle {
  backgroundColor?: ColorValue;
  padding?: number;
  paddingLeft?: number;
  paddingRight?: number;
  paddingTop?: number;
  paddingBottom?: number;
  borderRadius?: number;
  /** iOS only; Android always renders circular corners. */
  borderCurve?: 'circular' | 'continuous';
  borderColor?: ColorValue;
  borderWidth?: number;
  borderLeftColor?: ColorValue;
  borderLeftWidth?: number;
  borderRightColor?: ColorValue;
  borderRightWidth?: number;
  borderTopColor?: ColorValue;
  borderTopWidth?: number;
  borderBottomColor?: ColorValue;
  borderBottomWidth?: number;
}

export interface MarkdownImageStyle {
  borderRadius?: number;
  backgroundColor?: ColorValue;
  /** Fixed rendered height; wins over the image's intrinsic height. */
  height?: number;
  maxHeight?: number;
}

export interface MarkdownTableStyle extends MarkdownLayoutStyle {
  /** Lower clamp for computed column widths. Default 44. */
  minColumnWidth?: number;
  /** Upper clamp for computed column widths. Default 320. */
  maxColumnWidth?: number;
}

export interface MarkdownSpoilerStyle {
  backgroundColor?: ColorValue;
  borderRadius?: number;
  /** iOS only; Android always renders circular corners. */
  borderCurve?: 'circular' | 'continuous';
}

export interface MarkdownListStyle {
  marginLeft?: number;
}

export interface MarkdownListMarkerStyle {
  width?: number;
  marginLeft?: number;
  color?: ColorValue;
}

/**
 * Mention styling. `variants` maps a regular expression (matched against the
 * mention link's URL) to the style for that mention type. Longest pattern
 * first, first match wins:
 *
 * ```ts
 * mention: {
 *   color: 'gray',
 *   variants: {
 *     '^users://': { color: 'blue' },
 *     '^channels://': { color: 'green' },
 *   },
 * }
 * ```
 */
export interface MarkdownMentionStyle extends MarkdownTextStyle {
  variants?: Record<string, MarkdownTextStyle>;
}

export interface MarkdownInlineCodeStyle extends MarkdownTextStyle {
  backgroundColor?: ColorValue;
  borderRadius?: number;
  padding?: number;
  paddingLeft?: number;
  paddingRight?: number;
}

export type MarkdownHeadingLevel = 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6';

/**
 * Per-element styles for the markdown viewer.
 */
export interface MarkdownStyles {
  headings?: Partial<Record<MarkdownHeadingLevel, MarkdownTextStyle>>;
  paragraph?: MarkdownTextStyle;
  image?: MarkdownImageStyle;
  table?: MarkdownTableStyle;
  tableRow?: MarkdownLayoutStyle;
  tableCell?: MarkdownTextStyle &
    Pick<
      MarkdownLayoutStyle,
      'padding' | 'paddingLeft' | 'paddingRight' | 'paddingTop' | 'paddingBottom'
    >;
  spoiler?: MarkdownSpoilerStyle;
  superscript?: MarkdownTextStyle;
  subscript?: MarkdownTextStyle;
  bold?: MarkdownTextStyle;
  italic?: MarkdownTextStyle;
  strikethrough?: MarkdownTextStyle;
  list?: MarkdownListStyle;
  listMarker?: MarkdownListMarkerStyle;
  listItem?: MarkdownTextStyle;
  link?: MarkdownTextStyle;
  mention?: MarkdownMentionStyle;
  inlineCode?: MarkdownInlineCodeStyle;
  codeBlock?: MarkdownTextStyle & MarkdownLayoutStyle;
  blockQuote?: MarkdownTextStyle & MarkdownLayoutStyle;
}

/**
 * Pre-sizing data for images referenced in the markdown. Images whose URL is
 * listed here lay out at their final size immediately (zero layout shift);
 * unknown images show a placeholder and resize once loaded.
 */
export interface MarkdownImageData {
  url: string;
  width: number;
  height: number;
}

export interface MarkdownUrlEvent {
  url: string;
}

export interface FastMarkdownViewProps {
  /** The markdown source to render. */
  markdown: string;
  /**
   * Main container style. `backgroundColor`, `padding*`, and `gap` (spacing
   * between blocks) are applied to the markdown content natively; all other
   * view styles pass through to the host view.
   */
  style?: StyleProp<ViewStyle & { gap?: number }>;
  /** Per-element markdown styles. Hoist to module scope or memoize. */
  styles?: MarkdownStyles;
  images?: MarkdownImageData[];
  onLinkPress?: (event: MarkdownUrlEvent) => void;
  onLinkLongPress?: (event: MarkdownUrlEvent) => void;
  onImagePress?: (event: MarkdownUrlEvent) => void;
}
