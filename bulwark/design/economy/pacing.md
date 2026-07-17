# Bulwark: Pacing and Balance-Check Schedule

This document is a balance-check schedule for Bulwark's two-year buildout, not a script the player
is meant to follow beat for beat. It lays out one plausible order in which the buildings commission
and upgrade, the characters arrive, and the territories open, and it does the arithmetic to check
that a reasonably engaged player can actually afford that order on the calendar the framework brief
pins down. A player who farms harder, fights more, or ignores half the roster will finish faster or
slower than this map. What this document checks is that the schedule is possible at a conservative,
not-especially-optimized pace, and it flags the handful of places where that pace gets tight. It
draws every bundle number from `design/economy/buildings.md`, every item id and route from
`design/economy/materials.md`, and every arrival trigger from `design/economy/characters.md`. It
proposes one change to a trigger in that last document (the Aldric building count, section 5 below)
and otherwise treats all three as fixed inputs.

## Assumptions and method

This document is rebuilt at full Stardew scale (revised 2026-07-14): `buildings.md`'s bundles now run
in the hundreds for raw commons and carry a Gold cost alongside every bundle, `materials.md`'s
gathering routes now return a Stardew-parity haul per node, and combat drops roll 1-3-part quantity
bands per creature. Every number below is recomputed against that rescale; nothing here reuses the
prior draft's totals. Layered on top of that rescale, the same-day three-biome revision splits the old
Forest biome into the Verdant Fringe (easy, unchanged) and the Elderwood (moderate, new), moves the
Command Post's biome-unlock ladder so tier 2 opens the Elderwood and tier 3 opens the Sunken Reach
(replacing the previously proposed tier-3 "expedition logistics"), and re-tiers two of the four
Verdant Fringe creature families (Beasts, and the new Root Wardens) into the Elderwood. This section's
totals and every season below are recomputed again against that revision; where a number moved by more
than a couple of percentage points from the pre-revision draft, the relevant section says so directly.

**The bestiary widened after this document's own rescale.** `materials.md` later added six new
creature families across the three biomes (Bramble Slicks, Hedge Folk, Canopy Spiders, Thornbacks,
Swamp Drakes, Marsh Wisps), and `buildings.md` wove their thirteen new items into a handful of existing
bundles as swaps or small added lines. None of this touches the supply models above: it widens which
common parts and trophies a fight can drop, giving the player more routes to the same combat-pool
totals, not a change to how much any pool holds. The season-by-season map and checkpoint audits below
are recomputed against the handful of bundles the new items actually touch; every other season's
arithmetic is unchanged.

**Season length.** The brief allows a default of 28 days per season if the repo does not already
pin a different number. It does: `DayClock.cs` and `ArrivalTrigger.cs` both hard-code 28 days per
season, 4 seasons per year. This document uses that same 28-day season throughout, so 8 seasons
is 224 days, just under two full years by the real-world calendar but exactly "2 in-game years" by
the game's own 4-season year.

**Conservative supply pools.** Three pools are tracked, matching the three kinds of demand a bundle
can now carry (materials of two kinds, plus Gold).

- **Gather pool.** Crops, forage, wood, stone, ore, fish, husbandry and apiary goods, and anything
  crafted or refined from them (plank, cut stone, cloth, ingots, cheese, tinctures, and so on) all
  draw from the same conservative pool: 10 dedicated gathering days a season, at the conservative
  low end of `materials.md`'s 150-300-units-a-day range, for **1,500 units a season**. Ten days out
  of 28 is still a deliberately modest share of the season; the rest goes to farm upkeep, combat
  expeditions, crafting, exploration, and story. This pool is fifteen times the prior draft's
  100-units-a-season figure, because node yields themselves rose to Stardew parity (a tree now gives
  12-15 wood in one harvest, not one), not because the party gathers more often.
- **Combat pool.** Common monster parts and trophies both draw from the brief's rescaled drop
  doctrine, which brings combat supply to genre parity alongside the node-yield rescale: each
  defeated creature drops 1 to 3 common parts (drop tables roll quantity bands, not a flat 1), a
  common encounter defeats 3 to 5 creatures, and a combat-engaged week runs 8 to 10 fights, for a
  conservative supply of roughly 250 to 400 common parts a season. This document audits against the
  low end: **250 units a season**. The same drop model is stated on the supply side in
  `materials.md`'s combat-drops route section, so the two documents agree by construction. Trophies
  (goblin_totem, hollow_locket, and the rest) are a special case inside this pool and are untouched
  by the drop-band rescale: they only drop from named elite roamers and bosses, not from common
  encounters, so a season that asks for more than one or two trophy units is asking the party to
  have kept active hunting pressure on that specific creature family, not just fought whatever
  crossed its path.
- **Gold pool.** Unlike the two material pools, Gold is not itemized inventory with a Bulk cap; it
  is savings, and it does not reset at a season boundary the way a gathering trip does. This
  document tracks Gold as a **running cumulative balance**: income accrues every calendar day, not
  just dedicated gathering days, at a conservative flat **100 gold a day**, the midpoint of the
  brief's stated 50-150g/day mid-game range, held flat across both years as a single conservative
  estimate for the whole schedule rather than modeled as growing. That is **2,800g by the end of a
  28-day season**, and cumulative from there (11,200g by day 112, 22,400g by day 224). Every
  checkpoint below compares cumulative Gold spend against this cumulative income line, not a
  per-season reset, because a capstone's 1,000-2,500g cost is meant to be paid from savings banked
  over the preceding seasons, the same way a player saves toward a Stardew Barn rather than earning
  its full price in the 28 days before building it.

