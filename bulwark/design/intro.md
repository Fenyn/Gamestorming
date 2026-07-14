# Bulwark — Opening Cutscene

Three-scene intro sequence before gameplay. Short, character-driven, establishes the mission
and the cast. Ivalician register — formal, archaic, poetic but grounded. Longer worldbuilding
comes through gameplay journals and notes, not front-loaded exposition.

## Voice guide

- **Player**: Direct, military formality. Grounded metaphors — earth, iron, seasons. Spare with
  words. The farmhand-soldier who speaks when it matters.
- **Fenwick**: Academic warmth. Well-educated (wizard college) but approachable. Lighter
  formality, self-deprecating humor, food adjacent. Cheerful without being grating.
- **Elara**: Silver-tongued, measured, knowing. An elf who has been doing this longer than the
  humans have been alive. Dry wit, quiet confidence, never flustered. Words as tools.
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

*Player and Fenwick on a neglected frontier road. The landscape is overgrown, the
infrastructure crumbling. They are lost. Elara finds them.*

---

### Draft dialogue — Scene 0

```
FENWICK
I am given to believe we passed a signpost some three miles hence.

PLAYER
There has been no signpost for three miles, Fenwick.

FENWICK
Precisely. A proper marker would have had the decency to inform us
of its absence.

[Beat — they walk. The player surveys the road.]

PLAYER
This road has not seen a mason's hand in years. The stones are
half-swallowed by the earth.

FENWICK
The whole of this country bears the same neglect. Overgrown,
hollowed out... I had understood the crown still held these
borderlands?

PLAYER
They do. On parchment.

[Elara enters from a side path, unhurried. She regards them with
quiet amusement.]

ELARA
You bear the look of men about to walk into a ravine.

FENWICK
We follow the route we were furnished upon departure—

ELARA
That route crosses a bridge which surrendered itself to the river
two seasons past. Whither are you bound?

PLAYER CHOICE:
  > "A frontier garrison. We are sent as reinforcements."
  > "That would depend upon who asks."

[If "who asks"]
ELARA
One who knows these roads rather better than whoever drew your map.
So. Whither are you bound?

[Converge]
PLAYER
A border outpost, near the forest's edge. The garrison has been
undermanned for some time. We are sent to mend what we can.

ELARA
The old post by the Thornwood? I know the place. Or what remains
of it.

FENWICK
Your confidence inspires the very soul.

ELARA
I am Elara. I have traded along these frontier routes for longer
than your parents have drawn breath. The crown extends favorable
concessions to any who would bring commerce back to the
borderlands. I make for the same road you walk, albeit with a
clearer sense of where it leads.

FENWICK
Well met. I am Fenwick, and this is {player_name}. We should be
glad of the company — and gladder still of the direction.

ELARA
Then keep pace. I do not wait for stragglers.
```

---

## Scene 1 — "The Road"

*The three walking together. Fenwick and the player press Elara for information about the
frontier. She answers with the wearied knowledge of someone who has watched this decline
unfold over decades.*

---

### Draft dialogue — Scene 1

```
FENWICK
What manner of ruin befell this land? These were imperial holdings
once, were they not?

ELARA
They remain so, in the strictest legal sense. But the crown began
withdrawing its garrisons some eight years past. Disputes of
treasury, renegotiations of border — the usual machinery of an
empire turning its gaze inward.

PLAYER CHOICE:
  > "They abandoned the frontier."
  > "There must have been cause."

[If "abandoned"]
ELARA
Abandoned carries a weight the court would not suffer. They prefer
"consolidated." The distinction is of comfort only to those who
made the decision, not to those who bore its cost.

[If "cause"]
ELARA
There is always cause. It matters precious little to those left
standing in the silence that follows.

[Converge]
FENWICK
And none raised objection? No petition, no appeal?

ELARA
Some did. Most simply moved to ground more hospitable. Those who
remained are of a particular sort. Stubborn, or without the means
to leave.

PLAYER
What do you know of the outpost itself?

ELARA
Little of recent vintage. There is said to be one soldier still
posted there. A dwarf — held the garrison alone for longer than
any soul ought to be asked.

FENWICK
A single man? Holding an entire garrison?

ELARA
Dwarves possess a certain... immovability of spirit. I believe I
mentioned stubbornness.

PLAYER
Our orders stated the post was operational.

ELARA
(a pause)
Your orders were written by hands that have not set foot beyond
the capital walls.

[Beat — they walk in silence for a moment.]

FENWICK
Well. Whatever state it holds, there shall be a hearth to set
right. No proper outpost was ever built without a proper kitchen,
and no proper kitchen was ever built without one who knows the
sacred art of turning raw provision into something worth the
living.

ELARA
You are a cook?

FENWICK
I am a gastronomancer.

ELARA
...Pray tell, is that a word?

FENWICK
It is now.
```

---

## Scene 2 — "The Outpost"

*The three arrive. The outpost is worse than expected — walls crumbling, fields choked with
weeds, timber sagging. Tharr emerges from within. He has been alone a long time, and it shows
in the careful way he regards them — measuring, guarded, quietly relieved beneath the stone.*

---

### Draft dialogue — Scene 2

```
[Fade in to the outpost. The three stand at the entrance, taking
in the state of the place.]

FENWICK
...Ah.

ELARA
As foretold.

PLAYER
It stands. That is something.

FENWICK
Portions of it stand. Other portions have entered into negotiation
with the earth regarding their continued verticality.

[Tharr enters from within the outpost walls. He stops at a
distance, regarding the newcomers.]

THARR
You are the reinforcements, then.

PLAYER CHOICE:
  > "We are. Forgive the delay."
  > "What remains to be reinforced?"

[If "forgive the delay"]
THARR
Delay does not begin to name it. But you are here. That is what
holds weight.

[If "what remains"]
THARR
More than you would reckon. Less than there ought to be.

[Converge]
THARR
I am Tharr. Stonemason. Cleric. And, until this moment, the whole
of the garrison. You stand at the edge of the empire. Such as it is.

ELARA
Elara. I am here for the trade concessions. And because these two
would have walked into a river without guidance.

FENWICK
Fenwick. I was given to understand there would be a kitchen.

THARR
There is a room. It has a hearth. Whether it becomes a kitchen is
a question your hands must answer, not your expectations.

FENWICK
That shall do splendidly.

THARR
(turning to the player)
And you?

PLAYER
{player_name}. Soldier. Farmhand before that.

THARR
(a nod)
Good. We have need of both.

[Beat. Tharr surveys the outpost behind him — the crumbling walls,
the overgrown fields, the sagging timber.]

THARR
I will not dress the truth. The walls want mending. The fields
have gone to seed. And the forest grows bolder with each passing
season, pressing closer than it has any right to.

[He turns back to them.]

THARR
But the bones are sound. Good stone does not forget its purpose.
This place can be something again.

THARR
Come. I shall show you what we are working with.

[Fade out. Player gains control at outpost. Flag: intro_complete]
```

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
