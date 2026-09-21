# Combat UX revamp tracker

Created 2026-09-20 from an adversarial review of the current duel scene at 1600x900 and 1280x720.

## Product direction

The combat scene should feel like a focused fighter-versus-fighter card duel. The two duelist cards, their essential resources, and the cards exchanged in combat own the center of the screen. Secondary piles, history, settings, and detailed rules stay available without competing with the current decision.

Keep the card-game presentation. Fighters remain cards. Combat feedback should use reusable card movement, scale, color, shader flashes, particles, floating values, and sound. Avoid character animation and new animation-heavy art requirements.

## Success criteria

A player can identify all of the following within a few seconds, without opening an inspection view:

- Which two fighters are dueling.
- Who must act now.
- Each fighter's Life, Energy, Might, Aspect, and Fervor.
- Which card or attack is being resolved.
- What the incoming consequence is.
- Which actions are currently available.

The two fighters remain visible during normal hand browsing and combat decisions. Secondary information becomes prominent only when the player requests it or when it affects the current decision.

## Constraints

- Reuse existing card art and school palettes.
- Do not require animated fighter illustrations or bespoke character animation.
- Preserve exact public game state and rules-driven forecasts.
- Preserve direct card interaction, full inspection, pile browsing, keyboard navigation, and reduced-motion support.
- Clients continue to render from `SeatView` and `PromptView`; calculated outcomes stay in the referee-facing presentation data.

## P0: decisions must remain usable

### Keep every combat action inside the viewport

- [ ] Replace the current vertical stack of full-size focus card followed by prompt controls with one bounded combat-decision region.
- [ ] Keep the decision question, consequence, and every primary action visible without scrolling at 1280x720 and 1600x900.
- [ ] Provide a compact incoming-card presentation during decisions: title, art, type, relevant text, and forecast.
- [ ] Keep the full card available through hover, focus, or inspection.
- [ ] Ensure cardless choices such as **Take it**, **Pass**, and **No Endurance** remain reachable even when the hand is tucked.
- [ ] Prevent long card names, dense rules, multiple stop requirements, and outcome previews from moving buttons outside the viewport.
- [ ] Preserve keyboard focus and show the same forecast on keyboard focus that pointer hover shows.

Current risk: `DuelHud._compact_prompt()` places the prompt below the focus card. In current captures, the defense question and **Take it** action fall partly or completely below the viewport.

Acceptance criteria:

- At 1280x720, a defense prompt shows the incoming attack, expected Energy/wounds, defense instruction, legal response, and **Take it** together.
- At 1600x900, opening a legal-card preview does not move or conceal the decision controls.
- No prompt requires blind scrolling to discover the only legal action.

## P1: make the fighters the visual anchors

### Consolidate each fighter's hero data

- [ ] Treat the duelist card, Life, and core resources as one visual unit.
- [ ] Make Life and Energy the strongest values.
- [ ] Keep Might clearly readable as the primary combat comparison.
- [ ] Present Aspect and Fervor as compact progression attached to the same unit.
- [ ] Show temporary conditions as short contextual chips only while they matter.
- [ ] Identify a controlling Ally within the same fighter unit when control changes.
- [ ] Use the same information order for the player and opponent.
- [ ] Use existing school color and card art to strengthen identity around each fighter.
- [ ] Remove text overlaps between duelist names, role labels, cards, Life, and resource trackers.

Acceptance criteria:

- Both fighters and their five core values remain visible during neutral play, attack declaration, defense, and hand browsing.
- A player can compare Life, Energy, and Might across both fighters without scanning another screen region.
- Temporary states do not occupy permanent space after they expire.

### Remove duplicated identity and counts

- [ ] Show each player's name and **You/Opponent** role once in the primary composition.
- [ ] Remove duplicate hand, discard, reserve, and status counts from competing locations.
- [ ] Keep the player's hand count peripheral because the visible hand already communicates most of it.
- [ ] Associate opponent hand count with the opponent fighter or face-down hand.

## P1: establish a central combat lane

- [ ] Move the declared attack card into a stable exchange area between the fighters.
- [ ] Place a defense, counter, or response card in the same exchange area when used.
- [ ] Attach the current result to that exchange: expected damage, stopped state, dealt damage, and wounds.
- [ ] Keep the target relationship readable with a restrained directional treatment.
- [ ] Clear resolved cards back to their correct zones without leaving stale combat information.
- [ ] Distinguish preview, commitment, and resolution with consistent visual states.

Suggested low-cost feedback vocabulary:

- Declaration: short slide and scale bump into the combat lane.
- Legal response: stable border or aura.
- Selected response: stronger border and a short positional lock.
- Stop: defense-color flash and transverse marker.
- Hit: brief target-card shake, impact flash, and resource change.
- Wound: Life value accent and visible Life Deck change.
- Resolution: concise result text remains long enough to read, then clears.

Acceptance criteria:

- Combat reads from attacker to attack card to defender without requiring the event log.
- The active exchange is visually stronger than history, empty piles, and settings.
- Reduced motion retains the same state distinctions using static position, border, icon, and text changes.

## P1: reduce secondary visual weight

### Backline and piles

