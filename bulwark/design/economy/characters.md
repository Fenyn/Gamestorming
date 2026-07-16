# Bulwark: Character Arrival Economy

This doc is the unlock table for all 14 non-starting characters: the concrete mechanical trigger
that brings each one to the outpost, and the pattern that trigger follows (whether the character
unlocks a building, a building unlocks the character, the arrival is missable, or it fires from a
field encounter). Each character's fiction, personality, and story arc stay in that character's own
file under `design/characters/`. This doc only resolves the mechanics and checks that the triggers
form a workable sequence across a normal Year 1.

Two patterns recur throughout the roster:

- **Character-first.** The character's arrival trigger is an exploration or combat event, and their
  arrival is what makes their associated building commissionable. Arkus, Josen, Spore, Thistle,
  Aldric, Sera, and Hazel all follow this shape.
- **Building-first.** The building already exists or reaches a named tier, and that milestone is
  what draws the character in. Oskar, Grub, Wynn, and Hilde follow this shape.

Raven, Vasska, and Flick sit outside those two: Raven and Vasska are missable, and Flick fires from
a swamp expedition event rather than a building or character state.

## Unlock table

| Character | Class | Trigger | Pattern | Building relationship | Source doc |
|---|---|---|---|---|---|
| Arkus | Barbarian | Clear the first forest expedition encounter; found wounded on the return trip | character-first → Smithy | Arrival unlocks Smithy construction | `characters/arkus.md` |
| Josen | Monk | A party member ends a combat wounded or downed for the first time (fallback: mid-Spring, Year 1, if this has not yet happened) | character-first → Infirmary | Arrival unlocks Infirmary construction | `characters/josen.md` |
| Spore | Witch | The Elderwood biome is explored (first expedition into it) | character-first → Apothecary | Arrival unlocks Apothecary construction | `characters/spore.md` |
| Thistle | Ranger | The far-forest campsite zone, deep in the Elderwood, is discovered | character-first → Watchtower | Arrival unlocks Watchtower construction | `characters/thistle.md` |
| Aldric | Champion | Eight buildings have been constructed at the outpost | character-first → Training Yard | Arrival unlocks Training Yard construction | `characters/aldric.md` |
| Sera | Magus | Trading Post reaches tier 2 | character-first → Arcane Study | Requires Trading Post already at tier 2; arrival unlocks Arcane Study construction | `characters/sera.md` |
| Oskar | Oracle | The Chapel is constructed | building-first | Requires Chapel already constructed | `characters/oskar.md` |
| Grub | Druid | Farmhouse reaches tier 2 and a territory-expansion milestone is reached | building-first | Requires Farmhouse already at tier 2 | `characters/grub.md` |
| Hazel | Thaumaturge | The party holds a proposed 8 monster trophies or rare drops (current carry + warehouse count) | character-first → Reliquary | Arrival unlocks Reliquary construction | `characters/hazel.md` |
| Wynn | Bard | Kitchen reaches tier 2 (the tavern common room exists) | building-first | Requires Kitchen already at tier 2 | `characters/wynn.md` |
| Hilde | Summoner | Kitchen reaches tier 3 (boarding rooms exist); PC-reveal follows at hearts 2-4 | building-first | Requires Kitchen already at tier 3; rents a room there as townsfolk | `characters/hilde.md` |
| Raven | Swashbuckler | Trading Post and Kitchen are both built and a day threshold passes (begins visits); recruitment at hearts 5-6 | missable | Requires Trading Post and Kitchen already constructed (both commissioned within the first days of Year 1) | `characters/raven.md` |
| Flick | Sorcerer | An early swamp expedition encounter | expedition event | None; found in the field | `characters/flick.md` |
| Vasska | Psychic | Oskar reaches 6/10 hearts, the swamp biome is explored, and a recruitment subquest is completed | missable | None directly; gated behind Oskar's heart level, not a building | `characters/vasska.md` |

## Character notes

### Arkus

