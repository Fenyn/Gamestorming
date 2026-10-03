# Tutorial, lessons 1 to 5

One continuous training session in the Rooke yard. Caedan Vale teaches Emrys the sword, Emrys'
Steel wakes in the middle of it, and Caedan changes the training to fit. One board the whole way:
no fades, no separate screens. Each lesson opens with its title as a banner over the table while
play carries on, and the title stays as a small tag in the top left corner.

The script is `data/tutorial/lessons.json`: every step, line, callout, ring and greyed-option
reason, in order. Read it there; this file holds the rules the script follows and the turn order it
runs on, not its lines. The rest of the data is `decks.json` (the three Life Decks, top card first)
and `cards.json` (the Straw Knight and Emrys' four plain tutorial cards). The director is
`tutorial/tutorial_director.gd`, the timing of every line `tutorial/tutorial_pacing.gd`, and the
table side `scripts/duel/tutorial_panel.gd` with `scenes/duel/bark_bubble.tscn`.
`tests/tutorial_tests.gd` plays it end to end and checks the numbers below.

## Rules for every lesson

- Every draw is stacked (a scripted duel never shuffles) and every Caedan or Straw Knight move is
  scripted. A rival decision the script does not name gets the quietest answer (pass, no defense,
  skip, discard the hand, decline, take nothing).
- The real engine resolves every move, so every number the player sees is a real one.
- At each player prompt only the taught move is enabled. Other options stay visible, greyed out.
  Hovering one swaps Vale's reason into his box in the warning colour; clicking one shakes the box
  and pulses the ring on the right move. Harmless choices (which card to keep, which card a Final
  Strike throws, which of two identical copies to play) stay free, and every branch leads to the
  same next beat. A "you may" and a Life Deck search are always asked; a search shows the whole
  deck, the cards that are not the taught pick greyed with a reason.
- The script adjusts the board between beats (swap the rival, deal cards onto a Life Deck, set
  Energy or Fervor, end a Combat). Every adjustment plays as ordinary card movement on the table.
- No turn passes empty. Each turn either teaches something or ends a lesson; a turn where the rival
  only draws and discards is cut by moving the next beat onto it.
- A lesson ends when its last beat is taught. Nobody has to win.
- Saving: the lesson reached is stored in the profile (`progress.json`). Resuming replays the
  script to that lesson's start in one instant step, so the board is the same as it was. Finishing
  lesson 5 marks the tutorial done and the next start is lesson 1 again.

## Voices and where they show

| Speaker in the data | Where it shows |
|---|---|
| `vale` | Vale's coach box: a small box with his face chip, docked beside what he means and joined to it by a glowing thread, with a ring round the spot. Lines with no ring in a stop pop in as chat bubbles instead. In lessons 3 to 5 he is also the rival, and the box speaks as him: "my Fervor", never "his". |
| `narration` | A banner across the middle of the table that sweeps open and fades. |
| `emrys` | A speech bubble at Emrys' duelist card. |
| `caedan` | A speech bubble at the rival's duelist card, lessons 3 to 5 only, where he fights. |

Three kinds of step carry words:

- **Stop.** The table waits while its lines play one after another. Each line has its time
  (`TutorialPacing`): a line in the box or the banner 0.8 s plus 0.3 s a word, 2 to 7 s; a bubble
  0.9 s plus 0.045 s a character, 1.4 to 3.2 s. A click anywhere, Space or Enter shows the rest of
  the line or moves on. A stop marked `hold` waits on its last line for that click.
- **Move.** Vale's instruction for the prompt now up stays in the box, tethered to the move, until
  the move is made.
- **Bark.** A line in passing, in a bubble, that fades on its own while play goes straight on. A
  move or a rival move can carry one (`says`), shown as it is made.

Stops per lesson: 4, 2, 3, 2 and 3, 14 in all (the cap is 4, 3, 4, 3 and 3). Lines and callouts
come to at most 1200 words; greyed-option reasons do not count.

A Move's instruction waits while Vale's passing note is still up, so a note and the instruction
after it are read one after the other. A click or a key sends the note away early.

## Cast on the board

- **Emrys Rooke.** Ladder for the session: the Eldest (Might 0, 4, 5 ... 13, Surge 1), then First
  Plate (Might 0, 12, 13 ... 21, Surge 2). First Plate is his top Aspect here. Power Up gains
  Surge + 1. Starts at Energy 5, Fervor 0. No Mastery.
- **Straw Knight.** Tutorial-only card (`tutorial_personality_01`). Might 5 at every stage (band
  B), so its numbers never shift. Surge 2. Power: Strike doing +3 Energy (unused until lesson 2,
  when Caedan ties the rope to its arm). Life Deck of 40 Freestyle attack cards it never plays.
  Portrait: the Scarecrow from LimeZu's Modern Farm pack.
- **Caedan Vale.** Ladder for the session: Last Heir (Might 0, 3, 4 ... 12, Surge 2), then
  Unparried. Power: on entering Combat, look at the top 8 and may take a "Sword" card. His
  Freestyle Discipline Mastery comes with him. Enters at the end of lesson 2 at full Energy.

Until the plate appears Emrys plays four plain tutorial-only cards, each with one rule: Emrys'
Rising Cut (Strike +3 Energy, Attune 1), Emrys' Overhand Cut (Strike +2 Energy), Emrys' Parry
(stops a Strike) and Thrown Dagger (a bare Art). Signature cards with longer text come in only
where a lesson teaches that text (Emrys Risks It All, Emrys' Sword Flourish and his Swordplay
Drill), then Steel cards join. Caedan's deck holds Caedan signature cards and Freestyle cards.

## Turn by turn

| Turn | Lesson | What it teaches |
|---|---|---|
| 1, Emrys | 1 | Declaring Combat, Emrys' Power draw, a Strike's Energy damage (Rising Cut, Knight 5 to 0, Fervor 1), Energy spilling into wounds (Overhand Cut, 4 wounds), an Art's cost and wounds (Thrown Dagger, Emrys 7 to 5 and Might down a band), two passes ending Combat. The lesson ends as the Knight's turn reaches its declare. |
| 2, Straw Knight | 2 | The rope goes on and the Knight declares, so Emrys draws three as defender, and Vale's note says so. Its Power is stopped by the Parry, the defender swings back (Rising Cut, Fervor 2), and a Final Strike throws a spare Parry. |
| 3, Emrys | 2 | Skipping Combat, the Discard step (only keeping the Parry is open, because the opponent attacks next), Recover. |
| 4, Caedan | 2, 3 | The Knight draws for its turn, and at its declare Caedan takes the seat at Energy 10 with his turn's three cards (`swap_duelist` with `draw`; a seat is swapped at a declare decision, which names no card). Caedan declares and his Power takes Vale's Sword Draw from his top eight. He lets Emrys strike first. Riposte stops the Rising Cut but its Attune counts (Fervor 3), his thrown-back swing meets the kept Parry, Risks It All gets past Strike cards (Fervor 4), Sword Draw lands to show a hit draining Energy, and the last Rising Cut climbs Emrys to First Plate. Then a fresh bout: Combat ends, Emrys at Energy 5, Caedan at 8, Caedan's Fervor 0, and the Steel cards dealt to the top and bottom of Emrys' Life Deck. |
| 5, Emrys | 4 | Drills (both placed). That leaves one card in hand, so he skips Combat and Recovers: one card makes a poor Combat, and the defender draws three anyway. |
| 6, Caedan | 4 | Caedan declares. Emrys draws three Parries as defender and First Plate's search fetches the Ironscale Hide. What stops what: Pommel Bash (a Strike) meets the Hardscale Defense Shield; the Lashing Tail swings back with the Drill's +2 (Fervor 1); the Declaration (an Art) carries Disrupt 2 and only the Hide, which stops any attack, can stop it (Energy 8 to 10); the Sword Draw (a Strike) meets a Parry; then Sharp Rebuke (an Art, 8 wounds) lands with nothing left to stop it, and the Scalebound Blow's Endurance 4 soaks half. |
| 7, Emrys | 5 | Sword and Steel together, then the close. A full hand this time, so he declares; First Plate's search fetches the Routing Roar; the Overhand Cut opens with the sword (Table 1, +2, the Drill's +2: 5 Energy); Caedan lets him finish; the Roar Empowered deals 7 wounds, a critical hit, and Disrupt 1 takes Caedan from Fervor 4 to 3; the last-Aspect Fervor win is named, and Caedan calls the session. |

