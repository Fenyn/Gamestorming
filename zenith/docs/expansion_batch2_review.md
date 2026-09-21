# Card expansion, batch 2: review sheet

49 candidates that bring Pyre, Steel, Tide and Shade to 40 cards each. Nothing here is built.
The full rows, with the printed card behind each one, are in `tools/source_candidates.tsv`
(`status: candidate`). Batch 1 (Storm 26, Root 29) is built.

How to review: write in the **Verdict** column. `ok`, `rename: <title>`, `cut`, or a note.
An empty cell counts as not yet approved. Titles follow the rule that the school's element and the
card's mechanic both show in the name. Steel alone keeps hand-to-hand names.

Rulings already applied to every row: the printed "declared" riders are always on, format-only
notes are dropped, no card carries a bloodline or alignment gate, and no Defense Shield Drills
were added. New Fervor denial is 5 cards, all in Pyre and Tide.

**Engine column.** `ready` maps to effects the engine has today. `add` needs a small engine
addition, listed at the end. No card needs a new rules system.

---

## Pyre, 15 (25 to 40)

Pillars the picks were made from:
1. Fervor on everything, gain first.
2. Fervor as a scaling number: X = your Fervor.
3. Fervor protection and reset, not only gain.
4. Stripping the board on the attack.

The printed style leans on Drills and on X = Fervor damage. Pyre has neither today.

| Title | Type | What it does | Why | Engine | Verdict |
|---|---|---|---|---|---|
| Pyre Rising Heat Drill | Drill | Your attacks do +X Energy, X = your Fervor. Limit 1 | pillar 2 | add | |
| Pyre Banked Coals Drill | Drill | Your Fervor cannot be lowered | pillar 3 | add | |
| Pyre Hearthstone Drill | Drill | Your other Drills survive an Aspect change | the climb, Drill gap | add | |
| Pyre Laying Fire | Strike | Endurance 2. +3 Energy. Hit: put a Pyre Drill into play | Drill payoff | ready | |
| Pyre Bonfire | Strike | Empower 4. Put up to 5 Pyre Drills into play. Fervor +1. Removed after use | Drill payoff | ready | |
| Pyre Drawing Flue | Art | Endurance 4. 1 wound + X, X = your Fervor. Hit: shuffles back in | pillar 2 | add | |
| Pyre Stokehold | Combat | Each Strike that lands on you this Combat raises your Fervor 1 | pillar 1 | add | |
| Pyre Dousing | Strike | +4 Energy. Hit: their Fervor to 0 | pillar 3 | ready | |
| Pyre Searing Cut | Strike | Focused, +1 Energy. Hit: Fervor +2 | pillar 1 | ready | |
| Pyre Burned Through | Art | 5 wounds. They cannot use Endurance against your Pyre attacks this Combat. Hit: Fervor +2 | pillar 1 | ready | |
| Pyre Sudden Flare | Art | Focused, 3 wounds. Hit: Fervor +2 | Art gap (3 of 25) | ready | |
| Pyre Struck Spark | Art | 3 wounds for 1 Energy. Fervor +1 | Art gap | ready | |
| Pyre Choking Smoke | Art stop | Endurance X, X = your Fervor. Stops an Art. Their Fervor -1. Strips the bottom of their discard pile when their Fervor is low | Art answers (Pyre has 2) | add | |
| Pyre Heat Haze | Art stop | Stops an Art. With Fervor 1+, stops every Art this Combat. Removed after use. Limit 1. **Lockout** | Art answers | add | |
| Pyre Cinder Sift Drill | Drill | Once a Combat, a landed Strike shuffles a card from your discard pile back in | recursion (Pyre has 1) | ready | |

After: 27 Strike, 7 Art, 2 Combat, 0 Non-Combat, 4 Drill. Pyre still has no plain Non-Combat. The
printed style's Non-Combats are nearly all Drills.

---

## Steel, 10 (30 to 40)

Pillars:
1. The heaviest bodies, with Endurance in place of blocks.
2. Energy as the lever: take theirs, refill yours, price their cards up.
3. The Might comparison.
4. Empower as the standard mode. The printed style has it on nearly every late card. Steel has two.