Every season's schedule is split into a **gather total**, a **combat total** (line items summed by
quantity, trophies included in the combat total), and a **Gold total**, then checked against these
three pools, the first two per season and the third as a running balance. A checkpoint or season is
flagged when a total exceeds 60 percent of its conservative pool, per the task's own threshold,
because the remaining headroom also has to cover crafting inputs, meals, gifts, and (for materials)
Smithy and Trading Post purchases that this document does not itemize separately.

**How the rescale settled.** The prior small-scale draft found gather the tight pool (Year 1 at 64.75
percent of a 100-unit season) and combat comfortable throughout. The first pass of this rescale
briefly inverted that: bundle monster-part quantities grew 3x to 4x while the combat supply assumption
was still the old 72-units-a-season pace, which produced hard overshoots at every checkpoint. The
brief has since corrected the supply side to match (the drop-band doctrine above), because the old
6-fights-times-3-parts arithmetic was the same under-scaled thinking the whole rescale exists to fix.
With both sides of the ledger at genre parity, the schedule closes again: gather is comfortable
everywhere (tightest single season 47 percent), combat clears every checkpoint with room to spare and,
after the framework brief's later three-biome revision (2026-07-14) moved the Sunken Reach's unlock
from Command Post tier 2 to tier 3 and out of Winter Year 1 entirely, stays under the 60 percent line
in seven of eight seasons. Only Spring Year 2 still exceeds it (a convergence season where five
combat-facing tier-2 upgrades land at once) and is flagged below as a genuine pinch point to watch in
playtesting, not broken math; Winter Year 1, which the pre-three-biome draft flagged alongside it, is
now comfortable (see the Winter Year 1 section and Checkpoint 2). The building order and calendar
position in `buildings.md` and in the season-by-season map below reflect the three-biome revision
throughout.

**What is not modeled.** Gold-side purchases beyond bundle Gold costs (Smithy weapon and rune
shopping, Trading Post goods) are a separate draw on the same Gold balance and are not itemized here.
Gift cadence, meal cooking, and rune costs draw from the same physical inventory as bundles and are
part of why the 60 percent line is treated as a real ceiling rather than a rounding margin, but they
are not itemized quantity by quantity in this document.

## Season-by-season map

### Spring, Year 1

| Buildings commissioned | Characters arriving | Routes online | Territories open |
|---|---|---|---|
| Trading Post, Tavern, Farmhouse (all constructed in the first ten days), Chapel, Smithy, Infirmary, Command Post tier 2 | Arkus (Smithy trigger), Josen (Infirmary trigger, or the mid-Spring fallback), Oskar (arrives the moment the Chapel stands) | Verdant Fringe gathering (wood, stone, herb, berries, fiber), Spring/Summer crop planting (turnip, potato, wheat, tomato, carrot), goblin and rat combat drops | The Verdant Fringe's starting zone and the first expedition zone; the Elderwood opens once Command Post tier 2 completes |

Elara, Fenwick, and the player are present from day one and start running the Trading Post and
Tavern as soon as each is commissioned. Oskar's arrival is the season's most important beat: the
Chapel's construction bundle (rat_pelt 20, goblin_fang 15, cloth 12) is affordable from the party's very
first goblin and rat fights, so nothing stops it from going up in the first two to three weeks, and
his own heart-building can begin immediately. This is the earliest the Chapel can plausibly land, and
it is exactly the "early Year 1" position his ritual timeline needs (see section 4). Command Post tier 2
(goblin_fang 30, deserter_badge 20, wood 15) is the season's other important beat under the three-biome
revision: it is priced entirely from Verdant Fringe commons and easy-family parts, so it is affordable
alongside the Chapel and Smithy from the same first weeks of forest fighting, and it is what opens the
Elderwood, satisfying the brief's "early-to-mid Year 1" call for that unlock. Spore's and Thistle's own
triggers sit inside the Elderwood, so this tier landing early in Spring is what keeps both of them
reachable on their previously scheduled beats later in the year (see the ordering-check in
`characters.md`).

**Sanity check.** Seven buildings/tiers go up this season: Trading Post (wood 90, stone 60), Tavern
(wood 90, stone 60, herb 15), Farmhouse (wood 120, stone 90), Smithy (goblin_fang 25, rat_pelt 20, wood
15), Infirmary (wood 120, herb 20), Chapel (rat_pelt 20, goblin_fang 15, cloth 12), Command Post tier 2
(goblin_fang 30, deserter_badge 20, wood 15). Summed by material type: gather total = 150 + 165 + 210 +
15 + 140 + 12 + 15 = **707 units** against a 1,500-unit pool (47.1 percent, comfortable). Combat total =
45 (Smithy's goblin_fang + rat_pelt) + 35 (Chapel's rat_pelt + goblin_fang) + 50 (Command Post tier 2's
goblin_fang + deserter_badge) = **130 units** against a 250-unit pool (52 percent, comfortable, though
noticeably busier than the two-biome draft's 32 percent since the Elderwood unlock now lands here
instead of in Summer). Gold total = 60 + 70 + 90 + 120 + 90 + 70 + 350 = **850g** against a 2,800g
cumulative pool (30.4 percent, comfortable). Spring Year 1 clears all three pools comfortably: seven
construction/upgrade bundles land in the same 28 days, but the rescaled gather pool absorbs the
wood-and-stone load easily, and the drop-band combat pool (fights returning 3 to 15 parts each rather
than a flat few) covers the Smithy, Chapel, and Command Post bundles with real headroom even though
this is the very first season and nothing has been banked yet. The prior draft's sharpest early pinch
(63 percent gather, from the original two-biome draft before the Stardew-scale rescale) is fully
resolved at the new scale, and moving the Elderwood unlock into this season keeps the combat total well
under the flag line despite the added load.