Arkus is found wounded and unconscious after a territory expedition, dragged back by the outpost's
patrol. Wiring that to "clear the first forest expedition encounter" makes the trigger literal: the
party proves it can survive the same ground that broke him, and the patrol that finds him is the
party returning from that fight. No building needs to exist first. His arrival is what makes the
Smithy commissionable in the first place.

### Josen

Josen already lives in the wilderness near the outpost, drawn by "the stream of injuries and
sickness that frontier life produces." The first time a party member ends a fight wounded or downed
is the moment that stream becomes real to him, so it is the natural trigger. The mid-Spring, Year 1
fallback date exists so a cautious or lucky player cannot accidentally lock him out by never taking
a bad hit; he arrives on schedule regardless. His arrival unlocks the Infirmary.

### Spore

Spore has lived in the Elderwood for longer than anyone can measure, and she is found there "crouched
over her cauldron." Her trigger is simply reaching that part of the map: the Elderwood biome being
explored, on the party's first expedition into it. There is no day count or combat gate beyond that,
because her fiction never suggested she was waiting for anything. She was always there; the party just
had to walk far enough, once they were able to. That "once they were able to" is the one mechanical
change from the prior two-biome draft: the Elderwood is now a gated territory rather than an
un-gated deep zone within a single forest biome, so Spore's trigger cannot fire until the Command
Post's tier 2 Elderwood unlock has already opened the biome (see the ordering-check below). Her arrival
unlocks the Apothecary.

### Thistle

Thistle is found at a campsite that is "clearly long-established but barely maintained," sitting at
the far edge of scouted territory, deeper into the Elderwood than the first expedition that finds
Spore. Tying her trigger to that specific far-forest campsite zone being discovered, rather than to
the Elderwood's exploration in general, keeps that fiction literal and keeps her trigger clearly later
than Spore's: Spore's trigger is the Elderwood's first entry, Thistle's is a specific, farther-in zone
within it, the farthest thing the party finds when they push past what they already knew. Like Spore,
she cannot be found before the Command Post's tier 2 Elderwood unlock has opened the biome she sits in.
Her arrival unlocks the Watchtower, fitting for the character who already knows every trail before the
building formalizes that knowledge.

### Aldric

Aldric arrives "after hearing of the outpost's growth," and reputation is not a tracked stat, so the
trigger is a building count: eight buildings constructed. The Command Post does not count toward the
total, since it is the outpost's start state rather than something the player builds, and the Training
Yard cannot count since Aldric is what unlocks it. Eight is the count the pacing document validated
against the calendar: the three opening commissions (Trading Post, Kitchen, Farmhouse) plus Chapel,
Smithy, Infirmary, Fishing Dock, and Apothecary reach the threshold around the end of Summer Year 1,
the Year 1 midpoint. That is growth genuinely worth hearing about, and it places the Training Yard
exactly where the building schedule expects it. (The count was originally three, which the opening
commissions satisfied within days; the pacing audit raised it.)

### Sera

Sera "heard of it through frontier trade networks," so her trigger rides the Trading Post's own
growth: reaching tier 2, the expanded store. The Trading Post itself is commissioned within the first
days of Year 1, one of the party's opening builds, so tier 2 remains the meaningful gate on her arrival:
a normal mid-Year-1 milestone once the Trading Post is already standing, not a blocked one. Her arrival
unlocks the Arcane Study, giving the outpost's arcane research a home to match her ambition.

### Oskar

Oskar "arrives seeking a place to spend his final years," specifically a chapel. Building-first is
the only pattern that fits: without the Chapel there is nothing for him to tend, so the trigger is
the Chapel's construction itself. The Chapel can be commissioned through the Command Post like any
other building, with no character prerequisite, so nothing blocks it from going up whenever the
player chooses to prioritize it. That timing matters more than it first appears; see the
ordering-check section below for the calendar pressure his own curse timeline puts on this choice.

### Grub

