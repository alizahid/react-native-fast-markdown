import { type ColorValue, processColor } from "react-native";

import type {
  MarkdownLayoutStyle,
  MarkdownStyles,
  MarkdownTextStyle,
} from "./types";

type Serialized = Record<string, unknown>;

/**
 * Main container style extracted from the `style` prop; these keys affect
 * native content layout (and measurement), so they ride along in stylesJson.
 * Text keys become the `base` section: the root of the text-style cascade.
 */
export interface MainStyle extends MarkdownTextStyle {
  backgroundColor?: ColorValue;
  gap?: number;
  padding?: number;
  paddingBottom?: number;
  paddingLeft?: number;
  paddingRight?: number;
  paddingTop?: number;
}

function put(out: Serialized, key: string, value: unknown): void {
  if (value !== undefined && value !== null) {
    out[key] = value;
  }
}

function putColor(
  out: Serialized,
  key: string,
  value: ColorValue | undefined
): void {
  if (value === undefined || value === null) {
    return;
  }
  const processed = processColor(value);
  if (typeof processed === "number") {
    out[key] = processed;
  }
}

// Expands `padding` into explicit sides so native code never sees shorthand.
function putPadding(
  out: Serialized,
  style: {
    padding?: number;
    paddingLeft?: number;
    paddingRight?: number;
    paddingTop?: number;
    paddingBottom?: number;
  },
  sides: ReadonlyArray<"Left" | "Right" | "Top" | "Bottom">
): void {
  for (const side of sides) {
    put(out, `padding${side}`, style[`padding${side}`] ?? style.padding);
  }
}

function serializeText(
  style: MarkdownTextStyle | undefined
): Serialized | undefined {
  if (style == null) {
    return;
  }
  const out: Serialized = {};
  put(out, "fontSize", style.fontSize);
  if (style.fontWeight !== undefined) {
    out.fontWeight = String(style.fontWeight);
  }
  put(out, "fontFamily", style.fontFamily);
  putColor(out, "color", style.color);
  put(out, "fontVariant", style.fontVariant);
  putColor(out, "textDecorationColor", style.textDecorationColor);
  put(out, "textDecorationLine", style.textDecorationLine);
  put(out, "textDecorationStyle", style.textDecorationStyle);
  return Object.keys(out).length > 0 ? out : undefined;
}

function serializeLayout(
  style: MarkdownLayoutStyle | undefined
): Serialized | undefined {
  if (style == null) {
    return;
  }
  const out: Serialized = {};
  putColor(out, "backgroundColor", style.backgroundColor);
  putPadding(out, style, ["Left", "Right", "Top", "Bottom"]);
  put(out, "borderRadius", style.borderRadius);
  put(out, "borderCurve", style.borderCurve);
  for (const side of ["Left", "Right", "Top", "Bottom"] as const) {
    putColor(
      out,
      `border${side}Color`,
      style[`border${side}Color`] ?? style.borderColor
    );
    put(
      out,
      `border${side}Width`,
      style[`border${side}Width`] ?? style.borderWidth
    );
  }
  return Object.keys(out).length > 0 ? out : undefined;
}

function merge(
  ...parts: Array<Serialized | undefined>
): Serialized | undefined {
  const defined = parts.filter(
    (part): part is Serialized => part !== undefined
  );
  if (defined.length === 0) {
    return;
  }
  return Object.assign({}, ...defined);
}

/**
 * Serializes the styles into the stable JSON string handed to native code.
 * Colors become processed ARGB ints, padding shorthands are expanded, and
 * mention variants become a longest-pattern-first ordered array.
 */
