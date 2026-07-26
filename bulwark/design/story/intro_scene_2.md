# Intro Scene 2 — "The Outpost" (script)

**Single source for Scene 2** — beats, lines, staging, and notes all live here (`../intro.md`
keeps only a stub and the cross-scene flow). Wins over the JSON
(`data/dialogues/intro/scene_2.json`, currently an empty placeholder). Format conventions:
`README.md`. Voice authority: `../prose_style.md`.

- **Goal:** deliver the party to the outpost and meet Tharr through his work; close the intro's
  three threads — the garrison rumor becomes fact, the crown paper meets the man on the other
  side of it, the wolves become present-tense — and turn the mission from "reinforce a garrison"
  into "rebuild this place." Hand control to the player.
- **Cast:** `player`, `fenwick`, `elara`, `tharr` (Tharr's first appearance — register and
  emotional order: `../characters/tharr.md`. He starts at his floor: withdrawn, weary, one flash
  of anger, then clamped back down. He does not warm up here.)
- **Staging:** placeholder — plays on the outpost map with the cutscene flag active. Kept plain;
  the scene is carried by the lines, not by camera business.
- **Choices:** one, flavor only, converges, no effects — the player's footing after Tharr's
  accounting.
- **Clean ground:** Scene 0 paid for the danger plant (whispers of worse on the road); Scene 1
  paid for the garrison rumor (a dwarf, last of a garrison gone eight years) and the wizard
  reveal. Scene 2 confirms the rumor from the source and spends the crown paper one last time,
  from Tharr's side.
- **Flags:** sets `intro_complete` at the end.

---

## Beat — The approach

[Fade in. Midday. The outpost stands at the end of the road. The walls are up but patched many
times over, every mend the work of one hand. The gate is freshly broken — the wood pale and
splintered where something tore at it, high and wide. Hammering carries from it.]

**Player**: Still standing, at least.

**Fenwick**: After a fashion.

**Player** *(looking the walls over)*: Someone's kept this up. Years of it, and every patch the
same hand. *(then the gate)* But that's fresh. Days old. *(beat)* I don't know what does that to a
gate.

**Fenwick** *(cheer thinning)*: Nor do I. And I find I would rather not learn.

## Beat — Three

[The hammering stops. At the gate a dwarf sets a brace, tests it with one hand, and turns —
grey, worn, a warhammer at his belt. He looks at the three of them.]

**Tharr**: Three.

[The player straightens and salutes, academy-drilled, and holds out the orders.]

**Player**: Relief for the garrison, sir. Reporting as ordered.

[Tharr looks at the paper. He does not take it.]

**Tharr**: The garrison left eight years ago. *(beat)* I did not.

**Tharr**: How many did they send?

**Player**: ...The two of us, sir. The trader came with us off the road.

## Beat — The flash, and the clamp

[A silence. Something crosses his face and is put away.]

**Tharr** *(hard, brief)*: For eight years I asked for a garrison, and they send me children.

[He turns back to the brace.]

**Tharr**: Every season a new request filed, and every season naught but silence come back.

**Tharr**: T'were wolves what done it — a great pack come out of the deep wood a few nights past.
Caught the smell of my supper on the wind, like as not, and took a mind to force their way to it.
*(back to the work)* Held them off the once. They'll not be turned so easy the second time, and
the gate's in no state to argue.

## Beat — The footing

**Choice** *(the player's footing; flavor only, converges, no effects — the prompt is Tharr's
accounting)*

1. **"The orders are fresh, sir. Someone will have logged your requests. More will come."**
   - **Tharr** *(flat)*: Eight years of "more will come."
2. **"We're what they sent. We'll make it count."**
   - **Tharr**: Then we start there.
3. **"Tell me what the post needs first."**
   - **Tharr**: Everything. We start with what keeps.

## Beat — Introductions

**Fenwick**: If we are to be your garrison, warden, I have one question that outweighs the rest.
*(beat)* The kitchen. Is there one, and does it draw?

**Tharr** *(after a look at him)*: There is a hearth. It draws.

**Fenwick**: Then the posting is not a total loss.

