# delve UI guidelines

## 1. What this governs

Every 2D Control-layer surface in delve: combat HUD panels, modals, overlays, tickers, and any future menu work. The 3D presentation layer (unit tokens, damage popups, grid overlays) follows its own rules and is out of scope here, with one debt noted in section 7.

Use this document two ways. When designing a new surface, walk it through the four tests in section 2 before opening the editor. When reviewing existing or submitted UI, run the checklist in section 8 and cite case law from section 3 — a verdict already reached applies to the next element of the same kind unless someone argues why it shouldn't.

The baseline stance: game designers are maximalists, and the UI artist's job is to remove about 99% of what they ask for. Removal is the default outcome for any proposed element. Relocation to a toggle, hover, or expandable is the fallback. Permanent HUD residency is the exception and has to be earned.

## 2. The four tests

Ask these of every element, in order. Failing an early test means the later ones never come up.

### 2.1 Kitchen-sink test

Does this need to exist at all? Most HUD elements answer this question wrong because nobody asked it. A currency display that fades away when you can't spend anyway is decoration wearing an information costume — cut it. The counter-example that proves the test isn't dogma: souls in a soulsborne stay on screen permanently because the currency's fragility is the emotional core of the loop. You carry them, you can lose them, and the number staring at you is the tension. If an element can make that kind of argument, it stays. If its argument is "players might want to know," it goes.

### 2.2 Glacial-information test

Does this information change dramatically over a short period? Fast information — HP, action pips, cooldowns, whose turn it is — earns HUD residency because glancing at it mid-fight has value. Glacial information changes graaaadually: an XP bar that grows a picometer per kill by mid-game has stopped informing anyone, and what's easily ignored shouldn't be there. Glacial info gets sidelined to popups, insets, hovers, and toggles where the player summons it when they actually want it. For delve, the bar is: does this change within the current actor's turn? If yes, it may live on the HUD. If it changes per-encounter or slower, it demotes.

### 2.3 Design for the chaos moment

HUDs get designed in a quiet editor and used when shit gets real. The classic case is a boss fight — nervous glances flicking between your health and the boss's, and a cooldown indicator too obscure to read at a glance costs you the fight and possibly the controller. Judge every element against maximum competing stimulus, never against a calm mockup. Delve's chaos moment is concrete: a reaction prompt open mid-enemy-turn, damage popups in flight, several AI moves resolving back to back, the log ticker scrolling. If an element is illegible or its interaction is ambiguous in that exact frame, it fails, whatever it looks like on a static grid.

### 2.4 Trim everything except fonts

Compare Demon's Souls' enormous HUD to Elden Ring's decades-later refinement: trimmed to a corner, fading entirely at full health. Chrome shrinks relentlessly — borders, padding, panel real estate all get squeezed until something breaks. Fonts move the other way: get them to a comfortable reading size, then go bigger. Lots of people have garbage-eyes, but everyone deserves to see your game. Delve's floor is 14 px and that size is reserved for genuine hints; body text is 18 px. Any proposal to shrink a font to fit a layout is a layout problem.

## 3. Case law

Verdicts from the combat HUD rebuild. These are precedent.

- **Input legend — killed.** A permanent panel of keybindings is glacial information at its most glacial: it changes never. Replaced by a help overlay toggled on Tab/H, non-modal, playable underneath.
- **Combat log — demoted.** Full history is glacial; the last few events are fast. The passive surface is a 3-line ticker of the most recent non-detail entries, hidden entirely while it holds none — an empty chrome strip is pure cost; L (or clicking the ticker) expands the full history. Non-modal.
- **Action bar — the anchor surface.** It passes all four tests outright: every element on it changes within the turn and gets read under pressure. It inherits the size budget the killed and demoted panels gave up. Actor identity, HP vitals, three action pips, action buttons with hotkey captions, End Turn.
- **Spell/skill chips — foldered.** The flat chip wall (17 always-on chips stacked three rows above the bar) failed kitchen-sink and the chaos moment — a wall of same-weight text competing with the board — and was reorganized into Spells/Skills category flyouts on the bar (Q/E), one open at a time, closed the moment a chip is picked.
- **Turn order — trimmed.** Chips carry name, a 4 px HP bar, and a hard current-actor highlight. Everything else the old chips displayed failed the chaos test: under stimulus you read "who's next" and "how hurt," nothing more. Dead units dim to 0.45 alpha.
- **Unit inspect — passes by being hover-only.** AC, conditions, and exact HP are wanted information that nobody needs permanently. Hovering a unit shows the panel; moving off hides it. Zero cost when unsummoned.
- **Reaction prompt — the peak-stimulus modal.** It interrupts the enemy turn, so it gets the full modal treatment: dimmed backdrop, opaque panel, 26 px title, one accented default button, Enter/Y to use and Esc/N to skip. It is the element the chaos test was written for.
- **Victory banner — stays modal.** Combat is over; nothing underneath needs interaction. Dim, 42 px outlined result text, restart button.

## 4. Visual language

