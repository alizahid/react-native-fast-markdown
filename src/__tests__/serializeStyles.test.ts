import { describe, expect, mock, test } from 'bun:test';

// serializeStyles only uses processColor from react-native; the real module
// is Flow-typed native source that bun cannot parse.
mock.module('react-native', () => ({
  processColor: (value: unknown): number | null => {
    if (typeof value === 'number') {
      return value;
    }
    if (value === 'red') {
      return 0xffff0000 | 0;
    }
    if (value === 'blue') {
      return 0xff0000ff | 0;
    }
    if (typeof value === 'string' && value.startsWith('#')) {
      return (0xff000000 | parseInt(value.slice(1), 16)) | 0;
    }
    return null;
  },
}));

const { serializeStyles } = await import('../serializeStyles');

function parse(json: string): Record<string, any> {
  return JSON.parse(json);
}

describe('serializeStyles', () => {
  test('empty input produces empty object', () => {
    expect(serializeStyles(undefined, undefined)).toBe('{}');
  });

  test('main padding shorthand expands into sides', () => {
    const out = parse(serializeStyles(undefined, { padding: 16, paddingTop: 4, gap: 8 }));
    expect(out.main).toEqual({
      paddingLeft: 16,
      paddingRight: 16,
      paddingTop: 4,
      paddingBottom: 16,
      gap: 8,
    });
  });

  test('colors are processed to ints', () => {
    const out = parse(serializeStyles({ paragraph: { color: 'red' } }, undefined));
    expect(out.paragraph.color).toBe(0xffff0000 | 0);
  });

  test('fontWeight normalizes to string', () => {
    const out = parse(
      serializeStyles({ bold: { fontWeight: 700 }, italic: { fontWeight: 'bold' } }, undefined)
    );
    expect(out.bold.fontWeight).toBe('700');
    expect(out.italic.fontWeight).toBe('bold');
  });

  test('heading levels serialize independently', () => {
    const out = parse(
      serializeStyles({ headings: { h1: { fontSize: 40 }, h3: { color: 'blue' } } }, undefined)
    );
    expect(out.h1).toEqual({ fontSize: 40 });
    expect(out.h3).toEqual({ color: 0xff0000ff | 0 });
    expect(out.h2).toBeUndefined();
  });

  test('mention variants are ordered longest pattern first', () => {
    const out = parse(
      serializeStyles(
        {
          mention: {
            color: 'red',
            variants: {
              '^u:': { color: 'blue' },
              '^users://': { color: 'red' },
              '^ch:': { color: 'blue' },
            },
          },
        },
        undefined
      )
    );
    expect(out.mention.variants.map((pair: [string, unknown]) => pair[0])).toEqual([
      '^users://',
      '^ch:',
      '^u:',
    ]);
  });

  test('border shorthand expands per side, sides win', () => {
    const out = parse(
      serializeStyles(
        {
          blockQuote: {
            borderColor: 'red',
            borderWidth: 2,
            borderLeftWidth: 4,
          },
        },
        undefined
      )
    );
    expect(out.blockQuote.borderLeftWidth).toBe(4);
    expect(out.blockQuote.borderRightWidth).toBe(2);
    expect(out.blockQuote.borderTopColor).toBe(0xffff0000 | 0);
  });

  test('output is stable for identical input', () => {
    const styles = { paragraph: { fontSize: 15 }, bold: { color: 'red' } };
    expect(serializeStyles(styles, { gap: 4 })).toBe(serializeStyles(styles, { gap: 4 }));
  });

  test('undefined values are omitted', () => {
    const out = parse(
      serializeStyles({ paragraph: { fontSize: undefined, color: undefined } }, undefined)
    );
    expect(out.paragraph).toBeUndefined();
  });
});
