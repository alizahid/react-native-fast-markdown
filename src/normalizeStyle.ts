import { processColor } from 'react-native'
import { type MarkdownStyle } from './types'

const styleCache = new WeakMap<MarkdownStyle, string>()

/** Library-provided default styles. Merged underneath the user's styles
 *  so users only need to override the keys they care about. */
const defaultStyle: MarkdownStyle = {}

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
