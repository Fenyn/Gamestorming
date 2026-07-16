# Bulwark — Friendship / Heart System

A Stardew-style relationship system layered over the outpost's cast (`design/characters/`). The player
builds bonds with the named characters; hearts unlock story, romance, and optional perks. **Core
system implemented** (`scripts/cozy/FriendshipSystem.cs`: points/hearts, gifts, talk, thresholds,
save round-trip); heart events, romance, and per-character preference content are still to come.

## Decisions (locked with user, 2026-07-13)
- **Earned by:** gifts (with per-character preferences) + daily talking + helping/quests. *(Not
  adventuring-together.)*
- **Hearts unlock:** dialogue & heart events + romance (deeper bonds). Optional extras: some domain
  perks, and new recipe/item unlocks. Domain perks are a nice-to-have, not required.
- **No decay** — friendship only ever grows. No neglect penalty (cozy).
- **Recruitment is NOT gated by friendship** — recruitable characters still join via their arrival
  triggers (found in forest, etc.). Friendship is a parallel, social/narrative track.
- **Documented exceptions (missables):** three characters deliberately break the rule above, by
  design (see `design/economy/characters.md`). **Raven** joins only after reaching 5-6 hearts as a
  visiting customer; **Vasska**'s swamp encounter gates on Oskar at 6 hearts plus her subquest;
  **Hilde**'s playable reveal fires from her own 2-4 heart event. These are the only
  friendship-gated recruitments; everyone else follows their arrival trigger.

## Who is befriendable
The named cast — `tharr`, `elara`, `fenwick`, and the recruitables `arkus`, `aldric`, `spore`,
`josen` (befriendable once they've arrived in town). The **player avatar is not befriendable.**
Townsfolk added later are befriendable by default.

## Heart scale
- Friendship is a **point total per character → hearts.** Proposed **250 points / heart, 0–10 hearts**
  (2,500 max), Stardew-parity. Romance opens a further track past a threshold (see below).
- Hearts are the display unit; points are the storage unit. No decay, so points only rise.

## Earning mechanics
- **Gifts (preferences).** Give an item from your inventory to a present character. Each character has
  **loved / liked / neutral / disliked / hated** preferences (item ids or item categories, themed to
  their vibe — e.g. Arkus the orc smith loves ingots/ore, Spore the leshy witch loves rare mushrooms &
  reagents, Fenwick the chef loves fine ingredients & cooked dishes). Points by tier (proposed:
  loved +80, liked +45, neutral +20, disliked −20, hated −40). **Gift cadence:** limited gifts per
  character per week (Stardew = 2) so it's a choice; a **birthday** (season+day per character) multiplies
  that day's gift. Gifting consumes the physical item from the Bulk inventory.
- **Daily talking.** First conversation with a character each day grants a small bump (proposed +12,
  once/character/day). Pairs with the (future) dialogue system — grows as dialogue does; for now the
  "talk" interaction is a proximity/interact action on the villager NPC.
- **Helping / quests.** Character requests and favors (fetch a resource, clear a territory, restore
  their building) grant point chunks. Restoring a character's associated building is a natural large
  bump for that character.

## What hearts unlock
Thresholds fire once (no decay, so once-earned stays). Proposed threshold rungs: **2 / 4 / 6 / 8 / 10**.
- **Dialogue & heart events (primary).** New dialogue lines gate on heart level; scripted **heart-event
  scenes** trigger at thresholds (backstory reveals, character moments). Content authored per character
  (event id + trigger heart). Leans on the future dialogue/cutscene system — for now, thresholds fire an
  event hook the dialogue system will consume.
- **Romance (primary).** A per-character `Romanceable` flag. Past a high threshold (proposed 8 hearts)
  plus a **courting token** (a special gift item), a distinct **romance track** opens (deeper events /
  partnership). Which characters are romanceable is authored content.
- **Domain perks (optional).** A character's hearts may grant escalating perks in their building/domain
  — Elara → better store prices, Arkus → forge discount/recipe, Josen/Medic → +healing, Fenwick →
  better meals. Wired through the existing effect/economy systems (a friendship-driven effect source).
  Optional per character; declared as data.
- **Recipe / item unlocks (optional).** A heart threshold can unlock a new recipe or item (Fenwick
  shares a dish recipe, Spore a potion recipe). Hooks the crafting/consumable systems via the existing
  `CategoryUnlock` / recipe-availability seam.

## Data model (when implemented)
- **Per-character friendship data** — either extend `CharacterProfile` or a sibling `FriendshipProfile`
  keyed by character id, authored alongside the profile: `Befriendable`, gift preference lists
  (loved/liked/disliked/hated by item id or category), `Birthday` (season+day), `Romanceable`, and the
  **heart-threshold unlock table** (heart → {dialogue/event id, optional domain-perk effect, optional
  recipe/item unlock}).
- **`FriendshipSystem`** (plain C#, testable): per-character points/hearts; `GiveGift(charId,itemId)`
  (preference lookup → points, consume item, enforce weekly cadence + birthday multiplier),
  `Talk(charId)` (once/day bump), `AddFriendship(charId,points,reason)` (quests/help); events
  `FriendshipChanged(charId)` and `HeartThresholdReached(charId,heart)` (drives event hooks + perk/recipe
  unlocks). No decay logic.
- **GameState** commands `GiveGift` / `TalkTo` (+ quest awards route through `AddFriendship`); query
  `GetFriendshipView()` (per character: hearts, points, gifted-this-week, talked-today, romance state).
- **Save** (bump SaveData version): per-character points, weekly-gift counters (reset on week rollover),
  seen heart-event ids, romance state.
- **Integration:** gifting consumes from the physical Bulk inventory; domain perks register as a
  friendship effect source into `OutpostEffects`/the economy; recipe/item unlocks flow through the
  crafting/`CategoryUnlock` seam; heart-event hooks await the dialogue system.

## Content authoring (per character, like the profiles)
Each befriendable character authors: gift preferences, birthday, romanceable flag, and the heart-event
/ perk / recipe unlock table. The SYSTEM is the framework; the WHO-LOVES-WHAT and event scripts are
content in the character files/design — framework-first, consistent with the rest of the project.

## Suggested implementation phasing
1. **Core system + save** — FriendshipSystem (points/hearts, gift preferences, talk, quest awards, no
   decay, threshold events), GameState commands/query, save round-trip, a `friendship_spike`. Minimal
   proving content (a couple characters' preferences).
2. **Interaction wiring** — "talk" + "give gift" on the villager NPCs (VillagerLoader), and a small
   friendship/gift UI (per the inventory-driven UI pattern).
3. **Unlocks** — wire domain perks (effect source) + recipe/item unlocks (CategoryUnlock seam) at
   thresholds.
4. **Heart events + romance** — once the dialogue/cutscene system exists; thresholds already fire hooks.
5. **Content** — author each character's preferences, birthdays, event scripts, romance tracks.
