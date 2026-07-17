# Bulwark — Opening Cutscene

Three-scene intro sequence before gameplay. Short, character-driven, establishes the mission
and the cast. Longer worldbuilding comes through gameplay journals and notes, not front-loaded
exposition.

**The player speaks during the opening cutscene.** The intro needs a real conversational
presence — Fenwick needs a straight man, Elara needs someone to spar with. Once the cutscene
ends and gameplay begins, the player shifts to silent protagonist (choices only, Stardew-style).
Choices during the cutscene are still expressive and varied.

**Influences**: Sanderson (natural flow, characters who listen and react, wit from the
situation not from cleverness), Rothfuss (rhythm, precision, banter that feels musical),
Ivalician register (slightly elevated but never stiff — the formality is how these people
actually talk, not a costume they put on).

## Voice guide

- **Player**: Direct, grounded, practical. A farmhand's eye for the land and a soldier's
  economy with words. Not flowery — observational, honest. The one who sees what is in front
  of them. Serves as the straight man to Fenwick's warmth and Elara's wit.
- **Fenwick**: Academic warmth. Well-educated (wizard college) but approachable. Lighter
  formality, self-deprecating humor, food adjacent. Cheerful without being grating. Talks
  more than the others but earns it — he's genuinely good company.
- **Elara**: Silver-tongued, measured, knowing. An elf who has been doing this longer than the
  humans have been alive. Dry wit, quiet confidence, never flustered. Answers questions she
  finds interesting, redirects ones she doesn't.
- **Tharr**: Shortest sentences. Stone metaphors. Economy of words. The loneliest character —
  his relief shows in what he does NOT say.

## Flow

```
New Game → [Name Entry] → Scene 0 (road) → Scene 1 (road) → Scene 2 (outpost) → Gameplay
```

Each scene is a dialogue sequence. Scene 0 and 1 play on a simple road scene (user-painted
later; placeholder = dark background with character sprites). Scene 2 plays on the outpost map
with a cutscene flag active (Tharr walks out, dialogue, then player gets control).

Story flags set: `intro_scene_0`, `intro_scene_1`, `intro_complete`. A returning save with
`intro_complete` already set skips the whole intro.

---

## Scene 0 — "The Frontier"

*Player and Fenwick on a neglected frontier road. They've been walking too long on bad
directions. The road is falling apart, the landmarks are gone. They're not panicking yet,
but the silence between complaints is getting longer. Elara finds them before they find
the ravine.*

---

### Draft dialogue — Scene 0

```
FENWICK
I am reasonably certain we have not passed a signpost in the last
three miles.

PLAYER
Four.

FENWICK
Four, then. That is worse, though I appreciate the precision.

[Beat. They walk. The player looks down at the road — stones split
by roots, edges soft with overgrowth.]

PLAYER
Look at the road. These stones have not been set right in
years. Whatever the crown holds out here, it would appear their grasp is not a tight one.

FENWICK
I had been trying not to notice that. You have a gift for
dispelling comfort.

PLAYER
I have seen neglect of this sort before. When a family leaves
their homestead, the road is the first thing to go.

FENWICK
And what follows the road?

PLAYER
Everything else.

[A figure steps onto the road from a side path — unhurried,
deliberate. An elf. She has been watching them for longer than
they realize.]

ELARA
I would not take that fork, were I in your position.

PLAYER
Why not?

ELARA
The gorge bridge washed out two winters past. No one has troubled
to rebuild it. You shall discover that for yourselves if you
continue — though 'tis a long way down to learn a short lesson.

FENWICK
Well, it's nice to meet such a well-informed stranger on an empty road.

ELARA
I have traded these routes for a good many years. Long enough to
know which bridges still stand. Where are you bound?

PLAYER
A frontier garrison. Past the Thornwood, near the forest's edge.

ELARA
(her expression shifts — not quite surprise, but something close
to interest)
The old outpost? There are not many who head out that way.

FENWICK
We were told it was still manned. Though, given the state of everything else out
here, I am beginning to question the reliability of what we were
told.

PLAYER CHOICE:
  > "You seem surprised. What do you know of it?"
  > "We are reinforcements. Long overdue, by the sound of it."

[If "surprised"]
ELARA
Surprised is too strong. Let us say... curious. I had not thought
the crown remembered that post existed.

[If "reinforcements"]
ELARA
Reinforcements. After all this time. Well. Someone in the capital
must have found a conscience, or at least a reason.

[Converge]
ELARA
I am Elara. I trade along these frontier routes. That's the plan, at least, 
but there are few along them worth trading with.
 
The crown is offering concessions to anyone willing to bring commerce back to the
borderlands, and I intend to be the first to collect.

As it happens, I am heading the same direction. I can guide you to the outpost.

FENWICK
Then we are in your debt. I am Fenwick. This is {player_name}.

ELARA
Reinforcements for a forgotten outpost, armed with a map drawn by
someone who has never set foot out here. The crown's generosity
knows no bounds.

PLAYER
(laughs)
We would welcome the company, Elara.

[They begin to walk off down the new path]
```