### Summer, Year 1

| Buildings commissioned/upgraded | Characters arriving | Routes online | Territories open |
|---|---|---|---|
| Fishing Dock (construction), Apothecary (construction), Command Post tier 3, Tavern tier 2, Farmhouse tier 2 | Spore (Apothecary trigger, the Elderwood explored), Wynn (Tavern tier 2 trigger) | Rod fishing on the Verdant Fringe's pond/river, mushroom log and coop husbandry, Sunken Reach access once Command Post tier 3 lands | The Elderwood (already open since Spring) is explored far enough to find Spore; the Sunken Reach opens once Command Post tier 3 completes |

Command Post tier 3 (beast_hide 25, warden_bark 20, hardwood 15) is the season's hinge under the
three-biome revision: reaching it opens the swamp for travel and gathering, which is what the brief
calls for "mid-Year-1." Landing it in Summer, the second of four seasons in Year 1, satisfies that at
exactly the calendar slot the swamp unlock has always held, even though the tier number and the
bundle contents both changed (tier 2, priced from Verdant Fringe commons, moved to Spring; tier 3,
priced from Elderwood materials, took over this slot). Beast_hide and warden_bark require the Beasts
and Root Wardens encounter families, both reachable in the Elderwood that Command Post tier 2 opened
back in Spring, so this season is where hunting those two families starts mattering.

**Sanity check.** Gather total: Fishing Dock (plank 90, cut_stone 60 = 150) + Apothecary (herb 20,
berries 15, wood 100 = 135) + Command Post tier 3's hardwood 15 + Tavern tier 2 (mead 15, egg 25,
wild_mushroom 20, log_mushroom 15 = 75) + Farmhouse tier 2 (turnip 25, wheat 25, wood 200 = 250) =
**625 units** against 1,500 (41.7 percent, comfortable, identical to the two-biome draft's total since
tier 3's hardwood 15 replaces tier 2's wood 15 at the same unit count). A large share of that (325
units, Tavern and Farmhouse upgrades) draws on crops and husbandry the player is already producing
daily rather than one-off gathering trips, a softer kind of demand than raw foraging, but even the
raw-commons share stays well under the pool. Combat total: Command Post tier 3's beast_hide 25 +
warden_bark 20 = **45 units** against 250 (18 percent, comfortable, close to but slightly lighter than
the two-biome draft's 20 percent). Gold total: 110 + 190 + 450 + 300 + 400 = **1,450g** this season
(100g higher than the two-biome draft, since tier 3's Gold cost, 450, replaces tier 2's, 350, one rung
later in the ladder), cumulative spend to date 850 + 1,450 = 2,300g against a 5,600g cumulative pool by
day 56 (41.1 percent, comfortable). Summer Year 1 is the season with the most total construction work
and the lightest combat demand in Year 1; all three pools absorb it easily, which makes it the year's
natural banking season (see the slack analysis).

### Fall, Year 1

| Buildings commissioned/upgraded | Characters arriving | Routes online | Territories open |
|---|---|---|---|
| Training Yard (construction), Fishing Dock tier 2, Trading Post tier 2, Arcane Study (construction), Watchtower (construction) | Aldric (proposed 8-building trigger, see section 5), Sera (Trading Post tier 2 trigger), Thistle (Watchtower trigger, far-forest campsite deep in the Elderwood) | Trap fishing and Elderwood/Sunken Reach deeper-water fish, the expanded Trading Post shelf, Flick's early swamp encounter | The far-forest campsite zone within the already-open Elderwood (Thistle's trigger); deeper pushes into the already-open Sunken Reach |

By the start of Fall, eight buildings stand (Trading Post, Tavern, Farmhouse, Chapel, Smithy,
Infirmary, Fishing Dock, Apothecary), which is this document's proposed Aldric trigger. He arrives
right at the Year 1 midpoint and immediately makes the Training Yard commissionable, matching
`buildings.md`'s own "Mid Year 1" position for that building. Trading Post tier 2 needs swamp fish
(silt_carp, marsh_clam), so Fishing Dock tier 2 has to land in the same season to supply them, which
is why both appear together here. Flick's swamp expedition and Oskar's heart progress both land in
this window too (see section 4).

