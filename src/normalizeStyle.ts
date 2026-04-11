import { Platform, processColor } from 'react-native'
import { type MarkdownStyle } from './types'

const styleCache = new WeakMap<MarkdownStyle, string>()

const monoFont = Platform.select({
  ios: 'Menlo',
  android: 'monospace',
  default: 'monospace',
})

const defaultStyle: MarkdownStyle = {
  text: {
    fontSize: 16,
    lineHeight: 24,
    color: '#111',
  },
  heading1: {
    fontSize: 32,
    fontWeight: 'bold',
  },
  heading2: {
    fontSize: 28,
    fontWeight: 'bold',
  },
  heading3: {
    fontSize: 24,
    fontWeight: '600',
  },
  heading4: {
    fontSize: 20,
    fontWeight: '600',
  },
  heading5: {
    fontSize: 18,
    fontWeight: '600',
  },
  heading6: {
    fontSize: 16,
    fontWeight: '600',
  },
  paragraph: {},
  strong: {
    fontWeight: 'bold',
  },
  emphasis: {
    fontStyle: 'italic',
  },
  strikethrough: {
    textDecorationLine: 'line-through',
  },
  underline: {
    textDecorationLine: 'underline',
  },
  code: {
    fontFamily: monoFont,
    fontSize: 14,
    backgroundColor: '#f0f0f0',
    borderRadius: 3,
    padding: 2,
  },
  codeBlock: {
    fontFamily: monoFont,
    fontSize: 14,
    backgroundColor: '#f5f5f5',
    borderRadius: 6,
    padding: 12,
  },
  link: {
    color: '#0066cc',
  },
  blockquote: {
    borderLeftColor: '#ddd',
    borderLeftWidth: 3,
    fontStyle: 'italic',
  },
  listItem: {},
  listBullet: {
    color: '#666',
  },
  table: {
    borderColor: '#ddd',
    borderWidth: 1,
  },
  tableHeaderRow: {
    backgroundColor: '#f5f5f5',
  },
  tableCell: {
    padding: 10,
    fontSize: 14,
  },
  tableHeaderCell: {
    fontWeight: '600',
  },
  thematicBreak: {
    backgroundColor: '#ddd',
    height: 1,
    marginVertical: 16,
  },
  mention: {
    color: '#0066cc',
    fontWeight: '600',
  },
  spoiler: {
    backgroundColor: '#000',
  },
}

function normalizeColorValues(
  style: Record<string, unknown>,
): Record<string, unknown> {
  const result: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(style)) {
    if (
      typeof value === 'string' &&
      (key.toLowerCase().includes('color') ||
        key === 'backgroundColor' ||
        key === 'overlayColor')
    ) {
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
  const result: Record<string, unknown> = { ...defaults }
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