## Fervor over lessons 1 to 3

| Lesson | Card | Fervor after |
|---|---|---|
| 1 | Emrys' Rising Cut (Attune 1) | 1 |
| 2 | Emrys' Rising Cut, as the defender swinging back | 2 |
| 3 | Emrys' Rising Cut (stopped, but Attune still resolves) | 3 |
| 3 | Emrys Risks It All (Attune 1) | 4 |
| 3 | Emrys' Rising Cut | 5, the plate appears |

## Greyed-option reasons

Each one sits in `lessons.json` beside its step and says why where it can. Any option the script
gives no reason for says "Not that one. Make the move I named." Verbs follow the buttons: "Defend
with", "Take it" (no defense), "Take a wound", "Place", "Pick" for a search, "Draw" for a draw. A
bare "Take" always means damage.

## Left to first-time tips in normal play

Non-Combat cards, Grounds, "Use when needed", "Draconic only", "Remove from the game after use",
Ally control, Seals (until lesson 7), the Reserve, the taller-ladder Aspect win, Remain, paying
your own wounds for damage, Focused, and Hit text that searches.

## Build notes

Why the numbers are what they are. Numbers are the engine's.

- The Straw Knight's Power is a Strike doing +3 Energy. A bare Strike from Might 5 (band B) into
  Emrys' Might 10 (band C) is 0 damage, so it would teach nothing.