**Sanity check.** Gather total: Training Yard's wood 15 + Fishing Dock tier 2 (plank 120, cloth 12,
cut_stone 100 = 232) + Trading Post tier 2 (forest_root 20, tree_sap 20, silt_carp 20, marsh_clam 20
= 80) + Arcane Study's copper_ingot 12 + Watchtower's feather 15 = **354 units** against 1,500 (23.6
percent, comfortable; three units lighter than the pre-padded-bestiary draft, since Fishing Dock tier
2's cloth gave up a few units to spider_silk, a combat-pool item, see below). Combat total: Training
Yard's rat_pelt 25 + deserter_badge 20 (45) + Arcane Study's goblin_fang 20 + rat_pelt 20 (40) +
Watchtower's deserter_badge 25 + rat_pelt 20 + fey_charm 5 (50) + Fishing Dock tier 2's spider_silk 3
= **138 units** against 250 (55.2 percent, under the line but the busiest combat season of Year 1 so
far). Gold total: 220 + 300 + 250 + 200 + 350 = **1,320g** this season, cumulative spend 2,300 +
1,320 = 3,620g against an 8,400g cumulative pool by day 84 (43.1 percent, comfortable). Fall Year 1
is the first season with three different combat-facing building constructions landing at once
(Training Yard, Arcane Study, Watchtower), and their combined part demand pushes combat to just
under the 60 percent line: manageable at the stated pace, but a player who fights noticeably less
than a combat-engaged week in this season will feel it, especially on deserter_badge, which all
three bundles pull from the single Brigand family.

### Winter, Year 1

| Buildings commissioned/upgraded | Characters arriving | Routes online | Territories open |
|---|---|---|---|
| Farmhouse tier 3, Training Yard tier 2, Apothecary tier 2, Reliquary (construction) | Grub (Farmhouse tier 2 + territory-expansion trigger), Hazel (trophy-count trigger, proposed 8), Vasska (missable, if Oskar has reached 6 hearts by now) | Barn husbandry (milk, cream, wool) and the beehive, talisman crafting | Whatever territory milestone satisfies Grub's trigger, typically a farther push into the already-open Sunken Reach or Elderwood |

Training Yard tier 2 wants a nest_matriarch_tail (the Broodmother or the Gnaw King, the Rats'
elite/boss) and, since the padded-bestiary pass, an amber_core (the Ambercore or the Orchard Mother,
the Bramble Slicks' own elite/boss), the season's two trophy demands. Under the three-biome revision,
the Command Post has no
tier scheduled this season at all: tier 2 (the Elderwood unlock) landed back in Spring and tier 3 (the
Sunken Reach unlock, which replaces the previously proposed "expedition logistics" tier entirely) landed
in Summer, so neither draws on Winter Year 1's pools anymore. This removes what the two-biome draft
called the schedule's first real pinch point, the double-trophy convergence of nest_matriarch_tail and
deserter_signet landing in the same 28 days; deserter_signet's own sink has moved to Reliquary tier 3
instead (see `buildings.md` section 6), well outside this season.

**Sanity check.** Gather total: Farmhouse tier 3's carrot, frost_kale, marsh_reed (25 + 25 + 20 = 70)
+ Training Yard tier 2's leather (12) + Apothecary tier 2's tincture and bitter_root (15 + 20 = 35) +
Reliquary's ward_salt (12) = **129 units** against 1,500 (8.6 percent, comfortable). Combat total:
Farmhouse tier 3's beast_hide (15, an Elderwood material, open since Spring so no timing issue) +
Training Yard tier 2's nest_matriarch_tail, deserter_badge, rat_pelt, amber_core (1 + 25 + 25 + 1 = 52)
+ Apothecary tier 2's marsh_leech (15) + Reliquary's goblin_fang and deserter_badge (50) = **132
units** against 250 (**52.8 percent, comfortable**, a large drop from the two-biome draft's 70.8
percent flagged pinch, now that Command Post tier 3's old 46-unit combat draw no longer lands in this
season). Gold total: Farmhouse tier 3 (450) + Training Yard tier 2 (450) + Apothecary tier 2 (350) +
Reliquary construction (380) = **1,630g** this season, cumulative spend 3,620 + 1,630 = 5,250g against
an 11,200g cumulative pool by day 112 (46.9 percent, comfortable; identical to the two-biome draft's
cumulative total, since moving Command Post tier 2's Gold to Spring and tier 3's Gold to Summer nets to
the same amount removed from Winter). The two trophies (nest_matriarch_tail and, since the
padded-bestiary pass, amber_core) are the season's only real timing risk now: if the party has not kept
the Rats and the Bramble Slicks in active rotation since Fall, this is where that shows up, but it is
two easy-tier families rather than the harder two-family convergence the prior draft flagged. The
pinch that used to define this season is resolved; Winter Year 1 is now comfortably under the flag line
on every pool.

### Spring, Year 2

| Buildings commissioned/upgraded | Characters arriving | Routes online | Territories open |
|---|---|---|---|
| Chapel tier 2, Smithy tier 2, Reliquary tier 2, Arcane Study tier 2, Watchtower tier 2 | (none new; this season is upgrade-only) | Improved Smithy armor and metal work, higher-rank spellcasting, bestiary combat intel | No new territory; deeper pushes into the existing three biomes |

By Spring of Year 2, most of the roster is in place and the season turns toward tier upgrades rather
than new arrivals. Chapel tier 2 (its capstone) wants an alpha_pelt, a hollow_locket, and, since the
padded-bestiary pass, a drowning_lantern, all boss or elite drops from families the party has had a
full year to engage.

**Sanity check.** Gather total: Chapel tier 2's ward_salt (15) + Smithy tier 2's coal (25) +
Reliquary tier 2's cut_stone (15) + Arcane Study tier 2's bog_resin (20) + Watchtower tier 2's wood
(15) = **90 units** against 1,500 (6 percent, comfortable). Combat total: Chapel tier 2's alpha_pelt,
hollow_locket, and drowning_lantern (3) + Smithy tier 2's goblin_scrap and beast_hide (50) +
Reliquary tier 2's drowned_bone and rat_pelt (50) + Arcane Study tier 2's serpent_scale, goblin_fang,
and silkqueen_fang (46) + Watchtower tier 2's deserter_badge, mudclaw_hide, and hollow_crown (51) =
**200 units** against 250 (**80.0 percent, flagged, the tightest combat season in the whole two-year
schedule**). Gold total: 700 + 300 + 450 + 400 + 400 = **2,250g** this season, cumulative spend 5,250 +
2,250 = 7,500g against a 14,000g cumulative pool by day 140 (53.6 percent, comfortable). Five different
tier-2 upgrades all pulling on common monster parts and, now, three new trophies at once is the real
driver here, and the padded-bestiary pass pushes it a little further than the prior draft's 78.8
percent: the tightest combat season anywhere in the document, now at 80.0 percent of the drop-band
pool. It stays on the workable side of its pool because all five bundles are upgrade tiers, every one
of which accepts partial contributions over multiple trips, and because the demand spreads across
several part and trophy types and eight creature families rather than concentrating on one. A player
who has been banking surplus parts during Summer and Fall of Year 1 (both comfortably under the combat
line) absorbs this season without trouble; a player who only fights exactly enough for each season's
own bundles will feel this one most, more than before now that three trophy hunts stack on top of the
five bundles' common-part demand.

### Summer, Year 2

| Buildings commissioned/upgraded | Characters arriving | Routes online | Territories open |
|---|---|---|---|
| Farmhouse tier 4 (Greenhouse), Apothecary tier 3, Training Yard tier 3, Watchtower tier 3 | (none new) | Any crop in any season (Greenhouse), rare consumables, respec and later dedications, fast travel | No new territory; this is a capstone-heavy season |

Farmhouse tier 4 is the single largest bundle scheduled anywhere in this document: plank 350, cloth
18, cheese 20, honey 20, butter 20, all refined or husbandry goods rather than raw gathering.

**Sanity check.** Gather total: Farmhouse tier 4 (plank 350, cloth 18, cheese 20, honey 20, butter 20
= 428) + Apothecary tier 3's bog_moss and nightcap_mushroom (25 + 15 = 40) + Training Yard tier 3's
iron_ingot (18) + Watchtower tier 3's hardwood and bogwood (15 + 15 = 30) = **516 units** against
1,500 (34.4 percent, comfortable; Watchtower tier 3's timber line is now split between hardwood and
bogwood rather than all hardwood, but the split keeps its own 30-unit total exactly unchanged).
Farmhouse tier 4 alone is more than 80 percent of that total and is still, as in the prior draft, the
single largest bundle in the whole two-year schedule by raw unit count, but the 1,500-unit pool
absorbs it with room to spare; see section 3's mid-Year-2 checkpoint and section 6 for what this
means in practice. Combat total: Apothecary tier 3's venom_sac and spore_pod (1 + 20 = 21) + Training
Yard tier 3's mudclaw_hide, serpent_scale, nest_matriarch_tail, and, since the padded-bestiary pass,
sovereign_hide (25 + 20 + 1 + 1 = 47) + Watchtower tier 3's deserter_badge and mudclaw_hide (45) =
**113 units** against 250 (45.2 percent, comfortable). Gold total: 2,500 + 1,300 + 1,300 + 1,500 =
**6,600g**, the single most expensive season in the schedule, cumulative spend 7,500 + 6,600 =
14,100g against a 16,800g cumulative pool by day 168 (83.9 percent, flagged, the tightest point in
the Gold ledger so far). Summer Year 2 is a capstone-heavy season by design (Farmhouse's Greenhouse,
Apothecary's and Training Yard's top tiers, Watchtower's fast travel), and both material pools handle
it comfortably. Gold is the one pool under real pressure here: four capstone-band Gold fees landing in
the same 28 days narrow the cumulative cushion to its thinnest point in the schedule so far, which is
exactly the savings pressure a capstone season should exert.

### Fall, Year 2

| Buildings commissioned/upgraded | Characters arriving | Routes online | Territories open |
|---|---|---|---|
| Command Post tier 4 (Resurrection), Smithy tier 3, Reliquary tier 3 | (none new; Raven and Vasska should already be resolved by now if pursued, see section 4) | Resurrection service, advanced Smithy weapon tier and property runes, relic-display outpost buffs | No new territory |

This is where the schedule turns toward completion. Command Post tier 4 wants a hollow_locket, a
venom_sac, a goblin_totem, and, since the padded-bestiary pass, bogwood, its own timber forming the
resurrection dais; Reliquary tier 3 wants a reaver_tooth, a shadow_gar, a nest_matriarch_tail, a
deserter_signet, a heartwood_shard, and, with the same pass, one unit each of amber_core, hollow_crown,
silkqueen_fang, grovefather_knuckle, sovereign_hide, and drowning_lantern, eleven trophies in total,
one from every creature family the game now has (deserter_signet and heartwood_shard were themselves
additions from the three-biome revision: deserter_signet moved here once Command Post tier 3 stopped
using it, and heartwood_shard is the Root Wardens' own trophy). Smithy tier 3 also picked up a
swamp_drake_scale and a grovefather_knuckle in the same pass, part of a swap against its own
mudclaw_hide line rather than an addition. Both the Command Post and Reliquary bundles are the
"documented exception" pattern from `buildings.md`: light on total units, dominated by 1-unit trophies
rather than bulk commons.

**Sanity check.** Gather total: Command Post tier 4's iron_ingot, ward_salt, and bogwood (20 + 15 + 15
= 50) + Smithy tier 3's iron_ingot (15) + Reliquary tier 3's spirit_dust (18) = **83 units** against
1,500 (5.5 percent, comfortable). Combat total: Command Post tier 4's three trophies (3) + Smithy tier
3's mudclaw_hide, serpent_scale, goblin_totem, swamp_drake_scale, and grovefather_knuckle (20 + 25 + 1
+ 5 + 1 = 52) + Reliquary tier 3's eleven trophies (11) = **66 units** against 250 (26.4 percent,
comfortable, up from the pre-padded-bestiary draft's 23.6 percent now that Reliquary tier 3 carries
six more 1-unit trophies and Smithy tier 3 carries one more). Gold total: 2,000 + 500 + 1,600 =
**4,100g**, cumulative spend 14,100 + 4,100 = 18,200g against a 19,600g cumulative pool by day 196
(92.9 percent, flagged, the tightest point in the Gold ledger). Fall Year 2 is comfortable on both
material pools: the trophy-heavy bundles here are light in raw unit count by design even with six more
trophies added, and the party has had a full year and a half to have already banked spare trophies
from families it fought for other buildings' bundles. Gold is the season's one pressure point, with
Command Post tier 4's Resurrection fee (the schedule's second-largest single Gold cost) landing on a
ledger still recovering from Summer's capstone pile-up.