| Title | Type | What it does | Why | Engine | Verdict |
|---|---|---|---|---|---|
| Steel Shackle Drill | Drill | Their attacks cost +1 Energy, +2 when they play Root | pillar 2 | add | |
| Steel Anvil Drill | Drill | Your attacks do +2 Energy. Their personalities gain 1 less in the Power Up step | pillars 1 and 2 | add | |
| Steel Snapped Brace | Strike | Endurance 2. If stopped, a Drill in play of your choice leaves the game. Removed after use | pillar 1 | ready | |
| Steel Overbearing | Strike | +3 Energy. Doubles the Strike Table base while your Might is higher | pillar 3 | add | |
| Steel Boiling Blood | Art | 6 wounds. Focused while your Might is higher. Each Endurance you use this Combat pays 1 Energy | pillars 3 and 1 | add | |
| Steel Scar Count | Strike | Endurance 1. +3 Energy, Fervor +1, Empower 2. Your Strikes grow per Endurance spent this Combat | pillar 1 | add | |
| Steel Cauterize | Art | Fervor +1. Empower 4. This Combat your wounds leave the game and cannot be prevented | pillar 4 | ready | |
| Steel Blind Jab | Strike | +3 Energy. Only an Art-stop can stop it | pillar 1 | ready | |
| Steel Numbing Hold | Art stop | Stops an Art. Their Fervor -1. They skip their next attack phase. Shuffles back in. **Lockout** | Art answers | ready | |
| Steel Blood Rush | Non-Combat | A personality of yours gains 5 Energy | Non-Combat gap (Steel has none), Energy | ready | |

After: 27 Strike, 8 Art, 1 Combat, 1 Non-Combat, 3 Drill.

---

## Tide, 12 (28 to 40)

Pillars:
1. Fervor denial as the clock: hold them at 0.
2. Allies: put them out, keep them alive, pay per Ally. The printed style is the Ally style of the
   whole game. Tide has one Ally card today.
3. Stops in volume, and cards that attack and defend from one printing.
4. Reaching sideways: dig, reorder, strip.

| Title | Type | What it does | Why | Engine | Verdict |
|---|---|---|---|---|---|
| Tide Shoal Drill | Drill | A landed Strike fetches a tier 1 Ally to hand | pillar 2 | add | |
| Tide Mooring Drill | Drill | Your Allies cannot be discarded. Limit 1 | pillar 2 | add | |
| Tide Salt Burn Drill | Drill | Your attacks do +2 Energy. Lowering Fervor they do not have takes cards off their Life Deck | pillar 1 | add | |
| Tide Answering Current | Non-Combat | Put an Ally into play from your deck and one from your discard pile. Removed after use | pillar 2 | ready | |
| Tide Crowded Channel | Combat | Your Arts cost 1 less and hit +1 Energy per Ally they field. Fervor +1 | pillar 2, Fervor gain gap | add | |
| Tide Washout | Combat | Endurance 1. A Drill in play leaves the game. Your duelist and Allies gain 2 Energy. Fervor +1. Removed after use | pillar 4 | ready | |
| Tide Frozen Over | Strike | +2 Energy. Their Fervor to 0, and it cannot rise until their next turn | pillar 1 | add | |
| Tide Breaking Sea | Strike | +6 Energy. Their Fervor -4 | pillar 1, no large hit | ready | |
| Tide Claiming Swell | Strike | Focused. Hit: capture one of their Seals | Seal support (Tide has none) | ready | |
| Tide Sluice Guard | Strike stop | Stops a Strike. Discards one of their Non-Combats | pillar 3 | ready | |
| Tide Sounding | Strike stop | Stops a Strike. Look at your top 3 and take one. Below Aspect 3 the opponent picks which | pillar 4 | add | |
| Tide Backwash | Art | Focused, 5 wounds, or stops an Art. Returns cards from your discard pile equal to your Fervor. Removed after use | pillar 3 | add | |

After: 19 Strike, 13 Art, 3 Combat, 2 Non-Combat, 3 Drill.

---

## Shade, 12 (28 to 40)

Pillars:
1. Hand attack.
2. Reaching past the hand into their Life Deck: name it, find it, remove it. The printed style's
   second-biggest theme. Shade has none of it today.
3. Hexes that attach and keep working on their side of the table.
4. Debts paid in Energy.