- [ ] Replace permanently visible empty Mastery, Relic, Discard, and Out wells with compact representations.
- [ ] Show Mastery and Relic as cards when occupied or actionable.
- [ ] Show Discard and Out as compact pile icons and counts until opened.
- [ ] Associate Reserve count with the hand or Relic/backline area without reserving another large empty slot.
- [ ] Preserve one-click pile browsing.
- [ ] Keep Seal progress visible when it represents a victory condition; group unrelated Seal sets separately.

### History, phase, and settings

- [ ] Reduce recent history to one or two readable recent events.
- [ ] Keep full History expandable and preserve the user's scroll position while browsing.
- [ ] Consolidate turn, phase, attacker/defender role, and resolution state into one compact top-center strip.
- [ ] Avoid repeating the same combat state in the phase strip, toast, focus caption, and prompt.
- [ ] Move Reduced Motion into settings or a compact pause/settings entry.
- [ ] Keep network and waiting states visible only when relevant.

Acceptance criteria:

- Empty zones never carry more visual weight than an active fighter.
- The resting screen has quiet peripheral space.
- Expanding history or a pile does not alter the underlying combat state.

## P2: preserve the card-game hand while protecting the center

- [ ] Keep the overlapping or fanned 3D hand.
- [ ] Bound hover enlargement so it does not cover either fighter or the combat decision.
- [ ] Keep recognizable art, title, type, cost, and immediate forecast readable at rest or on light focus.
- [ ] Keep full rules in expanded preview and inspection.
- [ ] Retain clear legal-action highlighting without making unavailable cards unreadable for planning.
- [ ] Keep paging usable for crowded hands.
- [ ] Preserve bottom-edge reveal, keyboard hand opening, and direct card selection.

Acceptance criteria:

- Raising and browsing the hand never hides both fighters.
- Hovering one card does not conceal the primary action or the other legal choices.
- Large hands, long titles, and mixed legal/unavailable cards remain understandable at 1280x720.

## P2: responsive hierarchy

- [ ] Define explicit layouts or breakpoints for 1280x720, 1600x900, and wide aspect ratios.
- [ ] Preserve hero values and decision actions before secondary labels when space contracts.
- [ ] Replace uniform canvas shrinkage with responsive sizing or an intentional UI-scale policy.
- [ ] Keep primary decision text around 16 displayed pixels or larger at the minimum supported resolution.
- [ ] Keep secondary information around 14 displayed pixels or larger where it must be read during play.
- [ ] Keep primary click targets at least 40 displayed pixels high.
- [ ] Prevent panels, buttons, previews, and enlarged cards from crossing viewport bounds.

## Validation matrix

Capture and inspect each state at 1280x720, 1600x900, and one wide aspect ratio:

- [ ] Neutral non-combat decision with the hand tucked.
- [ ] Attack-action prompt with legal and unavailable cards.
- [ ] Incoming defense with Energy-only damage.
- [ ] Incoming defense with overflow wounds.
- [ ] Defense requiring more than one stop.
- [ ] Successful stop.
- [ ] Unstoppable attack.
- [ ] Endurance choice and hovered outcome.
- [ ] Counter/response window with a pending card.
- [ ] Final Strike sub-choice.
- [ ] Fight-back decision.
- [ ] Controlling Ally as attacker and defender.
- [ ] Fervor gain and Aspect change.
- [ ] Large hand and hand paging.
- [ ] Crowded permanents.
- [ ] Multiple status restrictions.
- [ ] Reserve batch and Life Deck search trays.
- [ ] Expanded history and pile browser.
- [ ] Keyboard-only navigation.
- [ ] Reduced-motion presentation.
- [ ] AI thinking, event replay, and network acknowledgement waiting states.

For every capture, verify:

- [ ] Both fighter identities remain clear.
- [ ] Life, Energy, and Might are immediately comparable.
- [ ] The current decision and all primary choices are visible.
- [ ] Incoming consequences are adjacent to the active exchange.
- [ ] No secondary panel is visually stronger than the active exchange.
- [ ] No text or card overlaps essential information.

## Relevant implementation surfaces

- `scenes/duel/hud.tscn`: phase, history, prompt, focus, backline, and overlay layout.
- `scripts/duel/duel_hud.gd`: prompt composition, focus card, combat result, hand preview, and responsive placement.
- `scenes/duel/backline_rail.tscn` and `scripts/duel/backline_rail.gd`: permanent secondary-zone footprint.
- `scenes/duel/duelist_display.tscn`, `scripts/duel/duelist_display.gd`, and `scripts/duel/duelist_readout.gd`: fighter identity and core-resource grouping.
- `scripts/duel/hand_3d.gd`: hand reveal, hover enlargement, paging, and keyboard navigation.
- `scripts/duel/duel_view.gd`: camera-facing focus card, combat event sequencing, and screen-space anchors.
- `scripts/duel/duel_fx.gd`: reusable declaration, stop, hit, wound, and resource feedback.

## Definition of done

- All P0 and P1 acceptance criteria pass at 1280x720 and 1600x900.
- The validation matrix has reviewed captures for all representative combat states.
- Headless rules and presentation-data tests still pass.
- UI smoke tests cover viewport containment for the decision region, focus preview, hand enlargement, and primary actions.
- A first-time observer can explain who is fighting, who acts, what is happening, and what the consequence will be from a combat screenshot without consulting the history panel.
- The final presentation uses existing card art and reusable interface effects without requiring animated fighter assets.