### Winter, Year 2

| Buildings commissioned/upgraded | Characters arriving | Routes online | Territories open |
|---|---|---|---|
| Smithy tier 4 (capstone) | (none new; this is the closing season for any missed missable or completionist trophy) | Masterwork/trophy-forged weapon tier | No new territory |

The final season is deliberately light. Smithy tier 4 wants a goblin_totem, an alpha_pelt, and a
reaver_tooth, one unit each, alongside iron_ingot 20 and, since the padded-bestiary pass, bogwood 15
for the masterwork hafts. Everything else in this season is completionist: finishing the Vasska ritual
quest if it has not already resolved, mopping up any trophy the player has not yet farmed for a side
goal, and generally coasting on the surplus the earlier seasons should have banked.

**Sanity check.** Gather total: iron_ingot 20 + bogwood 15 = **35 units** against 1,500 (2.3 percent).
Combat total: three trophies (3) against 250 (1.2 percent). Gold total: **2,200g**, cumulative spend
18,200 + 2,200 = 20,400g against a 22,400g cumulative pool by day 224 (91.1 percent, easing slightly
from Fall's 92.9 percent peak but still under the line). Winter Year 2 is the slackest season in the
schedule by gather and combat alike, which is the right shape for a finale: nothing new is gating the
player on materials, and any earlier tightness has had a full season to resolve. Gold is the one pool
still under real pressure this late, closing the two-year schedule at 91.1 percent of its cumulative
conservative income; see the checkpoint audits below for what that means across the whole run.

## Checkpoint audits

### Checkpoint 1: end of Spring, Year 1 (day 28)

Only one season's demand has landed by this point, so the checkpoint total equals Spring Year 1's
own sanity check. Gather demand = 707 units against a one-season pool of 1,500 (**47.1 percent,
comfortable**). Combat demand = 130 units against a one-season pool of 250 (**52 percent,
comfortable**). Gold demand = 850g against a cumulative pool of 2,800g (**30.4 percent,
comfortable**). All three pools clear the opening rush with room to spare, which resolves the
original two-biome draft's sharpest early-game pinch (63 percent gather demand at the old scale).
Seven construction/upgrade bundles inside 28 days (six building constructions plus Command Post tier
2, the Elderwood unlock, moved here from Summer in the three-biome revision) is still the busiest
single stretch of the whole schedule by bundle count, and combat is noticeably busier than the
two-biome draft's own Checkpoint 1 (52 percent versus 32 percent) since the Elderwood unlock's
goblin_fang and deserter_badge draw now land in the same season as the Smithy's and Chapel's own
combat demand. The intended feel survives the arithmetic: the wood-and-stone bundles each take a
meaningful slice of a gathering day (Farmhouse alone is 210 units, most of a focused day's low-end
haul), and Smithy, Chapel, and Command Post tier 2 together want a bit over two weeks of the season's
fighting, so the opening month reads busy without any pool actually running short.

### Checkpoint 2: end of Year 1 (day 112)

This sums all four Year 1 seasons. Gather demand = 707 + 625 + 354 + 129 = **1,815 units** against a
four-season pool of 6,000 (**30.25 percent, comfortable**). Combat demand = 130 + 45 + 138 + 132 =
**445 units** against a four-season pool of 1,000 (**44.5 percent, comfortable**). Gold demand =
5,250g against a cumulative pool of 11,200g (**46.9 percent, comfortable**). All four-season totals
land within a handful of units of the pre-padded-bestiary draft's own figures (1,815 gather versus
1,818; 445 combat versus 441; 5,250 Gold identical), because the padded-bestiary pass's swaps mostly
trade one combat-pool item for another and its few additions are each only a handful of units. All
three pools have real headroom across the whole of Year 1, and the three demand lines are far more
balanced against each other than the original single-biome draft's were: gather, combat, and Gold all
land within a 17-point spread of one another, meaning no single route can be ignored for a year
without consequence, which is the every-system-stays-engaged shape the bundle philosophy aims for.
Unlike the two-biome draft, combat's aggregate comfort no longer hides an individually tight season:
moving the Sunken Reach unlock's old demand out of Winter Year 1 drops that season from a flagged 70.8
percent to a comfortable 52.8 percent, so every individual season in Year 1 now clears the 60 percent
line (Fall Year 1's 55.2 percent is the closest any season comes). The banking advice in the slack
analysis still matters, since Spring Year 2 remains genuinely tight, but Year 1 itself is now
comfortable start to finish. By the end of Year 1, most buildings
sit at tier 1 or 2 (Command Post at tier 3, Farmhouse at tier 3, several others at tier 1 or 2),
matching the pacing anchor's call for "most buildings reach tier 1-2" by this point. Character-wise,
by this checkpoint the roster should include Arkus, Josen, Oskar, Spore, Aldric, Sera, Thistle, Wynn,
Flick, Grub, and Hazel, with Raven's recruitment and Vasska's subquest plausibly resolved or in
progress (see section 4) and Hilde still likely townsfolk-only pending Tavern tier 3.

### Checkpoint 3: mid-Year 2 (day 168, after Summer of Year 2)

This sums all six seasons through Summer Year 2. Gather demand = 1,815 (Year 1) + 90 (Spring Y2) +
516 (Summer Y2) = **2,421 units** against a six-season pool of 9,000 (**26.9 percent, comfortable**).
Combat demand = 445 (Year 1) + 200 (Spring Y2) + 113 (Summer Y2) = **758 units** against a six-season
pool of 1,500 (**50.5 percent, comfortable in aggregate**). Gold demand = 14,100g against a
cumulative pool of 16,800g (**83.9 percent, flagged; the ledger tightens further to its 92.9 percent
peak in Fall Year 2 before easing at the finale**). Gather stays comfortable throughout. Combat sits at
almost exactly half its cumulative pool, comfortable in aggregate and, under the three-biome revision,
carrying only one flagged season inside it rather than two: Spring Year 2's five simultaneous tier-2
upgrades, now also carrying three of the padded bestiary's new trophies (80.0 percent of that season's
own pool, the document's tightest single season, unaffected by the biome restructure since none of its
five bundles touch a Command Post tier). Winter Year 1, which the two-biome draft flagged alongside it
at 70.8 percent, is now a comfortable 52.8 percent (see Checkpoint 2), so Spring Year 2 stands alone as
the schedule's one sustained combat push rather than the tail end of a two-season stretch. Gold is
genuinely tight for the first time at this checkpoint, driven by Summer
Year 2's capstone pile-up (Farmhouse's Greenhouse, Apothecary's and Training Yard's top tiers, and
Watchtower's fast travel landing in the same 28 days). By this point in the schedule the player should
have all of Year 1's
building tiers finished and be mid-way through Year 2's tier-3 and capstone pushes, which is exactly
what the pacing anchor calls for ("Year 2: max tiers, missables, rare trophies"), and all three pools
support that pace, if only barely on the Gold side.