Grub is discovered "during a territory expansion," tending a patch of wild land that has been
productive for years. Farmhouse tier 2 signals the player is already serious about agriculture and
ready for the automation Grub brings, while the territory-expansion milestone is the literal act of
walking far enough to find his patch. His own doc already flags him as mid-late game, and this
combined trigger keeps him from showing up too early, before the farm has grown enough to make his
arrival feel earned.

### Hazel

Hazel arrives once she hears "about the growing settlement and the things its people have been
encountering," and offers to build something that lasts from whatever the party has found. A
trophy-count threshold captures that directly: once the party holds a proposed 8 monster trophies
or rare drops at once (current carry plus warehouse, matching the engine's ItemCountReached trigger;
if playtesting shows bundle spending starving the count, a lifetime counter is the fallback), there
is enough of a gathered collection to justify a curator showing up for it. Her
arrival unlocks the Reliquary. See the trophy-count proposal note below for the reasoning behind the
number.

### Wynn

Wynn "stayed for the evening… and then stayed for another day," and what keeps him is a room where
people linger and swap stories after a meal. That room is the tavern common room, which the Kitchen
ladder introduces at tier 2. The Kitchen itself is commissioned within the first days of Year 1, one of
the party's opening builds, so tier 2 remains the meaningful gate on his arrival: a normal early-to-mid
Year 1 milestone once the Kitchen is already standing. Wynn's arrival needs no character prerequisite of
his own; the building simply has to be ready to hold him.

### Hilde

Hilde is present "once the tavern reaches a certain development level (she needs a room to rent)."
That room is the Kitchen's boarding rooms, introduced at tier 3, one tier past Wynn's own trigger.
This creates a direct dependency: the Kitchen ladder must pass through tier 2 before it can reach
tier 3, so Wynn is guaranteed to already be a fixture (or at least the common room already exists)
by the time Hilde appears as townsfolk. Her PC-reveal, the moment she stops being background
scenery and becomes recruitable, still runs on the hearts 2-4 event already documented in her file.

### Raven

Raven "uses the Trading Post to sell loot and buy supplies… uses the Kitchen for a hot meal," which
means both buildings need to exist before her visits make sense. Since Trading Post and Kitchen are
both commissioned within the first few days of Year 1 as the party's opening builds, that half of her
trigger is satisfied early rather than instantly; the day threshold is what paces when her visits
actually begin, giving the outpost enough time to look like a plausible waypoint for a bounty hunter
passing through. Recruitment stays at the hearts 5-6 threshold already set in her own doc; nothing here
changes it.

### Flick

Flick is found "mid-fight where her magic is erupting in every direction," dragged back to the
outpost as much for containment as hospitality. An early swamp expedition encounter fits this
directly: since the swamp only opens once the Command Post reaches tier 3 (the Sunken Reach unlock,
moved from tier 2 in the three-biome revision), whichever encounter the party has soonest after that
opening is naturally an early one, and that is where she turns up.

### Vasska

Vasska's own doc already specifies that reaching 6/10 hearts with Oskar makes her encounter possible
in the swamp, and this doc formalizes the full condition: Oskar at 6/10 hearts, the swamp biome
explored, and a recruitment subquest completed once she is found. All three parts have to line up.
Oskar has to have arrived (which itself requires the Chapel), the player has to have spent enough
real friendship effort on him to reach that heart level, and the swamp has to already be open. This
is the tightest dependency chain in the whole roster; see the ordering-check section for the risk it
carries.

## Trophy-count proposal (Hazel)

The brief asks this doc to propose the trophy-count number for Hazel's trigger. **Proposed: 8.**
Trophies and rare drops are the rarest material band in the game (sell 25-60, and selling one is
usually the wrong move), sourced mainly from elite and named-roamer kills rather than common
encounters. Eight is enough to feel like the start of a real collection, the "collection's worth"
Hazel is looking for, without requiring the player to have cleared a boss first. It is reachable
across a normal stretch of Year 1 forest play once materials.md's elite/named-roamer trophies are in
place, and it does not require Hazel or the Reliquary to already exist, since trophies are ordinary
Bulk inventory items regardless of whether anyone is curating them yet.

