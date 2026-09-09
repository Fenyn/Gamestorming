# delve — recruitment and the roster cycle

Built and decided parts have moved into core_concept.md ("Meetings"). What is left here is the
reasoning behind them and the proposals that are still open.

**Built:** the Wayfarer node kind, whole meeting rows per floor (`RunMapConfig.MeetingFloorsByStratum`),
the AI ally on team 1 (`CombatSetup.Allies`), its cautious planning (`AllyAiRules`), the draw
order (`RecruitPool`), the join on a won fight. Spikes: `run_meeting`, `ai_caution`.

**Still proposals:** the draw weighting below (role coverage, recency, the pinned pick), the other
three meeting flavors, what a Wayfarer does for a full party, and the opening's slot-2 character.

## Problem

A run allows 4 characters. The player starts a run with 1 to 4 start slots, and open slots fill
from meetings in the delve. Two things need answering:

1. Pacing. Slot 2 must fill in the first minutes of a run, 3 and 4 soon after. A party that
   reaches floor 2 at two members has been fighting 4-member encounter budgets the whole time,
   because budgets count every member, dead or alive.
2. Cycling. The roster is meant to grow large. Only 4 can appear per run, so the draw has to
   rotate the roster without leaving the party without a healer.

## Pacing: guaranteed meeting beats

Meetings are not left to the weighted node roll. The map generator places them the way it places
row 0 = Combat.

| Slot | Guaranteed by | Reasoning |
|---|---|---|
| 2 | Floor 1, row 1. Every path. | The first fight is solo. The second node is not. |
| 3 | Floor 1, row 5, the row before the Campsite. | Full party for the Dire Wolf lair. Rows 3 and 4 stay free so the Elite and Rest top-up passes have somewhere to land. |
| 4 | Floor 2, first half. | Level 5-7. Still most of a run left to play them. |

Nothing joins after the floor 2 boss. A member arriving at level 8 gets one floor of screen time,
and the party spent two floors under strength to get them.

Backstop: if a slot is still open when the party reaches a Campsite, someone walks into the
firelight. This is the cheapest possible fallback and it fits the fog fiction, so the guarantee
never depends on the player picking the right lane.

Decided: a visible node kind rather than an overlay on Combat or Event. A guaranteed beat the
player cannot see is a beat they cannot plan around. The backstop is not built - a whole meeting
row on every path makes it unreachable today.

## Meeting flavors

Four shapes. All of them end the same way: the character joins for the run.

### 1. Third-party battle (the FF Tactics one) - built

A Skirmish node where an NPC is already fighting the monsters when the party arrives. Win the
fight with the NPC alive and they join. Let them die and the slot stays open until the next beat.

Cheap to build today. `CombatSession.IsPlayerControlled` is `TeamId == 1 && !_aiControlled`, so an
NPC placed on team 1 and added to `_aiControlled` is an ally the player does not command, fights
the monsters on its own, and gives flanking, with no engine change. The engine tests team relations
as `TeamId ==` equality everywhere (AI targeting, auras, reactions, pathfinding), so a genuine
neutral third faction is a real piece of work. It is not needed for this.

Variants, same node type:
- Captive. The NPC starts prone or restrained near the enemy and is freed by an action.
- Losing badly. The NPC starts at low HP, so the party's arrival is the reason they lived.
- Escort. The NPC wants to reach the far edge. A fail state that is not a TPK.

Deferred to a real faction layer: two monster factions fighting each other, which the party can
join either side of.

### 2. Happenstance

An event node. A choice, sometimes a check (Diplomacy, Medicine on a wounded stranger, gold, an
item they need). The event system already supports this shape, so it costs nothing but content.

### 3. Duel

The NPC is hostile. Reduce them to 0 and they yield rather than die, then join. Fits a brigand, or
a mage whose magic went off before the introductions did. Needs a yield path in the encounter end
condition.

### 4. Campsite arrival

Text only. The backstop above, and the quiet one the pacing guarantee leans on.

Suggested mix per run: one third-party battle, one happenstance, the rest by campsite.

## Once the party is full

Meetings after 4/4 must not become dead nodes. They convert:

- The NPC fights alongside the party for that one encounter and then goes their own way. The
  FF Tactics guest unit. Free to build, since it is the same AI ally as flavor 1.
- Or they give something: a ward charge, directions that reveal the next rows, a piece of gear.

## Cycling: the draw pool

Built: `RecruitPool` walks catalog order, skipping the leader and anyone already in the party. With
four characters that is the whole rotation. The rules below matter once the roster outgrows a run.

Draw rules:

- Size: open slots + 2, so the draw has slack.
- Role coverage. The draw weights up whatever the starting party lacks. No healer in the start
  party means the healers weight up. This prevents a run with no way to spend a Campsite.
- Recency penalty. A character met in the last run or two draws at reduced weight, so the roster
  rotates instead of showing the same three faces.
- One pinned pick. Feat attunement is the per-character permanence axis, so the player has a
  reason to want a specific character. Let them pin one at the outpost for gold, guaranteed into
  the draw. That settles cycling variety against attunement investment without weakening either.
- Not-yet-recruited characters are in the pool too. Meeting one for the first time is what starts
  their recruitment arc.

## From met to bound

The core concept already sets the shape: meet, hook, quest, stay a night. The draw pool is the
front door. A character the player has never recruited enters a run as a guest, the meeting fires
their hook, and completing it makes them start-eligible forever.

Guests that leave mid-run: not proposed. Losing a member the player has run for an hour reads as
a punishment for something they did not do.

## The opening and slot 2

The opening ends with a second character waiting at the camp. That character is fixed, not drawn,
and is the permanent slot 2 unlock.

Recommend Tharr. A cleric makes the level 1-4 stretch survivable, Campsite and Treat Wounds have
something to do from the first run, and the chapel of Aveline gives the fiction a place to point.
Elara is the other reasonable pick: a traveler the fog took, who does not answer questions about
where she came from, which reads well against a player character who cannot leave either.

## Roster size versus the engine

The catalog has 4 characters, because Pf2e.Core has compiled class features for Fighter, Cleric,
Wizard and Rogue only. A large roster cycling cannot happen until that changes. Phasing:

1. Now. Build the meeting system against the 4-character catalog. The draw is trivial at this
   size, and the pacing guarantee is what matters.
2. Next. Grow the roster with new subclass and Free Archetype combos on the four compiled
   classes, which is data-only work in `VariantComboDefinition`. A bow Ranger reads as a Rogue
   with the Archer dedication. A Champion reads as a Fighter (Sentinel) with Bastion and a divine
   deity. This can plausibly reach 10 to 12 distinct characters.
3. Later. Real class engines for the classes the Bulwark cast wants: Barbarian, Ranger, Champion,
   Bard, Monk, Witch, Druid, Magus, Oracle, Thaumaturge, Psychic, Swashbuckler, Summoner,
   Sorcerer, Alchemist.

Character source is the Bulwark cast (`bulwark/design/characters/`), 19 profiles with class and
ancestry already assigned. Hooks that fit the delve without rewriting: Thistle (found at an
abandoned campsite, already written as someone the wilderness hollowed out), Spore, Raven (a duel),
Flick (a duel that starts as an accident), Hilde, Josen, Hazel.