// biome-ignore lint/complexity/noExcessiveCognitiveComplexity: go away
export function serializeStyles(
  styles: MarkdownStyles | undefined,
  main: MainStyle | undefined
): string {
  const out: Serialized = {};

  if (main != null) {
    const section: Serialized = {};
    putColor(section, "backgroundColor", main.backgroundColor);
    putPadding(section, main, ["Left", "Right", "Top", "Bottom"]);
    put(section, "gap", main.gap);
    if (Object.keys(section).length > 0) {
      out.main = section;
    }
    // Text keys cascade into every text element as the `base` style.
    put(out, "base", serializeText(main));
  }

  if (styles != null) {
    for (const level of ["h1", "h2", "h3", "h4", "h5", "h6"] as const) {
      put(out, level, serializeText(styles.headings?.[level]));
    }
    put(out, "paragraph", serializeText(styles.paragraph));

    if (styles.image != null) {
      const image: Serialized = {};
      put(image, "borderRadius", styles.image.borderRadius);
      putColor(image, "backgroundColor", styles.image.backgroundColor);
      put(image, "height", styles.image.height);
      put(image, "maxHeight", styles.image.maxHeight);
      if (Object.keys(image).length > 0) {
        out.image = image;
      }
    }

    if (styles.table != null) {
      const table = serializeLayout(styles.table) ?? {};
      put(table, "minColumnWidth", styles.table.minColumnWidth);
      put(table, "maxColumnWidth", styles.table.maxColumnWidth);
      if (Object.keys(table).length > 0) {
        out.table = table;
      }
    }
    put(out, "tableRow", serializeLayout(styles.tableRow));
    if (styles.tableCell != null) {
      const cell = serializeText(styles.tableCell) ?? {};
      putPadding(cell, styles.tableCell, ["Left", "Right", "Top", "Bottom"]);
      if (Object.keys(cell).length > 0) {
        out.tableCell = cell;
      }
    }

    if (styles.spoiler != null) {
      const spoiler: Serialized = {};
      putColor(spoiler, "backgroundColor", styles.spoiler.backgroundColor);
      put(spoiler, "borderRadius", styles.spoiler.borderRadius);
      put(spoiler, "borderCurve", styles.spoiler.borderCurve);
      if (Object.keys(spoiler).length > 0) {
        out.spoiler = spoiler;
      }
    }

    if (styles.divider != null) {
      const divider: Serialized = {};
      putColor(divider, "color", styles.divider.color);
      put(divider, "height", styles.divider.height);
      if (Object.keys(divider).length > 0) {
        out.divider = divider;
      }
    }

    put(out, "superscript", serializeText(styles.superscript));
    put(out, "subscript", serializeText(styles.subscript));
    put(out, "bold", serializeText(styles.bold));
    put(out, "italic", serializeText(styles.italic));
    put(out, "strikethrough", serializeText(styles.strikethrough));

    if (styles.list != null) {
      const list: Serialized = {};
      put(list, "marginLeft", styles.list.marginLeft);
      if (Object.keys(list).length > 0) {
        out.list = list;
      }
    }
    if (styles.listMarker != null) {
      const marker: Serialized = {};
      put(marker, "width", styles.listMarker.width);
      put(marker, "marginLeft", styles.listMarker.marginLeft);
      putColor(marker, "color", styles.listMarker.color);
      if (Object.keys(marker).length > 0) {
        out.listMarker = marker;
      }
    }
    put(out, "listItem", serializeText(styles.listItem));

    put(out, "link", serializeText(styles.link));

    if (styles.mention != null) {
      const { variants, ...base } = styles.mention;
      const mention = serializeText(base) ?? {};
      if (variants != null) {
        const ordered = Object.keys(variants)
          .sort((a, b) => b.length - a.length || a.localeCompare(b))
          .map((pattern) => [pattern, serializeText(variants[pattern]) ?? {}]);
        if (ordered.length > 0) {
          mention.variants = ordered;
        }
      }
      if (Object.keys(mention).length > 0) {
        out.mention = mention;
      }
    }

    if (styles.inlineCode != null) {
      const code = serializeText(styles.inlineCode) ?? {};
      putColor(code, "backgroundColor", styles.inlineCode.backgroundColor);
      put(code, "borderRadius", styles.inlineCode.borderRadius);
      putPadding(code, styles.inlineCode, ["Left", "Right"]);
      if (Object.keys(code).length > 0) {
        out.inlineCode = code;
      }
    }

    put(
      out,
      "codeBlock",
      merge(serializeText(styles.codeBlock), serializeLayout(styles.codeBlock))
    );
    put(
      out,
      "blockQuote",
      merge(
        serializeText(styles.blockQuote),
        serializeLayout(styles.blockQuote)
      )
    );
  }

  return JSON.stringify(out);
}
