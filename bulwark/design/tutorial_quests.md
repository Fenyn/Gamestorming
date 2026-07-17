# Bulwark — Tutorial Quest Arc: "The First Season"

The guided quest chain that bridges the Day 1–5 onboarding (`design/tutorial.md`) into open play.
Where the onboarding teaches *verbs* (gather, build, rest), this arc teaches the *systems*: what each
building unlocks, how tier upgrades work, why combat funds and gates the outpost, and how the forest's
depths open only once the beast that guards them is dead. Twelve major objectives with scripted story
beats between them, paced against Spring Year 1 (`design/economy/pacing.md`), with a boss at the hinge.

**This chain is the canonical reference for the early game (rewritten 2026-07-16).** The flow is now
directed, not free-order: Day 1's clock is frozen and closes on a scripted sequence; Day 2 tours the
ruins and points at two specific builds; the dire wolf gates the Elderwood; the Trading Post needs
Elderwood hardwood; Arkus is the first recruit and his wake opens both the Smithy and the Infirmary.
`design/tutorial.md`, `design/economy/buildings.md`, and `design/economy/characters.md` all defer to
the table below where they disagree.

Character arrivals follow `design/economy/characters.md`. **Arkus is the first recruit**, found on the
road after the wolf kill; his wake is what makes the Smithy AND the Infirmary commissionable. **Josen
no longer gates the Infirmary** — he arrives via random event 1-3 days after it is built.

## Principles

- **Each quest teaches exactly one system**, delivered by the NPC who owns it.
- **The opening is directed, not free.** Day 1 is a single frozen-clock task (repair the lodging) that
  closes on a scripted cutscene. Day 2 hands the player two specific builds (Farmhouse + Tavern), not a
  menu of three. Freedom widens only once the base systems are taught.
- **Construction downtime is the teacher's window.** One-building-at-a-time means Tharr's build days
  leave the player idle — combat, gathering, and expedition quests are slotted into those gaps, so the
  rhythm is commission → fight/gather while he builds → building rises → commission the next.
- **The wolf is the spine.** The near forest (Thornwood / Verdant Fringe) is safe; the deep forest
  (Elderwood) is gated by a dire wolf that guards the passage in. Killing it opens the Elderwood, which
  is what every later building's hardwood and the outsiders who live there (Spore, Thistle) sit behind.
- **Auto-start, auto-complete.** Every quest starts from a story flag / event and completes from one —
  no "turn in" friction unless talking to the NPC IS the lesson (quests 1 and 6).

## The wolf thread (narrative spine)

A dire wolf has come down out of the deep Elderwood and holds the passage between the near forest and
the deep. It is the arc's hinge:

- **Foreshadowed on the first night.** The scripted Day-1 close ends on a howl heard through the dark
  (`design/intro.md`, "The Hearth and the Howl"). No name yet — just a splinter under the day.
- **It guards the Elderwood.** The near forest is safe to gather in; the party cannot press deeper
  until the wolf is dead. Its death (`dire_wolf_slain`) is what unlocks the Elderwood territory — the
  unlock lives on the territory definition (`elderwood` → `dire_wolf_slain`), not on Command Post
  tier 2 anymore.
- **It is beatable with starting gear.** The wolf is tuned as a Severe encounter for a level 1–2 party
  of four (dire wolf + a pack-mate or two), winnable with the gear the party already carries — the
  Smithy does not exist yet and is not needed. It is a test of using the systems already taught (meals,
  Treat Wounds, three actions), not a gear check.
- **It is the creature that broke Arkus.** On the first walk home after the kill, the party finds Arkus
  wounded on the road — the same beast, the same ground. He is the first recruit.
- **It motivates the gear loop as forward prep.** Arkus wakes once the Trading Post stands and asks for
  a forge — not to fight the wolf (already dead) but because "what he carried was not enough" for
  whatever the Elderwood sends next. First Steel and the Infirmary are preparation for the deep forest,
  not for the boss behind them.