---

## Scene 1 — "The Road"

*The three walking together. The initial awkwardness of strangers has settled into the easy
rhythm of shared travel. Fenwick is curious about everything. The player notices things the
others miss. Elara has answers but parcels them out at her own pace.*

---

### Draft dialogue — Scene 1

```
[They have been walking for a while. The terrain has not improved.]

FENWICK
Elara, might I ask you something? This land feels abandoned.
Not ruined or destroyed. Just... left. What happened here?

ELARA
The short answer is the crown pulled its garrisons back. Eight
years ago, perhaps nine. Some dispute of treasury or
shifting borders, all the usual arguments that sound very sensible
when spoken in a marble hall.

PLAYER
And the long answer?

ELARA
The long answer is that when the soldiers left, the trade
caravans stopped. When the caravans stopped, the settlements
shrank. When the settlements shrank, the roads fell apart. And everyone 
who could afford to leave did so.

FENWICK
And the ones who stayed?

ELARA
Are either very stubborn or had nowhere else to go.

[Beat.]

PLAYER
We passed a farmstead a few miles back whose roof had completely caved in. There
were still tools hanging on the wall.

ELARA
Many families took only what they could carry. The rest was left for the forests to reclaim.

PLAYER CHOICE:
  > "Nobody told us it was this bad. Our briefing said nothing of this."
  > "Those tools were well-kept. Whoever hung them there loved that land."
  > "If this is what the road looks like, I am not certain I want to see the outpost."

[If "briefing"]
ELARA
Briefings written by men who have never set foot beyond the
capital walls. You will find the frontier full of things no one
thought to mention.

[If "loved that land"]
ELARA
Aye. Most of them did. But love does not put food on the table.

[If "not certain"]
ELARA
The roads answer to the crown, and you can see how well the crown
has answered for them. But the outpost has its own keeper. I would
not judge the one by the other.

[Converge]
FENWICK
Its own keeper? Someone is still out there?

ELARA
So the traders say. A dwarf.

FENWICK
One dwarf, alone all this time?

ELARA
He moved in shortly after the garrison left. Rumor has it that he's taken a liking to the 
old fort.

FENWICK
Let us hope the solitude has not driven him to madness.

ELARA
He is a dwarf. It is stubbornness that drives him, which is likely a point of
personal pride.

[Beat.]

PLAYER
Our orders called the post operational.

ELARA
One soldier and a crumbling wall. The crown's standards have
slipped since last I checked.

[They walk in silence for a moment. The road is getting worse.]

FENWICK
Well. Whatever state we find it in, there will be a hearth that
needs sorting. I have yet to see an outpost that could not be
improved by someone who understands the fundamental importance
of a proper meal.

ELARA
You are a cook?

FENWICK
I am a gastronomancer.

ELARA
I have lived a very long time, and I have never heard that word.

FENWICK
That is because I coined it. Wizard by training, cook by
vocation. The two disciplines share more than you might expect.

PLAYER
He graduated from the academy and immediately requested a kitchen
posting. His professors were... unsure how to process the
paperwork.

FENWICK
They lacked vision. Both fields demand precision, timing, and a
willingness to accept that some things will simply explode if
you get the ratios wrong. The only difference is that when a
soufflé collapses, fewer people catch fire.

ELARA
Fewer?

FENWICK
I did say fewer.
```

---

## Scene 2 — "The Outpost"

*The three arrive. The outpost is worse than any of them expected — walls crumbling, fields
choked with weeds, timber sagging under its own weight. But it is still here. Tharr emerges
from within. He moves like a man who has forgotten what company feels like — careful, measured,
sizing them up the way a mason sizes up a crack in a load-bearing wall.*

---

### Draft dialogue — Scene 2

