# Bulwark — Planned Buildings

> **Superseded for costs and tiers:** the full progression design (commission prerequisites,
> construction bundles, tier ladders, benefits, migration notes vs shipped code) now lives in
> **`design/economy/buildings.md`**, priced against the material catalog in
> `design/economy/materials.md` and scheduled in `design/economy/pacing.md`. This file remains the
> quick theme/roster tracker.

Living tracker for the outpost's buildings: their theme, the PF2e class/archetype each embodies, what
they do, and how they're funded. Buildings are commissioned at the Command Post **planning table**,
rise at a fixed map spot (`%Building_<id>` marker), and grow through bundle-gated tiers. Each building
also introduces a domain-related **villager** (see `design/characters/`) — some of whom are playable
party members.

## Currency & role model
- **Gold** → the **Trading Post** (buy/sell finished goods) and the **Smithy's rune bench**.
- **Materials** (metal ingots, magical reagents) → the **Smithy** crafts gear from metal and etches
  runes with magical reagents. Metal = the equipment; magical reagents = the enchantment (runes).
- **Resource bundles** (Community-Center / shrine style) → town/meta unlocks for every other building.
- **Smithy upgrades unlock new Trading Post offerings.**
- Combat party is always 4; the **roster pool** of playable characters grows as villagers arrive.

## Roster

| Building | Theme | Class / archetype it embodies | Function | Currency | Status |
|---|---|---|---|---|---|
| **Command Post** | HQ / leadership | Veteran / leader | Planning table (commission buildings), roster, biome unlocks, resurrection | bundles | systems built |
| **Trading Post** | The store / market | Merchant (townsfolk) | Buy & sell goods for gold; stock expands with Smithy upgrades | **gold** | in progress |
| **Smithy** | The forge | Fighter / smith | **Crafts** weapons & armor from **metal** materials; **etches runes** (gold + magical reagent); shields | materials + gold | systems built (reframing) |
| **Infirmary** | Field medicine | Cleric / Medic (Battle Medicine) | Treat Wounds, remove wounded/afflictions, rest quality | bundles | systems built |
| **Chapel / Shrine** | Faith & the divine | Cleric / divine caster / Champion | Focus spells, divine font, hero-point grants, blessings | bundles | planned |
| **Arcane Study** | Library of magic | Wizard / arcane caster | Learn spells, higher ranks, scrolls, Recall Knowledge | bundles | planned |
| **Training Yard** | Drill & discipline | Martial trainer (Fighter/Ranger/Monk) | Proficiency training, class feats, archetype/dedication unlocks, respec | bundles | planned |
| **Apothecary / Lab** | Alchemy & reagents | Alchemist / herbalist | Potions, elixirs, poisons, antidotes, talismans; rune reagents | bundles + gold | planned |
| **Kitchen** | Hearth & provisions | Cook (townsfolk, or Bard-ish) | Day-long meal buffs, tonics, feasts | bundles | systems built |
| **Farmhouse / Fields** | The homestead | Farmhand / Druid-ish nature | Crops, tillable-**area** expansion, watering, greenhouse | bundles | systems built |
| **Watchtower** | Scouting & the frontier | Rogue / Ranger | Reveal territory, encounter previews, ambush/initiative, fast travel | bundles | planned |

## Character-matching notes
- **Two divine buildings, split on purpose:** the **Infirmary** is the *medicine / battle-medic* side;
  the **Chapel** is the *faith / focus-spell* side — room for a distinct devout character.
- **Three martial personalities:** the **Smithy** (craftsman), the **Training Yard** (drillmaster),
  the **Watchtower** (scout).
- **Unclaimed archetypes worth a character:** **Alchemist** (Apothecary — nobody occupies it yet),
  a **primal/nature** figure (Farmhouse), a **social/support** figure (Kitchen), a **merchant**
  (Trading Post).

## Engine feasibility (for character builds)
- Base classes (Fighter/Cleric/Wizard/Rogue, plus their spells/skills/feats) are fully supported.
- Only these archetype **dedications** have working engine feature-classes: **Marshal, Medic, Bastion,
  Archer, Dual-Weapon Warrior**. Any other archetype a character leans on needs an engine feature-class
  built first — fine to *plan*, flag it when it comes to the (deferred) Free-Archetype build layer.
