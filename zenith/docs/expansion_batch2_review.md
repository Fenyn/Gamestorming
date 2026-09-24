# Card expansion, batch 2: review sheet (revision 2, 2026-09-23)

**Locked in 2026-09-23.** Approved: batch 2 revision 2, batch 3 (with the Tide Sinking Blow swap),
the 15 new Masteries, the Mastery names, the Steel dragon rename (humanoid, no wings), and the full
naming pass including first-name signature titles and the four named-source cards. Where a later
section renames a card, the later name wins. **Built:** Pyre, all 25 cards and both Masteries
(2026-09-23, `tools/decks/pyre_expansion.py`); their ids are in `docs/card_pool.md` and their
`tools/source_candidates.tsv` rows read `built`. The ids in this sheet are the old proposals and are
kept as a record. Still open: the
11 characters the blocked named cards wait on, and whether ids change with the titles when the
renames are applied. The full pool is `docs/card_pool.md`, rebuilt by `tools/gen_card_pool.py`;
source rows are `approved` or `cut` in `tools/source_candidates.tsv`.

50 candidates that bring Pyre, Steel, Tide, Root to 40 cards each and Shade to 41. Nothing here is
built. Counts leave out Masteries and signature cards and include gated cards. Storm (43) is left
as it is.

Revision 2 re-cut the first draft around subthemes. Every pick either fills an element the school
lacks in the current set or is a top-end card for a theme the school already has a few of. 36 of
the first draft's 49 stay (some renamed), 13 are cut, and 14 are new. Each new pick parallels a
printed card; sources go into `tools/source_candidates.tsv` once the titles are approved.

How to review: write in the **Verdict** column. `ok`, `rename: <title>`, `cut`, or a note.
An empty cell counts as not yet approved.

**Naming rule.** Every title shows the school's element and the way that school performs the
mechanic. Pyre is fire that feeds on and consumes. Steel is the Draconic blood surfacing in a
humanoid fighter for the length of a fight (scales, talons, horns, fangs, breath), never a full
dragon; see "Steel rename" below. Tide is water that drags, drowns and carries. Shade is shadow, hexes and the
whispered word. Root is thorn, sap, stone and frost.

Rulings still applied to every row: printed "declared" riders are always on, format-only notes are
dropped, no card carries a bloodline or alignment gate, and the one-school-of-Drills exemptions two
printed Drills carry are dropped.

**Engine column.** `ready` maps to effects the engine has today. `add` needs a small engine
addition, listed at the end. `new` marks a pick that was not in the first draft.

---

## Pyre, 15 (25 to 40)

| Subtheme | Now | After |
|---|---|---|
| Fervor as a number (X = your Fervor) | 0 | 5 |
| Drills, and cards that put them into play | 0 | 8 |
| Burning their discard pile to ash | 1 | 4 |
| Burning the board | 4 | 5 |
| Art answers (gap) | 2 | 5 |

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Pyre Rising Heat Drill | Drill | Your attacks do +X Energy, X = your Fervor. Limit 1 | Fervor as a number, bomb | add | |
| Pyre Banked Coals Drill | Drill | Your Fervor cannot be lowered | Drills | add | |
| Pyre Hearthstone Drill | Drill | Your other Drills survive an Aspect change | Drills | add | |
| Pyre Cinder Sift Drill | Drill | Once a Combat, a landed Strike shuffles a card from your discard pile back in | Drills, recursion gap | ready | |
| Pyre Flame Screen Drill | Drill | Defense Shield: stops the first unstopped Art each Combat | Drills, Art answers | new, ready | |
| Pyre Smoldering Drill | Drill | Your attacks do +2 Energy. At the start of your turn, the bottom 3 cards of their discard pile leave the game | Drills, ash | new, ready | |
| Pyre Laying Fire | Strike | Endurance 2. +3 Energy. Hit: put a Pyre Drill from your deck into play | Drills | ready | |
| Pyre Bonfire | Strike | Empower 4. Put up to 5 Pyre Drills into play. Fervor +1. Removed after use | Drills, bomb | ready | |
| Pyre Drawing Flue | Art | Endurance 4. 1 wound + X, X = your Fervor. Hit: shuffles back in | Fervor as a number | add | |
| Pyre Blazing Hide | Strike | Endurance X, X = your Fervor. +3 Energy | Fervor as a number | new, add | |
| Pyre Choking Smoke | Art stop | Endurance X, X = your Fervor. Stops an Art. Their Fervor -1. At their Fervor 0 or 1, the bottom 10 of their discard pile leave the game | Fervor as a number, ash, Art answers | add | |
| Pyre Heat Haze | Art stop | Stops an Art. With Fervor 1+, stops every Art this Combat. Removed after use. Limit 1. **Lockout** | Art answers | add | |
| Pyre Cremation | Strike | Strike. Hit: their whole discard pile leaves the game | Ash, bomb | new, ready | |
| Pyre Conflagration | Combat | Pay 5 Energy. Discard every Ally and Non-Combat in play. Your Energy drops to 0. Fervor +1. Limit 1 | Burning the board, bomb | new, ready | |
| Pyre Burned Through | Art | 5 wounds. They cannot use Endurance against your Pyre attacks this Combat. Hit: Fervor +2 | Art body | ready | |

Ash is new to the set as a theme. It is the school's answer to recursion decks: fire leaves nothing
to bring back. After: 27 Strike, 5 Art, 2 Combat, 0 Non-Combat, 6 Drill.

---

## Steel, 10 (30 to 40)

| Subtheme | Now | After |
|---|---|---|
| Might comparison | 3 | 7 |
| Endurance as armour | 4 | 7 |
| Squeezing their Energy | 5 | 7 |
| Empower | 3 | 6 |
| Non-Combat (gap) | 0 | 1 |
| Recursion (gap) | 1 | 2 |

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Steel Outweighing Blow | Strike | +3 Energy. Doubles the Strike Table base while your Might is higher | Might, bomb | add | |
| Steel Overflowing Might | Art | Art. If your Might is higher: Fervor +1, and your other attacks do +2 wounds this Combat | Might | new, ready | |
| Steel Blood Memory | Non-Combat | Fervor +2. The bottom 2 cards of your discard pile go under your Life Deck. If your Might is higher, draw a card. Removed after use | Might, Non-Combat gap, recursion gap | new, ready | |
| Steel Boiling Blood | Art | 6 wounds. Focused while your Might is higher. This Combat, each Endurance you use gains you 1 Energy | Might, Endurance | add | |
| Steel Scar Count | Strike | Endurance 1. +3 Energy, Fervor +1, Empower 2. This Combat your Strikes do +1 Energy per Endurance you have used | Endurance, Empower, bomb | add | |
| Steel Snapped Brace | Strike | Endurance 2. If stopped, a Drill in play of your choice leaves the game. Removed after use | Endurance | ready | |
| Steel Iron Stare Drill | Drill | Their attacks cost +1 Energy, +2 when they play Root | Energy squeeze | add | |
| Steel Anvil Drill | Drill | Your attacks do +2 Energy. Their personalities gain 1 less in the Power Up step | Energy squeeze | add | |
| Steel Lasting Wound | Art | Fervor +1. Empower 4. This Combat your wounds leave the game and cannot be prevented | Empower | ready | |
| Steel Whole-Body Blow | Strike | +3 Energy. Empower 2. This Combat, when you Empower, you keep the rest of the card's text | Empower, bomb | new, add | |

