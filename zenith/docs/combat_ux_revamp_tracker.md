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

Status: complete and verified 2026-09-20.

### Keep every combat action inside the viewport

- [x] Replace the current vertical stack of full-size focus card followed by prompt controls with one bounded combat-decision region.
- [x] Keep the decision question, consequence, and every primary action visible without scrolling at 1280x720 and 1600x900.
- [x] Provide a compact incoming-card presentation during decisions: title, art, type, relevant text, and forecast.
- [x] Keep the full card available through hover, focus, or inspection.
- [x] Ensure cardless choices such as **Take it**, **Pass**, and **No Endurance** remain reachable even when the hand is tucked.
- [x] Prevent long card names, dense rules, multiple stop requirements, and outcome previews from moving buttons outside the viewport.
- [x] Preserve keyboard focus and show the same forecast on keyboard focus that pointer hover shows.

Resolved defect: `DuelHud._compact_prompt()` previously allowed an incorrectly measured result label to push the defense question and **Take it** action partly or completely below the viewport.

Acceptance criteria:

- At 1280x720, a defense prompt shows the incoming attack, expected Energy/wounds, defense instruction, legal response, and **Take it** together.
- At 1600x900, opening a legal-card preview does not move or conceal the decision controls.
- No prompt requires blind scrolling to discover the only legal action.

Implementation notes:

- The focused card, question, consequence, instruction, and actions now share one bounded right-side column.
- Damage and outcome previews use a stable two-line result slot. This prevents an early one-pixel-wide layout pass from turning a short result into a 413-pixel minimum height.
- Pointer hover and keyboard focus replace the baseline with an explicitly labeled preview without moving the focused action.
- Combat presentation tests check the actual question, result, action region, and button rectangles. They also cover a long question, multiple required stops, damage-prevention text, cardless fallback, and a long scrollable action list.
- Rendered defense states were inspected at 1280x720 and 1600x900 with the hand tucked, a legal-card preview open, and an outcome preview active.

## P1: make the fighters the visual anchors

Status: complete; Life grouping revised and verified 2026-09-21.

### Consolidate each fighter's hero data

- [x] Treat the duelist card, Life, and core resources as one visual unit.
- [x] Make Life and Energy the strongest values.
- [x] Keep Might clearly readable as the primary combat comparison.
- [x] Present Aspect and Fervor as compact progression attached to the same unit.
- [x] Show temporary conditions as short contextual chips only while they matter.
- [x] Identify a controlling Ally within the same fighter unit when control changes.
- [x] Use the same information order for the player and opponent.
- [x] Use existing school color and card art to strengthen identity around each fighter.
- [x] Remove text overlaps between duelist names, role labels, cards, Life, and resource trackers.

Acceptance criteria:

- Both fighters and their five core values remain visible during neutral play, attack declaration, defense, and hand browsing.
- A player can compare Life, Energy, and Might across both fighters without scanning another screen region.
- Temporary states do not occupy permanent space after they expire.

### Remove duplicated identity and counts

- [x] Show each player's name and **You/Opponent** role once in the primary composition.
- [x] Remove duplicate hand, discard, reserve, and status counts from competing locations.
- [x] Keep the player's hand count peripheral because the visible hand already communicates most of it.
- [x] Associate opponent hand count with the opponent fighter or face-down hand.

## P1: establish a central combat lane

- [x] Move the declared attack card into a stable exchange area between the fighters.
- [x] Place a defense, counter, or response card in the same exchange area when used.
- [x] Attach the current result to that exchange: expected damage, stopped state, dealt damage, and wounds.
- [x] Keep the target relationship readable with a restrained directional treatment.
- [x] Clear resolved cards back to their correct zones without leaving stale combat information.
- [x] Distinguish preview, commitment, and resolution with consistent visual states.

Suggested low-cost feedback vocabulary:

- Declaration: short slide and scale bump into the combat lane.
- Legal response: stable border or aura.
- Selected response: stronger border and a short positional lock.
- Stop: defense-color flash and transverse marker.
- Hit: brief target-card shake, impact flash, and resource change.
- Wound: Life value accent, a card lifted and revealed from the Life Deck, then a visible flight into Discard or Out.
- Resolution: concise result text remains long enough to read, then clears.

Acceptance criteria:

- Combat reads from attacker to attack card to defender without requiring the event log.
- The active exchange is visually stronger than history, empty piles, and settings.
- Reduced motion retains the same state distinctions using static position, border, icon, and text changes.

## P1: reduce secondary visual weight

### Backline and piles

- [x] Replace permanently visible empty Mastery, Relic, Discard, and Out wells with compact representations.
- [x] Show Mastery and Relic as cards when occupied or actionable.
- [x] Show Discard and Out as compact pile icons and counts until opened.
- [x] Associate Reserve count with the hand or Relic/backline area without reserving another large empty slot.
- [x] Preserve one-click pile browsing.
- [x] Keep Seal progress visible when it represents a victory condition; group unrelated Seal sets separately.

### History, phase, and settings

- [x] Reduce recent history to one or two readable recent events.
- [x] Keep full History expandable and preserve the user's scroll position while browsing.
- [x] Consolidate turn, phase, attacker/defender role, and resolution state into one compact top-center strip.
- [x] Avoid repeating the same combat state in the phase strip, toast, focus caption, and prompt.
- [x] Move Reduced Motion into settings or reduce it to a compact peripheral control.
- [x] Keep network and waiting states visible only when relevant.

