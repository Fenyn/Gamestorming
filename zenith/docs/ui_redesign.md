# In-scene interface redesign

Implemented 2026-09-19, following [the interface audit](ui_ux_audit.md).

The hand and incoming attack are Sprite3D card faces. Duelist resources are Node3D fixtures anchored to the field cards, rendered through transparent SubViewport textures. They leave the card face clear and follow it as the camera moves. The separate portrait widgets have been removed. Table cards remain Card3D objects; combat effects use scene geometry and particles. Decision text, inspection, history, and selection trays remain Control UI for readability and scrolling.

## Player-facing changes

- Larger fanned hand with nearby hover enlargement, legal-action auras, short forecasts, paging, and animated draws and plays.
- One compact tracker attached to each duelist groups Energy, Might, and Fervor, with Aspect in its header and integrated Energy segments and Fervor runes. It sits below the near card and above the far card to keep the playing rows clear. The Life Deck sits beside its duelist and carries the sole prominent Life count. Energy previews show the contemplated cost. Detailed public status remains available in inspection.

Readout spacing follows the projected corners of the animated duelist and neighbouring Life Deck, including perspective and zoom. Text retains a readable size while its anchors move outside the card edges. The transparent canvas expands for close views, and hit regions follow the same layout. Life counts use each replay event's public snapshot, so wounds are shown as they resolve.
- Compact phase strip and decision area, readable incoming attack, and separate incoming damage and after-choice defense forecasts. Empty decision panels disappear during resolution.
- Dark arena surface with inlaid geometry; empty zone outlines removed and occupied piles labeled quietly.
- Distinct defense wards, impact bursts, resource pulses, and ascension effects. Event snapshots supply the correct controlling personality, Might, and Aspect during replay.
- Larger Reserve/search cards, wrapped action buttons, compact recent history, cleaner roster statistics, and three readable signature cards on selection screens.

## Controls

Move the pointer to the bottom of the screen to raise the hand. It retracts when the pointer returns to the field, leaving the top 15% of its card faces visible. Floating titles and forecasts stay hidden while tucked. Hover a hand card to enlarge it; click to choose a legal action; right-click to inspect. Hand browsing blocks board picking, hover effects, and background tooltips. Press **H** to raise and browse the hand with **Left/Right**, **Enter** to choose, **Space** to inspect, and **Escape** to leave hand navigation. Scroll over the hand to page when necessary. The top-right **Reduced motion** toggle suppresses decorative movement; `--reduced-motion` enables it at launch.

## Verification

Opponent activity restricts game commands rather than public observation. Board hover, hand browsing, inspection, history, and camera movement remain available while the AI thinks, events replay, or a network acknowledgement is pending. Commands require a settled prompt addressed to the viewer; a legal response does not require it to be the viewer's turn. Opponent moves preserve an open inspection window. The observer regression brings the UI smoke suite to 113 passing checks.

Godot 4.6.2: the original redesign passed 2,628 rules checks and 19 presentation-data checks. Following the zoom anchoring and Life Deck revision, the UI smoke suite passed 95 checks. It covers private hands, hotseat handoff timing, viewport changes, enlarged-face picking, crowded hands, overlays, draw arrivals, bottom-edge reveal/retraction, keyboard opening, hidden hit regions, projected card separation at multiple zoom levels, canvas bounds, and live Life Deck counts.

```text
--headless --path zenith -s tests/run_tests.gd
--headless --path zenith -s tests/presentation_data_tests.gd
--headless --path zenith -s tests/ui_redesign_smoke.gd
```

Rendered samples were inspected at 1600x900 and 1280x720, including defense, hand enlargement, Reserve, inspection, selection, matchup, and combat effects. These are deterministic sample states, not an exhaustive playtest of every deck or online flow. Existing card illustrations remain prototype assets.

Current revision: [unified tracker and tucked hand at 720p](ui_redesign/unified720.png), [hand preview with board hover blocked](ui_redesign/unified-hand.png). The UI smoke suite now passes 104 checks, including tucked-hand exposure and late background hover/inspection rejection. Earlier revisions: [separate readouts](ui_redesign/life720.png), [close zoom](ui_redesign/life-close.png), [field readouts](ui_redesign/field.png), [hand raised](ui_redesign/field-open720.png), [defense effect](ui_redesign/ward.png).

Reproduce the hand capture with the duel scene and user flags `--dev-autoplay --dev-fast --dev-policy=attack --dev-stop-at=defense --dev-peek --dev-seed=5 --dev-screenshot=<path.png>`. For the ward, use `--dev-policy=showcase --dev-freeze=attack_stopped --dev-steps=100` in place of the stop and peek flags. The showcase policy permits defenses and Endurance so those effects appear in automated captures.

Local capture runs required a writable `--log-file` path and reported environment certificate/shader-cache access errors. Freezing mid-animation also reports resources still alive at process exit; ordinary prompt captures and the headless suites completed successfully without script errors.