First-draft correction: Boiling Blood's printed rider gains Energy per Endurance used; the first
draft read it as paying Energy. After: 26 Strike, 9 Art, 1 Combat, 1 Non-Combat, 3 Drill.

---

## Tide, 12 (28 to 40)

| Subtheme | Now | After |
|---|---|---|
| Fervor denial | 13 | 17, plus a payoff |
| Allies | 4 | 9 |
| Digging and reshaping the deck | 5 | 7 |
| Drills (gap) | 0 | 4 |
| Moving an Aspect (gap across the whole set) | 0 | 1 |

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Tide Salt Burn Drill | Drill | Your attacks do +2 Energy. Lowering Fervor they do not have takes that many cards off their Life Deck | Fervor denial payoff, bomb | add | |
| Tide Dead Calm | Strike | Costs 2 Energy. +2 Energy. Hit: they discard X cards from the top of their Life Deck, X = 5 minus their Fervor | Fervor denial payoff | new, add | |
| Tide Frozen Over | Strike | +2 Energy. Their Fervor to 0, and it cannot rise until their next turn | Fervor denial | add | |
| Tide Breaking Sea | Strike | +6 Energy. Their Fervor -4 | Fervor denial, large hit gap | ready | |
| Tide Riptide | Non-Combat | Their Fervor to 0. Their duelist drops one Aspect. Removed after use | Fervor denial, Aspect movement, bomb | new, ready | |
| Tide Shoal Drill | Drill | A landed Strike fetches a tier 1 Ally to hand | Allies | add | |
| Tide Mooring Drill | Drill | Your Allies cannot be discarded. Limit 1 | Allies | add | |
| Tide Following Current Drill | Drill | Attacks your Allies perform do +2 Energy | Allies | new, add | |
| Tide Answering Current | Non-Combat | Put an Ally into play from your deck and one from your discard pile. Removed after use | Allies, bomb | ready | |
| Tide Washout | Combat | Endurance 1. A Drill in play leaves the game. Your duelist and Allies gain 2 Energy. Fervor +1. Removed after use | Allies, Fervor gain gap | ready | |
| Tide Sounding | Strike stop | Stops a Strike. Look at your top 3 and take one. Below Aspect 3 the opponent picks which | Digging | add | |
| Tide Backwash | Art | Focused, 5 wounds, or stops an Art. Returns cards from your discard pile equal to your Fervor. Removed after use | Digging, attack-or-stop | add | |

After: 18 Strike, 13 Art, 2 Combat, 3 Non-Combat, 4 Drill.

---

## Shade, 11 (30 to 41)

| Subtheme | Now | After |
|---|---|---|
| Whisper cards | 10 | 13 |
| Attacking the Life Deck | 0 | 3 |
| Hexes that attach | 1 | 3 |
| Hand attack | 12 | 13 |
| Energy gain, board removal, recursion (gaps) | 2, 2, 1 | 3, 3, 2 |

Whisper is the one subtheme in the set whose cards read each other (`shade_returning_whisper` pulls
three back). The three new whisper picks come from the same printed family as the existing ones.

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Shade Opening Whisper | Strike | Must be the first card you use this Combat. +10 Energy. Hit: they cannot perform Strikes this Combat. If stopped, discard your top 5 | Whisper, bomb | new, add | |
| Shade Stilling Whisper | Strike | +3 Energy. Hit: attaches to one of their Non-Combats, which cannot be used | Whisper, hexes | add | |
| Shade Feeding Whisper | Strike stop | Stops a Strike. Fervor +2 | Whisper | ready | |
| Shade Wasting Mark | Strike | +3 Energy. Attaches to their duelist. Their attacks do -2 Energy until they reach full Energy | Hexes | add | |
| Shade Erased Name | Combat | Name a card. Every copy leaves their Life Deck and the game. Removed after use. **Lockout** | Life Deck, bomb | ready | |
| Shade Pilfering Shadow | Non-Combat | Search their Life Deck and remove 2 cards from the game. Removed after use | Life Deck | add | |
| Shade Creeping Dark | Combat | Their Life Deck loses cards equal to your Surge | Life Deck | add | |
| Shade Clouded Mind Drill | Drill | Each successful attack puts a random card of their hand into their deck. They draw 1 | Hand attack | add | |
| Shade Shadow Respite | Non-Combat | Fill a personality's Energy. You may end the Combat | Energy gain gap | ready | |
| Shade Culling Dark | Art | Endurance 2. Hit: discard one of their Allies | Board removal gap | ready | |
| Shade Gathered Hexes | Art stop | Stops an Art. Returns 3 Shade cards from your discard pile. Removed after use | Recursion gap | ready | |

After: 20 Strike, 12 Art, 3 Combat, 2 Non-Combat, 4 Drill.

---

## Root, 2 (38 to 40)

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Root Sap Flow Drill | Drill | Your attacks do +2 Energy. Your card costs are 1 Energy less, to a minimum of 1 | Cost reduction (2 in the set), pays for Root's 3- and 4-Energy Arts | new, ready | |
| Root Swallowing Earth | Combat | Your Strikes do +2 Energy this Combat. A Seal in play goes to the bottom of its owner's Life Deck | Seals (2 today), works for or against a Seal deck | new, ready | |

Root's other thin spot, Fervor gain (1 card), has no printed card in the school's style to draw
from, so it stays with Freestyle.

---

# Batch 3: every school to 50 (2026-09-23, not yet approved)