[Elara has drifted a few steps off — she is looking at a collapsed building, a trading post, its
sign still half-hung over the door.]

**Elara**: Who kept the trading post?

**Tharr**: A family. Gone now. *(beat)* Why do you ask?

**Elara**: No reason.

[She does not look away from it.]

## Beat — The turn

**Player**: What are your orders, sir?

**Tharr**: I have no orders. I never had the rank. *(beat)* I have work.

**Tharr**: Walls to close. Fields gone to seed. A gate that will not hold the next time. *(beat)*
The foundation holds — I saw to that. The rest is yours to lift.

**Player**: Then we lift it.

## Beat — The gate

[Tharr sets a shoulder to the gate. It swings, the fresh brace holding.]

**Tharr**: Mind the brace. It is new. *(a beat)* It will do.

[They pass through, Tharr last. Inside: the outpost yard, worse up close, and still a place. The
three of them take it in. Elara's look holds longest.]

[Fade out.]

[set intro_complete]

---

## Construction notes

- **The scene runs on Tharr's floor.** His order is weariness (the approach, the brace he sets
  before he turns), a flat confirmation of the eight years, one flash of anger when he learns how
  few they sent, then the clamp — heat swallowed, the requisitions delivered flat. He ends as
  withdrawn as he began, only pointed at a job. He does not warm up; his cheer is the game-long
  payoff earned through keep upgrades and heart levels (`../characters/tharr.md`), and delivering
  it here would spend it. The dry gallows note ("smelled my supper... took a mind to force their
  way to it") is weariness, not thaw.
- **Crown paper, third and last instance — from the other side.** The map was the first (Scene
  0), the month-old orders the second (Scene 1); here the player's fresh orders meet eight years
  of Tharr's own requisitions, filed right and unanswered. Both papers were fiction. This is the
  first proof the player sees that the crown *received* the asking and did nothing, so his faith
  bends further than Scene 1 — but it holds. He files it as clerical rot, not betrayal; the
  footing choice routes his resolve, and even the crown-defending option is resolve, not a break.
  Option 1 costs him — Tharr's dry "eight years of 'more will come'" lands the defense as hollow.
  The break stays game-long (`../characters/player.md`).
- **The eight is confirmed here, by a living witness.** Scene 1's rumor becomes fact from the
  source: "The garrison left eight years ago. I did not." He never says *why* — no recall history,
  no war, no budget. One line of confirmation, no narration. The other numbers (bridge six, house
  ten) are not re-counted, and the trading post is left without a year so no fourth number
  competes with the three.
- **The party cannot name what hit the gate.** The damage is too severe and strange to read as an
  ordinary animal — the player, who knows farm predators, says plainly he cannot account for it,
  and Fenwick would rather not. Tharr, who was there, supplies "wolves," and even he keeps the
  leader vague ("a great pack") — the party has no concept of a dire wolf. The *why it was so bad*
  rides along to the Day-1 gather, where the big one is dealt with; the beast is named later
  (`../tutorial_quests.md`). Fenwick's cheer thins on the approach — the first real danger
  touching him.
- **Elara's settle seed is a look, not a line.** Her eye finds the ruined trading post before she
  is asked anything; "Who kept the trading post?" and the held look are the whole beat. A trader
  with no road left to run notices a post that had a life once. She does not announce staying —
  that is later. "No reason" keeps it under the surface.
- **The turn folds the survey into itself.** Tharr does not give orders — he never had the rank.
  He offers work and names the state of the place in the same breath, so the reframe and the work
  list are one beat. The mission changes on screen from *reinforce a garrison* to *rebuild* — the
  word "bulwark" stays unsaid. The player accepts plainly; "Then we lift it" is resolve, not
  disillusionment.
- **The closer keeps it plain.** Tharr last through the gate, one gruff caretaking line about the
  brace (his care surfaces only as maintenance). A held beat on the interior, Elara's look
  longest. Then the flag. No chain into another dialogue: control lands on the outpost map and the
  Day-1 quest prompt appears, but the gather dialogue fires only when the player walks to Tharr
  and interacts (gameplay seam, `../intro.md` / `../tutorial.md`).