# Player information and interface audit

Reviewed 2026-09-19. This records the original analysis; subsequent implementation is documented in [the in-scene redesign](ui_redesign.md).

## Evidence and scope

Reviewed the runtime title, duelist selection, matchup, attack with card preview, defense, and Reserve tray, plus their scene and script implementations. Captured 1600x900 screens and checked defense and Reserve at 1280x720. Duel captures use the first two shipped decks, seed 5, and the development attack policy. These are reproducible sample states, not a complete playtest of all decks, resolutions, keyboard navigation, online play, or crowded late-game boards.

Screenshots from this review are in `C:/Users/Midge/AppData/Local/Temp/zenith-ui-audit/`: `title.png`, `select.png`, `versus.png`, `attack.png`, `defense.png`, `defense720.png`, and `reserve-check.png`. These are temporary local evidence, not repository assets.

Godot initially crashed when it could not write its default user log. Redirecting `--log-file` into the temporary audit directory allowed captures. Runs also reported a root certificate store error; no network flows were tested. An initial Reserve capture used `--dev-steps=0`, which does not stop at the opening prompt; it was replaced by the explicit Reserve stop above.

## Main finding

Screen area and visual emphasis do not consistently follow the player's decision. The table reserves large spaces for empty zones while playable cards, current combat resources, and explanations are small or distributed across distant surfaces. Improving decoration alone will preserve that problem.

Keep the 3D table identity, rules-aware forecasts, legal-card highlighting, batch selection, detailed inspection, and event-by-event state presentation. Reorganize how players access them.

## Reference direction clarified by the player

The player explicitly likes Magic: The Gathering Arena and Hearthstone as digital card-game UI references. Favor an immersive board, expressive cards, direct interaction, and information attached to the relevant game object. Treat the layout sketch below as an information grouping exercise; it does not require a permanent dashboard sidebar.

This also refines the compact-hand recommendation: preserve recognizable card silhouettes and artwork. Prototype a larger, overlapping hand that expands a hovered or focused card close to its original position. Readable costs, identity, and forecasts should survive at rest; full rules can appear on expansion. Compare that against the current distant left-side preview before committing to a separate compact card design.

Lessons to apply to Zenith:

- Anchor each side around its duelist. Attach Life, Energy, Might, and ascension progress to that identity, with a clear controlling-Ally treatment. Reduce detached corner stat panels.
- Let occupied permanents define the board's visual weight. Use quiet grouping and spacing instead of a prominent outline for every possible empty slot.
- Put feedback where the action occurs: highlight a selected source and valid targets, show the attack relationship, and animate the result on the affected object. Preserve readable timing and the existing event-state synchronization.
- Keep a stable, compact action control that names the current decision. Zenith has alternating combat decisions within a turn, so a generic End Turn button would conceal essential state.
- Use on-demand card expansion, pile browsers, and recent-event history to keep the resting board calm. Do not require an expanded log to understand why a resource changed.
- Make availability, hover, selection, targeting, commitment, and resolution visibly distinct. Check cancellation and keyboard equivalents alongside pointer interaction.

Reference evidence: Wizards documents Arena's expandable/tucked hand, detailed card inspection, zone browsers, and layout changes for smaller displays in its [January 2021 interface overview](https://magic.wizards.com/en/news/mtg-arena/mtg-arena-state-game-january-2021-01-21). Blizzard documents contextual progress above the hero portrait in its [Saviors of Uldum announcement](https://hearthstone.blizzard.com/en-us/news/23037181), plus improvements to enlarged-card placement in its [iPad interface notes](https://hearthstone.blizzard.com/en-us/news/14070049/hearthstone-patch-notes-1005314-5-8-2014). These are historical examples of interaction patterns, not a claim about every current client detail. The Zenith adaptations above are design proposals.

Start with a combat-screen prototype containing both duelists and resources, occupied permanents, an expanded hand card, and a defense decision. Include representative resource motion and action feedback in that prototype so clarity and game feel are evaluated together.

## Expressive resource displays and board effects

The player explicitly welcomes dynamic, punchy displays, VFX, and diegetic UI to enhance the game's flavor and move away from basic rectangular number panels. This is a core redesign requirement. Use distinctive silhouettes, materials, resource behavior, and localized animation. Ordinary panels remain appropriate for long rules or settings where they support reading.

Proposed visual vocabulary to prototype, not approved final art:

| Information | Physical or magical presentation | Feedback when it changes |
| --- | --- | --- |
| Duelist identity and Life | Portrait medallion with a prominent Life numeral set into its frame; visually associate it with the Life Deck | Wounds strike the medallion and the deck loses cards in the corresponding event sequence; retain the resulting exact count |
| Energy | Ten clearly separated illuminated segments around part of the duelist frame, plus a readable current value | Gains light successive segments; spending extinguishes them; a hover preview marks projected spending with a distinct ghost treatment |
| Current Might | A bold engraved numeral on a blade-shaped or crest-shaped frame element | A brief transition when Energy or an effect changes Might; the new value stays visible |
| Fervor and Aspect | Runes charging toward ascension, with an Aspect crest | Gaining Fervor lights runes; ascension sends a short pulse through the frame and transforms the crest. Rune count must follow the effective threshold |
| Seals | Collected seal emblems assembling a gate motif | Acquired emblems settle into place; show set-specific progress and any pending victory condition accurately |
| Incoming attack and defense | A visible source-to-target connection, a damage marker near the target, and a ward effect for a successful block | Selection previews the relationship; commitment launches the effect; resolution updates the affected resource |

Energy must follow the affected personality, including Allies. A seal motif cannot combine unrelated sets into apparent victory progress. Flavor must preserve the distinctions the rules ask the player to understand.

Use three levels of motion: a quiet resting state, immediate hover/selection response, and a brief resolution accent. Reserve the largest moments for ascension, major impacts, and victory. Avoid continuous pulsing of every actionable object. Give each effect a specific meaning, retain exact values after it ends, and keep text and click targets unobstructed. Preview effects must look different from committed changes. Support reduced motion without removing state information.

School identity can influence textures, particles, and edge shapes while resource meanings and interaction cues remain consistent. A player should not need to relearn the display for each deck. Essential readouts can use crisp screen-space elements anchored to world objects; they do not need to inherit the table's perspective distortion to feel integrated.

Existing implementation support: `duel_fx.gd` provides floating text, particle bursts, slashes, and rings. `duel_view.gd` already sequences source pulses, damage, Energy, Fervor, and Aspect events. Extend that event-driven presentation and its intermediate display states. Persistent resource displays should own their lasting visual state; transient VFX should explain changes. Prototype Energy spending, one blocked attack, and an ascension alongside the revised board and hand.

## Priority 1: readable decisions and combat state

### Give the player a useful summary of each combatant

`scripts/duel/player_panel.gd` gives Life, Hand, and Discard equally sized stat tiles. Energy, current Might, Aspect, and Fervor instead live on personality card faces and their 3D markers. At normal table scale those details are difficult to read; the incoming card can also obscure the opponent's duelist.

Show Life, Energy, current Might, Aspect, and Fervor progress in stable, readable player summaries. Identify the controlling Ally when relevant. Keep hand count compact, particularly the player's own count. Put discard/removed/reserve counts near their piles or in secondary details. Show meaningful Seal victory progress when applicable, rather than treating it as another generic pile count. The two sides should remain easy to compare.

### Use a compact hand presentation instead of scaling down full rules cards

`duel_hud.gd` sets hand cards to 126x176 logical pixels. `card_face.gd` renders a 512x716 face and fits rules text between 12 and 24 pixels before that face is scaled down. At 1600x900, the hand face is approximately 105x147 displayed pixels and even the largest rules text is about 5 pixels high. At 1280x720 it is about 4 pixels. Inspection is therefore required for basic reading.

Prototype a larger overlapping hand with readable names, costs, roles, and forecasts at rest, and full wording in a nearby expanded card and inspection view. If necessary, adapt the resting card layout while preserving its silhouette and artwork. Simply enlarging the existing texture modestly will not solve its typography. Avoid dimming unavailable cards so strongly that planning ahead becomes difficult; explain why an action is unavailable.

### Bring threat, response, and consequence together

Defense currently asks the eye to move from the center incoming card to the bottom hand, to a left-side hover preview, and then to the right-side decision panel. The persistent top banner repeats turn/role information also present in player panels.

Use one stable decision area adjoining the hand and preview. Lead with who must act and what they are answering. Show the target and the projected result, including Energy loss and wounds, with relevant on-hit consequences. In the sampled Sword Lunge defense, the panel says 5 Energy while the Fervor loss remains in the small card rules. Keep full rules available so a summary cannot imply that damage is the whole effect.

Preserve the existing wound preview, but do not let it suppress other relevant values. `_show_attack()` hides all fact tiles when the wound hero is visible, and `_preview_outcome()` only presents the `life` field. A stable result area should distinguish the baseline from the hovered choice without making the player remember the previous number. Any additional calculated result must come through `SeatView`/`OptionView`, not duplicated client rules.

### Stop styling passive choices as recommendations

