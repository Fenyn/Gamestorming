# Zenith

A two-player dueling card game. Great houses vie for the king's favor through structured duels; each sends a named spellsword fighter. Design: `../designs/zenith.md`.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** playable hotseat and online prototype. Rules engine with headless tests, 3D playspace, deck select, six starter decks whose cards carry their full mechanics (functional names, no flavor yet).
- **Run:** Open `zenith/project.godot` in Godot 4.6 and press F5. Title → Hotseat duel → pick two decks → play. The table swings to whoever has to decide, behind a hand-off screen.
- **Online:** one player presses Host online duel (port 7777), the other types the host's address and presses Join. The select screen becomes the lobby: each client picks its own house, the host starts. The host runs the rules; the joiner receives only what its seat may see and sits at its own side of the table.

## Layout

| Path | What |
|---|---|
| `engine/` | Rules engine. RefCounted only, no Nodes, no autoloads. `DuelEngine` is the rules; `Referee` wraps it and speaks to seats in `SeatView`, `PromptView` and `SeatUpdate` |
| `data/strike_table.json` | Might bands and cap for Strike base damage |
| `data/cards/starter/` | Starter set: 195 cards with functional names and real mechanics. Generated; not final content |
| `data/decks/` | Six starter loadouts (55 to 80 life cards plus Armories), validated and self-played by the tests |
| `assets/card_art/` | Card art, one PNG per card id (`<id>_t<tier>.png` for a fighter tier). Loaded by id at face render time; missing art shows the type glyph |
| `docs/card_roster.md` | Every starter card with rules text, art brief and deck usage, one row per art image |
| `scripts/ui/zenith_theme.gd` | The runtime-built dark theme, applied to every screen. Gold means "act here", green is Vigor, red an attack, blue a defence, orange a warning; guild colours mark identity only |
| `scripts/autoload/session.gd` | `Session`: loaded library, decks, the two chosen decks, scene changes |
| `scripts/autoload/net.gd` | `Net`: ENet host or join, lobby seats, and the command relay for online duels |
| `scenes/main.tscn` | Title |
| `scenes/select/` | Deck and fighter select |
| `scenes/duel/` | Playspace: table, camera, cards, HUD, card face renderer |
| `tests/` | Headless engine tests and fixtures |

## Engine

`DuelEngine` runs the duel as a state machine. It advances on its own until a player has to decide something, then exposes a `Prompt` whose `options` are the only `Command`s it accepts. `submit(command)` applies one and runs on to the next prompt or the end of the game. Everything that happens is appended to `events` as `GameEvent`s for the client to animate and log. Same seed plus same commands replays the same game.

```gdscript
var engine: DuelEngine = DuelEngine.new()
engine.setup([deck_a, deck_b], library, strike_table, seed_value)
engine.start()
while not engine.is_over():
	var choice: Command = engine.prompt.options[0]   # a driver picks here
	engine.submit(choice)
```

Prompt kinds: `armory` (armory_in / armory_done), `non_combat` (place / master / done), `declare` (declare / skip), `attack_action` (attack, with value `"empower"` for the Empowered version / use / power / copied_attack / final_strike / pass), `respond` (counter / decline), `defense` (defend / power_defend / no_defense), `control`, `redirect` (target), `endurance` (endure / no_endure), `capture` (capture / no_capture), `keep` (keep / discard_all), `recover` (recover / no_recover), `pay` (value = Vigor paid), `discard_choice`, `pick_in_play` (+ pick_none), `name_card` (value = title), `pick_option`.

Batches: a prompt that picks several cards (`armory`, a discard of two or more, a search or pick-in-play for several) also sets `batch_type`, `batch_min`, `batch_max` on the `Prompt` and `PromptView`. One Command of that type with `value` = an Array of card uids taken from the options answers it in a single step; `Prompt.accept` normalises and checks it, and the referee refuses anything outside the options, repeats, or the wrong count. Clients build it with `PromptView.batch_option(uids)`. The one-card options stay legal, so drivers that pick one at a time still work.

Effects run through a queue that pauses on a choice prompt and resumes afterwards, so a card can ask its owner or the target to pick cards mid-resolution.

