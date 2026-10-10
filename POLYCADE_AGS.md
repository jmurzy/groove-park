# Sente Artwork UI Specification

Sente uses three artwork variants so the game reads clearly across the library and game-detail UI.

| File | Dimensions | UI placement | Purpose |
| --- | --- | --- | --- |
| `header.png` | 460 x 215 px | Library tile | A compact, immediately recognizable game cover. Keep the title and primary visual focal point legible at small sizes. |
| `hero.png` | 1920 x 1080 px | Detail view | Full-screen or wide game-detail artwork. Compose for a 16:9 frame, with enough clear space for UI overlays and readable title treatment. |
| `marquee.png` | 1920 x 360 px | Digital marquee | A wide, shallow arcade-style banner. Prioritize the game title and strong horizontal composition; avoid important content near the top and bottom edges. |

## Artwork Direction

The three images should use the same Sente visual identity: consistent logo treatment, palette, character or game imagery, and overall tone. Each file is a separately composed asset, not simply a crop of another size.

- `header.png` should be optimized for browsing: bold subject, simple silhouette, and a title that remains clear within the tile.
- `hero.png` should establish the game world and support contextual information in the detail view. Keep its most important imagery away from likely UI overlay areas.
- `marquee.png` should feel like a physical arcade cabinet marquee translated to a digital display: high-impact branding, broad composition, and minimal small detail.

## Packaging

Place the final PNG files in `images/ags/` using the exact filenames and dimensions above. The `just package-ags` recipe adds `header.png`, `hero.png`, and `marquee.png` from that directory to the distributable package under `artwork/`.