56 more candidates, each one filling a gap the school still had after batch 2. Same rules as batch 2,
with one change. Steel now needs a Draconic Duelist and Root a Verdant one, so a printed
"Heritage only" line costs almost nothing. Four picks keep it as "Draconic only" or "Verdant only".
Titles are placeholders for the renaming pass. Steel titles already lean toward the dragon theme.

## Batch 3: Pyre, 10 (40 to 50)

Gaps: attacking Arts (4, which leaves Cinder Mastery with nothing to boost), a stop for either
attack type (0), and Non-Combat (0; the printed Pyre style has almost none, so none are added).

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Pyre Phoenix Flame | Art | 5 wounds. Hit: shuffle 5 Pyre cards from your discard pile back in. Removed after use | Pyre Arts, recursion | ready | |
| Pyre White Flame | Art | Endurance 2. 6 wounds, and they leave the game. Draw your bottom card. Removed after use | Pyre Arts, bomb | add | |
| Pyre Flare Volley | Art | Endurance 2. 2 wounds, Remain 2. You may discard a card for +3 wounds. Removed after use | Pyre Arts | add | |
| Pyre Unmaking Blaze | Art | 6 wounds, or their duelist drops an Aspect. Removed after use | Pyre Arts, bomb | add | |
| Pyre Sudden Flare | Art | Focused, 3 wounds. Hit: Fervor +2 | Pyre Arts | ready | |
| Pyre Struck Spark | Art | 3 wounds for 1 Energy. Fervor +1 | Pyre Arts | ready | |
| Pyre Kiln Drill | Drill | Your successful Arts do +2 wounds | Pyre Arts, Drills | ready | |
| Pyre Stoked Blaze | Combat | Your Arts cost 1 less (to 1) and do +2 wounds this Combat. Their Fervor -1 | Pyre Arts | ready | |
| Pyre Burnt Offering Drill | Drill | Discard your whole hand to stop a Strike or an Art. You need a card in hand | Drills, stop either type | add | |
| Pyre Backfire | Strike | Stops a Strike. They discard their top 3. Removed after use | Climbing blocks | ready | |

## Batch 3: Steel, 10 (40 to 50)

Gaps: board removal (2), Drill fetch (0), Defense Shields (0), Combat and Non-Combat (1 each). The
three Draconic-only picks are the Empower cards batch 2 left out.

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Steel Reclaimed Hoard | Art | Draconic only. 3 wounds. Empower 4. Put 2 Steel cards from your discard pile on top of your deck. Removed after use | Empower, recursion | ready | |
| Steel Tail Sweep | Art | Draconic only. 3 wounds. Empower 4. Discard up to 3 of their Drills. Removed after use | Empower, board removal | ready | |
| Steel Wingbeat | Art | Draconic only. Art. Empower 3. Discard up to 3 of their Allies. Removed after use | Empower, board removal | ready | |
| Steel Cornered Wyrm | Art | Endurance 4. 5 wounds. Fervor +1. This Combat your Steel attacks with Empower are Focused | Empower, Endurance armour | add | |
| Steel Awakened Blood | Art | 5 wounds. Empower 2. Put a Steel Drill that adds damage from your deck into play. Their Fervor -2 | Empower, Drill fetch | ready | |
| Steel Crushing Coil | Strike | Focused, +3 Energy. Put a Steel Drill from your deck into play. Hit: their Surge is 0 until the end of their next turn | Energy squeeze, bomb | add | |
| Steel Hardscale Drill | Drill | Defense Shield: stops the first unstopped Strike each Combat | Endurance armour | ready | |
| Steel Towering Charge | Strike | +4 Energy. If your Might is higher, discard up to 2 of their Allies | Might comparison | ready | |
| Steel Swelling Might | Combat | Use when you attack. Fill your Energy. Your next attack does +X Energy, X = Energy gained, up to 5. Removed after use | Might comparison | add | |
| Steel Bared Fangs | Non-Combat | Your duelist loses 4 Energy. Your attacks do +3 wounds this Combat | Raw Strikes | ready | |

## Batch 3: Tide, 10 (40 to 50)

**Tide subthemes revised 2026-09-23.** Fervor denial is a school-wide trait, a rider on 19
cards, and no longer a build-around: it stops a climb but never wins. The build-arounds are
**Drowning** (payoffs that turn low Fervor into lost Life Deck cards or a lost Aspect: Salt Burn
Drill, Dead Calm, Pounding Surf, Leeching Brine, Riptide, Frozen Over, Sinking Blow), **Allies**, and
**Guard** (stops, Defense Shields, attack-or-stop cards, Eddy and Fathom Masteries). Sinking Blow
replaced Still Waters, which was denial with no payoff.

Gaps: recursion (1), a stop for either attack type (0), Defense Shields (0), Fervor gain (4), and
board removal of Drills (1).

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Tide Returning Tide | Combat | Their Fervor -2. Put your top 3 discards under your deck | Fervor denial, recursion | ready | |
| Tide Flotsam | Strike | Endurance 3. Stops an Art. Fervor +1. Put 2 Non-Combats from your discard pile on top of your deck. Removed after use | Digging, recursion | ready | |
| Tide Sinking Blow | Strike | 1 wound. Hit: if the top card of their discard pile is not a Strike, they discard their top 5 | Drowning | add | |
| Tide Spring Tide | Art | 5 wounds. Fervor +2. Their Fervor -1 | Fervor denial, Fervor gain gap | ready | |
| Tide Pounding Surf | Strike | Endurance 3. +3 Energy. Fervor +1. Hit: this Combat your Strikes read the table as if the base were 4 minus their Fervor | Fervor denial payoff | add | |
| Tide Parting Waters | Combat | Endurance X, X = your Fervor. Stops a Strike or an Art. Removed after use, or discarded at Aspect 3+ | Stops | add | |
| Tide Seawall Drill | Drill | Defense Shield: stops the first unstopped Strike each Combat | Stops | ready | |
| Tide Narrow Channel Drill | Drill | They may place only 1 Non-Combat a turn | Board strip | add | |
| Tide Erosion | Non-Combat | Discard one of their Drills | Board strip | ready | |
| Tide Leeching Brine | Art | Art. Hit: attaches to their duelist; they discard their top 2 at each turn start until they reach full Energy | Fervor denial payoff (mill), hexes | add | |

## Batch 3: Storm, 7 (43 to 50)