**Seat views.** Clients never read the engine. `Referee` owns it and answers each seat with a `SeatUpdate`: the log lines for what happened, a `SeatView` (public standings, every zone as uids, and a card table where cards that seat may not see carry only uid and zone: Life Decks, the other seat's hand and Armory), and a `PromptView` when the next decision is that seat's (kind, title, options with ready-made labels). `Referee.submit(seat, command)` refuses anything that is not the pending prompt's own option from the right seat. Everything has `to_dict` / `from_dict` so the same objects cross the wire. Card uids are dealt after the shuffle so a face-down uid says nothing about the card.

Covered: Armory swap at setup, bracket first-player rule, 7-step turn, 6-phase Combat, 15-step battle sequence, Strike Table, Arts with costs and cost discounts, overflow to wounds, Endurance (fixed and X), Defense Shields, Focused and unstoppable attacks, unpreventable damage, prevent-all, floating stop-all and stop-next, Acclaim and Favor tiers (set, lose, advance, threshold changes, Acclaim and tier shields), Allies (placement, overlay, control at any stage, redirect, protection), Drills with guild lock, modifiers, shields, once-per-Combat uses and Drill protection, Tokens (placement, bypass, capture, capture effects, both win paths), Grounds with standing forbids, Masteries (modifiers, entering-Combat, on-success, use), Masters with per-game powers and passives, Final Strike, Remain, Empower, counter window for Combat cards, attack variants ("if X is in control, +3"), per-Ally and Surge-scaled damage, pay-any-Vigor attacks, attachments (modifiers, entering-Combat draws, wound removal), constant powers (focused attacks, first styled attack unstoppable, on-attack, turn-start, shared with Allies), named-card locks, copied attacks, forbids by card type / attack type / powers / Mastery / Drills / end-Combat / stop-all / Tokens / everything-but-attacking, searches by type, guild, title, tag, signature, or Armory into hand or play, start-in-play Drills, hand discards chosen by either player or shuffled back.

Also covered: "you may" prompts on any effect line with a `then` list that runs only on a yes, pay-any-Vigor effects with a per-unit follow-up, look-at-top-or-bottom-N with a pick, searches that let the searcher choose among distinct hits, instead-of-damage choices after a successful attack, attacks that need two stops, Ally powers usable without control, Drills that promote "if successful" text or discard themselves, Remain cards that shuffle back when unused, returning removed cards, forbids with a Vigor escape clause, forced Combat declarations.

And: Bonds (two named Allies fold under a Bond card that fights as one at full Vigor, burning a life card each turn until it ends), wound triggers on life cards ("if this card is discarded from your Life Deck…", optionally delayed to the next fight-back phase), look-at with a play-instead option and reshuffle, searches by what a card does (`has_effect`), an end-turn effect, and a response window during the opponent's Declare step (`opponent_declare` trigger on a Non-Combat in play).

Not yet: Use-when-needed windows outside the Combat-card counter and the Declare window, damage multipliers and caps, reordering the cards a look-at leaves behind.

## Client

- `duel_view.gd` renders one seat's `SeatView` and nothing else. Hotseat and hosting keep a `Referee` in the scene; after every command it plays the seat's `SeatUpdate` into the log and into table tweens, then shows the next prompt. A `Card3D` exists per uid the view lists, with a face only when the view carries a definition. Any card decision can be made by clicking the card (in the 2D hand or on the table) or by the button list in the prompt panel, which always lists every legal option.
- `table_layout.gd` turns zone names into table slots. Each zone owns its own rectangle on the felt (two rows per side: Mastery, Allies, Fighter, Tokens, Life Deck, Discard; then Master with its Armory, Drills, the card in play, Non-Combats, Removed; Grounds across the centre). The outlines and labels on the table are drawn from the same markers and slot counts. Rows squeeze past their slot count instead of spilling into a neighbour. Player 1's slots mirror player 0's; every card and label turns to read upright for the current viewer.
- `card_face_cache.gd` draws each card face once into a `SubViewport` and caches the texture. Faces are procedural: guild color frame, title, type line, generated rules text, and the art from `assets/card_art/<id>.png` when it exists (452 x 230 box at the 512 x 716 render size, covered and cropped).
- Rules text comes from `CardText` in the engine (`rules_text` for cards, `tier_text` for a personality tier with its Power, Constant powers and Defense Shield). Effects that share a trigger and condition fold into one sentence; a forbid or board clear that hits both players reads once. `CardText.KEYWORDS` lists every keyword with a regex, a colour role and a tooltip; `scripts/ui/keyword_text.gd` turns plain text into BBCode with those colours (ink on the cream face, light on the dark HUD) and `keyword_label.gd` is the `RichTextLabel` that shows the tooltip on hover. The hover zoom is a live `CardFace`, so hovering a keyword on it explains it; the zoom waits 0.3 s before closing so the pointer can reach it and stays while the pointer is over it.
- Hotseat: when the prompt's player changes, a hand-off overlay hides the hand, and on confirm the camera swings to that player's side.
- Online: the host (seat 0) runs the only `Referee`. The joiner holds no engine and no seed: it sends its choices up as `Command` dictionaries and gets back seat 1's `SeatUpdate`, so hidden cards never reach its process. Traffic that arrives while the table is still animating waits in a queue. When the other player is deciding, the prompt panel says so without listing their options. Disconnects end the duel with a notice; only the host can call a rematch or return both clients to the lobby.
- What the host can still do: read everything, since the rules run in its process. That is the friends-only limit of P2P; a headless server running the same `Referee` for both seats is the next step, and the client already speaks only views.

Dev flags after `--` when launching `res://scenes/duel/duel.tscn` directly: `--dev-autoplay` (random legal choices), `--dev-steps=N`, `--dev-seed=N`, `--dev-stop-at=<prompt kind>` (stop autoplay at the first prompt of that kind, e.g. `defense`; add `--dev-click` to open the first card's action sub-choice before the shot, or `--dev-zoom` to open the hover zoom on the first hand card), `--dev-pick=A,B` (deck indexes, in file order, for the two players), `--dev-fast` (tweens run at eight times speed, so a long autoplay takes seconds), `--dev-hide-hud`, `--dev-screenshot=<path.png>`. The select screen takes `--dev-pick=A,B` and `--dev-screenshot=<path.png>`.

Online without clicks, launching the project (title scene) twice: the first instance with `--dev-host`, the second with `--dev-join=127.0.0.1`; both with `--dev-pick=A,B` (each uses only its own seat), `--dev-autoplay` (the host starts as soon as both seats are set), `--dev-steps=N` (counts every command applied, so both stop on the same state) and `--dev-screenshot=<png>`. Online, `--dev-seed` and `--dev-pick` on the duel scene are ignored because the lobby already agreed on both.

## Loadouts

Six starter decks modelled card-for-card on a community set of sample decks for the reference game, ordered easy to advanced. Counts and roles are kept and each card carries the mechanics of the card it stands in for, written in the effect schema below; every name is original. `data/cards/starter/starter_set.json` and the deck files are generated together by `tools/gen_starters.py` (run it from `zenith/`), so edit the generator rather than the JSON by hand.

| Deck | Type | Plan |
|---|---|---|
| House Ashmark, Bram Ashmark, Ember Knave (79 + 11 Armory) | Physical beatdown, easy | High-Might fighter, Strikes that raise Acclaim, the single-copy stop-alls, Acclaim-from-discard Mastery |
| House Quarr, Halden Quarr, Steel Knave (55 + 11 Armory) | Physical beatdown, easy | Brute Strikes, a Mastery that drains the opponent on entry, three Tokens, Truce |
| The Draik Company, Sable Draik, Shade Knave (80 + 4 Armory) | Ally deck, easy | Five sworn blades who share the captain's constant power, ally search, hand disruption |
| House Rooke, Dame Alder Rooke, Tide Knight (79 + 3 Armory) | Ally deck, medium | Four protected kin, Arts, a Mastery that raises the opponent's tier threshold |
| House Vale, Caedan Vale, Freestyle Knight (77 + 4 Armory) | Drill deck, medium | Five-tier swordsman, "Sword" title synergies, protected Drills, a named-card lock |
| House Corven, The Ninth Vessel, Storm Knave (80 + 9 Armory) | Energy beatdown, medium | Cheaper Arts that search more Arts, Acclaim ramp, a Master that shields Acclaim and tier |

Alignment strings are `knight` and `knave` (the Chivalry and the Knavery at court; see the design doc's Setting). Knights open the duel when the bracket rule does not decide it.

Later rulings adopted with them: a Focus needs a Mastery (so Endurance does too), the Armory swap happens as a prompt before the first turn, and the first player is decided by Strike Table bracket instead of doubling stages.

Remaining approximations in the starter set:

- Hard Glare and Challenge show the owner the opponent's whole hand as the choice list. Tokens 2, 6 and 7 of each set are simple fillers the sheets never use.
- Truce ends the turn for both players: nobody takes a Discard step.
- Bonds (the two-Allies-as-one card): the Bond burns one life card per turn of its owner and ends at five; the two Allies return at 3 Vigor and the Bond card goes back to the Armory. A Bond that leaves play takes both Allies with it.

## Card JSON

```json
{"id": "ember_overhand_cut", "title": "Ember Overhand Cut", "type": "strike", "guild": "ember",
 "endurance": 1,
 "attack": {"kind": "strike", "stages": 2},
 "effects": [{"trigger": "if_successful", "op": "acclaim", "amount": 1}]}
```

- `type`: fighter, ally, strike, art, combat, non_combat, drill, token, grounds, mastery, master
- `guild`: ember, tide, storm, shade, steel, root, or omitted for Freestyle
- `attack`: `kind` strike | art; `stages`, `life` add to base; `printed_stages`, `printed_life` replace it; `cost_stages` (default 2 for arts), `cost_life`; `focused`, `unstoppable`, `no_prevent`, `no_stop_by` (a card type), `stages_from_table`, `life_per_ally`, `life_from_surge`, `only_first_attack`, `pay_stages` `{per, life}`, `variants[]` of `{when, ...overrides, effects}` merged when the condition holds
- `defense`: `{"stops": "strike" | "art" | "any"}` plus optional `when` (condition), `stop_all` (kind), `stop_focused` (true or `"discard_hand"`), `cost_stages`, `cost_life`, `copy_attack`. A card with both `attack` and `defense` attacks in the attack phase and defends in the defense phase; `use_in_attack` lets a pure defense also be used in place of an attack
- `effects[]`: `trigger` secondary (default) | if_successful | if_stopped | before_damage (after a successful attack, before damage; with `skip_damage` the attack then deals none) | on_place | use | master_use | on_success (Mastery) | entering_combat (optional `role`) | on_wound (this card left the Life Deck as a wound or cost; `at: "fight_back"` delays it to the next fight-back phase of the Combat) | opponent_declare (a Non-Combat in play, offered to its owner during the opponent's Declare step); `who` self | opponent; `when` (condition); `may` asks the owner first; `then` is a list of effects that run right after this one (only on a yes for `may`, once per unit paid for pay_vigor); `after_empower` drops the line when Empowered. Ops: acclaim, set_acclaim, vigor (amount or `"max"`, `target` fighter, `no_overflow`), set_vigor, draw, draw_until, draw_discard (`from`), draw_check (guild, effects), discard_life, discard_hand (`random`, `chooser` owner, `to` deck, `filter` signature | non_token), remove_hand, pay_vigor (`per`, with `then`), look_at (`from` top | bottom, `amount`, `pick` filter, `to`, `play_if` filter for a card that may go into play instead, `shuffle_after`), search (`card_type`, `guild`, `title_contains`, `exclude_title`, `tag`, `signature_of` fighter, `source` deck | discard | either | armory, `to` hand | play, `stages`, `amount`, `has_effect` `{op, who}` to match by what a card does; the searcher picks when several distinct cards match, `choose: false` takes the first), choose_forbid_type (`unless_vigor_min`), return_removed (`card_type`), focus_attack (the current attack becomes Focused), end_turn, force_declare, bond (`card`: the Bond Ally id, found anywhere in the owner's zones), discard_in_play (`card_type` non_combat | non_combat_only | drill | freestyle_drill | ally | token | non_combat_or_ally | drill_or_ally, `amount`, `all`, `remove`, `choose`, `up_to`, `chooser`), remove_discard (`all`), shuffle_discard (`per_personality`), recover, end_combat, skip_next_attack_phase, cannot_declare_combat, stop_all, choose_stop_all_kind, float (`what`, `duration` combat | turn | next_turn_end, `params`), forbid (`what`, `duration`), lose_tier, advance_tier, set_tier (`tier` or `"acclaim"`), no_favor_win, attach (`to`), capture_token, name_card, next_attack_tax
- Conditions (`when`): focus, opponent_focus, character, fighter_character, alignment, performed_by, tier_min, vigor_min, opponent_acclaim, allies_min, ally_present, opponent_allies_min, opponent_non_combats_min, discard_top_guild, discard_top_guild_not, discard_top2_guild, discard_min, higher_might, opponent_used_combat_card, first_attack, role, tokens_min, hand_min, stopped_last_phase, source_guild
- `vigor` accepts `target` fighter | last_searched (the card the last search put into play); `draw_check` takes `check` guild | named | signature | title_contains
- Floating `what`: no_prevent, prevent_all, make_focused (guild), after_use_bottom (guild), damage_removes, no_gain, no_ally_control, keep_hand, endurance_boost, no_endurance, stop_next, prevent_art_life, modifier (a modifier dict, `once` for a single attack)
- Forbid `what`: strike_attacks, art_attacks, strike_cards, art_cards, combat_cards, non_combats, drills, mastery, powers, end_combat, stop_all, tokens, non_attack_actions, skip_combat. Printed `forbid[]` lists work on Grounds, Drills, and Non-Combats
- `modifiers[]` on drills, masteries, grounds and constants: `scope` own | against, `kind` strike | art | any, `stages`, `life`, optional `guild`, `title_contains`, `when`, `per_ally`
- `forbid[]` on grounds and drills: `{"who": "all" | "owner" | "opponent", "what": ...}`; `shield` on drills: strike | art | any; `attachment`: `{target, modifiers, effects, damage_removes, title_contains}`
- Keywords: `endurance`, `endurance_when` `{value_if, then, else}`, `empower`, `remain`, `remain_when` `{when, remain}`, `unused_return` `"shuffle"`, `counter` `"combat"`, `start_in_play` (from the Life Deck or the Armory), `only` `{character | fighter_character}`, `bottom_after_use`, `remove_after_use`, `once_per_combat`, `tags[]`; on Drills also `promote_if_successful` (title fragment) and `discard_if_other_non_combats`
- Attack extras: `stops_needed` (the defender must stop it that many times), `life_per_opponent_token`
- Personalities: `character`, `tiers[]` with `tier`, `surge`, `might` (11 ints for stages 0 to 10), optional `wild`, `shield`, `power` (`attack`, `defense`, `effects`, `uses`, `no_control_needed` on Allies), `constant`; a Bond Ally adds `bond_of` (two Ally characters) and `bond_timer_max`, and can never be placed directly (`attacks_focused`, `first_styled_unstoppable`, `damage_removes`, `protect_allies`, `ally_control_any_stage`, `allies_share`, `acclaim_multiplier`, `forbid_opponent[]`, `modifiers[]`, `on_attack[]`, `turn_start[]`, `entering_combat[]`)
- Masteries: `art_cost_delta`, `opponent_tier_threshold`, `protect_drills`; Masters: `armory_size`, `uses_per_game`, `master_flags` (`no_favor_win`, `acclaim_shield`, `tier_shield`); Grounds: `double_costs`
- `text` overrides the generated rules text; `alignment_only`, `limit_per_deck`, `token_set`, `token_number`, `capture_trait`

Deck JSON: `name`, `fighter`, `tiers`, `focus`, `alignment`, `mastery`, `master`, `armory[]`, `cards[]` of `{"id", "count"}`.

## Tests

```powershell
$godot = "G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe"
& $godot --headless --path zenith --import
& $godot --headless --path zenith -s tests/run_tests.gd
```

Run the import once after adding a `class_name` script, or headless runs will not see it. The suite also validates every deck in `data/decks/` and plays each one against itself with random choices to the end. `tests/stress_starters.gd` plays every deck pairing for three seeds and reports any game that does not finish.

Visual check without a screen:

```powershell
& $godot --path zenith --resolution 1600x900 res://scenes/duel/duel.tscn -- --dev-autoplay --dev-steps=45 --dev-seed=5 --dev-screenshot=C:\path\shot.png
```

Online check, two instances on one machine (start the joiner a few seconds after the host):

```powershell
& $godot --path zenith --resolution 1600x900 -- --dev-host --dev-pick=3,5 --dev-autoplay --dev-steps=40 --dev-screenshot=C:\path\host.png
& $godot --path zenith --resolution 1600x900 -- --dev-join=127.0.0.1 --dev-pick=3,5 --dev-autoplay --dev-steps=40 --dev-screenshot=C:\path\client.png
```

The suite's `test_seat_view_masks_hidden_cards` checks exactly which cards go out blank, `test_referee_gates_commands` that the wrong seat or a forged option is refused, `test_uids_hide_deck_order` that uids do not follow the deck list, and `test_command_wire_lockstep` that a second engine fed only wire-form commands ends in the same state.