## The missables timeline

### Raven

Raven's trigger has two parts: Trading Post and Tavern built, then a day threshold before her
visits begin. Both buildings are commissioned in the first ten days of Spring Year 1, so this
document proposes a threshold of roughly three to four weeks (21 to 28 days) before her visits
start, landing her first appearance in late Spring to early Summer Year 1 (around day 35 to 45).
From there, recruitment needs hearts 5-6. Because she is a periodic visitor rather than a resident,
her friendship pace is likely slower than a character who is present every day: this document
estimates two to three weeks a heart rather than the brief's one-to-two-week resident pace, so 5 to
6 hearts takes roughly 10 to 18 weeks (70 to 126 days) of active investment once her visits begin.
Starting from day 40, that lands recruitment anywhere from around day 110 (right at the end of Year
1) to around day 166 (deep into Summer Year 2). Both ends of that range sit inside the two-year
window, but a player who does not start engaging with her until late Year 1 is working with much
less slack than a player who befriends her from her first visit. This is the schedule's most
timing-sensitive missable outside of Vasska, and the pacing recommendation is simply that Raven's
early visits should read as clearly worth engaging with from the start, since the friendship clock
on her is the longest-running one in the roster.

### Vasska

Vasska's gate has three parts: Oskar at 6 of 10 hearts, the swamp explored, and a recruitment
subquest. Oskar's own doc puts the friendship investment at the brief's stated one-to-two-week-a-
heart pace for a heavily invested character. If the player begins building his friendship the moment
he arrives (Chapel construction, roughly day 15 to 20 of Spring Year 1), 6 hearts lands somewhere
between day 62 (early Summer Year 1, at the fast end) and day 104 (late Fall Year 1, at the slow
end). The swamp half of the gate, Command Post tier 3 (the Sunken Reach unlock, moved from tier 2 in
the three-biome revision), is still scheduled for Summer Year 1 in this document's calendar (see the
Summer Year 1 section), so by the time either end of Oskar's heart range is reached, the swamp is
already open. The subquest itself (befriending a nagaji who is not
immediately willing to leave) is estimated at two to four more weeks once both gate conditions are
met. Combining the slowest plausible path (Oskar hits 6 hearts on day 104, subquest takes 4 weeks),
Vasska is recruited by roughly day 132, early Winter Year 1. That leaves the entire remainder of
Year 1 plus all of Year 2, minus whatever calendar room the ritual's own fixed death-event timeline
consumes, as slack for assembling the ritual team: Hazel, whose own trophy-count trigger is
reachable "across a normal stretch of Year 1 forest play" per her file, and a high-friendship Josen,
who arrives in Spring Year 1 and has the same year and a half of friendship-building runway. Even
under this document's slowest reasonable estimate for every step in the chain, roughly a year of
calendar room remains before Year 2 ends, which is the slack the ritual quest needs to feel
achievable rather than a hidden trap. The one real risk this document flags is the same one
`characters.md` already flags: if the Chapel is deliberately delayed into late Year 1 or Year 2,
this entire chain compresses and the slack disappears. Nothing in this schedule does that; the
Chapel lands in the first weeks of Spring Year 1 specifically so this chain has room to work.

