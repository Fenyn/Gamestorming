# Bulwark: Material Catalog

This document is the complete material catalog for Bulwark's economy: every gatherable, farmable,
craftable, and lootable item in the game, where it comes from, and where it goes. It implements the
`design/economy/economy_brief.md` framework contract (families, rarity bands, id conventions,
creature framework) as concrete content. This design supersedes `scripts/data/Items.cs` where the two
disagree. The code is a Phase-5 proving set; this catalog is the target state. A later code pass adds
the new ids here to `Items.cs` and its sibling data files (`Crops.cs`, `ResourceNodes.cs`,
`DropTables.cs`, `EncounterTables.cs`, `Recipes.cs`). No item id already shipped in code is renamed or
removed. The catalog totals **97 items** across the ten material families below, including this pass's
padded-bestiary expansion (six new creature families and their thirteen new items, `bogwood` among
them); see the padded-bestiary judgment-call entry near the end of this document for the accounting.

This catalog is built at full Stardew scale (revised 2026-07-14). Node yields, daily throughput, and
bulk conventions are covered in their own section below; nothing about the item list itself (ids,
families, rarity bands, or sell values) changes for the rescale, only how much a single harvest action
returns and how heavy the result is to carry.

This catalog now works from three biomes rather than two, a difficulty ladder the party climbs in
order: the Verdant Fringe (easy, the start territory), a moderate second territory, and the Sunken
Reach (dangerous). The swamp biome is **the Sunken Reach**, a name already adopted across the design:
where the Fringe is the tamed edge of the wilderness, the Reach is the wilderness that swallows things
whole. The moderate middle territory, the older and darker forest interior the Fringe frays into, is
proposed here as **the Elderwood**: if the Fringe is young growth still in reach of the outpost's axes,
the Elderwood is what that same forest becomes once nothing has thinned it in a lifetime. It is a
flagged proposal, not a locked decision; every other design doc should adopt or override it
consistently.

Each biome's bestiary is padded well past its old two-or-three-family roster: the Verdant Fringe now
carries five creature families, the Elderwood four, and the Sunken Reach six, fifteen families in all,
each with its own fiction, common encounters, elite roamer, boss, and drops. See the biome creature
family sections below for the full roster and the padded-bestiary judgment-call entry for why the
count runs higher than the framework brief's original target.

## Acquisition routes overview

### Farming
Tillable plots at the Farmhouse. Farmhouse T1 opens zone 1 (Spring and Summer staples). Farmhouse T2
opens zone 2, which is what makes a Fall and Winter crop roster practical without giving up the
Spring/Summer harvest. Winter-hardy crops grow outdoors once the season turns; they do not require the
Greenhouse. Farmhouse T4's greenhouse instead removes the season restriction entirely, letting any crop
be planted in any season, a convenience unlock rather than a gate.

### Foraging
Hand-tool gathering from the territories. Verdant Fringe foraging is available from day one. Elderwood
foraging opens once the Command Post reveals the Elderwood (T2). Sunken Reach foraging opens once the
Command Post reveals the Sunken Reach (T3). The deepest, rarest forage in each of the latter two biomes
(the ward-salt deposit in the Elderwood, the nightcap mushroom in the Sunken Reach) sits behind further
zone exploration within its biome, not a building tier.

### Mining
Pick-tool and Axe-tool harvesting from resource nodes in the territories. Stone and the shallow copper
vein are available in the Verdant Fringe from day one. Hardwood and coal are Elderwood deposits, gated
behind the Command Post's Elderwood unlock. Iron ore is a Sunken Reach deposit (bog iron), gated behind
the Command Post's Sunken Reach unlock alongside foraging. Bogwood, the Sunken Reach's own timber, is
gathered the same Axe-tool way wood and hardwood are elsewhere, from a drowned-tree stand node gated
behind that same Sunken Reach unlock: the swamp's drowned trees, waterlogged for years, cut into a
timber denser and harder than anything the Fringe or the Elderwood grows.

### Fishing (NEW)
The Fishing Dock building. T1 opens rod fishing on the Verdant Fringe's pond and river. T2 adds traps
and deeper waters, opening the Elderwood's shaded pools and the Sunken Reach's murk waters together
(both are "deeper" than the starter pond in their own way), including shellfish caught by trap rather
than rod. No character is attached to this building yet; it is a future-character hook.

### Animal husbandry (NEW)
Farmhouse outbuildings. The coop (Farmhouse T2) yields eggs and feathers daily. The barn (Farmhouse T3)
yields milk and cream daily and wool on a periodic shearing cycle.

### Apiary and tapping (NEW)
Passive daily producers that need no active harvest beyond a daily collection. The mushroom log sits at
the Farmhouse alongside the coop (T2). The beehive sits at the Farmhouse alongside the barn (T3). Tap
lines are different: they are placed directly in the territories rather than at the outpost, so a
Verdant Fringe tap line is available as soon as the zone is reached, and a Sunken Reach tap line opens
with the Command Post's Sunken Reach unlock.

### Combat drops
Every creature family in a territory rolls a loot table on defeat. Common encounters drop common
monster parts every time, at genre parity with the rest of the rescale: each defeated creature drops
1 to 3 units of its family's common part (drop tables roll a quantity band, not a flat 1), and a
common encounter defeats 3 to 5 creatures, so a single fight returns roughly 3 to 15 common parts. A
combat-engaged week runs 8 to 10 fights, which puts conservative common-part supply at roughly 250 to
400 units a season; `pacing.md` audits against the 250 low end. Elite named roamers drop a single unit
of that family's trophy; the family's boss guarantees two to three units of the same trophy. Trophies
stay rare and are untouched by the drop-band rescale. See the biome creature sections below for the
full roster. Content-pass implication: the shipped `DropTables.cs` quantities widen to MinQty 1 /
MaxQty 3 per creature, the combat-side parallel of the node-yield rescale.

### Crafting and refining
The CraftingSystem turns raw materials into refined goods and reagents at gated stations (smelter,
tanner, still, loom, kitchen), each granted by a building's CategoryUnlock effect. Two chains
(plank, cut stone) need no station at all. Refining reagents specifically (arcane essence, spirit
dust) is an Apothecary T2 privilege, per the building ladder.