- **The outpost's growth is a later chapter.** With the Elderwood open and the forge lit, Command Post
  upgrade tiers would be the natural next milestone — but they are DEFERRED pending design (2026-07-16
  decision): the Command Post's purpose is the planning table that guides the whole outpost's repair,
  not a tier ladder of its own. This arc now closes at Mend the Wounded / First Steel, handing off to
  open play; a tier ladder can be designed and slotted in later without touching this chain.

## The chain

| # | Quest | Teaches | Starts when | Objectives | Completes when |
|---|---|---|---|---|---|
| 1 | **Repair the Lodging** | Gathering: tools, harvest, carry, the day clock | Intro ends (`intro_complete`) | Gather 15 wood · Gather 10 stone · Return to Tharr | Turn 15 wood + 10 stone in to Tharr (`lodging_repaired`) |
| — | *Scripted Day-1 close* — Fenwick at the hearth, then a wolf's howl overnight; the day closes automatically (no "rest" quest). See `design/intro.md`. | `lodging_repaired` | — | Advances to Day 2, sets `first_rest`, unfreezes the clock |
| 2 | **The Planning Table** | The build system + a tour of the three ruins (camera pans) | Day 2, talk to Tharr (`first_rest`) | Follow Tharr's tour · Visit the planning table | Table visited (`planning_table_shown`) |
| 3 | **Raise the Hearths** | Construction rhythm: bundles, one-at-a-time, Tharr's build days | `planning_table_shown` | Raise the Farmhouse to stage 1 · Raise the Tavern to stage 1 (Trading Post is deferred) | `farmhouse_built` AND `tavern_built` |
| 4 | **First Blood** | Combat: touching a roamer, the 3-action turn, loot drops | First building commissioned (`first_commission`) | Win 2 encounters near the gate | 2 encounter victories |
| 5 | **First Harvest** | The farm loop: seeds → till → plant → water → harvest | `farmhouse_built` | Plant the starter seeds (granted via dialogue) · Harvest 6 crops | 6 crops harvested |
| 6 | **Fenwick's Table** | Where the harvest goes: the hearth (meal buffs) | Quest 5 complete AND `tavern_built` | Give Fenwick 3 fresh crops · Eat the meal he cooks | Meal buff active |
| 7 | **The Wolf of the Fringe** | Boss encounters; preparation from taught systems, not gear | Quest 6 complete | Track the dire wolf to the forest passage · Slay it | Boss encounter won (`dire_wolf_slain`) |
| 8 | **Restore the Trading Post** | Territory progression: the Elderwood opens, hardwood is deep-forest timber | Quest 6 complete | Enter the Elderwood · Gather hardwood · Fund the Trading Post | `trading_post_built` |
| — | *Arkus found* — first return to the outpost after `dire_wolf_slain`; sets `arkus_found`, Arkus placed as an unconscious resident. *Elara opens the store* on `trading_post_built`. | — | — | `arkus_found` |
| 9 | **The Smith and the Sickbed** | Character-first arrivals; one wake unlocks two buildings | `arkus_found` AND `trading_post_built`, resolved at the next day-start (wake dialogue sets `arkus_awake`) | Speak with Arkus · Commission the Smithy · Commission the Infirmary | `smithy_built` AND `infirmary_built` |
| 10 | **First Steel** | Smithy crafting: metal → gear, gold + reagents → runes | `smithy_built` | Craft or upgrade one piece of gear | First craft/upgrade at the forge |
| 11 | **Mend the Wounded** | Attrition & recovery (Treat Wounds) | Josen arrives, 1-3 days after `infirmary_built` (`josen_arrived`) | Speak with Josen · Treat a squad member's wounds | First Treat Wounds at the Infirmary |

