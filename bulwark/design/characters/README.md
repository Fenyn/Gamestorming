# Bulwark — Characters

One profile file per character. Profiles live in `scripts/data/characters/` as plain C# static classes
that declare a `CharacterProfile` instance. The `Characters` registry aggregates them; non-starting
characters auto-emit `VillagerDefinition`s for arrival and placement.

## The cast (starting party)

| Id | Name | Class | Ancestry | Role | Building |
|---|---|---|---|---|---|
| `player` | *(player-chosen)* | Fighter | Human | Farmhand-soldier. The player avatar: farming, expansion, upgrades. | — (generalist) |
| `tharr` | Tharr | Cleric (Warpriest) | Dwarf | Stonemason. Construction-master: repairs, restores, builds. | Command Post |
| *(TBD)* | *(TBD)* | Rogue | Elf | Charismatic merchant. Runs the trading post. | Trading Post |
| *(TBD)* | *(TBD)* | Wizard | Halfling | Friendly cook. Loves recipes and learning new spells. | Kitchen / Tavern |

The story opens with the player, the elf, and the halfling traveling to reinforce the outpost. Tharr
is already there — the lone holdout who's been struggling to maintain the place alone.

## How to add a character

1. Copy `scripts/data/characters/_Template.cs` to `scripts/data/characters/<Name>.cs`
2. Rename the class and fill in the profile fields
3. Add `<Name>.Profile` to the `Characters.cs` registry constructor
4. For non-starting characters: provide an `ArrivalTrigger` and place a `%Villager_<id>` marker in the outpost scene

That's it — no other files need editing. The registry auto-emits a `VillagerDefinition` for
non-StartingPC profiles, which flows into the existing villager arrival and placement systems.

## Building themes (match characters to these)

| Building | Theme | Class / archetype | Function |
|---|---|---|---|
| Command Post | HQ / leadership | Veteran / leader | Planning table, commissioning, roster, biome unlocks |
| Trading Post | The store | Merchant (townsfolk) | Buy & sell goods for gold |
| Smithy | The forge | Fighter / smith | Craft weapons & armor, etch runes |
| Infirmary | Field medicine | Cleric / Medic | Treat Wounds, remove afflictions |
| Chapel / Shrine | Faith & divine | Cleric / Champion | Focus spells, divine font, blessings |
| Arcane Study | Library | Wizard / arcane caster | Learn spells, scrolls, Recall Knowledge |
| Training Yard | Drill & discipline | Martial (Fighter/Ranger/Monk) | Proficiency training, respec |
| Apothecary / Lab | Alchemy | Alchemist / herbalist | Potions, elixirs, poisons |
| Kitchen | Hearth | Cook (townsfolk or Bard) | Day-long meal buffs, feasts |
| Farmhouse / Fields | Homestead | Farmhand / Druid-ish | Crops, tillable expansion, greenhouse |
| Watchtower | Scouting | Rogue / Ranger | Reveal territory, encounter previews, fast travel |

## Supported PF2e classes

**Fully compiled (engine features + spellcasting + feats):**
Fighter, Cleric, Wizard, Rogue

**Planned (no engine feature-classes yet — fine to assign in a profile, flag in BuildSpec later):**
Alchemist, Ranger, Champion, Bard, Monk, Barbarian

## Supported ancestries

Human, Dwarf, Elf, Halfling, Gnome, Goblin — stored as strings, no engine validation.

## Deferred: the Free Archetype build layer

Each profile has a nullable `Build` field (`BuildSpec`). It is null for all current profiles. When
populated, it will carry the character's Free Archetype line, variant combo id, and equipment notes —
enough for the Characters registry to auto-register a `PartyPresetSpec` so recruitable characters
can join the combat roster. The 4 starting PCs' combat builds still live in `PresetCharacters.cs`
and are NOT driven by BuildSpec.

## Supported Free Archetype dedications (engine features compiled)

Marshal, Medic, Bastion, Archer, Dual-Weapon Warrior

Any other dedication a character might use needs an engine feature-class built first.