`ACCENT_TYPES` and `_fill_buttons()` make Pass and Take it solid gold. In the captures these are the strongest conventional buttons while card actions are represented by borders. That risks suggesting a preferred tactical move.

Use consistent styling for available alternatives. Reserve a strong confirmation treatment for an explicitly selected action or batch. Keep Final Strike's deliberate extra choice, and explain its consequences there. Do not add a confirmation dialog to every routine card play.

## Priority 2: recover space and stabilize the layout

- Reduce the 860x140 logical-pixel phase panel in `scenes/duel/hud.tscn` to a compact turn/phase strip. Emphasize the current decision; full phase order can remain available as secondary guidance.
- Reframe the table within a defined central area. `table_layout.gd` reserves full rows for five Allies, five Drills, five Non-Combats, and seven Seals on both sides even when empty. Reduce the visual weight of empty zones and enlarge occupied content within stable regions. Avoid reshuffling every zone whenever a card enters play.
- Give the decision panel a reserved region. In both defense captures it covers the near Life Deck/Discard area. The HUD and camera need a shared space budget rather than independent corner overlays.
- Make inspection adjacent to the decision area and allow it to remain open for comparison. Full modal inspection can remain for detailed rules and keyword explanations.
- Make the log a small recent-event summary with expandable history. In attack and defense captures it still shows opening Reserve events. `hud.tscn` nests a fit-content RichTextLabel inside a ScrollContainer, but scroll-following is set on the label; verify and correct scrolling at the owning container. Preserve the user's position when they deliberately browse older events.

Proposed arrangement:

```text
Compact turn / phase / player-to-act strip
Opponent identity and meaningful current resources
Table and occupied permanents       | Card preview / decision / result
Your identity and current resources | Contextual actions
Readable hand with costs and forecasts
```

This is a direction to prototype, not a final pixel specification. Budget the table camera and HUD together.

## Priority 3: selection and supporting screens

**Duelist selection.** The portrait establishes identity, but eight tiny key cards compete with a long descriptive block and considerable unused vertical space. Lead with playstyle, difficulty, how the deck wins, and its defining mechanic. Present two or three representative cards with readable explanations; put composition and the full card set in details. `_key_card_ids()` chooses Mastery, Relic, then cards matching words in the duelist's name, so the current key-card list is not a curated explanation of the strategy. Add explicit deck presentation metadata if needed.

The headline Top Might describes the highest supported Aspect while Surge describes the starting Aspect. Make that distinction clear or tie both values to the selected Aspect. Keep roster names readable rather than truncating them before players learn the cast.

**Matchup.** The two large personality cards are more readable and give this screen a clear purpose. Preserve opponent familiarization. Move Seed to advanced/development options, make AI difficulty clear before commitment, and consider a short opponent strategy summary. Avoid reproducing the entire selection screen.

**Reserve and other trays.** The 720p Reserve capture fits but still has tiny rules and substantial surrounding space. Scale card columns to available width and use a readable selected-card detail area. Keep selected count and confirmation visible. Small text-only choices should use compact labeled actions instead of 160x224 card-shaped tiles. Retain deliberate selection for hidden-information decisions and engine-defined batches.

**Title.** Its primary action is already clear. Remove the player-facing “273 card definitions” status; keep connection status when needed. This screen is a lower priority than the duel.

## Sizing and validation targets

These are proposed targets to validate in the game, not measured compliance or universal standards:

- At the smallest supported window, aim for 16 displayed pixels for primary action text and summaries, 14 for secondary information, and 40-pixel-high primary click targets. Count displayed pixels after viewport scaling.
- Keep essential current resources and action consequences readable without inspecting a card. Retain detailed rules and modifier math on demand.
- Use a small typography and spacing scale. Replace scattered font overrides as components are revised, rather than changing every label at once.
- At 1280x720, the current 1920x1080 canvas scales 13-pixel labels to roughly 8.7 pixels and 40-pixel controls to 26.7 pixels. Add deliberate responsive behavior or a UI scale policy; canvas shrinking alone is insufficient.
- Validate at 1280x720, 1600x900, and a wider aspect ratio. Include long card titles, dense rules, large hands, crowded permanents, multiple restrictions, overflow wounds, Energy-only hits, Endurance, attack variants, batch selection, and deck search.
- Check keyboard focus and equivalent previews on focus, since current outcome previews are wired to mouse entry/exit. Check that availability, selection, and warnings remain understandable without color alone.

Suggested order: prototype the player summaries, compact hand, and decision area together; verify several difficult combat states; then adjust the table camera and secondary panels; finish selection, trays, and visual styling. Success means a player can identify who acts, compare meaningful resources, read available actions, and understand a likely consequence without touring the screen.