## Aldric decision (proposed change)

`characters.md` currently gates Aldric on "three buildings constructed." Trading Post, Tavern, and
Farmhouse, the party's three cheap opening commissions, already satisfy that count within the first
ten days of Spring Year 1, well before the Smithy, Infirmary, or Chapel exist. That makes his arrival
trivial and immediate rather than the mid-Year-1 beat the building's own table position implies.

Working from this document's calendar: by the end of Spring Year 1, six buildings stand (Trading
Post, Tavern, Farmhouse, Chapel, Smithy, Infirmary). By the end of Summer Year 1, two more land
(Fishing Dock, Apothecary), for a total of **eight**, and this is the point at which this schedule
places Aldric's arrival, right at the natural midpoint of Year 1 (the Summer/Fall boundary, day
around 56). Eight is proposed here in place of three.

**PROPOSED CHANGE for `characters.md`:** change Aldric's trigger from "three buildings constructed"
to "**eight** buildings constructed at the outpost." The Command Post still does not count (it is
the start state, not something the player builds), and the Training Yard itself does not count
either, since it is what Aldric's own arrival unlocks. The other eleven buildings (Trading Post,
Tavern, Farmhouse, Chapel, Fishing Dock, Smithy, Infirmary, Apothecary, Arcane Study, Watchtower,
Reliquary) are the eligible pool; reaching eight of them is what fires the trigger. This count lands
him immediately after the natural "early Year 1" cohort of buildings (the six from Spring plus
Fishing Dock and Apothecary from Summer) finishes, which is exactly the set of buildings
`buildings.md`'s own rough-calendar table already calls "Early Year 1," and it puts his arrival at
the same "Mid Year 1" position that table already assigns to the Training Yard he unlocks. If a
player skips Fishing Dock (it has no attached character and no forced trigger), Aldric simply waits
for whichever eighth building comes next, which still keeps him solidly inside Year 1 rather than
reopening the "arrives on day one" problem this proposal is meant to fix.

