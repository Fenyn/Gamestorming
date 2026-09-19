# In-scene interface redesign

Implemented 2026-09-19, following [the interface audit](ui_ux_audit.md).

The hand and incoming attack are Sprite3D card faces. Duelist resources are Node3D fixtures anchored to the field cards, rendered through transparent SubViewport textures. They leave the card face clear and follow it as the camera moves. The separate portrait widgets have been removed. Table cards remain Card3D objects; combat effects use scene geometry and particles. Decision text, inspection, history, and selection trays remain Control UI for readability and scrolling.

## Player-facing changes

- Larger fanned hand with nearby hover enlargement, legal-action auras, short forecasts, paging, and animated draws and plays.
- Field-card readouts with segmented Energy arcs, Life and Might crests, Aspect and Fervor runes, Seal progress, and public restrictions. Energy previews show the contemplated cost. Detailed public status remains available in inspection.
- Compact phase strip and decision area, readable incoming attack, and separate incoming damage and after-choice defense forecasts. Empty decision panels disappear during resolution.
- Dark arena surface with inlaid geometry; empty zone outlines removed and occupied piles labeled quietly.
- Distinct defense wards, impact bursts, resource pulses, and ascension effects. Event snapshots supply the correct controlling personality, Might, and Aspect during replay.
- Larger Reserve/search cards, wrapped action buttons, compact recent history, cleaner roster statistics, and three readable signature cards on selection screens.

## Controls

Move the pointer to the bottom of the screen to raise the hand. It retracts below the screen when the pointer returns to the field. Hover a hand card to enlarge it; click to choose a legal action; right-click to inspect. Press **H** to raise and browse the hand with **Left/Right**, **Enter** to choose, **Space** to inspect, and **Escape** to leave hand navigation. Scroll over the hand to page when necessary. The top-right **Reduced motion** toggle suppresses decorative movement; `--reduced-motion` enables it at launch.

## Verification

Godot 4.6.2: the original redesign passed 2,628 rules checks and 19 presentation-data checks. Following the field-readout and retractable-hand revision, the UI smoke suite passed 62 checks. It covers private hands, hotseat handoff timing, viewport changes, enlarged-face picking, crowded hands, overlays, draw arrivals, bottom-edge reveal/retraction, keyboard opening, hidden hit regions, and readouts following their field cards.

```text
--headless --path zenith -s tests/run_tests.gd
--headless --path zenith -s tests/presentation_data_tests.gd
--headless --path zenith -s tests/ui_redesign_smoke.gd
```

Rendered samples were inspected at 1600x900 and 1280x720, including defense, hand enlargement, Reserve, inspection, selection, matchup, and combat effects. These are deterministic sample states, not an exhaustive playtest of every deck or online flow. Existing card illustrations remain prototype assets.

Current revision: [field readouts with the hand retracted](ui_redesign/field.png), [hand raised at 720p](ui_redesign/field-open720.png). Earlier redesign references: [enlarged hand](ui_redesign/hand.png), [defense at 720p](ui_redesign/defense720.png), [defense effect](ui_redesign/ward.png).

Reproduce the hand capture with the duel scene and user flags `--dev-autoplay --dev-fast --dev-policy=attack --dev-stop-at=defense --dev-peek --dev-seed=5 --dev-screenshot=<path.png>`. For the ward, use `--dev-policy=showcase --dev-freeze=attack_stopped --dev-steps=100` in place of the stop and peek flags. The showcase policy permits defenses and Endurance so those effects appear in automated captures.

Local capture runs required a writable `--log-file` path and reported environment certificate/shader-cache access errors. Freezing mid-animation also reports resources still alive at process exit; ordinary prompt captures and the headless suites completed successfully without script errors.