Clean flat tactical — Into the Breach / Slay the Spire energy. Flat fills, hard 1 px lines, one warm accent against a cool dark ground.

### 4.1 Palette

The theme resource is the single source of color truth (section 5). These are the authored values.

| Name | Hex | Alpha | Role |
| --- | --- | --- | --- |
| `accent` | `e4b84e` | 1.0 | Gold. Active states, accent strips, default buttons, available pips |
| `ally` | `6fa85c` | 1.0 | Ally team identity (chips, strips, bars) |
| `enemy` | `c05b4c` | 1.0 | Enemy team identity |
| `ink` | `0c0e11` | 1.0 | Near-black. Text outlines over open ground, deepest fills |
| `surface` | `171a1f` | 0.92 | Standard translucent panel over the 3D scene |
| `inset` | `0e1013` | 0.92 | Recessed sub-panel: ticker, preview card, tooltips |
| `line` | `353b46` | 1.0 | 1 px borders and separators |
| `text` | `e8e6df` | 1.0 | Body text |
| `text_dim` | `9ba1ac` | 1.0 | Secondary text, detail log entries |
| `text_disabled` | `5f6570` | 1.0 | Disabled control text |
| `text_inverse` | `1a1508` | 1.0 | Dark text on accent fills (active turn chip, accent buttons) |
| `hp_high` | `73b55d` | 1.0 | HP fill/text, ratio > 0.5 |
| `hp_mid` | `d9a94c` | 1.0 | HP fill/text, ratio > 0.25 |
| `hp_low` | `d96555` | 1.0 | HP fill/text, ratio <= 0.25 |
| `victory` | `eed065` | 1.0 | Victory banner text |
| `defeat` | `e07169` | 1.0 | Defeat banner text |
| `modal_dim` | `0a0c10` | 0.60 | Full-screen backdrop behind modals |

Log severity colors, indexed by `PF2e.Core.CombatLogSeverity` ordinal, carried verbatim from the previous palette (each cleared 4.5:1 on the recess they ride):

| Name | Hex | Severity |
| --- | --- | --- |
| `log_info` | `ccc7b8` | Info |
| `log_hit` | `8bcd79` | Hit |
| `log_crit_hit` | `e6c45f` | CriticalHit |
| `log_miss` | `a5a28c` | Miss |
| `log_crit_miss` | `e67667` | CriticalMiss |
| `log_healing` | `6fd0b4` | Healing |
| `log_condition_applied` | `c496e1` | ConditionApplied |
| `log_condition_removed` | `a4a29c` | ConditionRemoved |
| `log_action_header` | `e5ba7e` | ActionHeader |
| `log_reaction` | `f2a260` | Reaction |

Contrast rule: every surface is dark, so every text and accent color is light. Target 4.5:1 for body text against the surface it sits on; verify before adding or changing a color.

### 4.2 Type scale

| Size | Variation | Use |
| --- | --- | --- |
| 14 px | `HintLabel` | Targeting hints, toggle captions. The floor — nothing renders smaller |
| 16 px | (chip/tooltip styles) | Turn chips, action chips, conditions line, ticker, tooltips |
| 18 px | default | Body text, vitals, log expanded view, help overlay |
| 22 px | `HeadingLabel` | Actor names, panel headings, preview stats |
| 26 px | `TitleLabel` | Modal titles |
| 42 px | `BannerLabel` | Victory/defeat result, dark outline |

### 4.3 Chrome rules

