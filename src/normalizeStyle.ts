import { processColor } from 'react-native'
import { type MarkdownStyle } from './types'

const styleCache = new WeakMap<MarkdownStyle, string>()

function normalizeColorValues(
  style: Record<string, unknown>,
): Record<string, unknown> {
  const result: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(style)) {
    if (
      typeof value === 'string' &&
      (key.toLowerCase().includes('color') || key === 'backgroundColor')
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

export function normalizeMarkdownStyle(userStyle?: MarkdownStyle): string {
  if (!userStyle) {
    return '{}'
  }

  const cached = styleCache.get(userStyle)
  if (cached) {
    return cached
  }

  const normalized = normalizeColorValues(
    userStyle as unknown as Record<string, unknown>,
  )
  const serialized = JSON.stringify(normalized)
  styleCache.set(userStyle, serialized)
  return serialized
}