- Caedan's ladder has two Aspects. With one, Emrys' climb to First Plate would stand above his whole
  ladder and win the duel on the spot (house rule 2026-09-19).
- Caedan enters at Energy 10. Lower, the lesson 3 climbing Cut lands on a spent Caedan for a
  critical hit before criticals are taught.
- No attack in lessons 1 and 2 deals 5 wounds, so no critical comes before lesson 5. That is why
  Overhand Cut is +2 and Thrown Dagger is a bare Art (4 wounds).
- The lesson 2 keep is fixed to the Parry so lesson 3 runs one way: a kept Overhand Cut would let
  Caedan's thrown-back swing land and change every number after it.
- Caedan's deck has a spare card in front of Pommel Bash for the one wound the climbing Cut deals
  him in lesson 3, and the three cards his old empty turn used to draw are gone, so lesson 4 opens
  on the same hand as before.
- The fresh bout sets Caedan to Energy 8, where Power Up on his old empty turn used to leave him.
  At 5 his Might drops a band and the Lashing Tail in lesson 4 deals 4 Energy instead of 3.
- Lesson 3 ends with a fresh bout. Without it Caedan climbs to Unparried from his own Fervor during
  lesson 4, and the Ironscale Hide's gain would not show on a full Emrys.
- Lesson 4: Steel Lashing Tail, not Horned Charge. Horned Charge with the Drill's +2 empties
  Caedan's Energy, and he then cannot pay 2 Energy for the Declaration.
- Lesson 4: Caedan ends on Sharp Rebuke, not a second Declaration. Declaration Attunes 2, and a
  second one climbs him to Unparried before lesson 5. The Rebuke's 8 wounds would be a critical on
  the Taloned Fist's Endurance 3, so the card it flips is the Scalebound Blow (Endurance 4): 4
  cards, no critical.
- Lesson 5 is boiled down (2026-10-03) to sword and Steel together, a critical hit and the
  last-Aspect Fervor win. Remain (Twin Claws), paying your own wound (Clawed Heel), Focused and Hit
  searches (Sword Flourish, Swordplay Drill) left the script for first-time tips, and with them
  Caedan's quiet turn and Emrys' second Combat.
- Lesson 5: the Routing Roar comes to hand through Emrys' Power rather than the draw, so no free
  keep can throw it away.
