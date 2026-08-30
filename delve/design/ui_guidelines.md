# delve UI guidelines

## 1. What this governs

Every 2D Control-layer surface in delve: combat HUD panels, modals, overlays, tickers, and any future menu work. The 3D presentation layer (unit tokens, damage popups, grid overlays) follows its own rules and is out of scope here, with one debt noted in section 7.

Use this document two ways. When designing a new surface, walk it through the four tests in section 2 before opening the editor. When reviewing existing or submitted UI, run the checklist in section 9 and cite case law from section 3 — a verdict already reached applies to the next element of the same kind unless someone argues why it shouldn't.

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

Verdicts from the hero-select overview rebuild. A calm menu is the opposite of the chaos moment, so chrome may breathe — but the first version of this screen was a printed Pathfinder character sheet, and a printed character sheet read on a screen is a spreadsheet: bounded blocks, aligned value columns, rank letters, every prepared spell by name. It was replaced wholesale. Four borrowed principles did the replacing, each from a game that solved this first.

- **One screen, no click and no scroll.** The Beamdog verdict on the BG:EE 2.0 record sheet is the cautionary case: the tabbed rewrite organised the data and destroyed the glance, so "with the old screens you only had to scroll — with the new UI, you have to first click and then scroll," and class abilities ended up "hidden entirely from view." Delve's sheet fits whole for all five characters, asserted in the spike. ([Beamdog forums](https://forums.beamdog.com/discussion/48463/character-record-sheet-ui-feedback))
- **The first screen is the claim about what matters.** BG3's Character panel keeps AC, HP, the abilities and the equipment permanently visible and files race, background, size, weight, proficiencies and carrying capacity behind a second level. Nielsen Norman states it generally: "initially, show users only a few of the most important options," and the initial display must not be so crowded that it fails to focus attention. What survives onto delve's page is four numbers, six abilities and seven labelled lines. ([Gamepressure](https://www.gamepressure.com/baldurs-gate-iii/interface/zad9f7), [NN/g](https://www.nngroup.com/articles/progressive-disclosure/))
- **The hover carries the arithmetic, per source.** BG3 puts the whole modifier breakdown on the tooltip and lets a keyword inside a tooltip open its own; "AC 17" is readable precisely because nobody printed "10 + 4 armour + 2 shield + 1 ring" beside it, and the breakdown enumerates contributors separately so the player can see which item to swap. Its known failure is inconsistency — players stop trusting a hover that only sometimes expands — so on delve's sheet every element explains itself, and the spike counts the ones that do not. ([Larian forums](https://forums.larian.com/ubbthreads.php?ubb=showflat&Number=878694))
- **A tall portrait, and text sized for the display you actually have.** Tchos rebuilt the NWN2 sheet's square portrait as a roughly 1:2 vertical frame because square portraits "show only their heads" and made party members hard to tell apart, and reverted a parchment reskin whose near-white body text was "nearly illegible" against it. Delve gives the header band a 240x300 plinth with the figure at a 7x integer scale, keeps the 18 px body, and no font shrank to make this layout fit. ([Tchos](http://tchosgames.blogspot.com/2012/03/neverwinter-nights-2-interface-mod.html))

- **Featured sheet — an overview, not a sheet.** The screen's one job is choosing which single character walks into the depths, so about 60% of the frame goes to one of them: a header band of portrait, 42 px name and one identity line, an ability band, and one line each for saves, senses, skills, strikes, defences, spells and features. Comparison happens by moving along the roster, not by reading five sheets at once.
- **Hand-written blurbs — killed.** The Stat focus / Playstyle / Abilities copy argued for a character in prose the build had to be checked against. Every word comes off the level-2 `PF2eCharacter` the preset builds (`HeroSheetBuilder` → `HeroSheetData`, Godot-free), so the sheet cannot say anything the build does not and there is no copy left to drift.
- **The numbers that pop — four.** HP, AC, the key ability ("WIS"), and one signature number: a caster's spell DC, a martial's leading strike ("LONGSWORD +10"). 26 px `SheetKeyValue` in accent with 16 px dim captions, and that band is the only accent ink on the page. The previous rule allowed six and spread them over three rows; six accented numbers in three places is a colour scheme, not a hierarchy.
- **Key ability — the one accent border.** `SheetBoxKey` (2 px accent) marks the ability the class is built on and is the sheet's only accent-bordered box. Its modifier stays body ink: the border is the emphasis, so the number does not shout twice. The headline box names that ability and stops there — "STR", where it used to read "STR +4" — because the rail box under the plinth prints the modifier and the hover spells the arithmetic out. A headline that repeats a number printed in the rail below it spends one of the four slots on nothing.
- **Ability scores — demoted to a rail.** Six boxes spanning the page gave the abilities the weight of the four headline numbers, and the ability modifier is the number a player acts on least: the strike, the save and the skill on the same page already carry it. They move to a 240 px rail under the plinth, sharing the plinth's two edges — two 114 px columns on the same 12 px gutter the headline boxes keep, physical (STR, DEX, CON) on the left and mental (INT, WIS, CHA) on the right, the way PF2e splits them. The box keeps all three of its lines around a 20 px modifier, with the caption and the score at the 14 px floor, so a rail box stands 84 px against a headline box's 196 px. The overview rows move up beside the rail, one gutter past its right edge and top-aligned with it, and take the width the band used to span.
- **Bounded blocks — killed.** Seven `HudInset` blocks with 22 px headings were seven small panels competing at the same weight. The overview replaced them with alignment: a label column in 16 px dim uppercase, sized to its own widest word and right-aligned so every label ends on one edge and every row's content starts 16 px past it, 32 px between rows and 48 px between bands. Common region grouped things; a shared edge groups them for free and costs no chrome.
- **Rank letters — off the page.** "T", "E", "M", "L" in a column beside every number was information nobody reads while choosing and the single largest source of visual noise. The rank is spelled out in words on the hover, with what it is worth at this level. The spike fails the sheet if a bare rank letter reaches any printed row.
- **Skills, strikes, defences, spells, features — chips of names.** A `StatChip` carries the name and nothing else ("Athletics", "Steel Shield", "Sneak Attack"); the modifier, the breakdown and the description are on its hover. A skill's "+8" on the page invites arithmetic the player cannot act on yet.
- **Spells — counted, not listed.** "Cantrips ×4 · Rank 1 ×4 · Focus ×1", not sixteen spell names across two rows. The count is the decision-relevant fact; the names, their action costs and a sentence each are on the chip's hover, straight out of the loaded pack.
- **Weapon traits — off the page entirely.** The earlier rule printed three traits and collapsed the rest into "+N". Even three was a second line of caption text under every strike. The full trait list, each with a one-line definition, is on the strike's hover.
- **Overflow — two lines, then "+N".** A chip row measures what fits and stops there, with the names it dropped on the "+N" chip's hover. The sheet's height is the layout's, not the character's: a build with twenty feats costs the same two lines as one with four.
- **Scrolling — designed out, not styled.** The old sheet scrolled and the caster's features fell below the fold. The overview fits at 1080p for every character and fills 91-94% of its panel, and `hero_select_spike` measures the laid-out height against the panel - it fails a sheet that overflows and a sheet that fills less than 85%, because a panel with a dead lower third is the other half of the same mistake.
- **Empty rows — absent.** A non-caster gets no spells row, and a row with nothing in it is not printed at all. The one deliberate exception is Defences, which always prints an armour chip: "Unarmoured" is why the wizard's AC is 16, not an absence.
- **Roster cards — trimmed to identity.** Portrait thumb, name, role, and nothing else. The numbers live on the featured sheet: numbers on a card invite comparing numbers, and only the character being read has enough room to print them honestly.
- **Page grid — one margin, one gutter, one set of shared edges.** 32 px outer margin, a 24 px gutter between the featured sheet and the roster, 28 px of padding inside the sheet panel. The title starts on the sheet's left edge, the Roster heading sits one gutter above the panel's top edge, the roster list spans exactly the panel's height so the fifth card's bottom meets the panel's bottom, and Embark is a fixed 280 px against the roster's right edge - a button the width of the whole column is a banner, and the page's loudest ink should not out-weigh the sheet it confirms. The headline band and the overview end on one right edge and start on one left edge; the ability rail runs under the plinth on both of the plinth's edges, and the overview starts one gutter past the rail. `HeroSelectGrid` measures every one of those edges off the laid-out tree, because a screenshot cannot tell 4 px of slop from intent.
- **Pick state — accent border plus caption.** `RosterCardSelected`'s 2 px accent border and "STARTING CHARACTER". Exactly one card is picked, so there is no slot number left to disambiguate and no strip needed.
- **Disabled entries — greyed, never hidden.** A locked entry stays on the roster with its "Unavailable: …" reason and the `RosterPortraitLocked` scrim over its thumb. A roster that hides what exists cannot show what unlocking would buy.
- **Hint line — 18 px, not 14.** The line under the title is what the screen is waiting for, not a keybinding footnote, so it reads at body size through `ScreenHint`. The 14 px floor stays reserved for in-fight hints and captions.
- **Back button — not built.** Hero select is the first screen of a run; there is nothing behind it. Esc gives the pick back instead, which is the undo the screen actually needs.

## 4. Visual language

Clean flat tactical — Into the Breach / Slay the Spire energy. Flat fills, hard 1 px lines, one warm accent against a cool dark ground.

### 4.1 Palette

The theme resource is the single source of color truth (section 5). These are the authored values.

| Name | Hex | Alpha | Role |
| --- | --- | --- | --- |
| `accent` | `e2683c` | 1.0 | Ember. Active states, accent strips, default buttons, available pips |
| `ally` | `6fa85c` | 1.0 | Ally team identity (chips, strips, bars) |
| `enemy` | `d94f4f` | 1.0 | Enemy team identity |
| `ink` | `0d0a08` | 1.0 | Near-black. Text outlines over open ground, deepest fills |
| `surface` | `1d1713` | 0.92 | Standard translucent panel over the 3D scene |
| `inset` | `16120e` | 0.92 | Recessed sub-panel: ticker, preview card, tooltips |
| `line` | `3e352c` | 1.0 | 1 px borders and separators |
| `text` | `ede7dc` | 1.0 | Body text |
| `text_dim` | `a49a8c` | 1.0 | Secondary text, detail log entries |
| `text_disabled` | `6b6258` | 1.0 | Disabled control text |
| `text_inverse` | `1a0e06` | 1.0 | Dark text on accent fills (active turn chip, accent buttons) |
| `hp_high` | `73b55d` | 1.0 | HP fill/text, ratio > 0.5 |
| `hp_mid` | `d9a94c` | 1.0 | HP fill/text, ratio > 0.25 |
| `hp_low` | `d96555` | 1.0 | HP fill/text, ratio <= 0.25 |
| `victory` | `eed065` | 1.0 | Victory banner text |
| `defeat` | `e07169` | 1.0 | Defeat banner text |
| `modal_dim` | `0c0906` | 0.60 | Full-screen backdrop behind modals |
| `steel` | `7d8a96` | 1.0 | Cold-steel secondary accent (reserved) |
| `char_player` | `c25b63` | 1.0 | Aldric's identity accent |
| `char_elara` | `a878d8` | 1.0 | Elara's identity accent |
| `char_tharr` | `7fc4d8` | 1.0 | Tharr's identity accent |
| `char_fenwick` | `4f7fd0` | 1.0 | Fenwick's identity accent |

The identity is **Emberlight** (adopted 2026-08-24, replacing the gold-on-cool-dark scheme): torchlight ember on warm charcoal. The `char_*` colours own CHARACTER SURFACES outright: on the hero-select sheet and roster cards, every accent role (name rule, portrait strip, headline strips and values, key-ability border, section diamonds, chosen-card border, captions, tooltip labels) takes the character's palette colour via `UiColors.CharacterAccent(id)`; neutral greys and panel chrome stay on the game palette. General screens use the ember accent and never the character colours. Character surfaces are the one sanctioned place for instance colour overrides — the values still come from the Palette, never from literals.

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
| 14 px | `HintLabel` | Targeting hints, toggle captions, the ability rail's caption and score. The floor — nothing renders smaller |
| 16 px | `CardRoleLabel`, `ChipLabel` | Turn chips, action chips, conditions line, ticker, sheet chips, every secondary caption and row label |
| 18 px | default, `ScreenHint` | Body text, vitals, log expanded view, help overlay, menu hint lines |
| 20 px | `SheetValue` | The ability rail's modifiers |
| 22 px | `HeadingLabel` | Actor names, panel headings, tooltip titles |
| 26 px | `TitleLabel`, `SheetKeyValue` | Modal titles; the sheet's four headline numbers in accent |
| 42 px | `BannerLabel` | Victory/defeat result, dark outline |

### 4.3 Chrome rules

- Borders and separators are 1 px `line`. Accent strips are 2 px `accent` (3 px team-color strip on unit inspect).
- Standard padding is 8 px. Ask for more only with a reason.
- Panels over the 3D scene use `surface` at 0.92 alpha. Modals are opaque.
- Any text floating over open ground carries a dark `ink` outline. No light color is safe over the 3D scene without one.
- Disabled state comes from the themed disabled styles, never from dimming a container's Modulate — dimmed containers take their text below readable contrast.
- Pips render only through the shared `PipRow` component (`scenes/ui/pip_row.tscn`) — the bar's 14 px action-economy pips and the chips' 8 px cost pips are both instances of it, so pip visuals change in one place.
- Action costs render as pips, never inline text: one 8 px square per action (`PipFilled` accent fill, 1 px `ink` border, `PipDisabled` dims them with the owning chip's disabled state); tooltips spell the cost out in words.
- Spell facts render in one shorthand grammar (`scripts/flow/SpellShorthand.cs`), fixed order `cost · range/area · defence · dice · duration`, tokens `nA` (actions), `n ft` / `n-ft cone`, `Fort/Ref/Will save` (`basic X` for basic saves), `spell atk`, `dice type` / `heal dice`, `sustained`. A fact the spell lacks is skipped, never padded; uninformative durations ("varies") are dropped. The same line format serves every spell row on every card.
- Explanatory depth renders through one shared hover panel (`scenes/ui/sheet_tooltip.tscn` + `scripts/ui/SheetTooltip.cs`), never through a popup built per element: `SheetTooltip` variation (opaque — a translucent panel over a menu shows the text underneath it), 22 px title, 16 px dim subtitle, 18 px body, held to one measure of at most 440 px, shown after 0.1 s of hover and clamped inside the viewport. The panel that owns the surface owns the wiring; a component announces what explains itself and never reaches for the tooltip. The content is a `SheetTip(Title, Subtitle, Body)` assembled in the Godot-free data layer, so a spike asserts on the same words the hover prints. The engine's own `TooltipText` popup stays reserved for the one-line `Unavailable: <reason>` case.
- Hotkey captions render as keycaps, never inline text: the action label (18 px) plus a separate `Keycap` chip (inset fill, 1 px `line` border, 4 px padding) holding the key name at 14 px `text_dim`. The key must read as an input, not as part of the action's name.

## 5. Theme mechanics and the pack-swap path

One resource: `assets/ui/ui_theme.tres`. Hand-authored, 100% StyleBoxFlat, `default_font_size = 18`. One exception to the no-ext_resources rule: the display font (`assets/fonts/Cinzel-SemiBold.ttf`, OFL, credited in `assets/fonts/CREDITS.md`) loads as an ext_resource and is instanced at weight 600 for display variations only (`BannerLabel`, `TitleLabel`, `HeadingLabel`, `TipTag`, `RowLabel`, `SheetCaption`, `SheetCaptionSmall`). Body text stays on the default sans — the display face is for names, titles and captions, never paragraphs. Every palette color from section 4.1 lives in it as a theme color item under the synthetic type `Palette`.

- `scripts/ui/UiColors.cs` lazy-loads the theme and exposes the code-side API: `Ally`, `Enemy`, `Victory`, `Defeat`, `HpFillColor(float)` (thresholds 0.5 / 0.25), and `LogSeverity[]` by ordinal. Load lazily from `_Ready`/render paths, never a static initializer.
- `scripts/ui/ThemeNames.cs` holds string consts for every variation set from code, plus `HpBarFor(ratio)`. Typos in variation names fail silently to the base style, so no literal variation strings in scripts.
- Variations: `HudPanel`, `HudInset`, `Keycap`, `ModalPanel`, `AccentButton`, `ActionChip`, `PipFilled`/`PipSpent`/`PipDisabled` (applied only by the `PipRow` component), `TurnChipAlly`/`TurnChipEnemy`/`TurnChipActive`, `HpBarAlly`/`HpBarEnemy`/`HpBarHigh`/`HpBarMid`/`HpBarLow`, `HintLabel`, `HeadingLabel`, `TitleLabel`, `BannerLabel`, `FloatingLabel`.
- Menu-screen variations: `ScreenGround` (full-screen opaque menu field, no border — nothing sits underneath a menu), `ScreenHint` (18 px `text_dim`, the gate line under a menu title), `RosterCard`/`RosterCardSelected`/`RosterCardLocked` (the card's three looks; hover is a state inside each one, not a fourth variation), `RosterPortrait` and `RosterPortraitLocked` (the portrait recess and the scrim over it), `StatChip`, `CardRoleLabel` (16 px `text_dim` — the shared caption style for every secondary word on a menu surface, not just a card's role line).
- Hero-sheet variations: `SheetKeyValue` (26 px `accent`, the four headline numbers), `SheetValue` (20 px `text`, the ability modifiers), `SheetBoxKey` (the inset box with a 2 px accent border, used only for the key ability) and `SheetTooltip` (the hover panel — opaque, and it shares its StyleBoxFlat with the engine-tooltip `TooltipPanel` type so both tooltip looks reskin together). Sheet boxes reuse `HudInset`, chips reuse `StatChip`/`ChipLabel`, row labels and headline captions reuse `CardRoleLabel`, the rail box's caption and score reuse `HintLabel`, and the tooltip title reuses `HeadingLabel`.
- `VScrollBar`'s track and grabber styles carry 4 px horizontal content margins. Without them the bar computes to zero width and a scrolling panel looks like a clipping bug. Only the combat log scrolls; the hero sheet is sized to fit instead.
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

Follow-up debt: the 3D unit-token HP bars in `WorldHpBar` use their own color literals and 0.6/0.3 thresholds, while the HUD uses the palette colors at 0.5/0.25. The same HP ratio can read as two different severities depending on where you look. Unify on the HUD's thresholds and `UiColors` when the 3D presentation layer gets its pass.

## 8. Inventory screens

Delve has no inventory surface yet, but the run loop is heading toward one — loot after fights, party gear between them. These rules are in force from the first mockup so the screen never needs walking back. Where they overlap the four tests, the tests win.

### 8.1 Badge what is new

The player takes a boss's ransom in loot, opens the inventory, and finds a grid that looks exactly like it did last time — the reward evaporated. Badge every unseen item: one small, prominent marker on the slot, cleared the first time the player actually sees it (a visit to the panel, or the selection sweeping over it), never persisting after. The same pattern scales upward: a count on a navigation header carries "new feat available" or "quest updated" the way a phone's home screen does. Delve's badge is drawn in accent ember from the Palette — never red, which this UI reserves for the enemy. Elden Ring shipped item badging in patch 1.12, two years after release; delve ships it the same day it ships an inventory.

### 8.2 Split the screen 1/3 to 2/3

Two pieces of information are never equally weighted, and an inventory screen is the proof: a grid of items and a detail pane for the selected one cannot both be the point. Carve the screen near the golden mean — 1/3 against 2/3 — and give the 2/3 to whichever pane the design says is primary (in an attaché-case design the grid is the point; in a stat-heavy RPG the detail pane usually is). The proportion structurally encodes the priority call and answers the blank-canvas problem before it starts. Delve already ruled this way once: hero select is a 1/3 roster rail against a 2/3 featured sheet, and that verdict is precedent.

### 8.3 Rarity without skittles

Rarity color ladders are mnemonic shorthand and shared culture — the MMO gray-green-blue-purple-orange, and PF2e's own common/uncommon/rare/unique hues — and they cannot be reassigned, any more than a traffic light can swap red and green. But honoring the canon does not mean painting with it: a late-game inventory in full rarity fill is a bag of skittles at war with the Emberlight palette. Ruling: rarity is a thin outline — on the slot's border or the item's silhouette — with values held in the Palette like every other color, never a fill and never a symbolic glyph (a rarity icon at 32 px is unreadable noise). The canon hue stays recognizable; the quantity of ink drops.

### 8.4 Navigation is designed, not assumed

A controller is no substitute for a mouse, and an inventory grid is where that hurts most. Before the layout is final, answer in writing: does the grid move on d-pad, stick, or both? How does a list scroll, and how does the player know it *can* — a grid that ends flush on its last visible row hides its own scrolling, so a scrollable grid always clips a partial row as its own affordance. If cells are irregular, define what lateral and diagonal movement do before a player finds the ambiguity. A faux-mouse cursor driven by the stick is the sluggish compromise that concedes the layout failed. If effortless traversal cannot be explained in a sentence or two, redesign the screen, not the input. (Delve is mouse-and-keyboard today with all input through `combat_*` actions — section 6 — so the controller answer can wait, but the layout that makes it easy cannot.)

### 8.5 The permanent ledger

The glacial-information test (2.2) evicts currency, XP, and their kin from the HUD; the inventory is where that information permanently lives. Surface gold and every earned resource here, plainly. If the screen allows healing or consumable use, party vitals belong on it too — otherwise the player is influencing numbers they cannot see. Item gates follow section 7 verbatim: an item the character cannot use yet says so in the `Unavailable: <reason>` form with the remedy in the same breath (`Unavailable: needs level 13`). Never present a problem without cheerfully presenting its answer.

### 8.6 Teach yourself the Big Three

An inventory hides more modes and states than any other screen, and the fastest way to find out whether it works is to onboard yourself through it as if it were the game's first five minutes. Three acts, in order: see detail on an equipped item; compare a new item against the equipped one; slot the new item in. Every other complexity flows from those three. If walking a new player through them feels cumbersome to script, the screen will be worse to learn than it was to teach — redesign the system, not the tutorial.

## 9. Review checklist

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

Inventory surfaces (when the change touches one)
- [ ] New/unseen items badge in accent ember; badge clears on first sight and never returns
- [ ] Panes split by information priority, near 1/3 to 2/3
- [ ] Rarity shown as a thin Palette-held outline — no fills, no rarity icons
- [ ] Scrollable grids clip a partial row; traversal defined for every cell pattern
- [ ] Currency/XP surfaced; vitals shown if the screen can spend or heal; gates use Unavailable: reason + remedy
```
