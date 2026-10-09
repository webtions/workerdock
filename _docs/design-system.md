# Design system

Goal: a flat, calm, consistent native-feeling Mac app. Defined in `WorkerDock/Views/Theme.swift`.

## Rules
- **Flat.** No gradients, no drop shadows, no tinted square behind an icon. Panels are hairline outlines.
- **One of each.** One spacing scale, one corner-radius pair, three icon sizes, a fixed type scale.
- **Zero repeats.** A fact appears once (status in the header, not also in a tile; address as a button, not also
  a card).
- **Plain words.** No internal jargon in the UI ("Running", not "Running · attached").
- **Everything reacts.** Every button/row has a hover state; presses scale slightly; changes animate lightly.
- **Same edges.** Header and page content share left and right edges at every window width.

## Colours (`Brand`)
Light uses a warm cream, dark uses near-black (from the Webtions / SVG Ready tokens). Accent coral `#FF3253`
is for the primary action and the selected tab underline only. State colours: green running, amber
starting/warm memory, red error/hot memory. Binding kinds have their own colours (icons and connection lines).
Hover is `text @ 4.5%`, selection `text @ 13%`.

## Tokens
| Token | Values |
|---|---|
| `Space` | xs 4, s 8, m 12, l 16, xl 24 |
| `Radius` | control 7, panel 10 |
| `IconSize` | sm 14, md 16, lg 20, xl 28 |
| Fonts | `dLargeTitle` 26, `dTitle` 20, `dHeading` 15, `dBody` 13, `dBodyMedium` 13 medium, `dCaption` 12, `dMono` 12 mono, `dLabel` 11 caps |

## Components
`Card` (hairline panel), `SectionTitle` (caps label + count), `DockButtonStyle` (primary / secondary / danger,
height 28, compact 24), `DockIconButtonStyle` (square icon button, optional border), `MenuChip`, `PillShape`
and `Pill` (22pt chips: tinted for status/memory, outlined for project type), `StatusDot`, `AppearIn`
(fade/lift on first appearance), `HoverFill`, `MemoryBadge`, `Icon` (Lucide), `KindIcon` (framework brand
mark or Lucide fallback).

## Layout behaviour
- Header second row holds path, type chips and the actions; on narrow windows the actions drop below
  (`ViewThatFits`).
- Overlay scrollbars are forced for this app (`AppleShowScrollBars = WhenScrolling`) so a scrollbar never
  takes width from the page and breaks alignment.
- Minimum window 820 x 520.

## Icons
Lucide (ISC) bundled as template SVG assets named `lucide-<name>`; framework logos from Simple Icons named
`brand-<id>`; EmDash mark derived from its official favicon. To add one: create
`Icons.xcassets/lucide-<name>.imageset` (copy another imageset's `Contents.json`) and keep the source SVG in
`tools/lucide/`.
