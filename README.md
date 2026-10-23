# Multicolor 2.0

**Perceptually Uniform Color Scheme Generator for macOS.**

Multicolor 2.0 is a native macOS color palette studio built on **OKLCH**—the modern, perceptually uniform color space designed by Björn Ottosson—paired with **CSS Color 4 Gamut Mapping**. Adjust any single swatch and watch the other four colors harmonize in real time with mathematically balanced lightness, chroma, and hue.

---

## Why Multicolor 2.0?

Traditional HSL and RGB palette generators distort perceived brightness—turning yellows blindingly bright and blues muddily dark. **Multicolor 2.0** computes every color relationship in cylindrical **Oklab (OKLCH)** space and binary-searches chroma into the sRGB gamut while preserving exact perceptual lightness (`L`) and hue (`H`).

- **Live 5-Swatch Synchronization**: Pick or drag any color well in the macOS Color Panel and all unlocked panels respond continuously at 60 fps.
- **Perceptual Luminance & Contrast**: Instant relative luminance (`%`) and one-click `HEX` copy on every swatch, plus detailed tooltips showing `HEX`, `RGB`, `OKLCH`, and **WCAG 2.1 contrast ratios** against white and black.
- **Pin What You Love**: Lock individual panels so they stay untouched while you tweak or randomize the rest of the scheme.
- **Seamless macOS Experience**: Full-bleed split-view canvas, persistent window size/position and harmony mode across launches, and full Undo/Redo (`⌘Z` / `⇧⌘Z`).

---

## 11 Harmony Modes

Switch harmony algorithms at any time from the window toolbar or the **Mode** menu:

| Shortcut | Harmony Mode | Description |
| :--- | :--- | :--- |
| `⌘1` | **Golden Ratio (OKLCH)** | Rotates hues by the golden angle (`137.508°`) with a parabolic midtone chroma curve and harmonic lightness wave. |
| `⌘2` | **Analogous** | Smooth `26°` steps along the perceptual hue wheel with gentle tonal progression. |
| `⌘3` | **Complementary** | Pairs your anchor color with its exact `180°` perceptual complement and balanced tints/shades. |
| `⌘4` | **Split-Complementary** | Combines the anchor hue with flanking `+150°` and `+210°` complements. |
| `⌘5` | **Triadic** | Equidistant `120°` perceptual triad across five balanced tonal slots. |
| `⌘6` | **Tetradic** | Rectangular double-complementary (`0° / 60° / 180° / 240°`) harmony. |
| `⌘7` | **Pentadic (72°)** | Five evenly spaced hues around the OKLCH color circle. |
| `⌘8` | **Cubehelix** | Helical trajectory through OKLCH with simultaneous hue rotation and monotonic lightness progression. |
| `⌘9` | **Monochromatic** | Constant perceptual hue with a natural bell-shaped chroma envelope across the lightness ramp. |
| `⌘0` | **Shades & Tints** | Chroma-preserving lightness progression for clean UI scales. |
| — | **Freeform (Unlinked)** | Adjust individual panels independently without modifying neighboring swatches. |

---

## Palette Controls & Shortcuts

Refine and transform your entire 5-color scheme from the toolbar or the **Scheme** & **Format** menus:

- **Random Scheme** (`⌘R`) — Generate a new harmonic palette following the selected harmony mode (respecting any locked panels)
- **Randomize Single Swatch** — Click the inline luminance `%` badge on any panel to re-seed from that slot
- **Rotate Hue +15° / -15°** (`⌘]` / `⌘[`) — Shift all unlocked hues along the OKLCH wheel
- **Brighten / Darken Scheme** (`⌘=` / `⌘-`) — Step perceptual lightness up or down
- **Boost / Mute Vibrance** (`⇧⌘=` / `⇧⌘-`) — Scale perceptual chroma without shifting hue or lightness
- **Sort by Luminance** (`⌘L`) — Toggle sorting panels from darkest to lightest or lightest to darkest
- **Reverse Order** (`⇧⌘R`) — Flip the 5 panels left-to-right
- **Invert Scheme** (`⇧⌘I`) — Compute the perceptual OKLCH complement of every unlocked panel
- **Unlock All Panels** (`⌥⌘U`) — Clear all panel locks at once
- **Equal Split** (`⌘I`) — Reset all 5 split-view columns to equal width
- **Toggle Info** (`⌘T`) — Hide or reveal on-canvas controls for a distraction-free color preview

---

## One-Click Copy & Developer Exports

Export your palette directly to the macOS clipboard from the **Scheme** menu or toolbar pull-down:

- **Single Swatch HEX** — Click any panel's recessed hex button to copy its 6-digit hex code
- **Copy Hex List** (`⇧⌘C`) — Comma-separated `#RRGGBB` list
- **Copy CSS Variables** — `:root` custom properties with `/* oklch(...) */` comments
- **Copy Swift Array** — Ready-to-paste `[NSColor]` array in `.sRGB`
- **Copy JSON** — Structured JSON with `hex`, `luminance`, `rgb`, and `oklch` values
- **Copy SVG Swatch** — Scalable vector palette card ready for design docs or READMEs

---

## Requirements

- **macOS** 14.0 or later
- Built with **Swift** & **AppKit**

---

Copyright © Lucian Marin. All rights reserved.