### Trading Post purchase
Gold buys seeds and, once the Trading Post reaches T2 (and as the Smithy's tier rises), a widening
shelf of finished goods. It is a convenience and gap-filler, never the primary route for a bundle
material.

## Node yields, daily throughput, and bulk

Bulwark's gathering routes run at full Stardew scale: a single harvest action returns a double-digit
haul of raw material, node density is high, and most nodes respawn daily. This applies specifically to
wood, stone, and ore; forage and fish stay at Stardew's own per-catch scale, which is small by design.

**Wood and ore node yields.**

| Node | Tool | Yield per harvest |
|---|---|---|
| Fallen wood | Axe | 12-15 wood |
| Rock | Pick | 8-12 stone |
| Copper vein | Pick | 5-10 copper_ore |
| Elderwood tree stand | Axe | 8-12 hardwood |
| Elderwood coal seam | Pick | 5-10 coal |
| Bog-iron deposit | Pick | 5-10 iron_ore |
| Drowned-tree stand | Axe | 8-12 bogwood |

**Forage and fish yields.** These stay small and unchanged by the rescale: a foraged item (herb,
berries, wild_mushroom, and the rest of the forage family) yields 1 unit per hand-gathered catch, and a
fishing catch yields 1 fish. Density and respawn rate, not per-catch size, are what make a forage or
fishing route productive across a day.

**Daily throughput.** A party that spends a focused day on wood, stone, and ore gathering, working
several nodes across a territory, should come home with roughly 150 to 300 commons total. This is the
throughput figure every bundle size in `buildings.md` and every seasonal audit in `pacing.md` is built
against.

**Bulk and hauling.** Raw building commons (wood, stone, every ore: copper_ore, coal, iron_ore, and
hardwood) are Light Bulk (0.1 per unit), which is what makes a 150-300-unit gathering day physically
haulable in a single trip alongside the party's own gear. This supersedes the shipped Bulk values on
wood and stone in `Items.cs` (currently near 1.0 each); closing that gap is a migration item for the
eventual code pass, listed again in `buildings.md`'s migration table. Everything else keeps its
existing Bulk teeth: refined and crafted goods (plank, cut_stone, ingots, leather, cloth, and the rest
of the refined family), gear, and every trophy stay at their current, heavier Bulk weight. A
warehouse full of lumber is light to haul; a warehouse full of masterwork armor and boss trophies is
not, and that distinction is the point.

## Material families

### 1. Crops
Category: `Seed` for the planting item, `Crop` for the harvest. All entries are Farming route,
Farmhouse-gated as noted.

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| turnip_seed | Turnip Seeds | Seed | 0 | Farming (Farmhouse T1) | Verdant Fringe | Spring | Trading Post stock; plants turnip | existing |
| turnip | Turnip | Common | 3 | Farming (Farmhouse T1) | Verdant Fringe | Spring | Sale; Farmhouse bundles | existing |
| potato_seed | Potato Seeds | Seed | 0 | Farming (Farmhouse T1) | Verdant Fringe | Spring, Summer | Trading Post stock; plants potato | existing |
| potato | Potato | Common | 4 | Farming (Farmhouse T1) | Verdant Fringe | Spring, Summer | cook_hearty_stew; cook_guard_ration | existing |
| wheat_seed | Wheat Seeds | Seed | 0 | Farming (Farmhouse T1) | Verdant Fringe | Summer, Fall | Trading Post stock; plants wheat | existing |
| wheat | Wheat | Uncommon | 5 | Farming (Farmhouse T1) | Verdant Fringe | Summer, Fall | cook_hearty_stew; cook_travel_ration | existing |
| tomato_seed | Tomato Seeds | Seed | 0 | Farming (Farmhouse T1) | Verdant Fringe | Summer | Trading Post stock; plants tomato | existing |
| tomato | Tomato | Uncommon | 6 | Farming (Farmhouse T1, regrows) | Verdant Fringe | Summer | cook_battle_draught | existing |
| carrot_seed | Carrot Seeds | Seed | 0 | Farming (Farmhouse T1) | Verdant Fringe | Spring | Trading Post stock; plants carrot | new |
| carrot | Carrot | Common | 3 | Farming (Farmhouse T1) | Verdant Fringe | Spring | Sale; Farmhouse bundles | new |
| winter_squash_seed | Winter Squash Seeds | Seed | 0 | Farming (Farmhouse T2, zone 2) | Verdant Fringe | Fall, Winter | Trading Post stock; plants winter_squash | new |
| winter_squash | Winter Squash | Uncommon | 6 | Farming (Farmhouse T2) | Verdant Fringe | Fall, Winter | Kitchen bundles | new |
| hearth_root_seed | Hearth Root Seeds | Seed | 0 | Farming (Farmhouse T2) | Verdant Fringe | Fall, Winter | Trading Post stock; plants hearth_root | new |
| hearth_root | Hearth Root | Uncommon | 6 | Farming (Farmhouse T2) | Verdant Fringe | Fall, Winter | Kitchen bundles | new |
| frost_kale_seed | Frost Kale Seeds | Seed | 0 | Farming (Farmhouse T2) | Verdant Fringe | Winter | Trading Post stock; plants frost_kale | new |
| frost_kale | Frost Kale | Common | 4 | Farming (Farmhouse T2) | Verdant Fringe | Winter | Sale; Farmhouse bundles | new |

Season coverage: Spring (turnip, potato, carrot), Summer (potato, wheat, tomato), Fall (wheat,
winter_squash, hearth_root), Winter (winter_squash, hearth_root, frost_kale). Every season clears the
3-4 viable crop floor.

### 2. Forage
Category: `Resource`. Foraging route unless noted.

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| herb | Herbs | Common | 2 | Foraging (Hand, herb patch) | Verdant Fringe | Any | craft_tincture; cook_herb_tonic; cook_battle_draught | existing |
| berries | Berries | Common | 2 | Foraging (Hand, berry bush) | Verdant Fringe | Any | cook_herb_tonic; cook_travel_ration; cook_guard_ration | existing |
| fiber | Fiber | Common | 1 | Foraging (Hand, NEW bramble patch node; closes the content flag) | Verdant Fringe | Any | craft_cloth | existing |
| wild_mushroom | Wild Mushroom | Common | 2 | Foraging (Hand, Elderwood floor) | Elderwood | Fall | Sale; Kitchen bundles | new |
| forest_root | Forest Root | Common | 2 | Foraging (Hand, Elderwood) | Elderwood | Spring, Fall | Sale; Kitchen bundles | new |
| bog_moss | Bog Moss | Common | 1 | Foraging (Hand, Sunken Reach) | Sunken Reach | Any | Apothecary bundles; craft_spirit_dust input | new |
| marsh_reed | Marsh Reed | Common | 2 | Foraging (Hand, Sunken Reach) | Sunken Reach | Any | Kitchen bundles; Farmhouse bundles | new |
| bitter_root | Bitter Root | Uncommon | 5 | Foraging (Hand, deep Sunken Reach) | Sunken Reach | Fall, Winter | Apothecary bundles | new |
| nightcap_mushroom | Nightcap Mushroom | Rare | 12 | Foraging (Hand, deep Sunken Reach, gated behind Sunken Reach exploration) | Sunken Reach | Fall | Apothecary T2 reagent refining into arcane_essence | new |

### 3. Wood, stone, and ore
Category: `Resource`. Mining route (Pick) unless noted; wood is Axe.

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| wood | Wood | Common | 1 | Gathering (Axe, fallen wood) | Verdant Fringe | Any | craft_plank; construction bundles | existing |
| stone | Stone | Common | 1 | Mining (Pick, rock node) | Verdant Fringe | Any | craft_cut_stone; construction bundles | existing |
| copper_ore | Copper Ore | Common | 2 | Mining (Pick, NEW copper vein node; closes the content flag) | Verdant Fringe | Any | craft_copper_ingot | existing |
| hardwood | Hardwood | Uncommon | 5 | Gathering (Axe, Elderwood, gated behind the Command Post's Elderwood unlock) | Elderwood | Any | Construction bundles (T3+) | new |
| coal | Coal | Uncommon | 5 | Mining (Pick, Elderwood seam, gated behind the Command Post's Elderwood unlock) | Elderwood | Any | craft_iron_ingot; Smithy bundles | new |
| iron_ore | Iron Ore | Uncommon | 6 | Mining (Pick, Sunken Reach bog-iron deposit, gated behind the Command Post's Sunken Reach unlock) | Sunken Reach | Any | craft_iron_ingot | new |
| bogwood | Bogwood | Uncommon | 5 | Gathering (Axe, Sunken Reach drowned-tree stand, gated behind the Command Post's Sunken Reach unlock) | Sunken Reach | Any | Watchtower T3 bundles; Command Post T4 bundles; Smithy T4 bundles | new |

**Later-biome flags.** Gold ore and mythril belong to the mountains and do not appear in this catalog;
until that biome ships, `iron_ore` and `iron_ingot` are the Elderwood/Sunken Reach alternate ceiling for
ore and metal equipment tiers. Alpine flowers belong to the coast/mountains; `nightcap_mushroom` and
`ward_salt` are the Elderwood/Sunken Reach alternate for rare reagent-grade forage until then.

### 4. Fish (NEW)
Category: `Resource`. Fishing Dock route.

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| river_minnow | River Minnow | Common | 2 | Fishing (Fishing Dock T1, rod) | Verdant Fringe | Spring, Summer | Sale; Kitchen bundles | new |
| stream_trout | Stream Trout | Uncommon | 5 | Fishing (Fishing Dock T1) | Verdant Fringe | Spring, Fall | Kitchen bundles; craft_smoked_fish | new |
| lake_bass | Lake Bass | Uncommon | 6 | Fishing (Fishing Dock T2, deeper waters) | Elderwood | Summer | Kitchen bundles; craft_smoked_fish | new |
| frost_pike | Frost Pike | Rare | 12 | Fishing (Fishing Dock T2, Winter only) | Elderwood | Winter | Kitchen bundles; Reliquary bundles | new |
| murk_catfish | Murk Catfish | Uncommon | 6 | Fishing (Fishing Dock T2, deeper waters) | Sunken Reach | Summer, Fall | Kitchen bundles; craft_smoked_fish | new |
| bog_eel | Bog Eel | Uncommon | 7 | Fishing (Fishing Dock T2) | Sunken Reach | Fall, Winter | Kitchen bundles; craft_smoked_fish | new |
| silt_carp | Silt Carp | Common | 3 | Fishing (Fishing Dock T2) | Sunken Reach | Spring, Summer | Sale; Kitchen bundles | new |
| shadow_gar | Shadow Gar | Rare | 14 | Fishing (Fishing Dock T2, Winter only, rare) | Sunken Reach | Winter | Reliquary bundles | new |
| marsh_clam | Marsh Clam | Common | 3 | Fishing (Fishing Dock T2, trap) | Sunken Reach | Any | Sale; Kitchen bundles | new |

Season coverage: Spring (river_minnow, stream_trout, silt_carp), Summer (river_minnow, lake_bass,
murk_catfish, silt_carp), Fall (stream_trout, murk_catfish, bog_eel), Winter (frost_pike, bog_eel,
shadow_gar). Every season clears the 2-fish floor with room to spare. By biome, the Verdant Fringe
carries river_minnow and stream_trout, the Elderwood carries lake_bass and frost_pike, and the Sunken
Reach carries murk_catfish, bog_eel, silt_carp, shadow_gar, and marsh_clam: every biome clears its own
2-fish floor as well.

### 5. Animal products (NEW)
Category: `Resource`. Animal husbandry route, Farmhouse-gated.

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| egg | Egg | Common | 2 | Animal husbandry (Farmhouse T2 coop, daily) | Verdant Fringe | Any | Kitchen bundles | new |
| feather | Feather | Common | 1 | Animal husbandry (Farmhouse T2 coop, daily) | Verdant Fringe | Any | Sale; Watchtower bundles (fletching flavor) | new |
| milk | Milk | Common | 3 | Animal husbandry (Farmhouse T3 barn, daily) | Verdant Fringe | Any | craft_cheese; craft_butter | new |
| wool | Wool | Uncommon | 5 | Animal husbandry (Farmhouse T3 barn, periodic shearing) | Verdant Fringe | Any | craft_spun_yarn | new |
| cream | Cream | Common | 3 | Animal husbandry (Farmhouse T3 barn, daily byproduct of milk) | Verdant Fringe | Any | craft_butter | new |

### 6. Apiary and tap (NEW)
Category: `Resource`. Passive daily producer route as noted.

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| honey | Honey | Uncommon | 6 | Apiary (Farmhouse T3 beehive, daily) | Verdant Fringe | Any | craft_mead; Kitchen bundles | new |
| tree_sap | Tree Sap | Common | 2 | Tapping (Verdant Fringe tap line, territory access, daily) | Verdant Fringe | Any | Sale; Kitchen bundles | new |
| bog_resin | Bog Resin | Uncommon | 5 | Tapping (Sunken Reach tap line, gated behind the Sunken Reach unlock, daily) | Sunken Reach | Any | Smithy bundles; Arcane Study bundles | new |
| log_mushroom | Log Mushroom | Common | 3 | Apiary (Farmhouse T2 mushroom log, daily; closes the mushroom content flag) | Verdant Fringe | Any | Sale; Kitchen bundles | new |

### 7. Monster parts (common)
Category: `MonsterPart`. Combat drop route; see the creature sections below for which family drops
which part.

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| goblin_fang | Goblin Fang | Uncommon | 5 | Combat (Goblins, all encounters) | Verdant Fringe | Any | Smithy T1 bundles; Reliquary bundles | existing |
| rat_pelt | Rat Pelt | Common | 3 | Combat (Rats, rat_pack) | Verdant Fringe | Any | Smithy T1 bundles; Training Yard bundles | existing |
| goblin_scrap | Goblin Scrap | Common | 2 | Combat (Goblins, secondary drop) | Verdant Fringe | Any | Smithy T1 bundles | new |
| deserter_badge | Deserter Badge | Uncommon | 5 | Combat (Brigands, all encounters) | Verdant Fringe | Any | Training Yard bundles; Reliquary bundles | new |
| beast_hide | Beast Hide | Uncommon | 8 | Combat (Beasts, all encounters) | Elderwood | Any | craft_leather; Smithy bundles | existing |
| warden_bark | Warden Bark | Uncommon | 6 | Combat (Root Wardens, all encounters) | Elderwood | Any | Command Post T3 bundles; Smithy bundles | new |
| mudclaw_hide | Mudclaw Hide | Uncommon | 6 | Combat (Mudclaws, all encounters) | Sunken Reach | Any | Smithy bundles | new |
| serpent_scale | Serpent Scale | Uncommon | 6 | Combat (Marsh Serpents, all encounters) | Sunken Reach | Any | Smithy bundles; Apothecary bundles | new |
| spore_pod | Spore Pod | Uncommon | 5 | Combat (Bog Fungus, all encounters) | Sunken Reach | Any | Apothecary bundles | new |
| drowned_bone | Drowned Bone | Uncommon | 6 | Combat (The Drowned, all encounters) | Sunken Reach | Any | Reliquary bundles; craft_spirit_dust input | new |
| marsh_leech | Marsh Leech | Common | 3 | Combat (any Sunken Reach encounter, secondary drop) | Sunken Reach | Any | Apothecary bundles | new |
| sap_gland | Sap Gland | Uncommon | 4 | Combat (Bramble Slicks, all encounters) | Verdant Fringe | Any | Chapel construction bundle | new |
| fey_charm | Fey Charm | Uncommon | 4 | Combat (Hedge Folk, all encounters) | Verdant Fringe | Any | Watchtower construction bundle | new |
| spider_silk | Spider Silk | Uncommon | 6 | Combat (Canopy Spiders, all encounters) | Elderwood | Any | Fishing Dock T2 bundle | new |
| thornback_hide | Thornback Hide | Uncommon | 7 | Combat (Thornbacks, all encounters) | Elderwood | Any | Infirmary T2 bundle | new |
| swamp_drake_scale | Swamp Drake Scale | Uncommon | 7 | Combat (Swamp Drakes, all encounters) | Sunken Reach | Any | Smithy T3 bundle | new |
| wisp_ember | Wisp Ember | Uncommon | 6 | Combat (Marsh Wisps, all encounters) | Sunken Reach | Any | Arcane Study T3 bundle | new |

### 8. Trophies and rare drops
Category: `MonsterPart` (trophy tier). Selling a trophy is almost always the wrong call; every one of
these is a bundle or Reliquary material. Each is dropped once by its family's elite roamer and
guaranteed at two to three units from the family's boss, the same item at a bigger yield rather than a
separate item, so the catalog does not need two ids per family to express "elite" and "boss."

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| goblin_totem | Goblin Totem | Trophy | 25 | Combat (Goblins: elite Rustjaw, boss the Warlord) | Verdant Fringe | Any | Smithy T3 bundles; Reliquary bundles | new |
| nest_matriarch_tail | Nest Matriarch's Tail | Trophy | 25 | Combat (Rats: elite the Broodmother, boss the Gnaw King) | Verdant Fringe | Any | Training Yard bundles; Reliquary bundles | new |
| deserter_signet | Deserter's Signet | Trophy | 30 | Combat (Brigands: elite the Outrider, boss the Warband Captain) | Verdant Fringe | Any | Command Post bundles; Reliquary bundles | new |
| alpha_pelt | Alpha Pelt | Trophy | 28 | Combat (Beasts: elite the Alpha, boss the Old Growl) | Elderwood | Any | Smithy T3 bundles; Chapel bundles | new |
| heartwood_shard | Heartwood Shard | Trophy | 30 | Combat (Root Wardens: elite the Bramble Warden, boss the Heartwood) | Elderwood | Any | Reliquary T3 bundles; Watchtower bundles | new |
| reaver_tooth | Reaver's Tooth | Trophy | 30 | Combat (Mudclaws: elite the Silt Reaver, boss the Bog Chief) | Sunken Reach | Any | Smithy T3 bundles; Reliquary bundles | new |
| venom_sac | Venom Sac | Trophy | 32 | Combat (Marsh Serpents: elite the Coildancer, boss the Great Coil) | Sunken Reach | Any | Apothecary T3 bundles; Reliquary bundles | new |
| fungal_core | Fungal Core | Trophy | 35 | Combat (Bog Fungus: elite the Bloomcap, boss the Rootmind) | Sunken Reach | Any | Arcane Study T3 bundles; Reliquary bundles | new |
| hollow_locket | Hollow Locket | Trophy | 40 | Combat (The Drowned: elite the Deep Keeper, boss the Drowned Lord) | Sunken Reach | Any | Chapel T2 bundles; Reliquary T3 bundles; Command Post T4 resurrection commission | new |
| amber_core | Amber Core | Trophy | 26 | Combat (Bramble Slicks: elite the Ambercore, boss the Orchard Mother) | Verdant Fringe | Any | Training Yard T2 bundles; Reliquary T3 bundles | new |
| hollow_crown | Hollow Crown | Trophy | 27 | Combat (Hedge Folk: elite Old Thistlewhistle, boss the Hollow King) | Verdant Fringe | Any | Watchtower T2 bundles; Reliquary T3 bundles | new |
| silkqueen_fang | Silkqueen's Fang | Trophy | 29 | Combat (Canopy Spiders: elite the Weaver, boss the Silkqueen) | Elderwood | Any | Arcane Study T2 bundles; Reliquary T3 bundles | new |
| grovefather_knuckle | Grovefather's Knuckle | Trophy | 31 | Combat (Thornbacks: elite Stumpfist, boss the Grovefather) | Elderwood | Any | Smithy T3 bundles; Reliquary T3 bundles | new |
| sovereign_hide | Sovereign Hide | Trophy | 34 | Combat (Swamp Drakes: elite the Ironjaw, boss the Bog Sovereign) | Sunken Reach | Any | Training Yard T3 bundles; Reliquary T3 bundles | new |
| drowning_lantern | Drowning Lantern | Trophy | 37 | Combat (Marsh Wisps: elite the Lantern, boss the Drowning Light) | Sunken Reach | Any | Chapel T2 bundles; Reliquary T3 bundles | new |

### 9. Refined goods
Category: `Refined`. Crafting/refining route, station-gated as noted.

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| plank | Plank | Common | 3 | Crafting (craft_plank, no station) | Verdant Fringe | Any | Construction bundles | existing |
| cut_stone | Cut Stone | Common | 3 | Crafting (craft_cut_stone, no station) | Verdant Fringe | Any | Construction bundles | existing |
| copper_ingot | Copper Ingot | Uncommon | 6 | Crafting (craft_copper_ingot, smelter) | Verdant Fringe | Any | Smithy weapon MetalCost; construction bundles | existing |
| leather | Leather | Rare | 12 | Crafting (craft_leather, tanner, from beast_hide) | Elderwood | Any | Construction bundles | existing |
| tincture | Tincture | Uncommon | 6 | Crafting (craft_tincture, still) | Verdant Fringe | Any | Apothecary bundles | existing |
| cloth | Cloth | Uncommon | 5 | Crafting (craft_cloth, loom) | Verdant Fringe | Any | Construction bundles; Kitchen bundles | existing |
| iron_ingot | Iron Ingot | Rare | 14 | Crafting (craft_iron_ingot, smelter T2, from iron_ore + coal) | Sunken Reach/Elderwood | Any | Smithy T2 weapon upgrades; construction bundles | new |
| cheese | Cheese | Uncommon | 8 | Crafting (craft_cheese, kitchen, from milk) | Verdant Fringe | Any | Kitchen bundles | new |
| butter | Butter | Uncommon | 6 | Crafting (craft_butter, kitchen, from cream) | Verdant Fringe | Any | Kitchen bundles | new |
| spun_yarn | Spun Yarn | Uncommon | 7 | Crafting (craft_spun_yarn, loom, from wool) | Verdant Fringe | Any | Construction bundles | new |
| mead | Mead | Uncommon | 9 | Crafting (craft_mead, still, from honey) | Verdant Fringe | Any | Kitchen tavern common-room bundles (T2) | new |
| smoked_fish | Smoked Fish | Uncommon | 8 | Crafting (craft_smoked_fish, kitchen, from any fish) | Verdant Fringe/Elderwood/Sunken Reach | Any | Kitchen bundles | new |

### 10. Reagents
Category: `Reagent`.

| Id | Name | Rarity | Sell | Route/Source | Biome | Season | Sinks | Status |
|---|---|---|---|---|---|---|---|---|
| arcane_essence | Arcane Essence | Uncommon | 10 | Foraging (NEW ley glade node, Hand, Elderwood) or crafting (Apothecary T2 reagent refining, from nightcap_mushroom); closes the content flag with two routes | Elderwood/Sunken Reach | Any | Smithy rune reagent (Potency, Striking) | existing |
| ward_salt | Ward Salt | Uncommon | 10 | Foraging (Hand, Elderwood, gated behind the far-forest campsite discovery) | Elderwood | Any | Chapel bundles; Reliquary bundles; Arcane Study bundles | new |
| spirit_dust | Spirit Dust | Rare | 14 | Crafting (Apothecary T2 reagent refining, from drowned_bone + bog_moss) | Sunken Reach | Any | Chapel T2 bundles; Reliquary T3 bundles; Arcane Study rare-spell bundles | new |

## Biome creature families

Each family below lists its fiction, its common encounters, its elite named roamer, its boss, and its
drops. Common parts drop from every kill in the family. The elite roamer drops one unit of the family's
trophy; the boss guarantees two to three units of the same trophy.

### The Verdant Fringe (forest, easy)

**Goblins.** A reclaimer band has staked a claim on the ruins bordering the outpost, salvaging scrap
the party needs for its own rebuilding. Neither side asked the other's permission, and neither side is
willing to back down first. Common encounters: a goblin pair, a goblin patrol, a goblin warband. Elite:
Rustjaw, a duelist who fights with a blade cobbled from three broken ones. Boss: the Warlord, the
band's chief, found once the party clears the ruins the goblins have claimed as their own. Drops:
goblin_fang and goblin_scrap (common); goblin_totem (Rustjaw, the Warlord).

**Rats.** The outpost's collapsed granary drew a vermin infestation years before the party arrived, and
it has bred in the walls ever since. Common encounter: a pack of giant rats. Elite: the Broodmother, an
oversized rat that leads the largest nests. Boss: the Gnaw King, the alpha of the infestation, found at
the granary's source once the party clears down to it. Drops: rat_pelt (common); nest_matriarch_tail
(the Broodmother, the Gnaw King).

**Brigands.** Deserters from the hegemony's border legions have gone to ground in the Fringe, raiding
whatever crosses their path rather than face a court-martial back home. Common encounters: a deserter
patrol, an outrider ambush. Elite: the Outrider, a mounted scout who marks targets for the rest of the
warband. Boss: the Warband Captain, a renegade officer who still wears his hegemony insignia, out of
spite more than loyalty. Drops: deserter_badge (common); deserter_signet (the Outrider, the Warband
Captain).

**Bramble Slicks (new).** Sap and resin from the old hedge-orchards along the outpost's boundary
curdled into something that moves, decades before the party arrived, and it has never stopped being
hungry. This is the biome's ooze family: slow, resilient, and closer to an attrition fight than a
straight brawl, since a slick shrugs off a hit that would have staggered a goblin. Common encounters: a
bramble slick, a knot of slicks. Elite: the Ambercore, a slick grown thick and hard-shelled around a
core of its own hardened sap. Boss: the Orchard Mother, the oldest slick in the hedge-line, large enough
to have swallowed the orchard's own roots into itself over the years. Drops: sap_gland (common);
amber_core (the Ambercore, the Orchard Mother).

**Hedge Folk (new).** Small, sharp-eyed fey have lived in the boundary hedges longer than the outpost's
walls have stood, delighting in swapped tools, spooked livestock, and travelers led in wide, pointless
circles before being let go, mostly unharmed. This is the biome's fey-adjacent family: an evasive,
trickster fight built on misdirection rather than raw damage, the opposite feel from the Goblins'
straight melee or the Rats' swarm attrition. Common encounters: a hedge prankster, a hedge folk
gathering. Elite: Old Thistlewhistle, a hedge fey cunning enough to lead an armed patrol in circles for
a full afternoon before losing interest. Boss: the Hollow King, the oldest and least amused of the hedge
folk, who has stopped treating the outpost's presence as a game. Drops: fey_charm (common);
hollow_crown (Old Thistlewhistle, the Hollow King).

The Verdant Fringe now carries five creature families (Goblins, Rats, Brigands, Bramble Slicks, Hedge
Folk), clearing the padded-bestiary floor of four to six with room to spare.

### The Elderwood (moderate, proposed name)

**Beasts.** Wolves and other predators range the Elderwood, drawn toward the outpost's livestock and
the easy scent of a settlement whenever hunger pushes them out toward the Fringe's edge. This family
fills the beast_drops table that has existed in code with no creature behind it. Common encounters: a
lone predator, a hunting pack. Elite: the Alpha, a scarred pack leader that has marked the Elderwood's
outer boundary as its own. Boss: the Old Growl, an ancient predator that has ruled the deep woods longer
than the outpost has stood. Drops: beast_hide (common); alpha_pelt (the Alpha, the Old Growl).

**Root Wardens (proposed).** Deep in the Elderwood, root and bark and years without a single
disturbance have knit themselves into something that moves. Nobody built the Root Wardens and nobody
commands them; they simply patrol the oldest groves the way a trunk defends its own heartwood,
mistaking anything that lingers too long for a threat to the grove around it. Common encounters: a
root warden, a stand of root wardens. Elite: the Bramble Warden, a warden grown twisted and vast around
some old wound in its bark. Boss: the Heartwood, the grove's oldest and largest warden, old enough that
its wood remembers the Elderwood before the outpost existed. Drops: warden_bark (common);
heartwood_shard (the Bramble Warden, the Heartwood). This family is proposed alongside the Elderwood
biome itself, filling the moderate tier's second creature family so the Elderwood clears the
two-family floor without duplicating the Sunken Reach's own fungal identity (Bog Fungus stays a
swamp-only family; the Root Wardens are wood and root, not spore and bloom).

**Canopy Spiders (new).** Web-spinning arachnids the size of hunting dogs have claimed the Elderwood's
high canopy, dropping silk-wrapped prey to the forest floor once they have had their fill. This is the
biome's own vermin family, an arachnid counterpart to the Fringe's rodent-swarm Rats: the fight is
vertical and ambush-driven, webbing and drops from directly overhead, rather than a ground-level swarm.
Common encounters: a canopy spider, a spider drop (an ambush struck from directly above). Elite: the
Weaver, a spider whose web spans an entire grove and is said to feel anything that touches any strand of
it. Boss: the Silkqueen, the largest spider in the grove and mother to the rest of its brood. Drops:
spider_silk (common); silkqueen_fang (the Weaver, the Silkqueen).

**Thornbacks (new).** Hulking, bark-skinned giant-kin, more root and rind than person by now, have made
the Elderwood's oldest fallen hollows their den, and treat any tree felled nearby as a personal insult.
This is the biome's giant-kin family: a heavy, single-target bruiser fight that rewards focused fire
over spread damage, distinct from the Canopy Spiders' ambush-and-terrain game and the Root Wardens'
stationary defense. Common encounters: a thornback brute, a thornback pair. Elite: Stumpfist, a
thornback that has driven off every hunting party that has come looking for its den. Boss: the
Grovefather, the eldest thornback in the Elderwood, broad enough to be mistaken for a fallen trunk
until it moves. Drops: thornback_hide (common); grovefather_knuckle (Stumpfist, the Grovefather).

The Elderwood now carries four creature families (Beasts, Root Wardens, Canopy Spiders, Thornbacks),
clearing the padded-bestiary floor of four to six.

### The Sunken Reach (swamp, dangerous)

**Mudclaws.** Territorial amphibian hunters patrol the shallows, defending nesting grounds against
anything that wades in too deep. Common encounters: a mudclaw hunting pair, a mudclaw ambush. Elite:
the Silt Reaver, a scarred hunter that drags prey under the surface before the rest of the party can
react. Boss: the Bog Chief, the eldest and largest of the shallows' hunters, guarding the deepest
nesting ground in the Reach. Drops: mudclaw_hide (common); reaver_tooth (the Silt Reaver, the Bog
Chief).

**Marsh Serpents.** Constrictors as long as a wagon coil through the reeds, ambushing anything that
disturbs the water. Common encounters: a marsh serpent, a nest of serpents. Elite: the Coildancer, a
serpent fast enough to strike before the party sees it move. Boss: the Great Coil, a serpent grown
massive on generations of unlucky travelers. Drops: serpent_scale (common); venom_sac (the Coildancer,
the Great Coil).

**Bog Fungus.** Animated fungal blooms drift through the Reach, spreading spores that root wherever
they land and slowly reclaim anything that stops moving long enough. Common encounters: a bloom
cluster, a spore swarm. Elite: the Bloomcap, a bloom grown large enough to move with purpose. Boss: the
Rootmind, a single fungal intelligence spread across an entire grove, coordinating every bloom in the
Reach at once. Drops: spore_pod (common); fungal_core (the Bloomcap, the Rootmind).

**The Drowned.** Travelers who went under the Reach's water and did not come back up sometimes rise
again: waterlogged, silent, and cold to the touch, walking the shallows on some errand only they
remember. This is the undead-lite family for the biome. Their wrongness is entirely behavioral (the
slow, single-minded gait, the silence, the way they move like they are still underwater); nothing about
their appearance changes. Common encounters: a drowned wanderer, a drowned procession. Elite: the Deep
Keeper, a drowned figure standing guard over something at the bottom of the Reach. Boss: the Drowned
Lord, once someone important, still leading the others on an errand that ended before it started.
Drops: drowned_bone (common); hollow_locket (the Deep Keeper, the Drowned Lord).

**Swamp Drakes (new).** Low-slung, armored reptiles lurk half-submerged in the deep bog, more patient
than the Reach's serpents and far better protected, striking only when a kill is certain. This is the
biome's drake-kin family, a heavier and warier escalation of the wyrmlings the party may have already
met in the Elderwood's own hollows: an armored, defensive fight that rewards precision over raw damage,
distinct from the Marsh Serpents' fast ambush strikes and the Mudclaws' grappling. Common encounters: a
swamp drake, a drake pair. Elite: the Ironjaw, a drake whose hide has thickened scale over scale until
spears no longer find purchase. Boss: the Bog Sovereign, the oldest drake in the Reach, large enough
that the shallows visibly shift when it moves. Drops: swamp_drake_scale (common); sovereign_hide (the
Ironjaw, the Bog Sovereign).

**Marsh Wisps (new).** Pale lights drift over the deep bog after dark, leading the unwary off the safe
paths and toward the water; nobody who follows one all the way ever explains why they did. This is the
biome's second fey-adjacent family, a darker turn on the Fringe's mischievous Hedge Folk: an evasive,
lure-and-punish fight that penalizes careless positioning rather than testing raw combat strength.
Common encounters: a marsh wisp, a wisp cluster. Elite: the Lantern, a wisp bright and patient enough to
lead a whole party astray before it starts to feed. Boss: the Drowning Light, the oldest wisp in the
Reach, old enough that the safe paths have started bending toward it instead of away. Drops: wisp_ember
(common); drowning_lantern (the Lantern, the Drowning Light).

The Sunken Reach now carries six creature families (Mudclaws, Marsh Serpents, Bog Fungus, The Drowned,
Swamp Drakes, Marsh Wisps), the richest roster of the three biomes, clearing the padded-bestiary floor
of four to six at its top end. That is a deliberate choice: the Reach is where Year 2's capstone
bundles and the Reliquary's own full-collection tier draw the most heavily, so its bestiary carries the
most variety to hunt.

## Source and sink closure appendix

Every item below has at least one source and at least one sink. This table is a flat cross-check
across the whole catalog; see the family tables above for full detail on each route.

| Id | Source | Sink |
|---|---|---|
| turnip_seed / turnip | Farming | Sale; Farmhouse bundles |
| potato_seed / potato | Farming | cook_hearty_stew; cook_guard_ration |
| wheat_seed / wheat | Farming | cook_hearty_stew; cook_travel_ration |
| tomato_seed / tomato | Farming | cook_battle_draught |
| carrot_seed / carrot | Farming | Sale; Farmhouse bundles |
| winter_squash_seed / winter_squash | Farming | Kitchen bundles |
| hearth_root_seed / hearth_root | Farming | Kitchen bundles |
| frost_kale_seed / frost_kale | Farming | Sale; Farmhouse bundles |
| herb | Foraging | craft_tincture; meals |
| berries | Foraging | meals |
| fiber | Foraging (bramble patch) | craft_cloth |
| wild_mushroom | Foraging | Sale; Kitchen bundles |
| forest_root | Foraging | Sale; Kitchen bundles |
| bog_moss | Foraging | Apothecary bundles; craft_spirit_dust |
| marsh_reed | Foraging | Kitchen bundles; Farmhouse bundles |
| bitter_root | Foraging | Apothecary bundles |
| nightcap_mushroom | Foraging | craft_arcane_essence |
| wood | Gathering | craft_plank; construction bundles |
| stone | Mining | craft_cut_stone; construction bundles |
| copper_ore | Mining (copper vein) | craft_copper_ingot |
| hardwood | Gathering | construction bundles |
| coal | Mining | craft_iron_ingot; Smithy bundles |
| iron_ore | Mining (Sunken Reach) | craft_iron_ingot |
| bogwood | Gathering (Sunken Reach drowned-tree stand) | Watchtower T3, Command Post T4, Smithy T4 bundles |
| river_minnow / stream_trout | Fishing (Fishing Dock T1) | Sale; Kitchen bundles; craft_smoked_fish |
| lake_bass / frost_pike | Fishing (Fishing Dock T2) | Sale; Kitchen bundles; craft_smoked_fish |
| murk_catfish / bog_eel / silt_carp / shadow_gar / marsh_clam | Fishing (Fishing Dock T2) | Sale; Kitchen bundles; craft_smoked_fish; Reliquary bundles |
| egg / feather | Animal husbandry (coop) | Kitchen bundles; Watchtower bundles |
| milk / cream | Animal husbandry (barn) | craft_cheese; craft_butter |
| wool | Animal husbandry (barn) | craft_spun_yarn |
| honey | Apiary | craft_mead; Kitchen bundles |
| tree_sap | Tapping | Sale; Kitchen bundles |
| bog_resin | Tapping | Smithy bundles; Arcane Study bundles |
| log_mushroom | Apiary | Sale; Kitchen bundles |
| goblin_fang / goblin_scrap | Combat (Goblins) | Smithy bundles; Reliquary bundles |
| rat_pelt | Combat (Rats) | Smithy bundles; Training Yard bundles |
| beast_hide | Combat (Beasts) | craft_leather; Smithy bundles |
| warden_bark | Combat (Root Wardens) | Command Post T3 bundles; Smithy bundles |
| deserter_badge | Combat (Brigands) | Training Yard bundles; Reliquary bundles |
| mudclaw_hide | Combat (Mudclaws) | Smithy bundles |
| serpent_scale | Combat (Marsh Serpents) | Smithy bundles; Apothecary bundles |
| spore_pod | Combat (Bog Fungus) | Apothecary bundles |
| drowned_bone | Combat (The Drowned) | Reliquary bundles; craft_spirit_dust |
| marsh_leech | Combat (any Sunken Reach encounter) | Apothecary bundles |
| sap_gland | Combat (Bramble Slicks) | Chapel construction bundle |
| fey_charm | Combat (Hedge Folk) | Watchtower construction bundle |
| spider_silk | Combat (Canopy Spiders) | Fishing Dock T2 bundle |
| thornback_hide | Combat (Thornbacks) | Infirmary T2 bundle |
| swamp_drake_scale | Combat (Swamp Drakes) | Smithy T3 bundle |
| wisp_ember | Combat (Marsh Wisps) | Arcane Study T3 bundle |
| goblin_totem | Combat (Goblins elite/boss) | Smithy T3 bundles; Reliquary bundles |
| nest_matriarch_tail | Combat (Rats elite/boss) | Training Yard bundles; Reliquary bundles |
| alpha_pelt | Combat (Beasts elite/boss) | Smithy T3 bundles; Chapel bundles |
| heartwood_shard | Combat (Root Wardens elite/boss) | Reliquary T3 bundles; Watchtower bundles |
| deserter_signet | Combat (Brigands elite/boss) | Command Post bundles; Reliquary bundles |
| reaver_tooth | Combat (Mudclaws elite/boss) | Smithy T3 bundles; Reliquary bundles |
| venom_sac | Combat (Marsh Serpents elite/boss) | Apothecary T3 bundles; Reliquary bundles |
| fungal_core | Combat (Bog Fungus elite/boss) | Arcane Study T3 bundles; Reliquary bundles |
| hollow_locket | Combat (The Drowned elite/boss) | Chapel T2 bundles; Reliquary T3 bundles; Command Post T4 |
| amber_core | Combat (Bramble Slicks elite/boss) | Training Yard T2 bundles; Reliquary T3 bundles |
| hollow_crown | Combat (Hedge Folk elite/boss) | Watchtower T2 bundles; Reliquary T3 bundles |
| silkqueen_fang | Combat (Canopy Spiders elite/boss) | Arcane Study T2 bundles; Reliquary T3 bundles |
| grovefather_knuckle | Combat (Thornbacks elite/boss) | Smithy T3 bundles; Reliquary T3 bundles |
| sovereign_hide | Combat (Swamp Drakes elite/boss) | Training Yard T3 bundles; Reliquary T3 bundles |
| drowning_lantern | Combat (Marsh Wisps elite/boss) | Chapel T2 bundles; Reliquary T3 bundles |
| plank / cut_stone | Crafting (baseline) | Construction bundles |
| copper_ingot | Crafting (smelter) | Smithy weapon MetalCost; construction bundles |
| leather | Crafting (tanner) | Construction bundles |
| tincture | Crafting (still) | Apothecary bundles |
| cloth | Crafting (loom) | Construction bundles; Kitchen bundles |
| iron_ingot | Crafting (smelter T2) | Smithy T2 weapon upgrades; construction bundles |
| cheese / butter | Crafting (kitchen) | Kitchen bundles |
| spun_yarn | Crafting (loom) | Construction bundles |
| mead | Crafting (still) | Kitchen T2 bundles |
| smoked_fish | Crafting (kitchen) | Kitchen bundles |
| arcane_essence | Foraging (ley glade) or crafting (Apothecary T2) | Smithy rune reagent |
| ward_salt | Foraging | Chapel, Reliquary, Arcane Study bundles |
| spirit_dust | Crafting (Apothecary T2) | Chapel, Reliquary, Arcane Study bundles |
| hearty_stew / herb_tonic / travel_ration / battle_draught / guard_ration | Crafting (kitchen recipes) | Eaten for day-long buff; sale |
| minor_healing_potion / guardian_elixir / antidote | Apothecary T1 (recipe authored with the building) | Combat use; sale |

## Content-flag closure

The framework brief named four unresolved gaps in the shipped code. This catalog closes all four.

- **copper_ore** now has an explicit gather source: a new `copper_vein` resource node (Pick tool,
  Verdant Fringe), alongside the existing Rock node that only yields stone.
- **fiber** now has an explicit gather source: a new `bramble_patch` resource node (Hand tool, Verdant
  Fringe).
- **arcane_essence** now has two sources rather than none: a rare forage node (`ley_glade`, Hand tool,
  the Elderwood) and an Apothecary T2 reagent-refining recipe that converts `nightcap_mushroom` into
  arcane_essence. Its sink was already wired in code (`RunePrices.ReagentItemId`); only the source side
  was missing.
- **A mushroom item** now exists with an explicit source: `log_mushroom`, produced daily by a cultivated
  mushroom log at the Farmhouse (T2). `wild_mushroom` (Elderwood) and `nightcap_mushroom` (Sunken Reach)
  each add a foraged mushroom to one of the two wilder biomes on top of that cultivated baseline.

## Judgment calls and deviations

- The family count bands in the framework brief are read as total item ids per family (matching how
  the existing catalog is tallied), not as "distinct types" separate from their seed items. Under that
  reading every family lands inside its band.
- Winter-hardy crops (winter_squash, hearth_root, frost_kale) grow outdoors once Farmhouse T2 is built,
  rather than being gated behind the T4 greenhouse. The greenhouse instead lifts the season restriction
  entirely (plant anything, any season), which reads as a stronger, later-game convenience than gating
  the base Winter roster behind it.
- Elite and boss trophies share one id per creature family (the boss guarantees more units of the same
  trophy rather than dropping a rarer second item), so every one of the fifteen creature families now
  in the catalog gets a full common/elite/boss structure at the cost of exactly two ids (one common
  part, one trophy) rather than three or four. The Monster Parts and Trophies families themselves now
  run past the framework brief's original 10-14 and 6-10 bands (17 and 15 items respectively); see the
  padded-bestiary bullet below for why that overshoot is intentional.
- iron_ore is placed in the Sunken Reach (bog iron) rather than the Verdant Fringe, giving the swamp
  its own mining route and keeping the Verdant Fringe/copper, Sunken Reach/iron split clean for a
  future Smithy tier gate.
- The three existing Consumable items (minor_healing_potion, guardian_elixir, antidote) still have no
  Recipes.cs entry in code. That gap is not one of the four the brief named, and closing it is Apothecary
  T1 content by the building ladder's own definition, so it is noted here as a forward reference rather
  than solved with new catalog items.
- **Three-biome restructure (2026-07-14).** This catalog now runs the difficulty ladder the framework
  brief revised to: the Verdant Fringe (easy, unchanged), the Elderwood (moderate, proposed name, new),
  and the Sunken Reach (dangerous, unchanged in substance, renamed consistently from "Swamp" to its own
  name in every Biome column). Hardwood, coal, wild_mushroom, forest_root, ward_salt, and the
  ley_glade route for arcane_essence all move to the Elderwood; nothing about the Sunken Reach's own
  materials changes, only its Command Post tier (T2 to T3, see `buildings.md`).
- **Creature re-tiering.** Of the four Verdant Fringe families, Goblins, Rats, and Brigands stay easy
  and stay put; Beasts moves to the Elderwood as the moderate tier's first family, since its own fiction
  (the Alpha marking "the deep-forest boundary," the Old Growl ruling "the deep woods longer than the
  outpost has stood") already read as deep-woods content before the Elderwood existed to file it under.
  That leaves the Elderwood with only one family, short of the two-family floor the brief's own
  cross-check calls for, so this catalog proposes a second, new moderate family, the Root Wardens, an
  animate root-and-bark family distinct from Beasts (animal) and from the Sunken Reach's Bog Fungus
  (spore and bloom, not wood). This is a deviation worth flagging: the brief's instruction described
  moving "1-2" existing families and did not ask for a new one, but with only four Verdant Fringe
  families to redistribute and three of them explicitly asked to stay put, no combination of moves
  alone reaches two families in the Elderwood without either dropping the "keep goblins/rats and one
  more" instruction or inventing new content. This catalog keeps the "one more" (Brigands) in the
  Verdant Fringe and invents the Root Wardens instead, since that reading contradicts fewer explicit
  instructions than pulling Brigands out of a biome its own fiction names it in.
- **The Sunken Reach's wood-type gap is now closed.** Every prior draft of this catalog flagged the
  Sunken Reach as the one biome with no wood-type material of its own (the biome's own doctrine gave it
  "bog iron, reeds and swamp forage, murk fish," with marsh_reed standing in as the closest functional
  analog). This revision closes that gap directly: `bogwood`, cut from the Reach's own drowned-tree
  stands, is the swamp's timber line, gathered by Axe the same way wood and hardwood are elsewhere. See
  the Wood/stone/ore family table, the node-yield table, and the padded-bestiary bullet below.
- **Fish, split three ways.** river_minnow and stream_trout stay Verdant Fringe pond/river fish on
  Fishing Dock T1. lake_bass and frost_pike move to the Elderwood's shaded pools, now gated behind
  Fishing Dock T2 rather than T1, alongside the Sunken Reach's five murk-water fish (unchanged). Every
  biome clears the 2-fish floor and every season still clears its 2-fish floor; see the Fish family
  section for the full breakdown.
- **Padded-bestiary expansion (2026-07-14).** Per the user's own directive that the source material has
  monsters to spare, this pass adds six new creature families, two per biome: the Verdant Fringe gains
  Bramble Slicks (ooze) and Hedge Folk (fey-adjacent); the Elderwood gains Canopy Spiders
  (vermin/arachnid) and Thornbacks (giant-kin); the Sunken Reach gains Swamp Drakes (drake-kin) and
  Marsh Wisps (a second, darker fey-adjacent family). Every biome now clears the four-to-six-family
  floor (Fringe 5, Elderwood 4, Reach 6), and no two new families share both a creature type and a
  biome, so the padding reads as genuinely varied rather than reskinned repeats: six different fictions,
  six different hunting feels (attrition, trickster evasion, vertical ambush, heavy-melee bruiser,
  armored patience, lure-and-punish). Each family adds exactly two items (one common part, one shared
  elite/boss trophy), for thirteen new ids in total once `bogwood` is counted alongside them. That
  brings the catalog's total item count from 84 to **97**, and pushes the Monster Parts family to 17
  items and the Trophies family to 15, both past the framework brief's original bands (10-14 and 6-10).
  This is a deliberate, user-directed overshoot of the brief's ~70-90 total-item target and its
  per-family bands, not a drift from them: the padded-bestiary revision explicitly asked for more
  per-biome creature variety than the original targets anticipated, and the closure rule (every new
  item sourced and sunk) is held exactly as strictly as it is everywhere else in this catalog. See
  `buildings.md` for where each of the thirteen new items lands as a bundle sink.
