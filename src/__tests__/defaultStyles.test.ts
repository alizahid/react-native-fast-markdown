import { describe, expect, test } from "bun:test";

const { defaultStyles, mergeStyles } = await import("../defaultStyles");

describe("mergeStyles", () => {
  test("no overrides returns the defaults", () => {
    expect(mergeStyles()).toEqual(defaultStyles);
    expect(mergeStyles({})).toEqual(defaultStyles);
  });

  test("element sections merge key-by-key", () => {
    const out = mergeStyles({ codeBlock: { fontSize: 12 } });
    expect(out.codeBlock?.fontSize).toBe(12);
    expect(out.codeBlock?.backgroundColor).toBe(
      defaultStyles.codeBlock?.backgroundColor
    );
    expect(out.codeBlock?.padding).toBe(defaultStyles.codeBlock?.padding);
  });

  test("heading levels merge individually", () => {
    const out = mergeStyles({ headings: { h1: { color: "magenta" } } });
    expect(out.headings?.h1?.color).toBe("magenta");
    expect(out.headings?.h1?.fontSize).toBe(
      defaultStyles.headings?.h1?.fontSize
    );
    expect(out.headings?.h2).toEqual(defaultStyles.headings?.h2 ?? {});
  });

  test("sections without defaults pass through", () => {
    const out = mergeStyles({
      mention: {
        color: "purple",
        variants: { "^users://": { color: "pink" } },
      },
      paragraph: { color: "magenta" },
    });
    expect(out.paragraph?.color).toBe("magenta");
    expect(out.mention?.variants?.["^users://"]?.color).toBe("pink");
  });

  test("inputs are not mutated", () => {
    const overrides = { headings: { h1: { color: "magenta" } } };
    const before = JSON.stringify(defaultStyles);
    mergeStyles(overrides);
    expect(JSON.stringify(defaultStyles)).toBe(before);
    expect(overrides).toEqual({ headings: { h1: { color: "magenta" } } });
  });
});