```
[Fade in. The three stand at the entrance to the outpost, seeing
it for the first time.]

FENWICK
Ah.

PLAYER
(quietly)
Well, at least it is standing.

FENWICK
Parts of it are standing. The rest appears to be negotiating
terms with gravity.

ELARA
I have seen worse. Though not recently.

[The outpost up close. The walls are cracked but patched in
places. Fresh-cut stone sits stacked near the gate. Someone has
been working here.]

[A dwarf steps through the gate carrying a mason's hammer. Stone
dust on his sleeves. He stops when he sees them and for a long
moment simply stands there.]

[Then he sets the hammer down on the stack of cut stone beside
the gate.]

THARR
The crown sent you.

PLAYER CHOICE:
  > "Aye. Reinforcements. We should have come sooner."
  > "We'd heard the garrison was manned by one soldier. I did not believe it until now."
  > "Two of us were sent, and one joined in along the way."

[If "sooner"]
THARR
You came. That is more than most.

[If "one soldier"]
THARR
(he looks down at the hammer on the stone)
It is the unfortunate truth.

[If "Two were sent"]
THARR
Three.
(he looks at the outpost behind him)
I suppose it's better than none.

[Converge]
PLAYER
I am {player_name}.

THARR
Tharr.

FENWICK
Fenwick. I trained as a wizard, but my true purpose has always
been the kitchen. Please tell me there is a hearth.

THARR
Aye. There is a hearth.

FENWICK
Then there is a kitchen. You simply lacked someone to tell you so.

ELARA
Elara. I trade these routes.
(she glances past Tharr, toward a collapsed structure inside
the walls)
Is that a trading post?

THARR
It was.

ELARA
Hmm. Interesting.

[Beat. Tharr looks between the three of them.]

THARR
Come inside.

[He picks the hammer back up and walks to the gate. He pauses
there, one hand on the stone.]

THARR
The walls need mending, the fields have gone to seed, and it seems the 
forest presses closer every season.

THARR
But the foundation holds. I have seen to that.

[He turns back to them.]

THARR
There is much work to be done here, if you are willing.  

PLAYER
We are willing.

THARR
Good.

[He walks through the gate. They follow.]

[Fade out. Player gains control at outpost. Flag: intro_complete]
```

---

# Story cutscenes (post-intro)

These are in-world dialogue-box sequences that fire during play, not part of the opening road
cutscene. They follow the same JSON/dialogue-box pattern as the intro scenes and use the same voice
guide above (plus Arkus below). They belong to the early-game progression rework
(`design/tutorial.md`, `design/tutorial_quests.md`, added 2026-07-16). Drafts are concise — these are
short modal beats, not the full road cutscenes.

**Arkus's voice** (see `design/characters/arkus.md`): blunt orc honesty. Says exactly what he thinks,
no softening, no cruelty intended. Short, plain sentences. He states problems as facts and expects the
same in return. Underneath the bluntness is someone who cares more than he knows how to show.

---

## Day-1 close — "The Hearth and the Howl"

*Fires automatically the moment the lodging repair is turned in on Day 1 (flag `lodging_repaired`).
Day 1's clock is frozen until this plays; the sequence ends by advancing to Day 2 and setting
`first_rest`. The player does not choose to sleep — the day closes on its own. Two beats: Fenwick at
the hearth as the light goes, then a wolf's howl heard through the dark.*

### Draft dialogue — Day-1 close

```
[The lodging is patched. Evening light. Fenwick is crouched at the
old hearth inside the hall, sleeves pushed up, examining the flue.]

FENWICK
Walls that hold, a roof that keeps the rain off the soup. You have
done more today than the crown managed in nine years.

PLAYER
That was Tharr's doing. I only carried the stone.

FENWICK
Carrying the stone is most of it. Ask any mason.
(he peers up the chimney)
And this — this is a proper hearth under all the soot. The draw is
honest. Give me a few days and it will feed everyone here.

[He stands, brushing ash from his hands. The light through the
doorway has gone amber, then grey.]

FENWICK
Get some rest. Whatever this place is going to be, it starts
tomorrow. Tonight it can simply be standing.

[Fade to black. A beat of quiet. Then, from far off in the dark —
a long, low howl. Held too long to be a dog. Closer than anyone
would like.]

[Fade in on morning. Day 2. The howl is not mentioned yet — it
sits under the day like a splinter.]
```

**Flags:** sets `first_rest`; advances to Day 2; unfreezes the day clock. The howl is foreshadow only —
the dire wolf thread pays it off later (`design/tutorial_quests.md`).

---

