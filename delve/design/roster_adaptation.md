# Bulwark roster adaptation

The four starters are permanently available before normal expeditions. Every run selects an unlocked leader and three unlocked companions. The leader determines personal objective credit and the intended dialogue POV; authored dialogue and encounter weighting remain future content.

Bulwark supplies character concepts and recruitment stories. Its profiles do not supply finished combat builds. Delve currently supports Fighter, Rogue, Cleric and Wizard builds. Adding an entry to the design roster does not make its class playable.

## Playable roster

| ID | Character | Current build | Availability |
|---|---|---|---|
| `player` | Aldric | Fighter / Sentinel | Starter |
| `elara` | Elara | Rogue / Thief | Starter |
| `tharr` | Tharr | Cleric / Warpriest | Starter |
| `fenwick` | Fenwick | Wizard / Battle Magic | Starter |
| `raven` | Raven | Rogue / Thief prototype, duelist with Intimidation | Locked, meetable |
| `thistle` | Thistle | Fighter / Sentinel prototype, shortbow scout | Locked, meetable |

Raven uses the existing rogue sprite and Thistle uses the recruit sprite. Thistle has the Fighter/Sentinel progression rather than Ranger features; shield features have no effect without a shield. Her bow uses the generic equipment icon until bow artwork exists. These are explicit combat prototypes, not implementations of Swashbuckler or Ranger.

## Recruitment and personal progress

`RecruitmentCatalog` authors each playable arc. Raven needs a meeting, three wins as a party member and a floor boss win as a party member. Thistle needs a meeting, two party wins and a floor boss win. The player then chooses a separate overnight outpost stay. Neither meeting, swapping, completing combat requirements nor restarting a run directly unlocks a guest.

The combat steps are an initial playable adaptation of Raven's earned trust and Thistle's return to exploration. They do not replace the longer friendship and character stories below. Failed runs retain completed steps. Guest participation in their meeting fight does not count as companion participation.

`CampaignProgress` owns save-wide recruitment and outpost milestones plus per-leader personal journals. `LeaderObjectiveCatalog` supplies initial focus objectives for each playable leader, credited by existing meeting and victory hooks. Recruitment remains shared when a different character leads the next run. Progress saves contain identifiers and counters, never live combat objects.

## Full cast mapping

Source: [Bulwark cast index](../../bulwark/design/characters/README.md). These are adaptation targets; only the two rows marked prototype are currently meetable.

| Bulwark recruit | Intended class | Recruitment / outpost hook | Delve status |
|---|---|---|---|
| Arkus | Barbarian | Wounded after failed rite; earn trust and restore Smithy | Design only; class build needed |
| Sir Aldric | Champion | Atonement and outpost reputation; Training Yard | Design only; resolve name collision before import |
| Spore | Witch | Deep forest outsider; potion work and Apothecary | Design only; class build needed |
| Josen | Monk | Treat frontier injuries; Infirmary and Quiet Hand arc | Design only; class build needed |
| Thistle | Ranger | Abandoned campsite; exploration and gradual recovery from Stillness; Watchtower | Playable Fighter prototype; Ranger and friendship story pending |
| Grub | Druid | Wild garden discovered during expansion; Fields | Design only; class build needed |
| Sera | Magus | Frontier research and academic exile; Arcane Study | Design only; class build needed |
| Oskar | Oracle | War curse, legacy and ritual; Shrine | Design only; class build needed |
| Hazel | Thaumaturge | Recover lost collection; Reliquary | Design only; class build needed |
| Wynn | Bard | Stories gathered through sustained visits; Tavern | Design only; class build needed |
| Vasska | Psychic | Swamp encounter gated by Oskar's relationship arc; ritual | Design only; Oskar dependency and class build needed |
| Raven | Swashbuckler | Periodic visitor, bounties and friendship; no building | Playable Rogue prototype; Braggart and friendship story pending |
| Hilde | Summoner | Tavern resident revealed through friendship; earth eidolon | Design only; summoner/eidolon composition needed |
| Flick | Sorcerer | Encounter during magical disaster; safe containment at outpost | Design only; class build needed |

Delve's existing Aldric is the `player` Fighter. Bulwark's `aldric` is a separate Champion concept. No second Aldric is registered. A future adaptation must choose a distinct name and ID or deliberately revise the existing character with a save migration.

## Remaining content

- Full authored relationship/quest events and reputation gates from the source stories.
- Leader-biased event selection and character-specific dialogue.
- Intended classes, archetypes and ancestry mechanics for the wider roster.
- Character-specific art and combat balance for four members plus a temporary guest.
- An optional outpost unlock for manual companion control; current default remains leader-only.
