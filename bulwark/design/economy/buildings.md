# Bulwark: Building Progression

This document is the complete building progression design for Bulwark: every building's commission
prerequisite, its construction bundle, and every upgrade tier's bundle and benefit. It implements the
`design/economy/economy_brief.md` framework contract (the pinned tier ladders, the combat pillar, the
bundle pricing rules) as concrete content, and it draws every bundle item id from
`design/economy/materials.md`, the catalog of record. This design supersedes the placeholder bundles
shipped in `scripts/data/Buildings.cs`. The content here lands in a later code pass; nothing in this
document edits code.

The building economy runs on a two-stage model. A building is **commissioned** by paying its
construction bundle all at once at the Command Post's planning table, which brings it to tier 1. From
there, each higher tier is reached by **accumulating** that tier's upgrade bundle, with partial
contributions allowed over as many trips as it takes. Construction bundles must be fully affordable in
a single payment; upgrade bundles are a running tally the party tops up whenever it returns with
materials. Every bundle in this document, construction and upgrade alike, now carries a Gold cost
alongside its materials, paid in full at the moment the bundle completes: the Stardew carpenter model
of gold plus materials, at full Stardew scale (revised 2026-07-14). Section 4 lays out the bands this
document builds every bundle against.

> **2026-07-16 revision (early-game progression rework).** Three construction bundles gain Elderwood
> **hardwood**, tying the outpost's early growth to the dire wolf that guards the passage into the
> Elderwood (see `design/tutorial_quests.md`, the canonical quest chain): Trading Post (90 wood /
> 60 stone / 30 hardwood), Smithy (90 wood / 40 hardwood / 25 goblin_fang), and Infirmary (120 wood /
> 30 hardwood / 20 herb). The Trading Post is still offered at the planning table from day one with no
> flag gate, but its hardwood line means it cannot actually be raised until the Elderwood opens — which
> now happens when the **dire wolf is slain** (`dire_wolf_slain`), NOT at Command Post tier 2. Smithy and
> Infirmary are now both gated on `arkus_awake` (Arkus wakes after the Trading Post is built and asks for
> a forge and a sickbed); Josen no longer gates the Infirmary — he arrives 1-3 days after it is built,
> via random event.
>
> **Same-day follow-up decision: Command Post upgrade tiers deferred.** The Command Post ships with NO
> upgrade tiers this pass — its purpose is the planning table that guides the outpost's repair, not a
> tier ladder. The previously drafted tier 2-4 ladder (including tier 3's Sunken Reach `BiomeUnlock`) is
> dropped from this document pending a future design pass; see the Command Post section below. The
> Sunken Reach's unlock is now TBD.

## 1. Unlock-order overview

Only the Command Post exists at tier 1 from the first day of play. Tharr already runs its planning
table, so it carries no construction bundle; its upgrade tiers are deferred pending design (tier 1 is
the whole of it for now). He is the lone holdout who kept it standing while everything else at the
outpost fell to ruin. Trading Post, Tavern, and Farmhouse
are offered at the planning table from day one as well, with no character or flag prerequisite, but each
is still rubble until its construction bundle is paid. The Tavern and Farmhouse bundles are cheap and
drawn entirely from Verdant Fringe commons, so they are the directed early builds: the tutorial points
the player at raising them to stage 1 first (see `design/tutorial.md`). The Trading Post is different.
Since the 2026-07-16 revision, its construction bundle includes Elderwood **hardwood** (90 wood / 60
stone / 30 hardwood), which the party cannot gather until the Elderwood opens — and the Elderwood is
gated behind the dire wolf that guards the passage in. So while the Trading Post shows at the planning
table from day one, it cannot be raised until the wolf is slain (`dire_wolf_slain`); it is the outpost's
first Elderwood-gated build rather than a day-one one. Elara, Fenwick, and the player are all present at
the outpost from day one regardless of construction state; Elara opens the Trading Post's store once it
is commissioned, and Fenwick starts cooking once the Tavern is commissioned. The remaining buildings are
commissioned over the rest of Year 1 and into Year 2, gated either by a character's arrival or by outpost
progress alone.

| Building | Commission prerequisite | Rough calendar position |
|---|---|---|
| Command Post | None. Exists at tier 1 from day one; upgrade tiers deferred pending design. | Day one (start state) |
| Trading Post | None (no flag gate), but its construction bundle needs Elderwood hardwood, so it cannot be raised until the Elderwood opens (dire wolf slain). | After the dire wolf is slain; early-mid Year 1 |
| Tavern | None. Commissionable from day one (construction bundle). | First days of Year 1 (directed) |
| Farmhouse | None. Commissionable from day one (construction bundle). | First days of Year 1 (directed) |
| Chapel | None beyond outpost progress. Buildable as soon as its construction bundle is affordable, with no character or tier prerequisite. | Early Year 1 |
| Fishing Dock | None beyond outpost progress. No character is attached yet. | Early Year 1 |
| Smithy | Arkus wakes (`arkus_awake`): found wounded on the return from the wolf kill, he wakes once the Trading Post is built and asks for a forge. | Early-mid Year 1 |
| Infirmary | Arkus wakes (`arkus_awake`): his lasting wounds prompt the sickbed. Josen arrives 1-3 days after it is built (no longer gates it). | Early-mid Year 1 |
| Apothecary | Spore arrives (the Elderwood biome is explored; requires the Elderwood open — dire wolf slain). | Mid Year 1 |
| Arcane Study | Sera arrives (Trading Post reaches tier 2). | Mid Year 1 |
| Training Yard | Aldric arrives (eight buildings have been constructed at the outpost). | Mid Year 1 |
| Watchtower | Thistle arrives (the far-forest campsite zone, deep in the Elderwood, is discovered; farther in than Spore's own trigger). | Late Year 1 |
| Reliquary | Hazel arrives (the party holds a proposed 8 monster trophies or rare drops, current carry plus warehouse). | Late Year 1 into Year 2 |

The Chapel's early, cheap placement is load-bearing. Oskar arrives the moment the Chapel is built, and
his own curse timeline runs on a fixed calendar; a late Chapel compresses the window the player has to
build friendship with him and, downstream, to recruit Vasska and assemble a ritual team before his
decline resolves. The Chapel's construction bundle is deliberately built from monster parts the party
can gather from its very first forest fights (see section 3), so nothing about zone exploration or
building tiers stands between the player and an early Chapel.

## 2. Character-first and building-first patterns, restated

Per `characters.md`: Smithy (Arkus), Apothecary (Spore), Watchtower (Thistle), Training Yard (Aldric),
Arcane Study (Sera), and Reliquary (Hazel) are character-first — each only becomes commissionable once
its character arrives; there is nothing to build before that. The **Infirmary is a special case since
the 2026-07-16 revision**: it is unlocked by `arkus_awake` (the same wake beat that unlocks the Smithy —
Arkus's lasting wounds are the reason the sickbed goes up), and Josen, the monk who runs it, arrives 1-3
days *after* it is built via a random event. So the Infirmary is character-gated (on Arkus, not on its
own staffing character) rather than building-first. Chapel, Tavern, Farmhouse, Trading Post, and Fishing
Dock are building-first: each is commissionable, or reachable, by outpost progress alone, with no
character required to unlock it. Tavern and Farmhouse are the directed day-one builds; the Trading Post
is offered from day one too but is hardwood-gated (see section 1), so it goes up after the dire wolf
opens the Elderwood. Any character tied to these (Oskar, Wynn, Hilde, Grub) arrives afterward because the
building reached the state that draws them in.

## 3. Buildings

Each section below gives the building's theme, its commission prerequisite, its construction bundle
(where one exists), and its full tier ladder. Tier numbers, benefit placements, and tier counts match
the pinned ladder in `economy_brief.md` exactly. Where the brief asks for a proposal, it is marked
**PROPOSED**.

### Command Post

The outpost's command post is where every building gets commissioned: the planning table that guides
the repair of the whole outpost. It is the start state of the whole economy: tier 1 exists before play
begins, with Tharr already running the planning table, so it carries no construction bundle.

**Commission prerequisite:** None. Start state.

**Tiers**

**Tier 1: Planning table.** No upgrade bundle (start state). This is the table itself: the commission
menu for every other building, plus the roster screen where new arrivals join the active squad of four.

**Upgrade tiers (2+): DEFERRED pending design (2026-07-16 decision).** The Command Post's purpose is the
planning table itself, not a tier ladder — it may gain upgrade tiers later, but they are not designed
yet. The previously drafted 2-4 ladder (a pure stat/facility tier; a `BiomeUnlock` (Sunken Reach) tier;
a `Resurrection` capstone) is dropped from this document — it lives in this file's git history, not
here — along with its open question about tier 2's replacement effect. The Sunken Reach's eventual
unlock path is **TBD (previously CP Tier 3)**, to be resolved whenever upgrade tiers are designed.

### Trading Post

The Trading Post is the outpost's merchant, buying and selling finished goods for gold and stocking
seeds for the Farmhouse. Elara is present at the outpost from day one, and she opens the store as soon
as the Trading Post is commissioned.

**Commission prerequisite:** None (no flag gate); offered at the planning table from day one. But its
construction bundle includes Elderwood hardwood, so it cannot actually be raised until the Elderwood
opens — which happens when the dire wolf that guards the passage is slain (`dire_wolf_slain`). It is the
outpost's first Elderwood-gated build, not a day-one one (2026-07-16 revision).

**Construction bundle** *(hardwood line added 2026-07-16)*

| Item id | Quantity |
|---|---|
| Gold | 60 |
| wood | 90 |
| stone | 60 |
| hardwood | 30 |

The hardwood is the deliberate gate: the Verdant Fringe supplies the wood and stone from day one, but the
30 hardwood cannot be gathered until the Elderwood is open. Restoring the Trading Post (quest 8 in
`design/tutorial_quests.md`) is what first sends the party into the Elderwood for it.

**Tiers**

**Tier 1: General store.** No upgrade bundle (reached at commission). *Effect:* `CategoryUnlock` (Detail:
`general_store`). Buys and sells the outpost's baseline goods and stocks every crop's seed.

**Tier 2: Expanded store.**

| Item id | Quantity |
|---|---|
| Gold | 250 |
| forest_root | 20 |
| tree_sap | 20 |
| silt_carp | 20 |
| marsh_clam | 20 |

*Effect:* `CategoryUnlock` (Detail: `expanded_store`). The shelf widens to carry a broader sample of
whatever the outpost's routes are producing, forage, tap-line goods, and modest catch from both
biomes, rather than only the starting staples. This tier is also Sera's arrival trigger: reaching it
makes the Arcane Study commissionable. Stock also widens with the Smithy's own tier as it rises, an
existing cross-building mechanic kept unchanged (see section 5).

### Smithy

The Smithy is the forge: Arkus's weapon catalog, fundamental runes, and, as it grows, the metal-armor
and property-rune work that keeps the party's gear scaling across two years.

**Commission prerequisite:** Arkus wakes (`arkus_awake`). Found wounded on the return from the dire-wolf
kill and laid up until the Trading Post is built, Arkus wakes and asks for a forge — naming the wolf as
what broke him and his lost gear as why. Gated on the wake, not on the earlier `arkus_found` beat.

**Construction bundle** *(rebuilt 2026-07-16 — now a wood + hardwood mix)*

| Item id | Quantity |
|---|---|
| Gold | 120 |
| wood | 90 |
| hardwood | 40 |
| goblin_fang | 25 |

The forge is a real timber project, so wood is its foundation and Elderwood hardwood braces the frame
(available by now — Arkus cannot wake to ask for it until the Trading Post is up and the Elderwood is
already open). The 25 goblin_fang keeps one combat-drop line, the thematic nod that a smithy on the
frontier is forged partly from what the party has killed. This replaces the shipped all-monster-parts
bundle (goblin_fang 25 / rat_pelt 20 / wood 15); the Smithy is no longer priced as a pure combat-facing
building, since the new flow raises it after the Elderwood opens rather than from the first forest fights.

**Tiers**

**Tier 1: Base catalog + fundamental runes.** No upgrade bundle (reached at commission). *Effect:*
`SmithyTier` (Magnitude 0). The base weapon catalog (dagger through longbow) plus Potency and Striking
runes, gold-only at this tier.

**Tier 2: Improved catalog + armor.**

| Item id | Quantity |
|---|---|
| Gold | 300 |
| goblin_scrap | 25 |
| coal | 25 |
| beast_hide | 25 |

*Effect:* `SmithyTier` (Magnitude 1). Unlocks the improved weapon tier (falchion, maul) and the
Smithy's first armor line, built from tanned beast hide and the coal-fired forge the Elderwood's own
seam now supplies. Both ingredients are Elderwood materials, but this tier lands a full year after the
Elderwood opens (the dire-wolf kill) on the schedule `pacing.md` lays out, so neither is a timing risk.

**Tier 3: Advanced catalog + property runes.**

| Item id | Quantity |
|---|---|
| Gold | 500 |
| mudclaw_hide | 20 |
| serpent_scale | 25 |
| goblin_totem | 1 |
| iron_ingot | 15 |
| swamp_drake_scale | 5 |
| grovefather_knuckle | 1 |

*Effect:* `SmithyTier` (Magnitude 2). Unlocks the advanced weapon tier (glaive, halberd) and property
runes, the enchantment layer above the fundamentals. The goblin totem, taken only from Rustjaw or the
Warlord, marks this as the tier where the Smithy starts asking for a defeated threat's proof rather
than just its raw materials. The tier also now draws on the Reach's swamp drakes and the Elderwood's
thornback giants: a swamp drake's scale reinforces the advanced catalog's armor work, and a
Grovefather's knuckle bone serves as the property rune's toughness catalyst.

**Tier 4: Trophy-forged / masterwork tier.**

| Item id | Quantity |
|---|---|
| Gold | 2200 |
| goblin_totem | 1 |
| alpha_pelt | 1 |
| reaver_tooth | 1 |
| iron_ingot | 20 |
| bogwood | 15 |

*Effect:* `SmithyTier` (Magnitude 3). The Smithy's capstone: masterwork equipment forged directly from
three different bosses' trophies (the Warlord, the Old Growl, the Bog Chief) alongside refined iron.
This is the top of the weapon ladder for as long as the Verdant Fringe, the Elderwood, and the Sunken
Reach remain the only three biomes. Weapon hafts at this tier are cut from bogwood, the Sunken Reach's
own water-hardened timber, the one material tough enough to be trusted behind a masterwork head.

### Infirmary

The Infirmary is field medicine: Josen's rest healing, and, as it grows, faster recovery and the
capacity to treat serious afflictions in a single stay.

**Commission prerequisite:** Arkus wakes (`arkus_awake`), 2026-07-16 revision. Arkus's lasting wounds
are what prompt the sickbed, so the Infirmary becomes commissionable from the same wake beat that unlocks
the Smithy (quest 9, "The Smith and the Sickbed"). **Josen no longer gates the Infirmary** — the monk who
runs it arrives 1-3 days *after* it is built, via a random event (see `characters.md`).

**Construction bundle** *(hardwood line added 2026-07-16)*

| Item id | Quantity |
|---|---|
| Gold | 90 |
| wood | 120 |
| hardwood | 30 |
| herb | 20 |

Wood remains the foundation; 30 Elderwood hardwood braces the frame (available by the wake beat, since
the Elderwood is open by then), and herb ties the bundle to the medicine the building is for.

**Tiers**

**Tier 1: Rest healing.** No upgrade bundle (reached at commission). *Effect:* `InfirmaryHealing`
(Magnitude 1). A night's rest at the Infirmary restores the squad more fully than resting in the field.

**Tier 2: Faster recovery + affliction treatment.**

| Item id | Quantity |
|---|---|
| Gold | 350 |
| herb | 25 |
| berries | 20 |
| beast_hide | 8 |
| spun_yarn | 10 |
| thornback_hide | 4 |

*Effect:* `InfirmaryHealing` (Magnitude 2). Recovery time drops further, and Josen's care extends to
treating ongoing afflictions, not just raw wounds, the bandaging and dressing work the beast hide,
thornback hide, and spun yarn go toward.

**Tier 3: Advanced care.**

| Item id | Quantity |
|---|---|
| Gold | 1200 |
| herb | 30 |
| tincture | 18 |
| leather | 15 |

*Effect:* `InfirmaryHealing` (Magnitude 3). Severe wounds and lingering afflictions are treated in a
single rest, cutting recovery time again. **Migration note:** the antidote and tonic category that
shipped at this tier moves to Apothecary tier 1 (see section 6); this tier's effect changes from a
`CategoryUnlock` to a third `InfirmaryHealing` step instead.

### Chapel

The Chapel is faith and the divine: focus spells, the divine font, and blessings, growing into
hero-point grants and greater blessings at its capstone. It is the character-first exception's mirror
image: nothing about it requires a character, and its own construction is what brings Oskar in.

**Commission prerequisite:** None beyond outpost progress. Buildable as soon as its construction bundle
is affordable.

**Construction bundle**

| Item id | Quantity |
|---|---|
| Gold | 70 |
| rat_pelt | 15 |
| goblin_fang | 15 |
| cloth | 12 |
| sap_gland | 5 |

**Tiers**

**Tier 1: Focus spells, font, and blessings.** No upgrade bundle (reached at commission). *Effect:*
`CategoryUnlock` (Detail: `focus_font_blessings`). The party gains a focus-spell font and access to
basic divine blessings.

**Tier 2: Hero-point grants + greater blessings.**

| Item id | Quantity |
|---|---|
| Gold | 700 |
| alpha_pelt | 1 |
| hollow_locket | 1 |
| drowning_lantern | 1 |
| ward_salt | 15 |

*Effect:* `CategoryUnlock` (Detail: `hero_point_grants_greater_blessings`). The Chapel starts granting
hero points on its own schedule and its blessings grow stronger. This is the Chapel's only upgrade
tier, so its trophy cost sits here rather than at a nominal tier 3 or 4; the hollow locket in particular
ties the Chapel's own growth to the same Sunken Reach threat. A
captured wisp-light, the Drowning Light's own lantern, adds a second Sunken Reach trophy to the tier: a
light that finally leads somewhere honest, fitting company for a font that grants hero points.

### Arcane Study

The Arcane Study is the outpost's library of magic: Sera's spell learning and scrolls, growing into
higher spell ranks and, at its capstone, rare spells and research tools.

**Commission prerequisite:** Sera arrives (Trading Post reaches tier 2).

**Construction bundle**

| Item id | Quantity |
|---|---|
| Gold | 200 |
| goblin_fang | 20 |
| rat_pelt | 20 |
| copper_ingot | 12 |

**Tiers**

**Tier 1: Spell learning + scrolls.** No upgrade bundle (reached at commission). *Effect:*
`CategoryUnlock` (Detail: `spell_learning_scrolls`).

**Tier 2: Higher spell ranks.**

| Item id | Quantity |
|---|---|
| Gold | 400 |
| bog_resin | 20 |
| serpent_scale | 25 |
| goblin_fang | 20 |
| silkqueen_fang | 1 |

*Effect:* `CategoryUnlock` (Detail: `higher_spell_ranks`). Bog resin, tapped from the Sunken Reach's
own tap line, becomes the binding agent for the study's higher-rank scroll and spell work. A silkqueen's
fang, ground fine, is the other new ingredient here: strong enough, Sera has found, to bind a scroll's
casting words together as tightly as the spider's own web binds its prey.

**Tier 3: Rare spells + research tools.**

| Item id | Quantity |
|---|---|
| Gold | 1400 |
| fungal_core | 1 |
| spore_pod | 20 |
| serpent_scale | 20 |
| spirit_dust | 15 |
| wisp_ember | 5 |

*Effect:* `CategoryUnlock` (Detail: `rare_spells_research_tools`). The fungal core, taken from the
Bloomcap or the Rootmind, is the reagent the study needs to research its rarest spells, the closest the
biome's fungal intelligence comes to a magical library of its own. A marsh wisp's captured ember
supplies the light the study's rarest research needs, the same glow that leads travelers astray turned
instead toward answering a spell's own question.

### Training Yard

The Training Yard is drill and discipline: Aldric's proficiency and feat training, growing into
archetype dedications and, at its capstone, respec and later dedications.

**Commission prerequisite:** Aldric arrives (three buildings have been constructed at the outpost).

**Construction bundle**

| Item id | Quantity |
|---|---|
| Gold | 220 |
| rat_pelt | 25 |
| deserter_badge | 20 |
| wood | 15 |

**Tiers**

**Tier 1: Proficiency and feat training.** No upgrade bundle (reached at commission). *Effect:*
`CategoryUnlock` (Detail: `proficiency_feat_training`).

**Tier 2: Dedications.**

| Item id | Quantity |
|---|---|
| Gold | 450 |
| nest_matriarch_tail | 1 |
| deserter_badge | 25 |
| rat_pelt | 25 |
| leather | 12 |
| amber_core | 1 |

*Effect:* `CategoryUnlock` (Detail: `dedications`). Unlocks the archetype dedications the engine
currently supports: Marshal, Medic, Bastion, Archer, and Dual-Weapon Warrior. An Ambercore's hardened
shell, broken down and studied, has taught the yard something about standing firm under sustained
pressure, useful for the Bastion dedication in particular.

**Tier 3: Respec + later dedications.**

| Item id | Quantity |
|---|---|
| Gold | 1300 |
| mudclaw_hide | 25 |
| serpent_scale | 20 |
| nest_matriarch_tail | 1 |
| iron_ingot | 18 |
| sovereign_hide | 1 |

*Effect:* `CategoryUnlock` (Detail: `respec_later_dedications`). Lets a squad member retrain their feat
choices, and opens whatever later dedications come online as the engine's feature-class support grows.
A Bog Sovereign's hide, thick enough to turn a spear, is added proof here too: the sort of resilience
the yard's later dedications are built to teach.

### Apothecary

The Apothecary is alchemy and reagents: Spore's potions, elixirs, and (per the migration below)
antidotes, growing into talisman crafting and reagent refining, then rare consumables at its capstone.

**Commission prerequisite:** Spore arrives (the Elderwood biome is explored; requires the Elderwood
open — the dire wolf slain, per the 2026-07-16 revision).

**Construction bundle**

| Item id | Quantity |
|---|---|
| Gold | 190 |
| herb | 20 |
| berries | 15 |
| wood | 100 |

**Tiers**

**Tier 1: Potions, elixirs, and antidotes.** No upgrade bundle (reached at commission). *Effect:*
`CategoryUnlock` (Detail: `potions_elixirs_antidotes`). **Migration note:** this tier absorbs the
antidote and tonic category that shipped at Infirmary tier 3 (see section 6). This tier is also where
the minor healing potion, guardian elixir, and antidote finally get a `Recipes.cs` entry; the items
already exist as `Consumables.cs` definitions with no crafting recipe behind them.

**Tier 2: Talismans + reagent refining.**

| Item id | Quantity |
|---|---|
| Gold | 350 |
| tincture | 15 |
| bitter_root | 20 |
| marsh_leech | 15 |

*Effect:* `CategoryUnlock` (Detail: `talismans_reagent_refining`). Unlocks talisman crafting and the
reagent-refining station that turns nightcap mushroom into arcane essence and drowned bone plus bog
moss into spirit dust.

**Tier 3: Rare consumables.**

| Item id | Quantity |
|---|---|
| Gold | 1300 |
| venom_sac | 1 |
| spore_pod | 20 |
| bog_moss | 25 |
| nightcap_mushroom | 15 |

*Effect:* `CategoryUnlock` (Detail: `rare_consumables`). The Apothecary's rarest tier of potions and
elixirs, built from a boss-tier venom sac alongside the Sunken Reach's own fungal and bog-grown
reagents.

### Tavern

The Tavern is hearth and provisions: Fenwick's day-long meal buffs, growing into a tavern common room
and, at its capstone, boarding rooms and feasts. Fenwick is present at the outpost from day one, and he
starts cooking as soon as the Tavern is commissioned.

**Commission prerequisite:** None, commissionable from day one. Along with the Farmhouse, the Tavern is
one of the two directed early builds the tutorial points the player at first (see `design/tutorial.md`).

**Construction bundle**

| Item id | Quantity |
|---|---|
| Gold | 70 |
| wood | 90 |
| stone | 60 |
| herb | 15 |

**Tiers**

**Tier 1: Mess hall (meals).** No upgrade bundle (reached at commission). *Effect:* `CategoryUnlock`
(Detail: `meals`). The day-long meal buffs (hearty stew, herb tonic, travel ration, battle draught, guard
ration) are cookable here.

**Tier 2: Tavern common room (performances).**

| Item id | Quantity |
|---|---|
| Gold | 300 |
| mead | 15 |
| egg | 25 |
| wild_mushroom | 20 |
| log_mushroom | 15 |

*Effect:* `Performances`. The common room's stage exists and morale performances become possible. This
tier is also Wynn's arrival trigger: reaching it is what keeps him at the outpost past his first
evening.

**Tier 3: Boarding rooms + feasts.**

| Item id | Quantity |
|---|---|
| Gold | 1200 |
| winter_squash | 25 |
| hearth_root | 25 |
| frost_pike | 10 |
| smoked_fish | 18 |

*Effect:* `Boarding` (Magnitude 1) plus `CategoryUnlock` (Detail: `feasts`). Boarding rooms open, and
feast-tier meals become cookable. This tier is Hilde's arrival trigger as townsfolk: she rents a room
here once it exists, though her PC-reveal still runs on the hearts 2-4 event in her own file.

### Farmhouse

The Farmhouse is the homestead: tillable land, growing through a coop and a barn into the greenhouse
that finally removes the season restriction entirely. The player is present at the outpost from day one
and works the Farmhouse as soon as it is commissioned, typically among the outpost's first builds
alongside the Trading Post and Tavern.

**Commission prerequisite:** None, commissionable from day one.

**Construction bundle**

| Item id | Quantity |
|---|---|
| Gold | 90 |
| wood | 120 |
| stone | 90 |

**Tiers**

**Tier 1: Tillable zone 1.** No upgrade bundle (reached at commission). *Effect:* `FarmPlots` (Magnitude 2).
Opens the Spring and Summer staples: turnip, potato, wheat, tomato, carrot.

**Tier 2: Zone 2 + coop.**

| Item id | Quantity |
|---|---|
| Gold | 400 |
| turnip | 25 |
| wheat | 25 |
| wood | 200 |

*Effect:* `FarmPlots` (Magnitude 2, additional) plus `Husbandry` (Magnitude 1). Zone 2 makes a practical
Fall and Winter crop roster possible (winter squash, hearth root, frost kale) without giving up the
Spring/Summer harvest, and the coop starts yielding eggs and feathers daily, alongside the cultivated
mushroom log. This tier, combined with a territory-expansion milestone, is Grub's arrival trigger.

**Tier 3: Barn + auto-water.**

| Item id | Quantity |
|---|---|
| Gold | 450 |
| carrot | 25 |
| frost_kale | 25 |
| marsh_reed | 20 |
| beast_hide | 15 |

*Effect:* `Husbandry` (Magnitude 2) plus `WateringAutomation`. The barn starts yielding milk, cream, and
periodic wool, and the beehive comes online alongside it. Auto-watering covers both farm zones, cutting
the daily upkeep the player has to spend on crops.

**Tier 4: Greenhouse.**

| Item id | Quantity |
|---|---|
| Gold | 2500 |
| plank | 350 |
| cloth | 18 |
| cheese | 20 |
| honey | 20 |
| butter | 20 |

*Effect:* `Greenhouse`. Removes the season restriction entirely: any crop can be planted in any season.
Winter-hardy crops already grow outdoors once Farmhouse tier 2 turns the season, so the greenhouse is a
convenience capstone rather than the gate on the base Winter roster.

### Watchtower

The Watchtower is scouting and the frontier: Thistle's territory reveal, growing into encounter
previews and, at its capstone, fast travel.

**Commission prerequisite:** Thistle arrives (the far-forest campsite zone, deep in the Elderwood, is
discovered; requires the Elderwood open — the dire wolf slain, per the 2026-07-16 revision, not Command
Post tier 2).

**Construction bundle**

| Item id | Quantity |
|---|---|
| Gold | 350 |
| deserter_badge | 25 |
| rat_pelt | 20 |
| feather | 15 |
| fey_charm | 5 |

**Tiers**

**Tier 1: Territory reveal.** No upgrade bundle (reached at commission). *Effect:* `CategoryUnlock`
(Detail: `territory_reveal`). Unexplored parts of a territory's map reveal themselves from the tower.

**Tier 2: Encounter previews + ambush.**

| Item id | Quantity |
|---|---|
| Gold | 400 |
| deserter_badge | 25 |
| mudclaw_hide | 25 |
| wood | 15 |
| hollow_crown | 1 |

*Effect:* `CategoryUnlock` (Detail: `encounter_preview_ambush`). Roamer encounters can be previewed
before the party commits to them, and the tower's vantage grants an ambush edge on the first round. The
Hollow King's own crown, taken from the hedge folk, is part of what makes the preview work: nothing
sees through a trick like something that has spent centuries pulling them.

**Tier 3: Fast travel.**

| Item id | Quantity |
|---|---|
| Gold | 1500 |
| hardwood | 15 |
| bogwood | 15 |
| deserter_badge | 25 |
| mudclaw_hide | 20 |

*Effect:* `FastTravel`. The tower's fast-travel service comes online, letting the squad move directly
between the outpost and any previously reached territory marker. Its waypoint posts are built partly
from bogwood driven into the Sunken Reach's own paths, timber dense enough to survive standing in the
bog year-round, alongside the Elderwood hardwood the rest of the network already uses.

### Reliquary

The Reliquary is Hazel's collection and identification of everything the party has fought and found,
growing into bestiary combat intel and, at its capstone, relic-display buffs for the whole outpost.

**Commission prerequisite:** Hazel arrives (the party has collected a proposed 8 monster trophies or
rare drops, lifetime count; see `characters.md` for the reasoning behind the number).

**Construction bundle**

| Item id | Quantity |
|---|---|
| Gold | 380 |
| goblin_fang | 25 |
| deserter_badge | 25 |
| ward_salt | 12 |

**Tiers**

**Tier 1: Collection + identification.** No upgrade bundle (reached at commission). *Effect:*
`CategoryUnlock` (Detail: `trophy_collection_identification`). Hazel begins cataloguing and identifying
whatever trophies and rare drops the party brings her.

**Tier 2: Bestiary combat intel.**

| Item id | Quantity |
|---|---|
| Gold | 450 |
| drowned_bone | 25 |
| rat_pelt | 25 |
| cut_stone | 15 |

*Effect:* `CategoryUnlock` (Detail: `bestiary_combat_intel`). The catalogue becomes a bestiary the party
can consult before an expedition, previewing a creature family's common drops and its known
weaknesses.

**Tier 3: Relic-display outpost buffs.**

| Item id | Quantity |
|---|---|
| Gold | 1600 |
| reaver_tooth | 1 |
| shadow_gar | 1 |
| nest_matriarch_tail | 1 |
| deserter_signet | 1 |
| heartwood_shard | 1 |
| amber_core | 1 |
| hollow_crown | 1 |
| silkqueen_fang | 1 |
| grovefather_knuckle | 1 |
| sovereign_hide | 1 |
| drowning_lantern | 1 |
| spirit_dust | 18 |

*Effect:* `CategoryUnlock` (Detail: `relic_display_buffs`). Displaying a completed set of relics grants
the outpost a passive buff. This tier deliberately runs lighter on raw material count than a typical
tier-3 bundle: it is dominated by trophies rather than bulk commons, since the Reliquary's whole purpose
is to want the rarest items in the game rather than the most plentiful ones. This tier now asks for one
unit of every trophy the padded bestiary produces, eleven trophies in total (the five original families'
proof plus the six new families' own), which is exactly the completionist's-shelf feeling the
Reliquary's whole design is going for.

### Fishing Dock (new building)

The Fishing Dock is the newest building in the roster: rod fishing on the Verdant Fringe's pond and
river, growing into trap fishing and the deeper waters of both the Elderwood and the Sunken Reach. No
character is attached to it yet; it is a flagged future-character hook.

**Commission prerequisite:** None beyond outpost progress.

**Construction bundle**

| Item id | Quantity |
|---|---|
| Gold | 110 |
| plank | 90 |
| cut_stone | 60 |

**Tiers**

**Tier 1: Rod fishing.** No upgrade bundle (reached at commission). *Effect:* `Fishing` (Magnitude 1).
Opens the Verdant Fringe's pond and river: river minnow and stream trout.

**Tier 2: Traps + deeper waters.**

| Item id | Quantity |
|---|---|
| Gold | 300 |
| plank | 120 |
| cloth | 12 |
| cut_stone | 100 |
| spider_silk | 3 |

*Effect:* `Fishing` (Magnitude 2). Trap fishing comes online, and the dock's reach extends into deeper
water on both fronts: the Elderwood's shaded pools (lake bass, and, in Winter, frost pike) and the
Sunken Reach's murk waters (murk catfish, bog eel, silt carp, shadow gar, and marsh clam, the last two
caught by trap, not rod). Reaching either territory's fish still requires that territory's own Command
Post unlock; the Fishing Dock's own tier only gates the fishing technique, not the biome underneath it.
The trap nets themselves are woven partly from canopy spider silk gathered in the Elderwood, stronger
and lighter than cloth alone.

## 4. Bundle pricing rules

This document runs on the framework brief's revised scale doctrine (2026-07-14): full Stardew scale,
gold plus materials, the Stardew carpenter model. The old bands (2 to 3 line items totaling 10 to 20
units) were tuned to a Bulk carry cap that no longer applies now that raw building commons are Light
Bulk (see `materials.md`'s node-yield section) and a focused gathering day returns 150 to 300 units.
Every bundle above follows the revised pricing bands instead:

- **Every bundle, construction and upgrade alike, now carries a Gold cost**, shown as a `Gold` row at
  the top of its table, paid in full alongside the materials when the bundle completes. This is net new
  against the shipped economy, which charged materials only.
- **Raw building commons** (wood, stone, and, where a building uses them as its foundation material,
  plank or cut_stone) run **100 to 350 units** in a construction bundle, **150 to 400 units** in a mid
  upgrade tier, and **300 to 550 units** in a capstone tier. Gold for the same tier runs **50 to 150g**
  for an early construction, **150 to 400g** for a mid-game construction, **100 to 800g** for a mid
  upgrade tier, and **1,000 to 2,500g** for a capstone.
- **Monster-part counts in the seven combat-facing buildings** (see below) scale to their own middle
  band, **30 to 80 units** per bundle, at construction and at every mid tier alike: parts drop a
  handful per fight, not a dozen per gathering node, so they never chase the raw-commons band.
- **Crop, forage, fish, and husbandry line items** run **10 to 30 units** per line, regardless of tier.
- **Refined and special goods** (ingots, leather, cloth, tincture, spun yarn, mead, smoked fish, reagents,
  and any raw-commons item used as a bundle's minor secondary ingredient rather than its foundation)
  stay **small, 3 to 20 units**.
- **Trophies** stay **1 to 5 units**, almost always 1 per line, since a boss guarantees only 2 to 3
  units of its own trophy per kill.

Two documented exceptions to the capstone material band exist, both deliberate and both kept from the
prior draft: Chapel tier 2 (the building's own top tier, since its ladder is pinned at only 2 tiers) and
Reliquary tier 3 both run lighter on total material units than a typical capstone, because both are
dominated by 1-unit trophies rather than bulk commons. Their Gold cost still reflects the tier's real
weight even though their material count stays light: this design treats Gold and material bulk as
independent dials, not a single combined price. This mirrors the combat pillar's own note that elite and
boss trophies gate top tiers.

The seven combat-facing buildings (Smithy, Training Yard, Chapel, Arcane Study, Watchtower, Reliquary,
Command Post) draw the majority of every one of their bundle's line items from monster parts and
trophies, including their construction bundles. This is possible even at commission because their
"commons" are the common drops (goblin fang, rat pelt, deserter badge) available from the very first
forest encounters, the same fights that, for several of these buildings, produce the arriving character
in the first place. Any raw-commons item that still appears in one of these bundles (wood, coal,
copper_ingot, hardwood, cut_stone) plays a minor cross-route role rather than the bundle's foundation,
so it stays in the small refined/special band rather than chasing the 100-plus raw-commons band; a
Smithy or a Watchtower is not, thematically, a lumber project the way a Farmhouse or a Trading Post is.
(**2026-07-16 exception:** the Smithy's *construction* bundle is the one place this rule now bends — the
early-game rework rebuilt it as a wood+hardwood mix, wood 90 / hardwood 40 / goblin_fang 25, because the
new flow raises the forge only after the Elderwood opens rather than from the first forest fights, so its
foundation is timber, not fangs. Its four upgrade tiers keep the majority-monster-parts character.)
The remaining six buildings (Trading Post, Tavern, Farmhouse, Infirmary, Apothecary, Fishing Dock) draw
mostly from their own thematic family, with monster parts appearing only as an occasional 1 to 2 item
cross-route ingredient (Apothecary's spore pod and venom sac, for instance), scaled modestly rather than
to the combat-facing 30-to-80 band since they are not that family's primary demand.

### Sink coverage appendix

Every catalog item from `materials.md` is listed below with where it lands: the bundle (or bundles) it
appears in, or the recipe, meal, rune, or gift mechanic that already sinks it without needing a bundle.

| Item id | Sink |
|---|---|
| turnip_seed | Trading Post stock (planting item, not a bundle ingredient) |
| turnip | Farmhouse tier 2 |
| potato_seed | Trading Post stock |
| potato | Recipe (cook_hearty_stew, cook_guard_ration) |
| wheat_seed | Trading Post stock |
| wheat | Farmhouse tier 2; recipe (cook_hearty_stew, cook_travel_ration) |
| tomato_seed | Trading Post stock |
| tomato | Recipe (cook_battle_draught) |
| carrot_seed | Trading Post stock |
| carrot | Farmhouse tier 3 |
| winter_squash_seed | Trading Post stock |
| winter_squash | Tavern tier 3 |
| hearth_root_seed | Trading Post stock |
| hearth_root | Tavern tier 3 |
| frost_kale_seed | Trading Post stock |
| frost_kale | Farmhouse tier 3 |
| herb | Recipe (craft_tincture, cook_herb_tonic, cook_battle_draught); also Infirmary construction/tier 2/tier 3, Apothecary construction, Tavern construction |
| berries | Recipe (cook_herb_tonic, cook_travel_ration, cook_guard_ration); also Infirmary tier 2, Apothecary construction |
| fiber | Recipe (craft_cloth) |
| wild_mushroom | Tavern tier 2 |
| forest_root | Trading Post tier 2 |
| bog_moss | Apothecary tier 3; recipe (craft_spirit_dust input) |
| marsh_reed | Farmhouse tier 3 |
| bitter_root | Apothecary tier 2 |
| nightcap_mushroom | Apothecary tier 3; recipe (Apothecary tier 2 reagent refining into arcane_essence) |
| wood | Recipe (craft_plank); construction bundles for Smithy, Training Yard, Command Post tier 2, Apothecary, Watchtower tier 2, Trading Post construction, Tavern construction, Farmhouse construction |
| stone | Recipe (craft_cut_stone); also Trading Post construction, Tavern construction, Farmhouse construction |
| copper_ore | Recipe (craft_copper_ingot) |
| hardwood | Trading Post construction, Smithy construction, Infirmary construction (all added 2026-07-16), Watchtower tier 3, Command Post tier 3 |
| coal | Smithy tier 2 |
| iron_ore | Recipe (craft_iron_ingot) |
| bogwood | Watchtower tier 3, Command Post tier 4, Smithy tier 4 |
| river_minnow | Recipe (craft_smoked_fish) |
| stream_trout | Recipe (craft_smoked_fish) |
| lake_bass | Recipe (craft_smoked_fish) |
| frost_pike | Tavern tier 3 |
| murk_catfish | Recipe (craft_smoked_fish) |
| bog_eel | Recipe (craft_smoked_fish) |
| silt_carp | Trading Post tier 2 |
| shadow_gar | Reliquary tier 3 |
| marsh_clam | Trading Post tier 2 |
| egg | Tavern tier 2 |
| feather | Watchtower construction |
| milk | Recipe (craft_cheese, craft_butter) |
| wool | Recipe (craft_spun_yarn) |
| cream | Recipe (craft_butter) |
| honey | Farmhouse tier 4; recipe (craft_mead) |
| tree_sap | Trading Post tier 2 |
| bog_resin | Arcane Study tier 2 |
| log_mushroom | Tavern tier 2 |
| goblin_fang | Smithy construction, Chapel construction, Arcane Study construction/tier 2, Reliquary construction, Command Post tier 2 |
| rat_pelt | Smithy construction, Chapel construction, Training Yard construction/tier 2, Arcane Study construction, Watchtower construction, Reliquary tier 2 |
| beast_hide | Farmhouse tier 3, Smithy tier 2, Infirmary tier 2, Command Post tier 3; recipe (craft_leather) |
| warden_bark | Command Post tier 3 |
| goblin_scrap | Smithy tier 2 |
| deserter_badge | Training Yard construction/tier 2, Watchtower construction/tier 2/tier 3, Reliquary construction, Command Post tier 2 |
| mudclaw_hide | Smithy tier 3, Watchtower tier 2/tier 3, Training Yard tier 3 |
| serpent_scale | Smithy tier 3, Arcane Study tier 2/tier 3, Training Yard tier 3 |
| spore_pod | Apothecary tier 3, Arcane Study tier 3 |
| drowned_bone | Reliquary tier 2; recipe (craft_spirit_dust input) |
| marsh_leech | Apothecary tier 2 |
| sap_gland | Chapel construction |
| fey_charm | Watchtower construction |
| spider_silk | Fishing Dock tier 2 |
| thornback_hide | Infirmary tier 2 |
| swamp_drake_scale | Smithy tier 3 |
| wisp_ember | Arcane Study tier 3 |
| goblin_totem | Smithy tier 3/tier 4, Command Post tier 4 |
| nest_matriarch_tail | Training Yard tier 2/tier 3, Reliquary tier 3 |
| alpha_pelt | Chapel tier 2, Smithy tier 4 |
| heartwood_shard | Reliquary tier 3 |
| deserter_signet | Reliquary tier 3 |
| reaver_tooth | Reliquary tier 3, Smithy tier 4 |
| venom_sac | Apothecary tier 3, Command Post tier 4 |
| fungal_core | Arcane Study tier 3 |
| hollow_locket | Chapel tier 2, Command Post tier 4 |
| amber_core | Training Yard tier 2, Reliquary tier 3 |
| hollow_crown | Watchtower tier 2, Reliquary tier 3 |
| silkqueen_fang | Arcane Study tier 2, Reliquary tier 3 |
| grovefather_knuckle | Smithy tier 3, Reliquary tier 3 |
| sovereign_hide | Training Yard tier 3, Reliquary tier 3 |
| drowning_lantern | Chapel tier 2, Reliquary tier 3 |
| plank | Fishing Dock construction/tier 2, Farmhouse tier 4 |
| cut_stone | Fishing Dock construction/tier 2, Reliquary tier 2 |
| copper_ingot | Arcane Study construction; system sink (Smithy weapon MetalCost) |
| leather | Training Yard tier 2, Infirmary tier 3 |
| tincture | Apothecary tier 2, Infirmary tier 3 |
| cloth | Chapel construction, Fishing Dock tier 2, Farmhouse tier 4 |
| iron_ingot | Command Post tier 4, Training Yard tier 3, Smithy tier 3/tier 4; system sink (Smithy tier 2 weapon upgrades) |
| cheese | Farmhouse tier 4 |
| butter | Farmhouse tier 4 |
| spun_yarn | Infirmary tier 2 |
| mead | Tavern tier 2 |
| smoked_fish | Tavern tier 3 |
| arcane_essence | System sink (Smithy rune reagent, RunePrices.ReagentItemId) |
| ward_salt | Reliquary construction, Chapel tier 2, Command Post tier 4 |
| spirit_dust | Reliquary tier 3, Arcane Study tier 3 |
| hearty_stew, herb_tonic, travel_ration, battle_draught, guard_ration | Meal recipes (eaten for a day-long buff) |
| minor_healing_potion, guardian_elixir, antidote | Consumable definitions (Apothecary tier 1 recipe, see section 3) |

## 5. Cross-links

- **Trading Post stock widens with Smithy tier.** This existing mechanic is unchanged: as the Smithy's
  tier rises, the Trading Post's shelf gains access to goods keyed to that tier, in addition to the
  widening its own tier 2 grants.
- **Tavern tiers gate two characters.** Reaching tier 2 (the tavern common room) is Wynn's arrival
  trigger. Reaching tier 3 (boarding rooms) is Hilde's arrival trigger as townsfolk, though her
  PC-reveal still runs on the hearts 2-4 event in her own file.
- **Farmhouse tiers gate the husbandry route.** The coop (tier 2) and the barn (tier 3) are what open
  eggs, feathers, milk, cream, wool, and honey; nothing in the husbandry family is available before its
  gating tier.
- **Fishing Dock tiers gate the entire fish family.** Tier 1 opens Verdant Fringe rod fishing; tier 2
  opens trap fishing and every Elderwood and Sunken Reach fish, gated jointly with each territory's own
  Command Post unlock.
- **The dire wolf's death gates the Elderwood** (2026-07-16 revision; formerly Command Post tier 2).
  Every Elderwood-sourced item in the catalog — hardwood, coal, forage, fish, tap-line goods, and both
  of its creature families — sits behind the `dire_wolf_slain` flag (wired as the `elderwood` territory's
  `UnlockFlagId`). The dire wolf guards the passage from the near forest into the deep Elderwood.
- **Command Post tier 3 gates the Sunken Reach.** Every swamp-sourced item in the catalog, forage,
  ore, tap-line goods, fish, and every Sunken Reach creature family, sits behind this unlock, and it can
  only be paid for with Elderwood materials and moderate-family parts, since the Sunken Reach itself is
  not open yet when this bundle is filled.

## 6. Migration table

**As-implemented (2026-07-16).** All 13 building definitions now ship in `Buildings.cs` matching section 3
of this document — its header comment names this doc as "the source of truth for every bundle, Gold cost,
and effect." This table is therefore history, not a proposal: it records how each definition reached its
current shipped form, from the original four placeholder definitions, through the 2026-07-14 full-Stardew
scale doctrine, to the 2026-07-16 early-game progression rework. The **"Shipped (`Buildings.cs`)"** column
below means the ORIGINAL placeholder code that predated this design; the code today matches "This design."
The 2026-07-16 rework changed four rows (Trading Post, Smithy, Infirmary, Command Post) after the code had
already caught up, so those four are once again ahead of code until workstream B mirrors them.

| Building | Shipped (`Buildings.cs`) | This design | What changed |
|---|---|---|---|
| Farmhouse | 3 tiers: T1 farm plots, T2 farm plots + watering, T3 greenhouse | 4 tiers: T1 zone 1, T2 zone 2 + coop, T3 barn + auto-water, T4 greenhouse | Reshuffled from 3 to 4 tiers. The coop is inserted at tier 2 and the barn at tier 3; watering automation moves from the old tier 2 to the new tier 3, alongside the barn. Greenhouse shifts from tier 3 to tier 4. |
| Smithy | 3 tiers: T1 base catalog, T2 improved catalog, T3 advanced catalog + property runes | 4 tiers: T1 base catalog + fundamental runes, T2 improved catalog + armor, T3 advanced catalog + property runes, T4 trophy-forged/masterwork | Tiers 1 through 3 keep their shipped substance (tier 3's "advanced catalog + property runes" already matches). A new tier 4 is appended. **Code note:** the `SmithyTier` enum in `Smithy.cs` (`Base`, `Improved`, `Advanced`) needs a fourth value (for example `Masterwork`) to gate the new tier's catalog entries; `BuildingEffectType.SmithyTier`'s `Magnitude` field needs no enum change since it is already a plain int. **2026-07-16 rework:** construction bundle rebuilt from all-monster-parts (goblin_fang 25 / rat_pelt 20 / wood 15) to a wood+hardwood mix (wood 90 / hardwood 40 / goblin_fang 25); `RequiredFlagId` changes from `arkus_arrived` to `arkus_awake`. |
| Infirmary | 3 tiers: T1 rest healing, T2 faster recovery, T3 antidotes + tonics category | 3 tiers: T1 rest healing, T2 faster recovery + affliction treatment, T3 advanced care | Tier count unchanged. Tier 3's effect changes from a `CategoryUnlock` (antidotes + tonics) to a third `InfirmaryHealing` step (advanced care). The antidote and tonic category moves to Apothecary tier 1. **2026-07-16 rework:** construction bundle gains a hardwood line (wood 120 / hardwood 30 / herb 20); `RequiredFlagId` changes from `josen_arrived` to `arkus_awake` (Arkus's wounds prompt the sickbed; Josen now arrives 1-3 days *after* it is built via random event, no longer gating it). |
| Apothecary | Not defined in shipped code | 3 tiers, new definition | Net-new. Tier 1 absorbs the antidote and tonic category migrated from Infirmary tier 3. |
| Trading Post | 2 tiers: T1 general store, T2 expanded store, with a construction bundle (wood 6, stone 4) | 2 tiers, same effects, construction bundle rescaled + hardwood-gated | Tier count and effects unchanged. Rescaled to full Stardew scale (was wood 6 / stone 4; then wood 90 / stone 60 + 60g). **2026-07-16 rework:** the construction bundle gains a 30-hardwood line (wood 90 / stone 60 / hardwood 30, 60g unchanged). No flag gate — the building is still offered from day one — but the hardwood cannot be gathered until the Elderwood opens (dire wolf slain), so the Trading Post is now the outpost's first Elderwood-gated build rather than a day-one one. |
| Command Post | Not defined in shipped code | 4 tiers, new definition, no construction bundle | Net-new. Tier 1 is the start state (no bundle, upgrades-only ladder). **2026-07-16 rework:** tier 2 LOSES its `BiomeUnlock` (`elderwood`) effect — the Elderwood is now unlocked by the `dire_wolf_slain` flag (an `UnlockFlagId` on the `elderwood` territory definition), not by this ladder. Tier 2 keeps its bundle as quest 12's "the outpost grows" milestone but no longer opens a biome (a replacement declarative effect is an open question for the systems pass). Tier 3's `BiomeUnlock` (`sunken_reach`) is unchanged, as is tier 4's `Resurrection`. |
| Chapel | Not defined in shipped code | 2 tiers, new definition | Net-new. |
| Arcane Study | Not defined in shipped code | 3 tiers, new definition | Net-new. |
| Training Yard | Not defined in shipped code | 3 tiers, new definition | Net-new. |
| Tavern | Not defined in shipped code | 3 tiers, new definition, with a proposed construction bundle | Net-new. The Tavern is commissionable from day one with no prerequisite (Fenwick is present from day one and starts cooking once it is commissioned), but it is not a start-state building: this design proposes a construction bundle (wood 90, stone 60, herb 15, plus a 70g Gold cost) at the same full-Stardew-scale band as Trading Post's and Farmhouse's construction bundles. |
| Watchtower | Not defined in shipped code | 3 tiers, new definition | Net-new. |
| Reliquary | Not defined in shipped code | 3 tiers, new definition | Net-new. |
| Fishing Dock | Not defined in shipped code | 2 tiers, new definition | Net-new building; no character attached yet. |

Nine building definitions are net-new against the shipped four (Farmhouse, Smithy, Infirmary, Trading
Post): Command Post, Chapel, Arcane Study, Training Yard, Apothecary, Tavern, Watchtower, Reliquary,
and Fishing Dock.

Three further migration items follow from the revised scale doctrine (2026-07-14) and apply on top of
everything above:

- **Every bundle quantity in this document supersedes the shipped `Buildings.cs` quantities, not just
  the four buildings that had shipped definitions.** The prior draft of this document matched or stayed
  close to shipped scale for Farmhouse, Smithy, Infirmary, and Trading Post; this revision does not.
  Every construction and upgrade bundle in section 3, including those four, is now sized to the 100-plus
  full-Stardew-scale bands in section 4, so the code pass that implements this document should treat
  every quantity here as authoritative and every shipped quantity (`Buildings.cs`'s existing four
  definitions) as superseded, not as a starting point to extend.
- **A Gold cost field is a net-new requirement on every bundle.** `Buildings.cs`'s existing bundle
  structure charges materials only; the code pass needs a Gold field added to whatever type represents a
  construction or upgrade bundle, populated from this document's `Gold` table rows.
- **Wood, stone, copper_ore, coal, iron_ore, and hardwood move to Light Bulk (0.1).** This supersedes
  the shipped Bulk values on wood and stone in `Items.cs` (currently near 1.0 each) and sets the same
  Light value for the ore and hardwood ids being added. Refined goods, gear, and trophies are unaffected
  and keep their existing (heavier) Bulk values. See `materials.md`'s node-yield section for the full
  reasoning.

Every `BuildingEffectType` value this design calls for already exists in the shipped enum:
`BiomeUnlock` (Command Post tier 3, `sunken_reach`; the Elderwood unlock moved off Command Post tier 2 to
the `dire_wolf_slain` territory `UnlockFlagId` in the 2026-07-16 rework), `Boarding` (Tavern tier 3),
`Performances` (Tavern tier 2), `FastTravel` (Watchtower tier 3), `Resurrection` (Command Post tier 4),
`Husbandry` (Farmhouse tiers 2 and 3), and `Fishing` (Fishing Dock tiers 1 and 2). Several tiers
(Watchtower tiers 1 and 2, Reliquary tiers 1 through 3, Apothecary all tiers, Arcane Study all tiers,
Training Yard all tiers, Chapel tier 1, and the general/expanded store tiers) use the generic
`CategoryUnlock` with a descriptive `Detail` string, the same pattern the shipped Trading Post already
uses for `general_store` and `expanded_store`. No new enum values are required beyond the `SmithyTier`
note above.

## Judgment calls

- **One start-state building, two directed day-one commissions, and a hardwood-gated third.** The
  framework brief pins only the Command Post as the no-construction-bundle start state: tier 1 exists
  before play begins, with no bundle and an upgrades-only ladder. The **Tavern and Farmhouse** are the two
  directed day-one commissions — cheap Verdant Fringe bundles the tutorial points the player at first. The
  **Trading Post** is offered at the planning table from day one too, with no flag gate, but since the
  2026-07-16 rework its construction bundle includes 30 Elderwood hardwood, so it cannot be raised until
  the Elderwood opens (dire wolf slain); it is the first Elderwood-gated build rather than a day-one one.
  Under the 2026-07-14 scale doctrine, Farmhouse and Trading Post no longer keep their shipped bundles
  from `Buildings.cs` (wood 8 / stone 6, and wood 6 / stone 4, respectively): both are rescaled to the
  full-Stardew-scale construction band. Tavern had no shipped definition; its bundle is wood 90 / stone 60
  / herb 15, 70g Gold, at the same scale.
- **2-tier buildings' only upgrade tier is priced as a mid tier, not a capstone.** Trading Post tier 2,
  Chapel tier 2, and Fishing Dock tier 2 are each the top of a ladder pinned at only 2 tiers by the
  framework brief. Rather than pricing them at the capstone band (300-550 commons, 1,000-2,500g), this
  design treats them as mid upgrade tiers (150-400 commons where a raw-commons line applies, 100-800g),
  consistent with how the prior draft already described Chapel tier 2 as running lighter than a nominal
  top tier. A 2-tier building is a smaller building by design; its one upgrade should read as
  meaningful, not as the same weight class as a Smithy masterwork tier or a Farmhouse greenhouse.
- **Combat-facing construction bundles use monster parts as "Verdant Fringe commons."** The pricing
  rule calls for construction bundles to draw on Verdant Fringe commons; for the seven combat-facing
  buildings, this reading includes the common monster drops (goblin fang, rat pelt, deserter badge)
  available from the outpost's very first fights, which keeps the majority-monster-parts rule true even
  at commission. Command Post tier 2 follows the same logic for an upgrade tier rather than a
  construction bundle: it is priced entirely from Verdant Fringe commons and easy-family parts because
  it is the unlock that opens the next territory up, so it cannot draw on anything from that territory
  itself. Command Post tier 3 repeats the same pattern one rung later, priced from Elderwood materials
  and moderate-family parts rather than Verdant Fringe ones, since the Elderwood is what tier 2 just
  opened and the Sunken Reach is what tier 3 is about to open.
- **Chapel tier 2 and Reliquary tier 3 run lighter on total units than their nominal band.** Both are
  documented exceptions in section 4: a 2-tier building's only upgrade tier, and a trophy-collection
  building's capstone, both end up trophy-dominated rather than bulk-commons-dominated by design.
- **Trophies and several common monster parts are reused across multiple buildings' bundles.** Named
  roamers respawn and bosses guarantee 2 to 3 units per kill, so a single creature family can supply
  more than one building's bundle over a full playthrough; the player chooses where each unit goes.
  `materials.md` itself lists multiple valid sinks for most trophies and several common parts, and this
  design treats that as intentional flexibility rather than a requirement to use every listed sink.
- **Seeds have no bundle sink.** All eight seed items (turnip_seed through frost_kale_seed) are
  Trading-Post-purchased planting items consumed by the planting action, not by a bundle, a recipe, a
  meal, a rune, or a gift. They do not strictly satisfy the sink-closure rule's letter, though they are
  fully sourced and sunk through an established mechanic. Flagged here rather than silently waived.
- **Command Post tier 3 is now the Sunken Reach unlock, replacing the earlier "expedition logistics"
  proposal outright.** The framework brief's 2026-07-14 revision to three biomes reassigns tier 3 to a
  second `BiomeUnlock` (the Sunken Reach) and retires the expedition-logistics `CategoryUnlock` this
  document previously proposed for that slot; nothing about multi-day expedition camping or the map
  overlay's milestone tracking survives into this revision. The tier's specific bundle quantities
  (beast_hide 25, warden_bark 20, hardwood 15, alongside the same 450 Gold the prior proposal already
  used) are this document's own proposal, since the brief asks for tier 2 and tier 3 to be repriced
  sensibly rather than pinning exact numbers.
- **Root Wardens and the Elderwood are both proposals, not locked content.** `materials.md` proposes
  the Elderwood as the moderate biome's name and the Root Wardens as its second creature family; this
  document's Command Post tier 3 bundle and its cross-links section adopt both, and either name change
  in `materials.md` should be mirrored here.
- **Padded-bestiary bundle edits (2026-07-14).** `materials.md`'s six new creature families (Bramble
  Slicks, Hedge Folk, Canopy Spiders, Thornbacks, Swamp Drakes, Marsh Wisps) and `bogwood` all needed
  bundle sinks per the closure rule. Every new common part was woven into one existing bundle, either
  as a partial swap against a sibling item from the same era so the bundle's total magnitude holds
  exactly (Chapel construction's rat_pelt, Watchtower construction's rat_pelt, Fishing Dock tier 2's
  cloth, Infirmary tier 2's beast_hide, Smithy tier 3's mudclaw_hide, and Arcane Study tier 3's
  spore_pod each gave up a few units to their new sibling part) or as a small added line in a
  non-combat-facing building where the pricing rule already allows an occasional monster-part
  cross-route ingredient. Every new trophy landed as an added 1-unit line in a fitting existing tier
  (Training Yard tier 2, Watchtower tier 2, Arcane Study tier 2, Smithy tier 3, Training Yard tier 3,
  and Chapel tier 2), each nudging that tier's total by only a single unit, plus a guaranteed slot in
  Reliquary tier 3, which now asks for one of every trophy in the game. Bogwood's own three sinks
  (Watchtower tier 3, where it splits hardwood's old 30-unit line in half; Command Post tier 4 and
  Smithy tier 4, both small added lines) keep every capstone's material count in the same light,
  trophy-or-reagent-dominated character those tiers already had. No bundle's total magnitude moved
  outside its existing pricing band from any of these edits; see `pacing.md` for the season-by-season
  arithmetic confirming that.
