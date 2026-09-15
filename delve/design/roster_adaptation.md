# Bulwark roster in Delve

[Authored feat tracks through level 10](roster_feats.md) are now wired for every character.

The [class rules review](class_rules_review.md) tracks remaining Remaster and class-feat work for all eighteen playable classes. Native class builds are playable; they are not yet complete rules implementations.

All eighteen Bulwark identities are registered. Aldric (`player`), Elara, Tharr and Fenwick remain the four starters. The other fourteen are locked, meetable recruits with their intended classes and authored combat builds. The four-value `WayfarerChassis` adapter has been removed.

Sir Aldric (`aldric`, Champion) and the starter Aldric (`player`, Fighter) are distinct characters. Their IDs and campaign progress do not collide.

## Playable recruit builds

| Character | Native class / specialty | Authored class mechanics |
| --- | --- | --- |
| Arkus | Barbarian / Fury | Quick-Tempered Rage, temporary HP, melee rage damage |
| Sir Aldric | Champion / Justice | Lay on Hands, Shield Block, Retributive Strike |
| Spore | Witch / Grandmother Mulch | Primal spellbook, Clinging Ice hex, Life Boost |
| Josen | Monk / Quiet Hand | Powerful Fist, Flurry of Blows, unarmored proficiency |
| Thistle | Ranger / Precision | Hunt Prey, first-hit precision damage |
| Grub | Druid / Leaf | Prepared primal spells, Cornucopia, Shield Block, Voice of Nature |
| Sera | Magus / Laughing Shadow | Bounded prepared casting, Ignition Spellstrike, recharge, Arcane Cascade, Dimensional Assault |
| Oskar | Oracle / Battle | Spontaneous divine casting, Weapon Trance, automatic Oracular Warning, Cursebound |
| Hazel | Thaumaturge / Chalice | Exploit Vulnerability, personal antithesis, implement empowerment, chalice healing |
| Wynn | Bard / Maestro | Spontaneous occult casting, Courageous Anthem, Lingering Composition, Soothe |
| Vasska | Psychic / Silent Whisper | Intelligence-based occult casting, Amped Daze, Unleash Psyche and backlash |
| Raven | Swashbuckler / Braggart | Demoralize earns Panache; Precise Strike and Confident Finisher |
| Hilde | Summoner / Earth | Manifested eidolon, shared HP/actions/MAP, Act Together, Boost Eidolon, Evolution Surge |
| Flick | Sorcerer / Elemental | Charisma-based primal repertoire, Elemental Toss, Sorcerous Potency |

Builds use native HP, initial proficiencies, key abilities, casting traditions and progression through levels 1-10. This is an authored playable build per recruit, not a complete class-builder or the full PF2e feat/subclass catalog. The engine's original four starter builds stay intact.

Prepared casters fill their available ranks from their authored spellbooks. Spontaneous casters use a repertoire. Sorcerer/Oracle slots, Psychic slots, and Magus/Summoner bounded slots have separate tables. Focus-only Champion casting has no fabricated rank-1 daily slots. In-place level gains and new builds use the same definitions.

## Combat and recovery

Class actions appear in the Skills flyout and use the existing world targeting. The action bar shows Focus and relevant class resources. Unit labels show active class states and buffs. The guest AI uses class actions before planning its remaining movement, attacks or spells.

Hilde's eidolon occupies its own tile and never gets an independent initiative turn. It shares Hilde's HP, actions and multiple attack penalty. Eidolon Advance uses normal pathfinding and movement reactions. Act Together currently offers one authored pairing: single-target Electric Arc plus an eidolon Strike against that target. Spell effects hitting both linked bodies use the greater damage or healing result rather than applying both to the shared pool.

Chalice recovery occurs during a ten-minute rest. Refocus restores Focus, restores two points for Psychic amps, and reduces Cursebound. Overnight recovery refreshes daily resources. Encounter bindings clean up temporary class state and callbacks without refilling spent Focus or spell slots.

## Recruitment

The run seed shuffles eligible guests. Every recruit can appear without needing fourteen meeting rooms in one expedition. A guest is built at the current party level; a dead, declined or dismissed guest cannot be redrawn in the same run.

Existing Raven and Thistle recruitment requirements remain. The twelve additional arcs require a meeting, two wins as an active companion, a floor guardian win, then an explicit overnight outpost stay. Meeting-fight guest participation does not count as companion participation. Permanent unlocks and personal objectives use the existing campaign save format.

The source introductions, outpost goals and original camp seating are retained. Full Bulwark friendship chains, reputation gates, bespoke character art and ancestry mechanics remain separate content work. Sprites reuse the existing authored hero sets; the eidolon currently uses placeholder art.

## Rules coverage limits

The native classes are now executable, but combat still uses Delve's small, approximate preset spell library. These limits are explicit:

- Progression is authored through level 10. Full feat choices, Free Archetype progressions for the new recruits, and higher-level class features are not included.
- Retributive Strike protects adjacent allies because the engine's ally-reaction discovery has a fixed 5-foot radius. Its tooltip states that limit.
- Spellstrike currently delivers Ignition; Arcane Cascade uses fire. The UI does not yet offer arbitrary spell/weapon pairings.
- Flurry resolves two normal strikes; its combined resistance treatment is not implemented. Confident Finisher uses one target.
- Grandmother Mulch uses Clinging Ice and Life Boost as the current patron loadout. The cauldron familiar is represented in the character's lore, not as a separate tactical unit.
- Amped Daze implements its damage and critical-failure Stunned effect; its mental weakness rider and the remaining Silent Whisper psi cantrips are not included.
- Exploit Vulnerability uses personal antithesis, not automated best-weakness discovery or the full implement upgrade tree.
- Elemental blood-magic riders, the complete Oracle granted spell list, and counter-performance reactions are not included. Soothe currently implements its healing component.
- The eidolon uses the shared health component's damage defenses. Its separate resistance/weakness profile and free selection of Act Together pairings need a future core extension.

## Verification and testing

`scenes/dev/wayfarer_class_spike.tscn` checks the full roster at levels 1, 2, 5 and 10, class identity, spell rank availability, in-place progression, action/focus costs, healing, Spellstrike recharge, Flurry, Panache and linked eidolon damage/healing.

`scenes/dev/wayfarer_combat_test.tscn` opens a generated combat with Sera, Hilde, Wynn and Josen. Its `PreviewParty` array can select any catalog IDs without unlocking them in campaign saves. `wayfarer_shot_spike.tscn` runs the existing rendered combat checks with that party.

Source identities: [Bulwark cast](../../bulwark/design/characters/README.md). Class baselines were read from the local pf2e-source class packs used by Pf2e.Core.