Dropped from the prior arc: **The Three Hearths** (split — Farmhouse+Tavern become quest 3; Trading
Post moves to quest 8), **Share the Harvest** (selling removed; folded into quest 6 as Fenwick's
Table), **The First Expedition** (retired — the wolf hunt is the expedition now), **Into the
Elderwood** (folded into quest 8's guidance objectives), and **The Bulwark Grows** (Command Post
upgrade tiers are deferred pending design — see `design/economy/buildings.md`). After quest 11 the log
hands over to organic play: Chapel (Oskar), Fishing Dock, Apothecary, and the Summer tier ladder emerge
from the pacing schedule without tutorial framing.

## Quest notes & NPC voice

**1 — Repair the Lodging (Tharr).** The gathering primer, and the whole of Day 1. The clock is FROZEN
for this day (see `design/tutorial.md`): the player can take as long as they like, brush into an
optional fight or two, and the day will not end until the task is turned in. Fifteen wood, ten stone —
small enough for one trip. Combats near the gate are welcome texture but never required; the quest
gates on materials, not blood. Turning in the bundle to Tharr sets `lodging_repaired` and triggers the
scripted close.

**— Scripted Day-1 close (Fenwick, then the wolf).** Not a quest — a cutscene that fires on
`lodging_repaired` and replaces the old "Rest for the Night" quest. Two beats: Fenwick examining the
newly usable hearth (warm, self-deprecating, food-adjacent — "a proper hearth under all the soot"),
then, after the fade, a long wolf howl heard through the dark. The day closes on its own; the player
does not choose to sleep. Sets `first_rest`, advances to Day 2, and unfreezes the clock so time now
runs. Full draft in `design/intro.md` ("The Hearth and the Howl").

**2 — The Planning Table (Tharr).** Day 2. Tharr walks the player past the three ruins — the farmhouse
frame, the hearth Fenwick claimed, and the collapsed storefront Elara has her eye on — the camera
panning to each (the `camera` staging step). He introduces the planning/command table as where every
building starts. He is plain about the order: two of the three go up now; the storefront must wait, its
timber comes from a forest they cannot yet reach. Visiting the table sets `planning_table_shown`.

**3 — Raise the Hearths (Tharr).** The construction lesson, narrowed to two directed builds: the
**Farmhouse** and the **Tavern**, both cheap Verdant Fringe bundles. The **Trading Post is explicitly
deferred** — its construction bundle now needs Elderwood hardwood, and the Elderwood is unreachable
until the dire wolf is dead, so Tharr sets it aside until "the forest gives up its harder timber."
One-at-a-time means the two builds span several days; quests 4 and 5 fill the gaps. Completes when both
`farmhouse_built` and `tavern_built` are set.

**4 — First Blood (Tharr).** The combat introduction, slotted into the first construction downtime: the
moment the player commissions their first building (`first_commission`), Tharr has a build day ahead and
hands them a soldier's chore — thin the goblins by the old quarry. Two victories, near the gate, tuned
easy. Many players will already have brushed into a fight on the Day-1 gathering trip; First Blood is
the directed version either way, and its counter only counts victories after it starts. Tharr's
`first_combat_victory` debrief (keep weapons sharp, Treat Wounds before pressing deeper) fires on
whichever victory comes first.

**5 — First Harvest (Fenwick / ambient).** The farm loop. No store exists yet — the Trading Post is
still deferred — so the **starter seeds are granted via dialogue** (a dialogue `item` effect) rather
than bought; the farming intro line hands them over so the quest never stalls on a store that isn't
there. Six crops: three for Fenwick's table (quest 6), three for the player's own use. Teaches till →
plant → water → grow-over-days → harvest.

**6 — Fenwick's Table (Fenwick).** The harvest in hand IS the lesson, narrowed to the hearth alone —
**selling is removed** here, because there is still no store to sell to. Give Fenwick three fresh crops;
he cooks; the player eats; the meal-buff icon on the HUD is the payoff. One economy sink, no busywork,
no dependency on a building that hasn't gone up. Completing quest 6 is the hinge: it starts BOTH the
wolf hunt (quest 7) and the Trading Post restoration (quest 8) in parallel.