Acceptance criteria:

- Empty zones never carry more visual weight than an active fighter.
- The resting screen has quiet peripheral space.
- Expanding history or a pile does not alter the underlying combat state.

Implementation notes:

- Each fighter now has a Life Deck tucked beside its card, with its sole prominent Life number directly on that deck. An adjacent three-column readout keeps Energy, Might, and Fervor in the same order, with Aspect and identity in its header. The repeated pile summary is hidden.
- Fighter identity, **You/Opponent**, and controlling-Ally state live inside that readout, clearing the table center of floating identity labels.
- Duelist cards are larger while the stable attack and response slots sit on distinct owner sides of the gap between them. The existing attack link, forecast, stop, hit, wound, and toast feedback all point back to this exchange.
- Backline rails use one compact row. Empty wells and captions disappear; occupied Mastery, Relic, Discard, Out, and Reserve information remain directly browsable.
- Recent history is reduced to roughly two lines, the phase strip remains compact, and Reduced Motion is a small flat peripheral control.
- The Life grouping revision was inspected in rendered defense states at 1280x720 and 1600x900. Earlier P1 damage states were inspected at 1600x900. UI smoke tests verify the Life number's deck anchor, compact three-stat geometry, backline behavior, and central owner-specific resolving slots.
- Life loss now pulses the number on its deck as that deck's card lifts, briefly reveals, and lands in its public pile. Reduced Motion snaps the card to the destination while retaining the number and text cue. The mid-flight state was inspected at 1280x720 and 1600x900.
- When a survival point triggers Second Wind, the discard pile returns to the Life Deck in one short shuffle beat instead of replaying a flight and pause for every card. The Life number updates when the cards land, and one Second Wind line replaces the flood of per-card recovery lines. A Life card lost and recovered in the same update still gets its public reveal before the shuffle; ordinary recovery keeps its individual card beats.
- Public opponent cards used during Combat now get a readable face at the right edge while the physical card holds in the central exchange. A stop names the outcome before its effects continue and holds longer for cards with more text. Spent attack routes stay anchored to the fighter rather than stretching from a discard pile. The opponent-stop state was inspected at 1280x720 and 1600x900.

## P2: preserve the card-game hand while protecting the center

- [x] Keep the overlapping or fanned 3D hand.
- [x] Bound hover enlargement so it does not cover either fighter or the combat decision.
- [x] Keep recognizable art, title, type, cost, and immediate forecast readable at rest or on light focus.
- [x] Keep full rules in expanded preview and inspection.
- [x] Retain clear legal-action highlighting without making unavailable cards unreadable for planning.
- [x] Keep paging usable for crowded hands.
- [x] Preserve bottom-edge reveal, keyboard hand opening, and direct card selection.

Acceptance criteria:

- Raising and browsing the hand never hides both fighters.
- Hovering one card does not conceal the primary action or the other legal choices.
- Large hands, long titles, and mixed legal/unavailable cards remain understandable at 1280x720.

Implemented: the hovered source card remains in its fan slot under the pointer while a separate reading face chooses a lane beside the projected Life Deck and fighter. This corrects the mismatch between the visible card and its hover target. The reading face stays clear of its source card, the visible focus card, and the decision panel; when those extend into the hand, the fan shifts clear of the action. The fan contracts below the player's stat readout in crowded states, while the reading face shows the full art, type/title caption, and immediate forecast. Unavailable faces remain recognizable. Wheel paging also works over the revealed lower hand band, including gaps between cards. Geometry and picking checks cover a crowded hand at 1280x720, 1600x900, and 1800x720; rendered attack and defense captures were inspected at those sizes.

## P2: responsive hierarchy

- [x] Define explicit layouts or breakpoints for 1280x720, 1600x900, and wide aspect ratios.
- [x] Preserve hero values and decision actions before secondary labels when space contracts.
- [x] Replace uniform canvas shrinkage with responsive sizing or an intentional UI-scale policy.
- [x] Keep primary decision text around 16 displayed pixels or larger at the minimum supported resolution.
- [x] Keep secondary information around 14 displayed pixels or larger where it must be read during play.
- [x] Keep primary click targets at least 40 displayed pixels high.
- [x] Prevent panels, buttons, previews, and enlarged cards from crossing viewport bounds.

Scale policy: the duel keeps the 1920x1080 canvas base and expands across aspect ratios. At 1280x720 its 2/3 scale gives 24-unit decision text about 16 displayed pixels, 21-unit supporting text about 14, and 60-unit primary buttons 40 displayed pixels high. Combat state, route, damage, and stop text were raised to that minimum where needed. Fighter stat labels and status text were enlarged within their 3D readouts. The hand uses viewport and projected hero/decision bounds rather than a fixed card position, so wide windows create more side room without pulling the exchange away from the fighters.

## Validation matrix

Capture and inspect each state at 1280x720, 1600x900, and one wide aspect ratio:

- [ ] Neutral non-combat decision with the hand tucked.
- [x] Attack-action prompt with legal and unavailable cards.
- [x] Incoming defense with Energy-only damage.
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