## Biome notes

The brief locks a three-biome ladder as the currently available territory: the Verdant Fringe (easy,
the start biome), the Elderwood (moderate, proposed name, the older and darker forest interior the
Fringe frays into), and the Sunken Reach (dangerous, the swamp), with mountains and coast still future
content beyond all three. This replaces the prior two-biome statement (Forest and Swamp only); nothing
about mountains or coast changes, and Hilde's note below still holds unmodified. Checking each
character's fiction against the three-biome line, only one points at content that does not exist yet:

- **Hilde.** Her whole arc is built around an earth eidolon and mining, and the natural long-term
  home for that fiction is a mountain quarry. That does not exist yet, so her story runs on the
  Verdant Fringe's existing copper_ore nodes for now: her eidolon improves ore quality and yield at
  whatever scale the Smithy already supports. A dedicated mountain quarry is a future content bonus,
  not a blocker; nothing about her arrival trigger (Kitchen tier 3) or her recruited role depends on it.

No other character's arrival trigger or building role reaches for later-biome content. Vasska and
Flick both point at the swamp, and Spore and Thistle both point at the Elderwood; all three of the
currently-available biomes are locked-but-reachable territory, not later content, so none of these four
triggers need an alternate path. Arkus's rootborn lore mentions collapsed mines as orc growth-sites
generally, but that is background lore, not a mechanical requirement; his own arrival is Verdant-Fringe-
bound and unaffected either way.

## Friendship exception

Per `friendship.md`, recruitment is normally **not** gated by friendship. Recruitable characters join
through their arrival triggers, and hearts run as a parallel, purely social track. Three cases in
this roster earn a documented exception:

- **Raven.** Her recruitment threshold is hearts 5-6, not an arrival trigger, because her entire arc
  is the slow process of a guarded, self-reliant bounty hunter deciding a place is worth staying for.
  For her, the friendship track and the recruitment track are the same track by design.
- **Vasska.** Her availability is gated behind hearts 6/10 with a different character, Oskar, not her
  own. This earns the exception because her whole presence in the story is downstream of Oskar's
  personal arc: she exists in this roster to notice what is wrong with his mind, so her entrance has
  to wait until that arc has progressed far enough to need her.
- **Hilde's PC-reveal.** The building trigger (Kitchen tier 3) only makes her present as townsfolk.
  The reveal that turns her into a recruitable party member, hearts 2-4, is heart-gated because the
  moment itself only works if the player has already earned enough trust that she does not flee when
  her secret is exposed.

Every other recruitable character in this roster, including the other missable-adjacent cases like
Flick, joins purely through their mechanical trigger. Hearts still accrue for all of them once they
are present, per `friendship.md`, but hearts play no role in whether they join.

## Ordering-check

Reading the dependency chain in construction order:

1. **The Command Post exists at tier 1 from day one**, run by Tharr, with no construction bundle and
   an upgrades-only ladder. **Trading Post, Kitchen, and Farmhouse are commissionable from day one with
   no prerequisite**, each needing only its cheap construction bundle, and they are typically the
   party's first three builds, usually all going up within the first few days of Year 1: Elara,
   Fenwick, and the player each take up their building once it stands. No character's trigger depends
   on any of these four buildings existing before the player has had a chance to commission them, only
   on them reaching a later tier.
2. **Command Post tier 2 (the Elderwood unlock) needs no character and no other building tier.** Its
   bundle is priced entirely from Verdant Fringe commons and easy-family parts (goblin_fang,
   deserter_badge, wood), all of it available from day one, so nothing blocks the party from reaching
   it early. This is the first of the roster's two biome gates.