Gaps: draw and search (2), recursion (1), and support for Storm's Drills now that Conductor Mastery
trades them.

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Storm Backflash Drill | Drill | When a Strike damages you, draw the bottom card of your discard pile | Drills, recursion | add | |
| Storm Seeking Spark Drill | Drill | Once a Combat, after your Art lands, search their deck for a card and discard it | Drills, Art boosts | add | |
| Storm Grounding Drill | Drill | When you stop an attack, you may remove this Drill to stop every attack of that kind this Combat. Limit 2 | Drills, Strike answers, Art answers | add | |
| Storm Stormwall Drill | Drill | Your Surge +1. Your Defense Shields can stop Focused attacks | Drills, Table defense | add | |
| Storm Gathering Front | Strike | +3 Energy. Empower 2. Look at your top 4 and put a Drill from them into play; the rest back in any order | Drills, draw and search | add | |
| Storm Lightning Rod | Strike | Strike. At the end of this Combat, put a Storm Drill from your deck into play | Drills, draw and search | add | |
| Storm Steady Current | Art | Endurance 1. 6 wounds. This Combat your Drills survive an Aspect change | Storm Arts, Drills | add | |

## Batch 3: Shade, 9 (41 to 50)

Gaps: Fervor denial (1), Energy gain (3), board removal (3), recursion (2), Defense Shields (0).

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Shade Umbra Drill | Drill | Defense Shield: stops the first unstopped Art each Combat | Answers | ready | |
| Shade Effacing Drill | Drill | After your Art lands, remove one of their Non-Combats in play from the game. Limit 1 | Board removal | add | |
| Shade Reclaimed Hex Drill | Drill | When you stop an attack, put your bottom discard under your deck | Answers, recursion | add | |
| Shade Stolen Secret | Combat | Endurance 2. Look at their hand. They skip their next attack phase. Your next attack this Combat does +2 wounds | Hand attack | ready | |
| Shade Mockery Hex | Combat | They discard their top 2 for each Fervor they have. They shuffle their hand into their deck and draw that many. Removed after use | Life Deck attack, Fervor denial | add | |
| Shade Named Doom | Strike | +3 Energy. Name a card; one copy leaves their deck for the discard pile | Life Deck attack | ready | |
| Shade Sapping Shadow | Strike | Stops a Strike. They lose 1 Energy. Their Fervor -1 | Answers, Fervor denial | ready | |
| Shade Reaching Shadow | Strike | +3 Energy. Hit: gain 3 Energy | Shade attacks, Energy gain | ready | |
| Shade Dilemma Hex | Art | Costs 3 Energy. Hit: you may discard a card; if you do they discard one at random or lose 4 Energy, their choice | Hand attack, Paying Energy | add | |

## Batch 3: Root, 10 (40 to 50)

Gaps: Fervor gain (1), a stop for either attack type (1), Ally support (1), and cheap Arts. Two picks
keep their printed heritage line as "Verdant only". The printed "Piccolo and Nail only" and
"up to 8 copies" lines are dropped.

| Title | Type | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Root Fallen Oak | Non-Combat | Remove one of your Allies from the game. Fervor +2. Removed after use | Fervor gain gap | ready | |
| Root Grove Kin | Non-Combat | Fill your Allies' Energy; you may use their powers this Combat. Discard your top card for each Ally | Allies | add | |
| Root New Shoots | Combat | Verdant only. Shuffle the top or bottom 3 cards of your discard pile into your deck | Recursion | ready | |
| Root Creeping Vine | Strike | Endurance 4. +2 Energy. Hit: shuffle a card from your discard pile back in | Recursion, Table defense | ready | |
| Root Seed Burst | Art | Focused, 5 wounds. Hit: choose up to 4 discards; 2 leave the game and the rest shuffle back in. Removed after use | Recursion | add | |
| Root Stone Cleaver | Strike | Endurance 4. Focused, +3 Energy. Empower 3. They cannot use Defense Shields this Combat. Discard up to 3 of their Allies | Board strip, bomb | add | |
| Root Frost Watch Drill | Drill | Discard an Art from hand to stop an Art. Your Surge +2 | Table defense | add | |
| Root Hurled Thorns | Art | 5 wounds for 1 Energy. Hit: shuffle your top discard back in | Costly Arts, recursion | ready | |
| Root Strangling Vine | Non-Combat | One of their Drills loses its power for the rest of the game. Removed after use | Board strip | add | |
| Root Oakheart Guard | Strike | Verdant only. Endurance 3. Strike, or stops a Strike | Table defense | ready | |

