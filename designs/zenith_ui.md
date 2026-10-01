# Eidolarch: UI standard

Adopted 2026-09-24. One visual logic for every screen. The only per-deck variation is the school
colour, and it appears as an edge, a title or the card frames, never as a whole panel. Code reads
every value below from one theme builder (`scripts/ui/zenith_theme.gd`); no screen defines its own
colours, sizes or radii.

Colour rules: no gold-and-blue scheme. Gold survives only on card identity (Aspect frames). Blue
survives only where it means something: usable now, the defend role and Motes.

Mechanics versus theme (user, 2026-09-28): if a colour itself tells the player something, it is a
fixed `game.*` or `accent.*` token, the same for every deck. If position or shape carries the
meaning, it may wear the Mastery colour (the board wash, the lit rung and Surge rail, the phase
track's lit edge and light pool, printed trim, backdrops, screen tints). Rings, frames and glows on
table cards are always mechanical; a school colour never outlines a card.

## 1. Colour tokens

Values are sRGB 0 to 1. **Bold** rows were chosen by the user on 2026-09-24; the rest were
approved with the mockups the same day.

| Token | Value | Used for |
|---|---|---|
| `bg.screen` | (0.055, 0.050, 0.055) | Every 2D screen's background |
| `scrim` | (0.03, 0.025, 0.03) at 0.70 / 0.88 | Behind modals, behind the inspect view |
| `scrim.light` | (0.03, 0.025, 0.03) at 0.45 (`SCRIM_LIGHT`) | Under a menu that hides nothing, such as the duel's options menu |
| `surface.panel` | (0.085, 0.078, 0.080, 0.96) | Framed panels, modals |
| `surface.raised` | white at 0.06 | Cards and rows inside a panel |
| `surface.sunken` | black at 0.30 | Inputs, bar tracks |
| `frame.metal` | (0.56, 0.57, 0.58) | **Every** panel and button frame: iron |
| `frame.dim` | (0.36, 0.37, 0.38) | Disabled frames, dividers |
| `text.primary` | (0.93, 0.91, 0.87) | Body and titles |
| `text.secondary` | (0.78, 0.77, 0.74) | Hints, details |
| `text.muted` | (0.60, 0.59, 0.60) | Captions, inactive steps |
| `text.disabled` | (0.42, 0.42, 0.42) | Disabled controls |
| `text.on_light` | (0.12, 0.10, 0.09) | Text on card faces and light fills |
| **`accent.act`** | **bone-white (0.94, 0.91, 0.84)** | Primary button, targets and picks, YOUR TURN, current step; a board card usable now glows blue (`ZenithTheme.USABLE`) |
| `state.selected` | bone-white 2 px ring plus a raised fill | Selected tile, card or tab |
| `state.hover` | white at 0.12 (2D), bone glow (3D) | Hover everywhere; replaces both cyans |
| `state.warn` | ember (0.93, 0.55, 0.30) | Warnings and refusals; free now that orange is no longer Fervor |
| `game.attack` | (0.90, 0.38, 0.30) | Attacker, Strike type |
| `game.usable` | (0.36, 0.66, 0.98) (`USABLE`) | Frame on a table card the viewer can use now, and nothing else |
| `game.defend` | (0.40, 0.62, 0.92) | Stopped and answered lines in the HUD; no card aura |
| **`game.fervor`** | **crimson (0.86, 0.22, 0.30)** | Fervor pips, numbers and keyword, everywhere |
| `game.energy` | (0.36, 0.76, 0.58) | Energy |
| `game.might` | (0.78, 0.82, 0.90) | Might |
| `game.life` | the seat's Mastery colour, muted | Life Deck plates and the stat tracker's rule keep their per-seat colour shift (user, 2026-09-24) |
| `game.xp` | (0.62, 0.55, 0.90) | XP bars and level chips |
| **`game.motes`** | **arcane blue (0.48, 0.72, 1.00) with a soft glow** | Motes and prices only (the second blue) |
| `game.mana` | lavender (0.77, 0.63, 0.94) with a soft glow (`MANA`) | Mana, the per-run currency, and Shop prices |
| `state.short` | (0.92, 0.47, 0.39) (`SHORT`) | A price the player cannot pay |
| `game.penalty` | amber (0.95, 0.78, 0.35) (`PENALTY`) | The penalty sentence of a style Resonance and its STYLE chip, on the Shrine, the board tooltip and the deck list; nothing else (2026-09-29) |
| `identity.school` | `Palette` school colours | Card frames, school chips, one edge or title per adventure screen |
| `identity.type` | `Palette` type colours | Card type chips and icons |
| `identity.seat` | seat colours | Online presence and seat markers |

## 2. Metrics

- **Radii:** 0 for pixel-framed panels and buttons; 4 for flat tiles, chips and bars. Nothing else.
- **Borders:** 1 px for tiles and dividers, 2 px for selection. The 5 px coloured edge on edged
  cards is the one exception.
- **Spacing:** multiples of 6 (6, 12, 18, 24, 36).
- **Type scale** (1080p design size; multiples of 6 draw whole pixels at 900p and 720p):
  18 caption, 24 body, 30 row title, 36 group heading, 48 screen title, 72 display.
- **Typefaces:** Pirata One for screen titles, group headings, card and duelist names and the duel
  banner (`ZenithTheme.TITLE_FONT`). Kurale for everything else (the project default font). Both
  have one weight, so emphasis comes from size and colour.

## 3. Components

| Component | Standard |
|---|---|
| Framed panel | Kenney border 009 (thin rule, small corner squares) in `frame.metal` over `surface.panel`. The panel fill is never tinted |
| Modal | Framed panel over the `scrim` |
| Flat tile / row | `surface.raised`, radius 4, optional 5 px edge in a meaning or school colour |
| Button, primary | `accent.act` fill, `text.on_light` text, iron frame |
| Button, secondary | `surface.panel` fill, `text.primary`, iron frame |
| Button, disabled | `frame.dim` frame, `text.disabled` |
| Tab / toggle | One implementation: secondary button, selected shows `state.selected` ring |
| Chip | Tag: outlined, tinted text. Badge: filled, `text.on_light`. Radius 4 |
| Screen title | Ornate scroll banner in iron on every screen (`SanctumUI.dress`); an adventure run adds a 4 px school-coloured edge under it (`MapArt.school`) |
| Map roads | Walked road in the run's school colour, open roads bone, the rest iron |
| Stat tile | Flat tile with caption and value; value in its meaning colour |
| Progress bar | `surface.sunken` track, meaning-colour fill, radius 4 |
| Divider | One 1 px `frame.dim` rule |
| Toast | Flat tile, meaning-colour edge, `text.primary` |
| Tooltip | Framed panel, `text.secondary`, 18 |
| Checkbox | Themed to the same frame and accent |
| Decision clock | `ClockLabel` 30 `text.primary`; `ClockWarnLabel` 30 `state.warn` once timer and bank together are 10 s or less |
| Fuse | `FuseBar` progress bar, 4 high, `state.warn` fill on a `state.warn` at 0.20 track, under the decision's clock |
| Read-only chip | `ChipLabel`: `surface.panel` fill, 1 px `frame.dim` border, radius 4, 18 `text.secondary`, such as the match score beside the gear |
| Rating line | `RatingLabel`, 24 `text.primary`, the rating sentence on a match result |
| Menu shade | `scrim` at 0.45 (`SCRIM_LIGHT`), under a menu that hides nothing |

## 4. Decisions still open

1. Mat reflections: turning them off makes the oxblood mat deeper and redder than the variant
   picked. To be shown side by side before changing.
2. The 3D hall behind select, adventure start and journal is relit neutral to match the duel.

## 5. Implementation order

1. Done 2026-09-24: `ZenithTheme` is the one builder with the tokens and type variations above
   (`SanctumUI.theme()` returns it); `MapArt.tint` is iron; button and panel art re-exported by
   `tools/import_map_art.py` in iron and bone.
2. Replace the ~98 script colour literals and ~20 scene colours with tokens; merge the two hover
   cyans, the teal "no school" fallbacks, the two backgrounds and the six scrims.
3. Components: one tab/toggle, one chip, one title, one divider; radii and font sizes to the scale.
4. Screens one at a time with a screenshot each: title, select, versus, duel, adventure start, map,
   reward, settle, vendor, loadout, journal.