3. **Command Post tier 3 (the Sunken Reach unlock) needs the Elderwood already open.** Its bundle is
   priced from Elderwood materials and moderate-family parts (beast_hide, warden_bark, hardwood),
   which do not exist until tier 2 has opened the Elderwood. The two biome gates are therefore strictly
   sequential and never reorderable: the Elderwood always opens before the Sunken Reach, because the
   Sunken Reach's own unlock is paid for out of the Elderwood.
4. **Arkus, Josen, and Hazel** trigger off Verdant Fringe exploration or combat events that need no
   building tier and no biome gate at all. All three are reachable immediately in Year 1, since the
   Verdant Fringe is available from the start.
5. **Spore and Thistle** also trigger off exploration events, but both sit inside the Elderwood, so
   both need Command Post tier 2 to have landed first. Since tier 2 itself needs nothing but ordinary
   Verdant Fringe play (point 2 above), this is a sequencing note rather than a real blocker: Spore's
   trigger is the Elderwood's first exploration, and Thistle's is a specific zone farther into the
   same biome, so Spore is always reachable no later than Thistle once the Elderwood is open.
6. **Aldric** needs eight buildings constructed. The three opening commissions plus the Chapel and
   Fishing Dock (progress-gated, no character needed), the Smithy and Infirmary (unlocked by Arkus and
   Josen, whose own triggers need no buildings or biome gates at all), and the Apothecary (unlocked by
   Spore, whose own trigger needs only Command Post tier 2, itself unblocked per point 2) reach eight
   by the Year 1 midpoint on the pacing schedule. Nothing in the chain can deadlock: every contributing
   building is either progress-gated or gated on a character reachable through ordinary early play.
7. **Sera** needs Trading Post tier 2. Since the Trading Post itself is commissioned within the first
   days of Year 1, this only requires that already-standing building to be upgraded once more. No
   blocker.
8. **Oskar** needs the Chapel constructed, and the Chapel has no character prerequisite. No blocker.
9. **Wynn** needs Kitchen tier 2, and **Hilde** needs Kitchen tier 3. Because the Kitchen ladder is
   strictly sequential, tier 2 always lands before tier 3, so Wynn is guaranteed to precede Hilde.
   This is the one hard ordering rule in the roster besides the biome-gate sequencing above, and it
   holds automatically since a tier cannot be skipped.
10. **Grub** needs Farmhouse tier 2 plus a territory-expansion milestone, both reachable mid-Year 1
    with no character prerequisite.
11. **Raven** needs Trading Post and Kitchen built, both of which are commissioned within the first few
    days of Year 1 as the party's opening builds, so only the day threshold beyond that gates her.
12. **Flick** needs the swamp open (Command Post tier 3, moved from tier 2 in the three-biome
    revision), which the brief already schedules for "mid-Year-1 onward." No blocker, though tier 3
    now also needs tier 2's Elderwood unlock to have already landed (point 3 above).
13. **Vasska** needs Oskar at hearts 6/10 plus the swamp explored. The swamp half is the same
    Command Post tier 3 gate as Flick's. The Oskar-hearts half is the soft risk in the whole chain:
    Oskar's own doc ties his survival to a hidden ritual quest with a fixed death-event timeline, and
    Vasska is the quest's required first step. If the Chapel is built late, or the player is slow to
    build friendship with Oskar afterward, there may not be enough calendar room left to reach hearts
    6/10, recruit Vasska through her subquest, and still assemble the full ritual team (which can also
    want Hazel and a high-friendship Josen) before Oskar's decline resolves. Nothing in this doc
    blocks that sequence from working, but it is worth flagging: Oskar's Chapel should not be treated
    as a late-Year-1 or Year-2 building if the player is meant to have a realistic shot at saving him.

No character in this roster requires a building tier that cannot exist before their own trigger fires
in a normal Year 1 playthrough. The one genuine pacing risk is Vasska's dependence on Oskar's heart
level within Oskar's own fixed timeline, which is a calendar-budget concern for playtesting rather
than a broken dependency.
