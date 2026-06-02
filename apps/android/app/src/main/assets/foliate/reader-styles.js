// Builds the CSS injected into foliate-js sections via renderer.setStyles().
// Ported from the web reader (client/src/components/reader/EpubReaderView.tsx
// themeCss / buildBookStyles) so Android and web render EPUBs identically.

export function themeCss(theme) {
  switch (theme) {
    case "dark":
      return `
        html, body {
          background: #1a1a1a !important;
          color: #e0e0e0 !important;
        }
        a { color: #79b8ff !important; }
      `;
    case "sepia":
      return `
        html, body {
          background: #f4ecd8 !important;
          color: #5b4636 !important;
        }
        a { color: #8b5e3c !important; }
      `;
    default:
      return `
        html, body {
          background: #ffffff !important;
          color: #1a1a1a !important;
        }
      `;
  }
}

// settings: { fontSize: number (percent), theme: string, writingMode: "auto"|"vertical"|"horizontal" }
export function buildBookStyles(settings) {
  const fontSize = settings.fontSize ?? 100;
  const theme = settings.theme ?? "light";
  const writingMode = settings.writingMode ?? "auto";
  // "auto" leaves writing-mode untouched so the book's own CSS wins.
  const writing =
    writingMode === "vertical"
      ? `html, body { writing-mode: vertical-rl !important; }`
      : writingMode === "horizontal"
        ? `html, body { writing-mode: horizontal-tb !important; }`
        : "";
  return [
    themeCss(theme),
    `html, body { font-size: ${fontSize}% !important; }`,
    writing,
  ]
    .filter(Boolean)
    .join("\n");
}

// The matching page background so the viewport around the columns matches the
// theme (the host document, outside foliate's shadow DOM).
export function pageBackground(theme) {
  switch (theme) {
    case "dark":
      return "#1a1a1a";
    case "sepia":
      return "#f4ecd8";
    default:
      return "#ffffff";
  }
}