**7 — The Wolf of the Fringe (Tharr / Elara, the hinge).** The howl from the first night pays off. A
fixed lair site appears at the forest passage while the quest is active (one-shot boss encounter, not a
roamer): the dire wolf, a Severe-budget fight for a level 1–2 party of four (dire wolf + a pack-mate or
two, exact composition at tuning time). **It is beatable with starting gear — the Smithy does not exist
yet and is not required.** Everything already taught is the strategy: eat a meal (quest 6), treat
wounds, spend all three actions well. Victory sets `dire_wolf_slain`, which **opens the Elderwood** (the
gate is the wolf, not a building tier) and, on the walk home, surfaces Arkus.

**8 — Restore the Trading Post (Tharr / Elara).** Runs in parallel with the wolf hunt but can only
finish after it. The store's construction bundle needs Elderwood **hardwood** (90 wood / 60 stone /
30 hardwood), and hardwood only exists in the Elderwood, which only opens once the wolf is dead. So the
quest's guidance objectives — **enter the Elderwood, gather hardwood** — double as the player's first
push into the deep forest (this is where the retired "Into the Elderwood" quest's content now lives).
Elara's store-open line fires on `trading_post_built`.

**— Arkus found (cutscene).** On the party's first return to the outpost after `dire_wolf_slain`, the
full squad finds Arkus wounded on the road — the same beast, the same ground the party just survived
(`design/intro.md`, "On the Road Home"). Sets `arkus_found`; Arkus is placed as an unconscious resident.
He does not speak yet.

**9 — The Smith and the Sickbed (Arkus).** Arkus wakes — resolved at the day-start after both
`arkus_found` and `trading_post_built` are set — and his blunt asks make TWO buildings commissionable at
once (`design/intro.md`, "What Was Not Enough"). He wants a **forge**: what he carried was not enough,
and the next thing out of the deep forest will be worse. He also names the plain problem that the
outpost patched him on a table with no proper place to mend — so a **sickbed**, before it is needed.
His wake sets `arkus_awake`, which gates BOTH the Smithy and the Infirmary (`RequiredFlagId =
arkus_awake` on each). Their construction bundles are wood + hardwood mixes (Smithy: 90 wood / 40
hardwood / 25 goblin_fang; Infirmary: 120 wood / 30 hardwood / 20 herb) — the hardwood is affordable
because the Elderwood is already open by now. The quest completes when both `smithy_built` and
`infirmary_built` are set.

**10 — First Steel (Arkus).** The forge stands; now it produces. Craft or upgrade one piece of gear —
framed by Arkus as forward preparation: "carry better." Tier-1 recipes must include at least one piece
craftable from drops the player already holds, so the quest never stalls on missing metal.

**11 — Mend the Wounded (Josen).** **Josen no longer gates the Infirmary** — Arkus's wake did (quest 9).
Instead the Infirmary *standing* is what draws Josen in: a standing sickbed for exactly the wounds
frontier life produces. He arrives via a **random event 1-3 days after `infirmary_built`**
(`josen_arrived`), which starts this quest. Speak with him, then treat a squad member's wounds. Teaches
attrition and out-of-combat recovery. The short randomized delay keeps his walk-in from feeling scripted
while guaranteeing he shows up soon after the building he belongs to exists.

**After quest 11 — open play.** The arc ends here and hands over to organic play. Command Post upgrade
tiers — the natural "the planning table does UPGRADES, not just new buildings" follow-on — are
DEFERRED pending design (2026-07-16 decision): the Command Post's purpose is the planning table that
guides the whole outpost's repair, not a tier ladder of its own. When tiers are designed, they slot in
here without reopening this chain (see `design/economy/buildings.md`).

## Story flags / hooks required

| Hook | Exists? | Notes |
|---|---|---|
| `intro_complete` | yes | Starts quest 1 |
| `lodging_repaired` | yes | Set by quest 1 turn-in; triggers the scripted Day-1 close |
| `first_rest` | yes (retriggered) | **Now set by the scripted Day-1 close**, not by a "rest" quest. Gates Tharr's Day-2 planning dialogue |
| `planning_table_shown` | yes | Set by quest 2; starts quest 3 |
| `farmhouse_built` / `tavern_built` | yes (derived) | Both required to complete quest 3; `farmhouse_built` starts quest 5 |
| `first_commission` | **new** | Set on the first building commissioned; starts quest 4 (First Blood) |
| `first_combat_victory` | yes | Tharr's combat debrief line |
| Encounter-victory count | yes/new | Quest objective advancing on combat victories (First Blood: 2) |
| Harvest-count progress | new | Quest 5 objective on crop-harvest events (6) |
| Starter-seed grant | new | Dialogue `item` effect in the farming intro line (no store exists yet) |
| Deliver-crops + meal-eaten | new | Quest 6: consume 3 fresh crops handed to Fenwick, one-shot on first meal buff |
| Boss lair site + one-shot encounter | yes | Fixed forest-passage site, appears while quest 7 is active, plays the dire-wolf encounter, despawns on victory, sets `dire_wolf_slain` |
| `dire_wolf_slain` | yes | Boss victory. **Unlocks the Elderwood** (territory `UnlockFlagId`), starts the Arkus-found gate |
| Elderwood territory `UnlockFlagId` | **new** | `elderwood` → `dire_wolf_slain` on the territory definition; `GameState.IsBiomeUnlocked` = building effects OR this flag |
| `trading_post_built` | yes (derived) | Completes quest 8; Elara store-open; half of quest 9's start gate |
| Hardwood in Trading Post bundle | new | 30 hardwood added to the construction bundle — the Elderwood gate made economic |
| `arkus_found` | **new** | Set by the Arkus-found cutscene on first return after `dire_wolf_slain` |
| `arkus_awake` | **new** | Set by Arkus's wake at the day-start after `arkus_found` + `trading_post_built`; gates Smithy AND Infirmary commissionability |
| `smithy_built` / `infirmary_built` | yes (derived) | Both required to complete quest 9; `smithy_built` starts quest 10, `infirmary_built` starts Josen's arrival timer |
| Craft/upgrade-at-smithy trigger | new | One-shot on first smithy craft; completes quest 10 |
| `josen_arrived` | yes (repurposed) | Now set by a **random event 1-3 days after `infirmary_built`**, NOT by a party wound; starts quest 11. No longer gates the Infirmary |
| Treat-Wounds-used trigger | new | One-shot on first Infirmary treat; completes quest 11 |

**Retired flags/hooks** (from the prior arc, no longer wired): `first_building` (quest-1 start moves to
`intro_complete`), `first_expedition_cleared` (no First Expedition quest — the wolf hunt is the
expedition), `arkus_arrived` (replaced by `arkus_found` + `arkus_awake`), the Josen "first party wound"
trigger (replaced by the post-`infirmary_built` random event), the sell-count objective (selling is
removed from quest 6), and `command_post_tier2_reached` / `command_post_tier2_built` (no Bulwark Grows
quest — Command Post upgrade tiers are deferred pending design).

**Commissionability gate (unchanged mechanic, new flags).** The Smithy and Infirmary must be HIDDEN
from the planning table until their `RequiredFlagId` is met — now `arkus_awake` for BOTH (was
`arkus_arrived` / `josen_arrived`). This is the character-first rule made mechanical, and it extends to
later buildings too (Spore→Apothecary, Thistle→Watchtower), so the gate stays a data field on the
building definition, not a special case.

## Out of scope for this arc

Chapel/Oskar, Fishing Dock, Apothecary, romance/heart events, the Sunken Reach (its unlock is TBD,
deferred with the Command Post's upgrade tiers) — all arrive through the pacing schedule as organic
play, not tutorial quests. The dire wolf's exact stat
composition is a combat-tuning task. Arkus's combat recruitment (joining the squad in battle) is a
later content pass — this arc only needs his `arkus_found` / `arkus_awake` flags and his talk/wake
dialogue. Josen's recruitment into the combat roster is likewise deferred; quest 11 only needs his
arrival flag and one talk entry.
