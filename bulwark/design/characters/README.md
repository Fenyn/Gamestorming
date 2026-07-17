# Bulwark — Characters

One profile file per character. Profiles live in `scripts/data/characters/` as plain C# static classes
that declare a `CharacterProfile` instance. The `Characters` registry aggregates them; non-starting
characters auto-emit `VillagerDefinition`s for arrival and placement.

## The cast

### Starting party

| Id | Name | Class | Ancestry | Role | Building |
|---|---|---|---|---|---|
| `player` | *(player-chosen)* | Fighter | Human | Farmhand-soldier. The player avatar: farming, expansion, upgrades. | — (generalist) |
| `tharr` | Tharr | Cleric (Warpriest) | Dwarf | Stonemason. Construction-master: repairs, restores, builds. | Command Post |
| `elara` | Elara | Rogue (Thief) | Elf | Silver-tongued merchant. Runs the trading post. | Trading Post |
| `fenwick` | Fenwick | Wizard (Battle Magic) | Halfling | Gastronomancer and chef. Social heart of the outpost. | Tavern |

The story opens with the player, Elara, and Fenwick traveling to reinforce the outpost. Tharr
is already there, the lone holdout who has been struggling to maintain the place alone.

### Recruitable

| Id | Name | Class | Ancestry | Role | Building | Arrival |
|---|---|---|---|---|---|---|
| `arkus` | Arkus | Barbarian | Orc | Failed rite of passage. Blacksmith. | Smithy | Found wounded in forest |
| `aldric` | Sir Aldric | Champion (Paladin) | Human | Ex-soldier seeking atonement. Drillmaster. | Training Yard | Drawn by outpost's reputation |
| `spore` | Spore | Witch | Leshy (Fungus) | Forest outsider. Brewer of potions and consumables. | Apothecary | Found in deep forest |
| `josen` | Josen | Monk | Elf | Quiet Hand master. Healer and anatomist seeking transcendence. | Infirmary | Already in the region, drawn in by injuries |
| `thistle` | Thistle | Ranger | Gnome | Frontier scout fading into The Stillness. | Watchtower | Found at abandoned campsite during expedition |
| `grub` | Grub | Druid | Goblin | Wilderness gardener and reclaimer. Automates farming. | Farmhouse / Fields | Found tending wild patch during territory expansion |
| `sera` | Sera | Magus | Human | Exiled academic. Studies the fabric of arcane magic. | Arcane Study | Arrives deliberately, seeking frontier research freedom |
| `oskar` | Oskar | Oracle | Dwarf | War-cursed elder. Builds a legacy before the decline takes him. | Chapel / Shrine | Arrives seeking a place to spend his final years |
| `hazel` | Hazel | Thaumaturge | Halfling | Ex-curator rebuilding a lost collection. Monster expert. | Reliquary | Arrives seeking a home for her work |
| `wynn` | Wynn | Bard | Human | Exiled playwright. Oral storyteller collecting material. | Tavern (co-tenant) | Wandered in, never left |

### Unassigned (no building)

| Id | Name | Class | Ancestry | Role | Arrival |
|---|---|---|---|---|---|
| `vasska` | Vasska | Psychic | Nagaji | Telepathic mind-reader. Key to Oskar's ritual quest. | Swamp biome, gated behind Oskar 6/10 hearts |
| `raven` | Raven | Swashbuckler (Braggart) | Human | Bounty hunter and wandering brigand. Real name hidden. | Periodic visitor, recruitable via friendship |
| `hilde` | Hilde | Summoner | Dwarf | Fugitive miner bonded to an earth eidolon. Starts as townsfolk. | Present at tavern, revealed via heart event |
| `flick` | Flick | Sorcerer (Elemental) | Goblin | Reckless junk-mage. Contained at outpost for everyone's safety. | Found mid-disaster during expedition |

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
| Tavern | Hearth | Cook (townsfolk or Bard) | Day-long meal buffs, feasts |
| Farmhouse / Fields | Homestead | Farmhand / Druid-ish | Crops, tillable expansion, greenhouse |
| Watchtower | Scouting | Rogue / Ranger | Reveal territory, encounter previews, fast travel |

## Supported PF2e classes

**Fully compiled (engine features + spellcasting + feats):**
Fighter, Cleric, Wizard, Rogue

**Planned (no engine feature-classes yet — fine to assign in a profile, flag in BuildSpec later):**
Alchemist, Ranger, Champion, Bard, Monk, Barbarian, Witch, Druid, Magus, Oracle, Thaumaturge,
Psychic, Swashbuckler, Summoner, Sorcerer

## Supported ancestries

Human, Dwarf, Elf, Halfling, Orc, Leshy, Gnome, Goblin, Nagaji (rare/exotic) — stored as strings,
no engine validation.

## Deferred: the Free Archetype build layer

Each profile has a nullable `Build` field (`BuildSpec`). It is null for all current profiles. When
populated, it will carry the character's Free Archetype line, variant combo id, and equipment notes —
enough for the Characters registry to auto-register a `PartyPresetSpec` so recruitable characters
can join the combat roster. The 4 starting PCs' combat builds still live in `PresetCharacters.cs`
and are NOT driven by BuildSpec.

## Supported Free Archetype dedications (engine features compiled)

Marshal, Medic, Bastion, Archer, Dual-Weapon Warrior

Any other dedication a character might use needs an engine feature-class built first.