Engine for batch 3: 28 of 56 map to effects the engine has today. The other 28 need small
additions. The recurring ones are Drills that react to a stop or a landed Art (6 cards), Surge
changes (3), Drills surviving an Aspect change (the same addition batch 2's Hearthstone Drill
needs), and a float that blocks Fervor gain (Still Waters, shared with batch 2's Frozen Over).

---

## Steel rename to the dragon theme (2026-09-23, proposed, revision 2)

Steel is the magic of the Draconic line. The duelist stays a person and, for the length of a fight,
the blood surfaces in them: scales across the forearms, hands gone to talons, horns, fangs, slit
eyes, a tail that sprouts and recedes, breath (fire included), a frame that swells heavier.
Every name is a humanoid fighter using a borrowed dragon trait, never a full-size dragon doing
something. Martial-arts names go. Titles only; ids would follow when this is applied.
`steel_bracing` searches for a card by the title "Steel Standoff", so that search changes with it.

**Shipped cards (30)**

| id | Now | Proposed | Mechanic | The trait |
|---|---|---|---|---|
| `steel_battering_ram` | Steel Battering Ram | Steel Horned Charge | +8 Energy, Fervor +1 | Horns push through the brow as they charge |
| `steel_bracing` | Steel Bracing | Steel Raised Scales | Stops either attack, fetches the standoff card | Scales rise across the arms to take the blow |
| `steel_bull_charge` | Steel Bull Charge | Steel Dragonblood Charge | 7 Energy; bigger Might shuts off their Mastery | The blood running hot enough to cow them |
| `steel_conditioning_drill` | Steel Conditioning Drill | Steel Clawed Hands Drill | Strikes +2 Energy | Nails kept hardened into claws |
| `steel_cross` | Steel Cross | Steel Talon Cleave | 10 Energy, once | One full cut with talons at full length |
| `steel_crushing_weight` | Steel Crushing Weight | Steel Dragonweight Blow | Bigger Might crushes a Non-Combat | A body suddenly far heavier than it looks |
| `steel_dead_weight` | Steel Dead Weight | Steel Pinning Claw | Empower; they cannot gain Energy | Held down under a clawed hand |
| `steel_forearm_guard` | Steel Forearm Guard | Steel Scaled Forearm | Stops a Strike, they lose 3 Energy | The blow lands on scale |
| `steel_hammer_blow` | Steel Hammer Blow | Steel Scalebound Blow | Endurance 4, +3 Energy +2 wounds | Scales take the return hit |
| `steel_headbutt` | Steel Headbutt | Steel Horn Gore | Hit: discard 2 Non-Combats or Allies | Horns driven through their table |
| `steel_immovable_guard` | Steel Immovable Guard | Steel Unyielding Scales | Bigger Might stops Strikes, Remain 9 | Scale over every inch, nothing gets in |
| `steel_iron_fist` | Steel Iron Fist | Steel Taloned Fist | Endurance 3, +4 Energy | A fist grown talons |
| `steel_iron_jab` | Steel Iron Jab | Steel Fanged Snap | Their next attack costs 2 more | A snap of sudden fangs and they flinch |
| `steel_iron_knee` | Steel Iron Knee | Steel Hoarding Claw | Hit: put a Seal into play | The blood's greed reaching for the prize |
| `steel_ironhide` | Steel Ironhide | Steel Ironscale Hide | Stops either attack, gain 7 Energy | Skin turned full scale |
| `steel_piston_slam` | Steel Piston Slam | Steel Recoiling Lunge | Focused; your Steel attacks go under your deck | Strike and snap back like a serpent |
| `steel_plating` | Steel Plating | Steel Dragonscale Mantle | Draconic only. Stops every Art this Combat | Scale spreading over the shoulders, spells slide off |
| `steel_rake` | Steel Rake | Steel Raking Talons | Draconic only. +5 Energy | Talons dragged through |
| `steel_reverse` | Steel Reverse | Steel Lashing Tail | +4 wounds, Fervor +1 | A tail that was not there a moment ago |
| `steel_scar_tissue` | Steel Scar Tissue | Steel Shed Skin | Endurance 2; shuffles 3 discards back | Wounded skin shed, new underneath |
| `steel_shockwave` | Steel Shockwave | Steel Deafening Roar | Draconic only. No Masteries or Drills this Combat | A roar no human throat should make |
| `steel_sink` | Steel Sink | Steel Swallowed Flame | Stops an Art; drains 4 if your bottom discard is Steel | The spell breathed in and swallowed |
| `steel_skull_crack` | Steel Skull Crack | Steel Locking Jaws | Reserve only. Unpreventable wounds, draw | Jaws that close and do not let go |
| `steel_slip` | Steel Slip | Steel Serpentine Twist | Stops a Strike, they lose 4 Energy | The spine bends further than it should |
| `steel_stamp` | Steel Stamp | Steel Clawed Heel | Discard your top card for +3 wounds | A heel grown talons |
| `steel_standoff` | Steel Standoff | Steel Kindred Standoff | End Combat, keep your hand | Blood knows blood; neither closes |
| `steel_tackle` | Steel Tackle | Steel Clawed Pounce | Discard your top card for +3 Energy | Legs gone taloned for one long leap |
| `steel_talon` | Steel Talon | Steel Rending Talon | Draconic only. +5 Energy, 2 wounds | A single talon, deep |
| `steel_tempering` | Steel Tempering | Steel Twin Claws | +3 Energy, Remain 1 | The second hand follows the first |
| `steel_triple_shock` | Steel Triple Shock | Steel Searing Breath | Focused Art, 3 wounds, draw | A short gout of breath |

**Batch 2 and 3 cards whose placeholder changes**

| Placeholder | Proposed | The trait |
|---|---|---|
| Steel Outweighing Blow | Steel Towering Frame | The body swells taller than the rival's |
| Steel Overflowing Might | Steel Dragonfire Breath | Breath that comes out hotter the bigger they have grown |
| Steel Scar Count | Steel Shedding Scales | Each spent scale feeds the next Strike |
| Steel Snapped Brace | Steel Thrashing Tail | Stopped, the tail still smashes a Drill |
| Steel Iron Stare Drill | Steel Baleful Gaze Drill | Slit eyes that make their spells cost more |
| Steel Anvil Drill | Steel Stifling Presence Drill | The blood's presence presses on them; they gain less Energy |
| Steel Lasting Wound | Steel Scorching Breath | Burnt wounds do not come back |
| Steel Whole-Body Blow | Steel Blood Unbound | Every trait at once, nothing held back |
| Steel Swelling Might | Steel Drawn Breath | A deep breath before the blow |
| Steel Cornered Wyrm | Steel Cornered Blood | The blood rises hardest when they are cornered |
| Steel Crushing Coil | Steel Constricting Grip | Scaled arms that squeeze until they cannot power up |
| Steel Wingbeat | Steel Routing Roar | A roar that sends their Allies running |
| Steel Wyrm Mastery | Steel Bloodrage Mastery | The blood takes over; they stop climbing and keep fighting |

Kept as they are: Boiling Blood, Blood Memory, Reclaimed Hoard, Tail Sweep, Awakened
Blood, Hardscale Drill, Towering Charge, Bared Fangs, and the Hoard, Dragonfear and Scale Masteries.
Quarr's three signature cards (Quarr Shrugs It Off, Quarr's Roar, Quarr's Crushing Blow) name him
rather than the move, so they are left alone.

---

## Full naming pass, all classes (2026-09-23, proposed rename)

Every title in the pool was checked against three rules. A school card names its element and how
that school performs the mechanic. A Freestyle card is mundane: will, footwork, blades, tricks. A
signature card names its character, by first name where a surname is shared by several characters
(Rooke, Draik, Vale) and by surname where it is not (Ashmark, Mourne, Quarr). Steel and the
Masteries are covered above. Only the cards that change are listed; everything else passed.

**School cards**

| id | Now | Proposed | Mechanic | Why it changes |
|---|---|---|---|---|
| `pyre_knee_bash` | Pyre Knee Bash | Pyre Scorching Blow | +4 Energy, Fervor +1 | Martial name, no fire |
| `pyre_warding_stance` | Pyre Warding Stance | Pyre Ember Ward | Endurance 2, stops an Art, Fervor +1 | Martial name, no fire |
| `pyre_sword_cleave` | Pyre Sword Cleave | Pyre Burning Sword Cleave | Your Pyre attacks count as "Sword" | Adds the fire; "Sword" must stay in the title because the Sword cards search for it |
| `tide_deadweight` | Tide Deadweight | Tide Waterlogged | Hit: they cannot Strike this Combat | No water; "dead weight" was Steel's word |
| `tide_bearing_down` | Tide Bearing Down | Tide Heavy Swell | +3 Energy, their Fervor -2 | No water |
| `tide_full_weight` | Tide Full Weight | Tide Cresting Wave | 5 wounds, Fervor +1, theirs -2 | No water |
| `storm_palm_surge` | Storm Palm Surge | Storm Jolt | 5 wounds, Fervor +1 | Martial word; "Surge" is Tide's |
| `storm_plasma_beam` | Storm Plasma Beam | Storm Stunning Bolt | Hit: they skip their next attack phase | "Plasma" reads as science fiction |
| `storm_trick_shot` | Storm Trick Shot | Storm Ricochet Bolt | Your attacks gain "Hit: gain 2 Energy" | No lightning |
| `storm_narrow_focus` | Storm Narrow Focus | Storm Narrow Arc | 5 Energy damage for 1 Energy | No lightning |
| `storm_catching_stance` | Storm Catching Stance | Storm Drawn Charge | Stops an Art, gain 4 Energy, their Fervor -1 | Martial word; the spell's charge is drawn off |
| `shade_rending_palm` | Shade Rending Palm | Shade Night Rend | 6 wounds, they lose 3 Energy | Martial word, no shadow |
| `shade_cutting_hand` | Shade Cutting Hand | Shade Severing Shadow | 4 wounds, stops an Art | Martial word, no shadow |
| `shade_snaring_web` | Shade Snaring Web | Shade Shadow Snare | 6 wounds, Hit: no Arts this Combat | A web is not shadow |
| `shade_preparation` | Shade Preparation | Shade Dusk Bolt | Focused Art, Fervor +1 | No shadow, no mechanic |
| `shade_draining_blast` | Shade Draining Blast | Shade Hungering Gloom | Costs 2, Hit: gain 4 Energy | No shadow |
| `shade_warding_burst` | Shade Warding Burst | Shade Binding Murk | 3 wounds, Hit: no Strikes this Combat | No shadow |
| `shade_stinging_palm` | Shade Stinging Palm | Shade Picking Shadow | Look at their hand, choose a discard | Martial word |
| `shade_recoil` | Shade Recoil | Shade Rebounding Hex | Stops an Art, trade discards | No shadow |
| `shade_takedown_drill` | Shade Takedown Drill | Shade Gleaning Drill | Draw after a successful attack | Martial word |
| `shade_composure_drill` | Shade Composure Drill | Shade Hoarded Secrets Drill | Keep 2 cards at the Discard step | No shadow |
| `shade_faltering_drill` | Shade Faltering Drill | Shade Forgetting Drill | Pay 1 Energy: they discard their whole hand | Names the effect on the mind |
| `root_energy_catch` | Root Rain Catch | Root Drinking Leaves | Stops an Art, gain 3 Energy | Rain is Tide's |
| `root_barred_path` | Root Barred Path | Root Bramble Wall | Stops a Strike or an Art | No thorn or wood |

| Placeholder | Proposed | Why it changes |
|---|---|---|
| Shade Culling Dark | Shade Culling Hex | Four "Dark" titles in one school |

Title words that cards search for must survive any rename: "Sword" and "Swordplay" (the Vale and
Emrys cards), "Sweep" (`ashmarks_choke_hold` fetches a "Sweep" card), and "Steel Standoff" (see the
Steel rename). That is why Tide Deep Sweep and Tide Sweep Aside keep their names even though Tide
has four "Sweep" titles.

**Freestyle**

| id | Now | Proposed | Why it changes |
|---|---|---|---|
| `mutual_escalation` | Mutual Escalation | Raised Stakes | Old placeholder wording |

**Named sources (rule confirmed by the user 2026-09-23).** If the printed card carried a
character's name, ours is a signature card of our mirror of that character, with the same legality:
the `character` field set, the name in the title, 4 copies for that Duelist, offered in adventure
only to that Duelist's runs, and any printed "Heroes only" / "Villains only" kept as Vigil / Pact.
This is Rule 3 in `docs/cast_backlog.md`, and `tools/audit_mirrors.py` checks it.

Fixable now, because the character exists:

| id | Now | Proposed | Becomes signature of | Printed card | Legality notes |
|---|---|---|---|---|---|
| `ashmarks_choke_hold` | Ashmark's Choke Hold | Ashmark's Choke Hold | Bram Ashmark | a named card of Ashmark's mirror | Gains `character`; it still fetches a "Sweep" card |
| `declaration` | Declaration | Caedan's Declaration | Caedan Vale | a named card of Caedan's mirror | Limit 1 stays |
| `quiet_study` | Quiet Study | Caedan's Quiet Study | Caedan Vale | same | |
| `guardian_drill` | Guardian Drill | Caedan's Guardian Drill | Caedan Vale | same, printed "Heroes only" | Vigil only stays |

The audit skips the three Caedan cards because its list of words that are not people includes that
character's source first name. That exclusion looks like noise-filtering rather than a decision, so it
is worth a look before these are applied. `stillness` comes from a card the database files as named
but whose title names nobody, so it stays Freestyle.

Blocked until a character exists (13 cards, 11 characters). `docs/cast_backlog.md` already says
where each one sits in the world, and only the names are missing. Nothing is written until you
approve a name.

| Placement already agreed in the backlog | Cards | Cards' current titles |
|---|---|---|
| The Kingsguard's form at contact (Corin Thrace was its form at distance) | 5 | Blinding Flare, Unerring Bolt, Keen Eye, Clear Mind, Sleight |
| No placement yet; Pact, a perfected made thing that feeds on others | 4 | Old Habit, Dismissal, Sever the Leyline, Terms of the Pact |
| A Vale, Caedan's mother; Vigil | 1 | Warden's Measure |
| Captains the retained guard | 1 | Captain's Barrage |
| No placement yet; a tyrant | 1 | Dead Air |
| Claims a Kingsguard form he was never taught | 1 | Old Trick |
| No placement yet; a champion of the dead | 1 | Second Wind |
| Holds the Vigil's highest office | 1 | Overreach |
| Tied back to Bram Ashmark | 1 | Headlong Plunge |
| Lays the demons' mark and works the toll gate (a Grounds) | 1 | Tollgate Yard |
| Holds the high watchpost (a Grounds) | 1 | The High Watch |

**Signature, first names (approved 2026-09-23).** These three surnames belong to several
characters, so the first name goes on the card.

| id | Now | Proposed | Character |
|---|---|---|---|
| `rookes_deluge` | Rooke's Deluge | Alder's Deluge | Dame Alder Rooke |
| `black_hands` | Draik's Black Hands | Sable's Black Hands | Sable Draik |
| `draiks_reckoning` | Draik's Reckoning | Sable's Reckoning | Sable Draik |
| `lingering_curse` | Draik's Lingering Curse | Sable's Lingering Curse | Sable Draik |
| `cut_short` | Vale Cuts It Short | Caedan Cuts It Short | Caedan Vale |
| `heirloom_blade` | Vale's Heirloom Blade | Caedan's Heirloom Blade | Caedan Vale |
| `vales_insight` | Vale's Insight | Caedan's Insight | Caedan Vale |
| `vales_pommel_bash` | Vale's Pommel Bash | Caedan's Pommel Bash | Caedan Vale |
| `vales_quickstep` | Vale's Quickstep | Caedan's Quickstep | Caedan Vale |
| `vales_riposte` | Vale's Riposte | Caedan's Riposte | Caedan Vale |
| `vales_sword_draw` | Vale's Sword Draw | Caedan's Sword Draw | Caedan Vale |

Left alone: Personality and Aspect titles, Seals, Grounds and Relics. The rest of Freestyle
reads as mundane already, and every other signature card names its character.

---

## Masteries, 15 (every school to 4)

The reference game printed exactly four Masteries per style (one each in its second, third, fifth
and seventh sets). We ship 9 of those 24, so these 15 are the complete remainder and there is no
choice to make about which ones. What is open is the titles, and whether the engine work is worth it
for each. Titles are placeholders for the renaming pass. Every Steel Mastery carries
`duelist_bloodline: draconic` and every Root one `verdant`, like the ones already shipped.

| School | Title | What it does | Serves | Engine | Verdict |
|---|---|---|---|---|---|
| Pyre | Pyre Tinder Mastery | Entering Combat, you may remove the top card of your discard pile from the game. Your Strikes do +1 Energy this Combat, +3 if it was a Pyre card | Fervor attacks, the Strike body | ready | |
| Pyre | Pyre Cinder Mastery | When you perform an Art, their Fervor -1. When they stop your Pyre Art, they discard their top 2 | Pyre's few Arts, Fervor pressure | add | |
| Steel | Steel Dragonfear Mastery | Entering Combat, draw a card. If it is Steel, you may show it and they lose 4 Energy | Energy squeeze | ready | |
| Steel | Steel Scale Mastery | Entering Combat, draw a card. The first attack against you this Combat does 4 less Energy damage; if the card was Steel and you show it, also 4 fewer wounds | Endurance armour | add | |
| Steel | Steel Bloodrage Mastery | You cannot win by Ascension. Your Steel attacks raise your Fervor 1 and gain 3 Energy. In the Recover step, if a Steel card goes back into your deck, Fervor +2 and gain 4 Energy | Raw Strikes, Might (keeps Energy high) | add | |
| Tide | Tide Eddy Mastery | Once per Combat, discard a card from hand to stop a Strike or an Art. If it was a Tide card, their Fervor -2 | Fervor denial, stops | add | |
| Tide | Tide Floodtide Mastery | Your Arts do +1 wound. Your Tide Arts gain "Hit: raise your Fervor 1" | Fervor gain gap, the Art half of Tide | ready | |
| Storm | Storm Gale Mastery | Your Strikes do +2 Energy. After a Storm Strike lands, your other Strikes do +1 wound this Combat | Storm's Strikes | ready | |
| Storm | Storm Conductor Mastery | Once per Combat, discard one of your Storm Drills to put 2 different Drills from your deck into play. In the Recover step you may put the top Drill of your discard pile under your deck | Storm's Drills and Defense Shields | add | |
| Shade | Shade Tithe Mastery | Once per Combat, in place of an attack, discard a card from hand. If it is Shade, they discard one at random; otherwise they choose one to discard | Hand attack | ready | |
| Shade | Shade Blight Mastery | Your attacks gain "Hit: discard a Drill in play". Your Shade attacks gain "Hit: you may discard a Non-Combat in play" instead | Board removal gap | add | |
| Shade | Shade Eclipse Mastery | Your Shade stops that are not Drills can stop Focused attacks. In your attack phase, you may discard a Shade card from hand: Fervor +1 and gain 6 Energy | Fervor and Energy gaps, answers | add | |
| Root | Root Compost Mastery | Entering Combat, shuffle the top card of your discard pile into your deck. If it is Root, draw a card | Recursion | ready | |
| Root | Root Deeproot Mastery | Entering Combat, draw the bottom card of your deck. If it is Root, you may show it and draw the next bottom card too | Recursion, pairs with the cards that put things under the deck | add | |
| Root | Root Sacred Grove Mastery | Your non-Root cards are removed from the game instead of going to the discard pile. Your Root attacks gain "Hit: put the bottom 2 of your discard pile under your deck and gain 3 Energy" | Recursion, bomb for a pure Root deck | add | |

### Mastery names, all 25

Every Mastery gets a descriptor between the school and "Mastery", and the descriptor says how that
school performs the Mastery's mechanic. Six shipped titles were bare ("Pyre Mastery" and so on) and
are renamed here. Ids would follow the titles when this is applied.

| School | Now | Proposed | Mechanic | Why the name |
|---|---|---|---|---|
| Pyre | Pyre Ember Mastery | keep | Burn your top discard for Fervor | An ember taken off a spent spell |
| Pyre | Pyre Mastery | **Pyre Crucible Mastery** | Take a wound to make a Pyre attack Focused; your Pyre blocks go under your deck | You put yourself in the fire to refine the blow, and the crucible keeps what it melts down |
| Pyre | (new) | Pyre Tinder Mastery | Burn your top discard; your Strikes hit harder this Combat | A spent spell used as tinder |
| Pyre | (new) | Pyre Cinder Mastery | Your Arts lower their Fervor; a blocked Pyre Art costs them 2 cards | Cinders fall on whoever stands in the way |
| Steel | Steel Mastery | **Steel Hoard Mastery** | Spend your top card, draw 2 if it was Steel | A dragon spends from the hoard and comes back richer |
| Steel | (new) | Steel Dragonfear Mastery | Show a Steel card and they lose 4 Energy | The dragon shown, and the nerve it breaks |
| Steel | (new) | Steel Scale Mastery | The first attack each Combat does less damage | Scales grown for the fight |
| Steel | (new) | Steel Bloodrage Mastery | No Ascension win; your Steel attacks feed Fervor and Energy | The blood takes over the fighter; they stop climbing and keep fighting |
| Tide | Tide Mastery | **Tide Undertow Mastery** | They need 6 Fervor to ascend; your Tide hits lower their Fervor | The undertow that pulls them back from every climb |
| Tide | Tide Fathom Mastery | keep | Tide Strikes +2 wounds; spend Tide discards to prevent wounds | Depth drawn on to take a blow |
| Tide | (new) | Tide Eddy Mastery | Discard a card to stop an attack | An eddy turns the blow aside |
| Tide | (new) | Tide Floodtide Mastery | Arts +1 wound; your Tide Arts raise your Fervor | The rising tide is your own |
| Storm | Storm Mastery | **Storm Brewing Mastery** | Your Arts cost 1 less and do +1 wound | A storm brewing: charge built slowly, released cheaply (the school's doctrine) |
| Storm | Storm Squall Mastery | keep | A landed Storm Art locks out their Strike cards next phase | A squall that pins them down |
| Storm | (new) | Storm Gale Mastery | Strikes +2 Energy; a landed Storm Strike powers the next | Wind at your back |
| Storm | (new) | Storm Conductor Mastery | Trade a Storm Drill for two Drills; recycle Drills | Charge routed from one standing fixture to the next |
| Shade | Shade Mastery | **Shade Nightfall Mastery** | Every attack does more, Shade attacks most | Everything cuts deeper once the dark comes down |
| Shade | (new) | Shade Tithe Mastery | Discard a card to make them discard one | A card paid to take a card |
| Shade | (new) | Shade Blight Mastery | Your attacks strip Drills and Non-Combats | A hex that rots what they built |
| Shade | (new) | Shade Eclipse Mastery | Shade stops catch Focused attacks; burn a Shade card for Fervor and Energy | The light blotted out, nothing gets through clean |
| Root | Root Mastery | **Root Regrowth Mastery** | Draw your bottom discard; if Root, refill Energy | What was cut away grows back (the school's doctrine) |
| Root | (new) | Root Compost Mastery | Shuffle your top discard back in; draw if Root | Spent spells turned back into soil |
| Root | (new) | Root Deeproot Mastery | Draw from the bottom of your deck | Roots drawing from the deepest layer |
| Root | (new) | Root Sacred Grove Mastery | Non-Root cards are removed instead of discarded; Root attacks recycle | Only the grove's own growth returns; outsiders rot |
| Freestyle | Freestyle Mastery | **Freestyle Discipline Mastery** | Your Drills cannot be discarded; trade a signature card for another | Drilled habit that nothing shakes loose |

Engine notes. Steel Scale needs a "reduce the first attack by N" effect. `tide_fathom_mastery`'s
`defense_burn` already prevents wounds, so part of it exists. Root Grove needs a replacement effect,
which the README lists as not supported yet, and it is the largest item here. Steel Wyrm and Storm
Conductor need a Recover-step trigger. Tide Eddy is a Mastery used as a defense and paid with a hand card.

Freestyle only ever printed two Masteries. The one we lack names a card and makes the opponent
discard a copy from their deck when your top discard is one of your Duelist's signature cards.

---

## Cut from the first draft

| First-draft title | Why |
|---|---|
| Pyre Searing Cut, Pyre Struck Spark, Pyre Sudden Flare, Pyre Stokehold | Plain Fervor gain. Pyre already has 20 cards that raise Fervor |
| Pyre Dousing | Fervor denial, which is Tide's identity rather than Pyre's |
| Steel Blind Jab | A plain Strike with no subtheme |
| Steel Numbing Hold | A lockout Art stop. Steel already has 4 Art answers |
| Steel Blood Rush | Replaced by Blood Memory, which fills the same Non-Combat gap and also brings recursion and the Might check |
| Tide Crowded Channel | Scales with the opponent's Allies, so it does not help a Tide Ally deck |
| Tide Sluice Guard | A plain Strike stop |
| Tide Claiming Swell | Tide has no Seal theme to support |
| Shade Blight | A second lockout, and it needed its own engine addition |
| Shade Owed Back | Needed two engine additions for a plain Strike |

---

## Engine additions the `add` cards need

28 of the 50 need one. Several share an addition.

| Addition | Cards |
|---|---|
| A value read from a player's current Fervor (damage, Endurance, amounts, "5 minus their Fervor") | Rising Heat Drill, Drawing Flue, Blazing Hide, Choking Smoke, Backwash, Dead Calm |
| A condition on the owner's own Fervor | Heat Haze |
| A Fervor shield read from a Drill in play | Banked Coals Drill |
| Drills that survive an Aspect change (adventure Resonances need this too) | Hearthstone Drill |
| A float that reacts to Endurance being used, and a modifier that counts those uses | Boiling Blood, Scar Count |
| A cost modifier that prices the opponent's attacks | Iron Stare Drill |
| Less Energy for the opponent in the Power Up step | Anvil Drill |
| Doubling the Strike Table base | Outweighing Blow |
| Empower that keeps the rest of the text | Whole-Body Blow |
| A search limited by Aspect tier | Shoal Drill |
| A standing "my Allies cannot be discarded" flag | Mooring Drill |
| A modifier on attacks performed by an Ally | Following Current Drill |
| A trigger when Fervor is lowered past 0 | Salt Burn Drill |
| A float that blocks Fervor gain | Frozen Over |
| Letting the opponent choose in a `look_at` | Sounding |
| A "first card used this Combat" condition | Opening Whisper |
| Attaching to a Non-Combat and switching it off | Stilling Whisper |
| A negative modifier on an attachment's host, discarded at full Energy | Wasting Mark |
| A hand card returned to the Life Deck | Clouded Mind Drill |
| An amount read from the duelist's Surge | Creeping Dark |
| A search of the opponent's whole Life Deck | Pilfering Shadow |

The `ready` marks on new picks come from checking that the ops exist in `engine/duel_engine.gd`.
Every parameter has not been checked yet.

## Counts to keep in mind

- Lockouts: 2 (Pyre Heat Haze, Shade Erased Name), down from 4.
- Printed limit 1: Pyre Rising Heat Drill, Pyre Heat Haze, Pyre Conflagration, Tide Mooring Drill.
- New Defense Shield: Pyre Flame Screen Drill. The set had 4, all in Storm and Root.

## Left out on purpose

- The printed damage-reduction package (Tide's third-largest printed theme). The engine has no
  partial-prevention effect.
- The best Steel Empower cards, which are all Draconic-gated.
- Cards whose text depends on what the opponent declared at setup, and Reserve-only cards.
- Near-duplicates of cards each school already has.