## Slack analysis

**Where the schedule has room.** Gather is comfortable in every single season of this document; its
tightest single-season total anywhere is Spring Year 1's 47.1 percent. Combat clears every checkpoint
in aggregate (52 percent, 44.5 percent, 50.5 percent) and stays under the 60 percent line in seven of
eight seasons, one more than the two-biome draft managed, now that moving the Sunken Reach unlock out
of Winter Year 1 resolves that season's old pinch. Summer Year 1 is the year's natural banking season,
the lightest combat season in Year 1 (18 percent of pool) despite being one of the busiest by
construction count, because Tavern tier 2 and Farmhouse tier 2 draw on crops and husbandry the player
is producing daily rather than fights.
Fall and Winter of Year 2 are the slackest seasons in the back half of the schedule (26.4 percent and
1.2 percent of the combat pool, 5.5 percent and 2.3 percent of the gather pool), which is the right
shape for a closing stretch: by then most of the roster and most building tiers are already in place,
and what remains is trophy consolidation the party has had a year and a half to prepare for. The
Fishing Dock is slack in a structural sense too: it has no attached character and no forced trigger,
so it is content a player can build whenever convenient, a natural pressure valve for an otherwise
busy season.

**Where it is tight.** Only one combat season still exceeds the 60 percent flag line at the drop-band
supply scale: Spring Year 2 (80.0 percent, the tightest season in the document, five tier-2 upgrades
all pulling common monster parts, and now three of the padded bestiary's trophies, at once), unaffected
by the biome restructure since none of its bundles touch a Command Post tier. The two-biome draft
flagged Winter Year 1 alongside it (70.8 percent, five bundles including a double-trophy convergence of
nest_matriarch_tail and deserter_signet), which made Winter Year 1 through Spring Year 2 a sustained
two-season combat push; moving the Sunken Reach unlock's old demand out of Winter Year 1 and into
Summer Year 1 (see Checkpoint 2) drops that season to a comfortable 52.8 percent, so Spring Year 2 now
stands alone as the schedule's
one tight combat season rather than the tail end of a longer push. It is not a break: every bundle
involved above tier 1 accepts partial contributions over multiple trips, and the season sits adjacent
to slack ones (Winter Year 1's own newly comfortable 52.8 percent before it, Summer Year 2's combat
comfort after) that a banking player converts into stockpile. The practical advice is the same as it
has always been: start hunting the relevant creature family one season earlier than the bundle that
needs its trophy, and treat slack seasons as part-banking seasons so the tight season draws down an
existing stockpile instead of starting from zero. Gold gets genuinely tight exactly once, in the
run-up through Summer Year 2's capstone pile-up and Fall Year 2's Resurrection fee (83.9 percent of
cumulative income by day 168, 92.9 percent by day 196, 91.1 percent at the schedule's end). That is
a real pinch but not a break: cumulative Gold income clears cumulative Gold spend at every checkpoint,
so a player who saves toward capstones the way a Stardew player saves toward a Barn will clear it,
and the thin margin is doing exactly what a capstone price should do.

One feel note the numbers support directly: the "multiple expeditions per bundle" experience is
intended, and the rescale preserves it. A Farmhouse construction (210 raw commons) is most of a
focused gathering day's low-end haul; Farmhouse tier 4's 428 units is two to three dedicated trips; a
combat-facing tier bundle of 40 to 50 parts is a week-plus of engaged fighting. Bundles are meant to
be filled across several outings, with upgrade tiers accumulating partial payments along the way, and
the pool percentages above measure exactly that multi-trip pace rather than any expectation of
single-day affordability.