- Borders and separators are 1 px `line`. Accent strips are 2 px `accent` (3 px team-color strip on unit inspect).
- Standard padding is 8 px. Ask for more only with a reason.
- Panels over the 3D scene use `surface` at 0.92 alpha. Modals are opaque.
- Any text floating over open ground carries a dark `ink` outline. No light color is safe over the 3D scene without one.
- Disabled state comes from the themed disabled styles, never from dimming a container's Modulate — dimmed containers take their text below readable contrast.
- Pips render only through the shared `PipRow` component (`scenes/ui/pip_row.tscn`) — the bar's 14 px action-economy pips and the chips' 8 px cost pips are both instances of it, so pip visuals change in one place.
- Action costs render as pips, never inline text: one 8 px square per action (`PipFilled` accent fill, 1 px `ink` border, `PipDisabled` dims them with the owning chip's disabled state); tooltips spell the cost out in words.
- Hotkey captions render as keycaps, never inline text: the action label (18 px) plus a separate `Keycap` chip (inset fill, 1 px `line` border, 4 px padding) holding the key name at 14 px `text_dim`. The key must read as an input, not as part of the action's name.

## 5. Theme mechanics and the pack-swap path

One resource: `assets/ui/ui_theme.tres`. Hand-authored, 100% StyleBoxFlat, no ext_resources, no font resource, `default_font_size = 18`. Every palette color from section 4.1 lives in it as a theme color item under the synthetic type `Palette`.

- `scripts/ui/UiColors.cs` lazy-loads the theme and exposes the code-side API: `Ally`, `Enemy`, `Victory`, `Defeat`, `HpFillColor(float)` (thresholds 0.5 / 0.25), and `LogSeverity[]` by ordinal. Load lazily from `_Ready`/render paths, never a static initializer.
- `scripts/ui/ThemeNames.cs` holds string consts for every variation set from code, plus `HpBarFor(ratio)`. Typos in variation names fail silently to the base style, so no literal variation strings in scripts.
- Variations: `HudPanel`, `HudInset`, `Keycap`, `ModalPanel`, `AccentButton`, `ActionChip`, `PipFilled`/`PipSpent`/`PipDisabled` (applied only by the `PipRow` component), `TurnChipAlly`/`TurnChipEnemy`/`TurnChipActive`, `HpBarAlly`/`HpBarEnemy`/`HpBarHigh`/`HpBarMid`/`HpBarLow`, `HintLabel`, `HeadingLabel`, `TitleLabel`, `BannerLabel`, `FloatingLabel`.
- Scenes carry no `theme` property and no instance-level style overrides. Styling reaches a node through a variation name or through UiColors, never any other way.

The pack-swap path is why the discipline pays: when a purchased UI art pack arrives, swapping a variation's StyleBoxFlat for a StyleBoxTexture inside the one .tres reskins every consumer. Scenes reference only variation names and scripts only ThemeNames/UiColors, so neither changes. Any styling that bypasses the theme breaks this promise and gets rejected in review.

## 6. Input and modality

UI code reads input actions only — never raw keycodes. The combat actions:

| Action | Keys | Meaning |
| --- | --- | --- |
| `combat_action_1..4` | 1–4, Kp 1–4 | Action bar buttons |
| `combat_end_turn` | Space | End turn |
| `combat_spells` | Q | Toggle Spells flyout |
| `combat_skills` | E | Toggle Skills flyout |
| `combat_confirm` | Enter, KpEnter, Y | Accept modal prompt |
| `combat_decline` | Escape, N | Decline modal prompt |
| `combat_help` | Tab, H | Toggle help overlay |
| `combat_log_toggle` | L | Toggle log expansion |

`HudRoot` owns modal state. It exposes a refcounted `ModalActive` (clamped at zero) with `PushModal()`/`PopModal()` and a `ModalChanged` event. Rules:

- Every modal panel pushes on show, pops on hide, and pops in `_ExitTree` if still open. A leaked refcount wedges every hotkey in the scene.
- Non-modal panels gate their hotkeys on `_hud?.ModalActive == true` and go inert while a modal is up. HudRoot itself stops handling `combat_help`/`combat_log_toggle` while modal.
- Modal panels take keys in `_Input`, gated strictly on `Visible`, and call `SetInputAsHandled`. This beats `GridInput3D`'s `ui_cancel` handling by input phase, so Escape closes the prompt before it can cancel targeting — precedence by phase, made explicit, never by tree order.
- Panels resolve HudRoot via `GetParentOrNull<HudRoot>()` and tolerate null, so they still run standalone in spikes.

## 7. Information honesty

The view-model layer masks what the player hasn't earned the right to know — recall checks, hidden AC, unrevealed stats. The UI's job is to keep that masking intact: render the pre-masked `*Text` string fields from view records, and never format the raw ints sitting next to them. A panel that prints `view.Ac` instead of `view.AcText` has silently deleted a game mechanic. Any new panel that wants a number asks the view model for a masked string first.

Honesty also runs the other way: a disabled control must explain itself on hover, as a tooltip line in the `Unavailable: <reason>` format, with the reason derived in the rules layer from the exact gate that failed (never invented by the UI, and never leaking masked knowledge). A grey button with no reason is a question the player can't answer.

Follow-up debt: the 3D unit-token HP bars in `UnitVisual3D` use their own color literals and 0.6/0.3 thresholds, while the HUD uses the palette colors at 0.5/0.25. The same HP ratio can read as two different severities depending on where you look. Unify on the HUD's thresholds and `UiColors` when the 3D presentation layer gets its pass.

## 8. Review checklist

Copy into the PR or review notes and check each line.

```
UI review — delve/design/ui_guidelines.md

The four tests
- [ ] Kitchen-sink: every new/changed element justifies existing at all; removal was considered first
- [ ] Glacial-information: everything permanently visible changes within the current actor's turn; slower info is behind a hover/toggle/expandable
- [ ] Chaos moment: layout judged with a reaction prompt open, popups in flight, and AI moves resolving — every element still legible and unambiguous
- [ ] Fonts: nothing below 14 px; body text at 18 px; no font was shrunk to fit chrome

Architecture
- [ ] All styling via theme variations (ThemeNames consts in code) or UiColors — no scene `theme` property, no instance-level style overrides, no color literals
- [ ] Input read via combat_* actions only — no raw keycodes
- [ ] Modal panels push/pop HudRoot correctly (including _ExitTree); non-modal hotkeys gate on ModalActive
- [ ] Only pre-masked *Text fields rendered — no raw stat ints formatted in UI code
```