## Arkus found — "On the Road Home"

*Fires on the party's first return to the outpost after the dire wolf is slain (flag
`dire_wolf_slain`, sets `arkus_found`). Template: the arrival-triggered cutscene pattern used for intro
Scene 2. The full squad — player, Tharr, Fenwick, Elara — is coming home from the kill and finds a
wounded orc on the road. He is placed as an unconscious resident afterward; he does not wake here.*

### Draft dialogue — Arkus found

```
[The road back to the outpost. The party is worn from the wolf.
Something large is slumped against the roots at the roadside — an
orc, armor scored and broken, not moving.]

ELARA
Hold. There — off the road.

[They approach. The orc is breathing, barely. Wounds days old,
none of them tended right.]

FENWICK
Stars above. He is alive. Only just.

PLAYER
Same wounds as the wolf gave. Look at the spacing. It had him
before it had us.

THARR
(kneeling, checking the orc's weight)
Then it is a debt.
(a beat)
We carry him.

ELARA
He is twice your size, mason.

THARR
Stone is heavier. Take his other arm.

[They lift the orc between them. Fade as they carry him through
the gate.]
```

**Flags:** sets `arkus_found`. Arkus is placed as an unconscious resident at the outpost. His wake is a
separate beat (below), gated on the Trading Post being built.

---

## Arkus wakes — "What Was Not Enough"

*Fires at the start of the day after both `arkus_found` and `trading_post_built` are set (quest 9,
"The Smith and the Sickbed"). Sets `arkus_awake`; his asks make BOTH the Smithy and the Infirmary
commissionable at the planning table.*

### Draft dialogue — Arkus wakes

```
[Arkus is upright on the mended bunk, stiff, bandaged wrong in
two places. He looks at the party without ceremony.]

ARKUS
You are the ones who carried me. Good. I hate owing strangers.

PLAYER
You were on the road past the near forest. A dire wolf.

ARKUS
The wolf. Yes.
(flat, no drama)
I went in to prove something. I came out like this. What I carried
was not enough. Bad steel breaks when you need it to hold.

[He tests his arm, winces, does not complain.]

ARKUS
You killed it, then. With better luck than sense, probably. Next
thing out of that forest will be worse. You will want a forge. I
can build one. I know metal — it is the one thing the rite did not
take from me.

PLAYER CHOICE:
  > "We have a place for a smithy. It's yours."
  > "You could barely stand a moment ago."

[If "it's yours"]
ARKUS
Then it is settled. I start when the frame is up.

[If "barely stand"]
ARKUS
I mended a spearhead once with a broken hand. Standing is
optional. Straight steel is not.

[Converge. He glances down at his own botched bandages.]

ARKUS
And this — whoever wrapped me meant well and did it wrong. You
have no proper place to mend the hurt. There will be more of us
coming back like I did. Build somewhere to put them. A sickbed,
before you need one and do not have it.

THARR
(from the doorway)
A forge and an infirmary.
(a nod)
The table can hold both.
```

**Flags:** sets `arkus_awake`. Unlocks Smithy (`arkus_awake`) and Infirmary (`arkus_awake`) at the
planning table. Josen — the monk who will run the Infirmary — arrives 1-3 days after it is built, via a
random event (`design/economy/characters.md`).

---

## Infrastructure needed

- **Road scene** (`scenes/intro/road.tscn`): simple Node2D, dark/simple background the user
  can paint later. Character sprites positioned. Transitions to outpost after Scene 1 ends.
- **SceneRouter** addition: `GoToIntro()` / new-game flow routes here instead of straight to
  outpost. After Scene 1 ends: `GoToOutpost()` with `intro_scene_1` flag set.
- **Outpost cutscene trigger**: on `_Ready`, if `intro_scene_1` is set but `intro_complete`
  is NOT, play Scene 2 sequence before giving player control.
- **Story flags**: `intro_scene_0`, `intro_scene_1`, `intro_complete`
- **Dialogue files**: `data/dialogues/intro/scene_0.json`, `scene_1.json`, `scene_2.json`

## Deferred

- Road scene art (user paints later — placeholder dark/simple for now)
- Character sprite staging in road scenes (enter/exit/move commands — framework supports it,
  wiring actors to sprites is scene-specific)
- Name entry UI (currently `PlayerName` is set in code; UI is a future piece)
- Tutorial prompts from Tharr (in-world NPC interactions, not cutscene — uses existing talk
  system + story-flag-gated talk pool entries)