| Title | Type | What it does | Why | Engine | Verdict |
|---|---|---|---|---|---|
| Shade Struck Name | Combat | Name a card. Every copy leaves their Life Deck and the game. Removed after use. **Lockout** | pillar 2 | ready | |
| Shade Blight | Strike | +3 Energy, Empower 3. Two of their Non-Combats in play, and every copy in their deck, leave the game. Removed after use. **Lockout** | pillar 2, board removal gap | add | |
| Shade Owed Back | Strike | +3 Energy. The damage they landed last phase comes back as wounds. Hit: reorder their top 6 | pillars 4 and 2 | add | |
| Shade Stilled | Strike | +3 Energy. Hit: attaches to one of their Non-Combats, which cannot be used | pillar 3 | add | |
| Shade Wasting Mark | Strike | +3 Energy. Attaches to their duelist. Their attacks do -2 Energy until they reach full Energy | pillar 3 | add | |
| Shade Culling Dark | Art | Endurance 2. Hit: discard one of their Allies | board removal (Shade has 2) | ready | |
| Shade Muddling Drill | Drill | Each successful attack puts a random card of their hand into their deck. They draw 1 | pillar 1 | add | |
| Shade Long Toll | Combat | Their Life Deck loses cards equal to your Surge | pillar 2 | add | |
| Shade Rifling | Non-Combat | Search their Life Deck and remove 2 cards from the game. Removed after use | pillar 2, Non-Combat gap | add | |
| Shade Taken Breath | Non-Combat | Fill a personality's Energy. You may end the Combat | Energy gain (Shade has none) | ready | |
| Shade Feeding Veil | Strike stop | Stops a Strike. Fervor +2 | Fervor gain (Shade has 3) | ready | |
| Shade Gathered Hexes | Art stop | Stops an Art. Returns 3 Shade cards from your discard pile. Removed after use | recursion, Art answers | ready | |

After: 21 Strike, 10 Art, 3 Combat, 2 Non-Combat, 4 Drill.

---

## Engine additions the `add` cards need

23 cards are ready. 26 need one of these. Several are shared.

| Addition | Cards |
|---|---|
| A value read from the owner's current Fervor (damage, Endurance, amounts) | Rising Heat Drill, Drawing Flue, Choking Smoke, Backwash |
| A condition on the owner's own Fervor | Heat Haze |
| A Fervor shield read from a Drill in play (today only the Relic has one) | Banked Coals Drill |
| Drills that survive an Aspect change (also what adventure Resonances need) | Hearthstone Drill |
| A float that reacts to a Strike landing on you | Stokehold |
| A float that reacts to Endurance being used, and a modifier that counts those uses | Boiling Blood, Scar Count |
| A cost modifier that prices the opponent's attacks | Shackle Drill, part of Crowded Channel |
| Less Energy for the opponent in the Power Up step | Anvil Drill |
| Doubling the Strike Table base | Overbearing |
| A search limited by Aspect tier | Shoal Drill |
| A standing "my Allies cannot be discarded" flag | Mooring Drill |
| A trigger when Fervor is lowered past 0 | Salt Burn Drill |
| A damage modifier that counts the opponent's Allies | Crowded Channel |
| A float that blocks Fervor gain | Frozen Over |
| Letting the opponent choose in a `look_at` | Sounding |
| Naming driven by cards already in play | Blight |
| "They landed a Strike last phase" condition, and stage damage returned as wounds | Owed Back |
| Attaching to a Non-Combat and switching it off | Stilled |
| A negative modifier on an attachment's host, discarded at full Energy | Wasting Mark |
| A hand card returned to the Life Deck | Muddling Drill |
| An amount read from the duelist's Surge | Long Toll |
| A search of the opponent's whole Life Deck | Rifling |

Two Drills (Steel Anvil Drill, Tide Salt Burn Drill) print an exemption from the one-school-of-
Drills deck rule. That is a deck-building note and can be dropped.

## Counts to keep in mind

- Lockouts: 4. Pyre Heat Haze, Steel Numbing Hold, Shade Struck Name, Shade Blight. Tide gets none.
- Printed limit 1: Pyre Rising Heat Drill, Pyre Heat Haze, Tide Mooring Drill.
- Two picks come from a promo printing of the original publisher (Pyre Rising Heat Drill, Tide
  Mooring Drill). Allowed under the real-cards rule.

## Left out on purpose

- The printed damage-reduction package, which is Tide's third-largest printed theme and also
  touches Pyre and Steel. The engine has no partial-prevention effect. It would be a new mechanic.
- The best Steel Empower cards. All are Draconic-gated.
- Cards whose text depends on what the opponent declared at setup.
- Near-duplicates of cards each school already has.

## Known hole in the check

55 shipped cards have an empty `Source card` cell in `docs/card_roster.csv`. For those, "already
in the game" was checked by mechanic and not by name. Filling the cells would make the next batch's
check reliable.
