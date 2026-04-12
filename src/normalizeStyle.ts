import { Platform, processColor, StyleSheet } from 'react-native'

import { type MarkdownStyle } from './types'

const styleCache = new WeakMap<MarkdownStyle, string>()

const colors = {
  background: 'rgb(242, 240, 229)',
  border: 'rgb(183, 181, 172)',
  link: 'rgb(160, 47, 111)',
  user: 'rgb(102, 128, 11)',
  channel: 'rgb(32, 94, 166)',
  command: 'rgb(94, 64, 157)',
}

const fonts = {
  mono: Platform.select({
    ios: 'Menlo',
    android: 'monospace',
  }),
}

/** Library-provided default styles. Merged underneath the user's styles
 *  so users only need to override the keys they care about. */
const defaultStyle: MarkdownStyle = {
  heading1: {
    fontSize: 24,
    fontWeight: '600',
  },
  heading2: {
    fontSize: 20,
    fontWeight: '600',
  },
  heading3: {
    fontSize: 18,
    fontWeight: '600',
  },
  // Note: bold / italic / strikethrough traits are derived from the
  // token itself by the native renderer — the only customization
  // exposed on `strong`, `emphasis`, `strikethrough` is `color`.
  code: {
    fontFamily: fonts.mono,
    fontSize: 14,
    backgroundColor: colors.background,
  },
  codeBlock: {
    fontFamily: fonts.mono,
    fontSize: 14,
    backgroundColor: colors.background,
    borderRadius: 6,
    padding: 12,
  },
  link: {
    color: colors.link,
  },
  image: {
    borderRadius: 6,
  },
  blockquote: {
    backgroundColor: colors.background,
    padding: 6,
    borderRadius: 6,
    borderLeftWidth: 6,
    borderColor: colors.border,
  },
  listBullet: {
    color: colors.border,
  },
  spoiler: {
    backgroundColor: colors.link,
    borderRadius: 4,
  },
  mentionUser: {
    color: colors.user,
    fontWeight: '600',
  },
  mentionChannel: {
    color: colors.channel,
    fontWeight: '600',
  },
  mentionCommand: {
    color: colors.command,
    fontWeight: '600',
    fontFamily: fonts.mono,
  },
  tableHeaderRow: {
    backgroundColor: colors.background,
  },
  tableHeaderCell: {
    fontWeight: '600',
  },
  tableCell: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.border,
    padding: 6,
  },
  thematicBreak: {
    backgroundColor: colors.border,
    height: StyleSheet.hairlineWidth,
    marginVertical: 12,
  },
}

function normalizeColorValues(
  style: Record<string, unknown>,
): Record<string, unknown> {
  const result: Record<string, unknown> = {}

  for (const [key, value] of Object.entries(style)) {
    if (typeof value === 'string' && key.toLowerCase().includes('color')) {
      result[key] = processColor(value)
    } else if (
      typeof value === 'object' &&
      value !== null &&
      !Array.isArray(value)
    ) {
      result[key] = normalizeColorValues(value as Record<string, unknown>)
    } else {
      result[key] = value
    }
  }

  return result
}

function mergeStyles(
  defaults: Record<string, unknown>,
  overrides: Record<string, unknown>,
): Record<string, unknown> {
  const result: Record<string, unknown> = {
    ...defaults,
  }

  for (const [key, value] of Object.entries(overrides)) {
    if (
      typeof value === 'object' &&
      value !== null &&
      !Array.isArray(value) &&
      typeof result[key] === 'object' &&
      result[key] !== null
    ) {
      result[key] = mergeStyles(
        result[key] as Record<string, unknown>,
        value as Record<string, unknown>,
      )
    } else {
      result[key] = value
    }
  }

  return result
}

export function normalizeMarkdownStyle(userStyle?: MarkdownStyle): string {
  if (!userStyle) {
    const cached = styleCache.get(defaultStyle)

    if (cached) {
      return cached
    }

    const serialized = JSON.stringify(
      normalizeColorValues(defaultStyle as unknown as Record<string, unknown>),
    )

    styleCache.set(defaultStyle, serialized)

    return serialized
  }

  const cached = styleCache.get(userStyle)

  if (cached) {
    return cached
  }

  const merged = mergeStyles(
    defaultStyle as unknown as Record<string, unknown>,
    userStyle as unknown as Record<string, unknown>,
  )

  const normalized = normalizeColorValues(merged)
  const serialized = JSON.stringify(normalized)

  styleCache.set(userStyle, serialized)

  return serialized
}
