# Tutorial script, lessons 1 to 5

One continuous training session in the Rooke yard. Caedan Vale teaches Emrys the sword, Emrys'
Steel wakes in the middle of it, and Caedan changes the training to fit. One board the whole way:
no fades, no separate screens. Each lesson opens with its title as a banner over the table while
play carries on, and the title stays as a small tag in the top left corner.

This is the script as built. The data is `data/tutorial/lessons.json` (beats), `decks.json` (the
three Life Decks, top card first) and `cards.json` (the Straw Knight). The director is
`tutorial/tutorial_director.gd`, the timing of every line `tutorial/tutorial_pacing.gd`, and the
table side `scripts/duel/tutorial_panel.gd` with `scenes/duel/bark_bubble.tscn`.
`tests/tutorial_tests.gd` plays it end to end. "Build notes" at the end lists where this differs
from the draft that was signed off, and why.

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
- A lesson ends when its last beat is taught. Nobody has to win.
- Saving: the lesson reached is stored in the profile (`progress.json`). Resuming replays the
  script to that lesson's start in one instant step, so the board is the same as it was. Finishing
  lesson 5 marks the tutorial done and the next start is lesson 1 again.

## Voices and where they show

| Speaker in the data | Where it shows |
|---|---|
| `vale` | Vale's coach box: a small box with his face chip, docked beside what he means and joined to it by a glowing thread (a notch when it sits right beside it), with a ring round the spot. In lessons 3 to 5 he is also the rival, and the box speaks as him: "my Fervor", never "his". |
| `narration` | A ribbon across the top of the table. |
| `emrys` | A speech bubble at Emrys' duelist card. |
| `caedan` | A speech bubble at the rival's duelist card, lessons 3 to 5 only, where he fights. |

Three kinds of step carry words:

- **Stop.** The table waits while its lines play one after another. Each line has its time
  (`TutorialPacing`): a line in the box or the ribbon 0.8 s plus 0.3 s a word, 2 to 7 s; a bubble
  0.9 s plus 0.045 s a character, 1.4 to 3.2 s. A timer bar runs under the box, the pointer on the
  box pauses it, and a click on the box, Space or Enter shows the rest of the line or moves on. A
  stop marked `hold` waits on its last line for that click ("Click or press Space.").
- **Move.** Vale's instruction for the prompt now up stays in the box, tethered to the move, until
  the move is made; then the box drops away before the move plays. After 6 s with no input the
  ring bobs and pulses faster.
- **Bark.** A line in passing, in a bubble (or, for `vale`, a note bubble beside what it is
  about), that fades on its own while play goes straight on. A move or a rival move can carry one
  (`says`), shown as it is made.

Stops per lesson: lesson 1 has 4, lesson 2 has 2, lesson 3 has 3, lesson 4 has 2, lesson 5 has 3:
14 in all (the cap is 4, 3, 4, 3 and 3). The session puts 548 words on screen in lines and
callouts, down from 846.

Before each scripted rival move the rival's card gathers itself for 0.5 s (it rises and glows) so
the move reads as coming. The Straw Knight rocks on its base and sheds straw when hit.

## Cast on the board

- **Emrys Rooke.** Ladder for the session: the Eldest (Might 0, 4, 5 ... 13, Surge 1), then First
  Plate (Might 0, 12, 13 ... 21, Surge 2). First Plate is his top Aspect here. Power Up gains
  Surge + 1. Starts at Energy 5, Fervor 0. No Mastery.
- **Straw Knight.** Tutorial-only card (`tutorial_personality_01`, in `data/tutorial/` only).
  Might 5 at every stage (band B), so its numbers never shift. Surge 2. Power: Strike doing +3
  Energy (unused until lesson 2, when Caedan ties the rope to its arm). Life Deck of 40 plain
  Freestyle attack cards it never plays. Portrait: the Scarecrow from LimeZu's Modern Farm pack.
- **Caedan Vale.** Ladder for the session: Last Heir (Might 0, 3, 4 ... 12, Surge 2), then
  Unparried. Power: on entering Combat, look at the top 8 and may take a "Sword" card. His
  Freestyle Discipline Mastery comes with him. Enters in lesson 3 at full Energy.

Emrys' deck holds Emrys signature cards and Freestyle cards until the plate appears, then Steel
cards join. Caedan's deck holds Caedan signature cards and Freestyle cards only.

## Fervor over lessons 1 to 3

| Lesson | Card | Fervor after |
|---|---|---|
| 1 | Emrys' Rising Blow (Attune 1) | 1 |
| 2 | Emrys' Rising Blow | 2 |
| 3 | Emrys' Rising Blow (stopped, but Attune still resolves) | 3 |
| 3 | Emrys Risks It All (Attune 1) | 4 |
| 3 | Emrys' Rising Blow | 5, the plate appears |

---

In the tables, **Kind** is Stop, Move (the player's prompt), Bark, Rival or Op. The words column
names the speaker of each line: Vale (coach box), Narration (ribbon), Emrys or Caedan (bubbles).
Ring targets are in brackets.

## Lesson 1. The Straw Knight (4 stops)

Teaches: the Life Deck and how emptying it wins, declaring Combat, Energy and Might, Strikes,
Energy damage spilling into wounds, Arts and their cost, the Fervor meter and climbing, Power.

Board: Emrys at Energy 5, Fervor 0. Straw Knight at Energy 5. Emrys goes first. The first turn's
draw (Emrys' Rising Blow, Emrys' Sword Thrust, Lobbed Bolt) and Power Up (5 to 7) play as the table
opens.

| # | Kind | What happens | Words |
|---|---|---|---|
| 1 | Stop | The table opens | Narration: "Caedan Vale, the last Vale swordsman, keeps his promise to teach Emrys." / Vale [the Knight's card]: "That's the Straw Knight. Hit it." / Emrys: "It's STRAW, Master Vale!" / Vale [the Knight's card]: "Then you'll win." |
| 6 | Move | Declare Combat, the only enabled option | Vale [Declare Combat button]: "Declare Combat." |
| 8 | Move | Emrys' Power, "draw a card?": only Yes. Draws Emrys' Hilt Guard | Vale [the Yes tile]: "Draw a card. Your Power gives one when you declare." |
| 7 | Bark | The Knight draws 3 | Vale note [the Knight's hand]: "It draws three when you declare." |
| 9 | Move | Attack: Emrys' Rising Blow. Might 10 (C) against 5 (B) gives 2, +3: 5 Energy, Knight 5 to 0. Attune 1, Fervor 1 | Vale [the card's number]: "Click the Rising Blow to attack. Its number counts both fighters' Might." |
| 9 | Bark | The Blow lands; the Knight rocks | Emrys: "Ha! Take THAT, straw!" |
| 9 | Stop | | Vale [Emrys' Fervor tab]: "Attune fills your Fervor. Five and you climb." |
| 10 | Rival | The Knight passes | Emrys: "Can't hit back, can you?!" |
| 11 | Move | Attack: Emrys' Sword Thrust. 2 + 2 = 4, the Knight has no Energy left: 4 wounds | Vale [the card]: "Attack with the Sword Thrust." |
| 11 | Stop, held | | Vale [the Knight's Life Deck]: "No Energy left, so the damage hit its Life Deck. Empty it and you win." |
| 12 | Rival | The Knight passes | |
| 13 | Move | Attack: Lobbed Bolt. Costs 2 Energy (7 to 5), 4 wounds | Vale [the card]: "Attack with the Lobbed Bolt. Arts cost Energy and ignore Might." |
| 13 | Bark | Emrys' Might falls to 8, band B | Vale note [Emrys' ladder]: "Spending Energy lowers your Might." |
| 14 | Move | Knight passes, Emrys passes (only Pass enabled), Combat ends | Vale [Pass button]: "Pass and keep the Hilt Guard." |
| 15 | | Discard step: Emrys holds only the Hilt Guard, nothing to decide | |
| 16 | | The Knight's turn plays out on its own: draw, Power Up to 3, no Combat, discard | |
| 17 | Stop | At the end of the Knight's turn | Vale [the Knight's card]: "Good. Now it hits back." / Emrys: "Since WHEN?!" |

## Lesson 2. Guard (2 stops)

Teaches: defending with a card, taking turns in Combat, two passes ending Combat, the Discard
step, being attacked, Final Strike, skipping Combat, Recover.

| # | Kind | What happens | Words |
|---|---|---|---|
| 0 | Stop | | Narration: "Caedan ties a rope to the Straw Knight's arm." / Vale [the Knight's Power line]: "Now it can use its Power, a Strike." |
| 1 | | Emrys draws Emrys' Rising Blow, Emrys' Sword Thrust, Emrys' Sword Sweep. No Non-Combat decision. Power Up to 7 | |
| 2 | Move | Declares Combat | Vale [Declare Combat button]: "Declare Combat." |
| 3 | Move | Power: Yes, draws a card | Vale [the Yes tile]: "Take your card." |
| 4 | Move | Attack: Emrys' Rising Blow, 5 Energy against the Knight's 3: 3 Energy and 2 wounds. Fervor 2 | Vale [the card]: "Attack with the Rising Blow." |
| 5 | Rival | Power: Strike, pulled on the rope. Might 5 (B) against 10 (C) gives 0, +3: 3 Energy | Emrys, as it winds up: "It MOVES?!" |
| 6 | Move | Defend: Emrys' Hilt Guard (the only enabled defence). Stops it, then brings Emrys' Sword Thrust back from the discard pile | Vale [the Hilt Guard]: "Block with the Hilt Guard. Strike cards stop Strikes." |
| 7 | Move | Pass (the only enabled option). The Knight passes, Combat ends | Vale [Pass button]: "Pass. Two passes in a row end Combat." |
| 9 | Move | Discard step: keeps one card of his choice | Vale: "End your turn by keeping one card." |
| 10 | Rival | Its turn: Caedan pulls the rope, it declares Combat. Emrys draws 3 | |
| 11 | Rival | Power: Strike. Emrys holds nothing that stops it and takes 3 Energy (7 to 4) | |
| 11 | Bark | | Emrys: "OW! It's STRAW!" / Vale note [Emrys' ladder]: "Energy soaks hits first." |
| 12 | Move | Attack: Final Strike, on any card (the only enabled option). Discards it for a bare Strike: 1 Energy | Vale [Final Strike button]: "Make a Final Strike. Any card becomes one bare Strike, once per Combat." |
| 13 | Move | Knight passes, Combat ends. Emrys keeps one card of his choice | (no words) |
| 14 | Move | New turn. Draws 3. Declare: only Skip Combat is enabled. Then keeps one card of his choice | Vale [Skip Combat button]: "Skip Combat this turn." / keep: (no words) |
| 15 | Move | Recover: moves the top discard to the bottom of his Life Deck | Vale [Recover button]: "Recover a card. A skipped Combat puts one back into your life." |
| 16 | Stop | The Knight's turn plays out, then Emrys draws Emrys' Rising Blow, Emrys Risks It All, Emrys' Rising Blow and powers up to 8 | Vale: "Enough straw." / Narration: "Caedan draws his sword." |

## Lesson 3. The Spar (3 stops)

Teaches: a real rival's Power, a stop that throws the attack back, Attune working even when the
attack is stopped, an attack Strike cards can't stop, climbing an Aspect.

Board adjustment: the Straw Knight and its piles are carried off the far edge. Caedan's Duelist
card, Mastery and Life Deck slide into the rival seat, Caedan at Energy 10. Emrys keeps
everything: Energy 8, Fervor 2, hand, piles.

| # | Kind | What happens | Words |
|---|---|---|---|
| 1 | Stop | | Emrys: "Finally! No more straw!" / Caedan: "Guard." |
| 2 | Move | Declares. Power: Yes, draws a card | Vale [Declare Combat button]: "Declare Combat." / Vale [the Yes tile]: "Take your card." |
| 3 | Rival | Power: looks at his top 8, takes Vale's Sword Draw. Draws 3 | Vale note [his Power line]: "Every Duelist has a Power. Read mine." |
| 4 | Move | Attack: Emrys' Rising Blow. Attune 1, Fervor 3 | Vale [the card]: "Attack with the Rising Blow." |
| 5 | Rival | Defends with Caedan's Riposte and stops it | Vale note [Emrys' Fervor tab]: "Stopped, but the Attune counted." |
| 6 | Rival | Attack: repeats the stopped Rising Blow against Emrys: 4 Energy (8 to 4) | Caedan, as he winds up: "Left shoulder. Just like your father." / then Vale note [his card]: "My Riposte threw your attack back." |
| 7 | | Emrys takes it (nothing in hand can stop it) | |
| 8 | Move | Attack: Emrys Risks It All, 4 Energy (Caedan 10 to 6). Caedan can't answer with a Strike card. Fervor 4 | Vale [the card's text]: "Attack with Emrys Risks It All. Strike cards can't stop it." / Emrys, as he plays it: "Everything I've GOT!" |
| 9 | Rival | Attack: Vale's Sword Draw. Emrys takes 4 Energy and 1 wound | |
| 10 | Move | Attack: Emrys' Rising Blow. Fervor 5: he climbs as the Blow is made, and it lands at Might 21 for 6 Energy | Vale [the card]: "Attack with the Rising Blow." |
| 11 | Stop | Emrys stands at First Plate: full Energy, Fervor back to 0. His card flashes and a grey metal sheen sweeps across it (0.9 s) as the caption shows | Narration: "Grey metal closes over Emrys' forearms." / Emrys: "Master Vale... my ARMS?!" / Caedan: "...That isn't my sword art, boy." / Emrys: "Is it GOOD?!" |
| 12 | Stop | | Vale [Emrys' Aspect]: "Five Fervor climbs an Aspect and refills your Energy." / Caedan: "Let's find out. Again." |
| 13 | Move | A fresh bout: Combat ends, both fighters to Energy 5, Caedan's Fervor to 0. Emrys keeps one card of his choice | Vale: "We both restart at five Energy. Keep one card." |

## Lesson 4. Steel (2 stops)

Teaches: Drills, Defense Shields, Endurance, a stop that also gains Energy, Disrupt.

Board adjustment, at the end of Caedan's turn: five Steel cards slide onto the top of Emrys' Life
Deck (Steel Clawed Hands Drill, Steel Hardscale Drill, Steel Lashing Tail, Steel Taloned Fist,
Steel Clawed Heel) and three onto its bottom (Steel Ironscale Hide, Steel Twin Claws, Steel
Routing Roar).

| # | Kind | What happens | Words |
|---|---|---|---|
| 1 | Stop | | Caedan: "I don't know magic. I know what hits. Show me." |
| 2 | | Draws Steel Clawed Hands Drill, Steel Hardscale Drill, Steel Lashing Tail | |
| 3 | Move | Non-Combat: places both Drills, one at a time. Power Up to 8 | Vale [the Drill]: "Set out the Clawed Hands Drill. Drills stay until you climb." / Vale [the Drill]: "Set out the Hardscale Drill. It stops one Strike each Combat." |
| 4 | Move | Declares. First Plate's Power searches the Life Deck (whole deck shown): only the Ironscale Hide enabled. Caedan's Power takes his second Vale's Sword Draw | Vale [Declare Combat button]: "Declare Combat." / Vale [the Hide in the tray]: "Take the Ironscale Hide. Your new Power fetches it." |
| 5 | Move | Attack: Steel Lashing Tail, with the Clawed Hands Drill adding 2: 3 Energy and 4 wounds. Fervor 1 | Vale [the card's number]: "Attack with the Lashing Tail. Its number includes the Drill's +2." |
| 6 | Rival, Move | Attack: Caedan's Pommel Bash. Emrys declines to block; the Hardscale Drill stops it | Vale [No Defense button]: "Don't block. Your Hardscale Drill is a Defense Shield." |
| 6 | Bark | | Emrys: "It held!" / Caedan: "...Hm." |
| 7 | Move | Passes | Vale [Pass button]: "Pass." |
| 8 | Rival, Move | Attack: Caedan's Declaration, an Art: a battle shout. Disrupt 2 as it is made. 4 wounds; Emrys declines to block. The first card flipped is Steel Taloned Fist | Caedan, as he winds up: "HAH!" / Vale [No Defense button]: "Don't block this one." |
| 9 | Move | Endurance prompt: only Use Endurance. Removes Taloned Fist to prevent 3, so the shout costs 1 card | Vale [Use Endurance button]: "Use Endurance. The flipped card soaks the rest." |
| 10 | Bark | Declaration's Disrupt 2 took Fervor 1 to 0 | Vale note [Emrys' Fervor tab]: "My Disrupt lowered your Fervor." / Caedan: "One Aspect a day, boy." |
| 11 | Move | Passes | Vale [Pass button]: "Pass again." |
| 12 | Rival | Attack: Vale's Sword Draw | |
| 13 | Move | Defends with Steel Ironscale Hide. Stops it and gains up to 7 Energy: 8 to 10 | Vale [the Hide]: "Block with the Ironscale Hide. It also gains Energy." |
| 14 | Move, Stop | Emrys passes, Caedan passes, Combat ends | Vale [Pass button]: "Pass." / Caedan: "...It holds." |

## Lesson 5. Both (3 stops)

Teaches: mixing sword and Steel, Focused, Empower, paying your own life for damage, Remain,
critical damage, and the Fervor win at the last Aspect.

| # | Kind | What happens | Words |
|---|---|---|---|
| 0 | Bark, Op | Both fighters to Energy 5, before Caedan's turn | Narration: "They square up for a fresh bout." |
| 1 | Stop | Caedan's turn plays out quietly | Vale: "Sword and metal. Both at once." |
| 2 | Move | Draws Steel Clawed Heel, Emrys' Sword Flourish and a spare card. Power Up to 8. Declares. His Power fetches Steel Twin Claws | Vale [Declare Combat button]: "Declare Combat." / Vale [the Claws in the tray]: "Take the Twin Claws." |
| 5 | Move | Attack: Steel Clawed Heel. Asked whether to discard his own top card for +3 wounds: only Yes. 7 Energy (Caedan 8 to 1) and 3 wounds | Vale [the card]: "Attack with the Clawed Heel." / Vale [Discard a life card button]: "Discard a life card for 3 more wounds." |
| 4 | Rival | Attack: Caedan's Quickstep. Hardscale stops it | |
| 3 | Move | Attack: Emrys' Sword Flourish, Focused: 4 Energy, 1 of it spilling into 3 wounds. Hit: puts Emrys' Swordplay Drill into play from the Life Deck (whole deck shown, only the Drill enabled) | Vale [the card]: "Attack with the Sword Flourish." / Vale note as it is played [his card]: "It's Focused, so Shields and stop-anything cards can't touch it." / Vale [the Drill in the tray]: "It landed. Put your Swordplay Drill into play." |
| 6 | Rival | Passes | |
| 7 | Move, Rival | Attack: Steel Twin Claws. Caedan's Riposte stops it; Remain 1 keeps it on the table | Vale [the card]: "Attack with the Twin Claws. Remain keeps it for another attack." |
| 8 | Rival | Passes | |
| 9 | Move | Attack: Steel Twin Claws again; the second Riposte stops it. Caedan passes, Emrys passes, Combat ends, Emrys keeps one card | Vale [the card]: "Attack with it again." / Vale [Pass button]: "Pass." / keep: (no words) |
| 10 | Move | Next turn. Declares. His Power fetches Steel Routing Roar. Attack: Routing Roar with Empower 3 (only the Empowered attack enabled): 4 + 3 = 7 wounds | Vale [Declare Combat button]: "Declare Combat." / Vale [the Roar in the tray]: "Take the Routing Roar." / Vale [the card]: "Attack with the Routing Roar. Empower adds wounds but skips its text." / Emrys, as he plays it: "My turn to shout! HAAAH!" |
| 11 | Move | Critical damage: only Disrupt 1 (lower Caedan's Fervor by 1) enabled. Fervor 4 to 3 | Vale [Disrupt 1 button]: "Five or more wounds is a critical hit. Use it to lower my Fervor." |
| 12 | Stop, held | | Vale [Emrys' Fervor tab and Aspect]: "At your last Aspect, filling this meter wins." |
| 13 | Stop | Caedan calls the session | Caedan: "Enough. Go show your father." / Emrys: "Same time tomorrow, Master Vale!" / Caedan: "...Same time tomorrow." |

The session ends with no winner ("Session ended") and the table closes to where the tutorial was
started from (the title today). Lessons 6 (Allies) and 7 (Seals) are not built yet.

---

## Greyed-option reasons

Vale's reason for each greyed option is in `lessons.json` beside its step. The common ones: a
Final Strike on an attack step, "Use your cards first."; the wrong attack, "Start with the Rising
Blow." or "Use the Sword Thrust." (and so on); Pass on an attack step, "Keep going." or "Attack
me."; an attack while he wants a pass, "Pass now." or "Wait for me."; Discard everything on a
keep, "Keep one."; a Life Deck card that is not the pick, "Take the Ironscale Hide." (and so on).
Any option the script gives no reason for says "Not that. Do what I told you."

## Left to first-time tips in normal play

Non-Combat cards, Grounds, "Use when needed", "Draconic only", "Remove from the game after use",
Ally control, Seals (until lesson 7), the Reserve, and the taller-ladder Aspect win.

## Build notes

Where the build differs from the signed-off draft, and why. Numbers are the engine's.

- The Straw Knight's Power is a Strike doing +3 Energy. A bare Strike from Might 5 (band B) into
  Emrys' Might 10 (band C) is 0 damage, so beats 2.5 and 2.11 would teach nothing.
- The Straw Knight's Life Deck is 40 cards: it draws 15 and takes about 12 wounds over two lessons.
- Caedan's ladder has two Aspects. With one, Emrys' climb to First Plate would stand above his whole
  ladder and win the duel on the spot (house rule 2026-09-19).
- Caedan enters at Energy 10. At 5, the lesson 3 climbing Blow lands at Might 21 on a spent Caedan
  for 7 wounds, a critical hit before criticals are taught.
- Lesson 1 beat 4 and lesson 2 beat 1: the engine asks no Non-Combat question when nothing can be
  set out, so neither has a step.
- Lesson 1 beats 7 and 8 trade places: Emrys' entering-Combat Power resolves before the opponent's
  draw.
- Lesson 1 beat 9: the forecast number shows on the card's attack badge when the card is hovered;
  the ring sits on the badge once the fan is open, and round the card while it is tucked.
- Lesson 2 gains two harmless Discard-step choices (after beat 13 and on the skipped turn).
- Lesson 3: the swap happens at Emrys' first decision of his turn, after that turn's draw, since a
  seat is only swapped while the other seat decides. Emrys' Power asks its "draw a card?" again.
- Lesson 3 ends with a fresh bout: both fighters to Energy 5 and Caedan's Fervor to 0. Without it
  Caedan climbs to Unparried from his own Fervor during lesson 4, and the Ironscale Hide's gain
  would not show on a full Emrys.
- Lesson 4: Steel Horned Charge became Steel Lashing Tail. Horned Charge with the Drill's +2
  empties Caedan's Energy, and he then cannot pay 2 Energy for the Declaration.
- Lesson 4: First Plate's Power is a Life Deck search every Combat, so it is taught at beat 4 and
  fetches the Ironscale Hide. Holding the Hide, Emrys is asked for a defense at beats 6 and 8, and
  declines both.
- Lesson 4 beat 7: Emrys passes instead of swinging a second Steel Strike. The lesson needs two
  Drills, a Strike and the Hide, and the draw plus the search bring four cards.
- Lesson 4 beat 13: the Ironscale Hide gains up to 7, and Energy stops at 10, so 8 to 10 shows.
- Lesson 5: a fresh bout (both to Energy 5) opens it, and the Clawed Heel comes before the Sword
  Flourish. In the draft order the Heel's overflow plus its 3 paid wounds made 6 wounds, a
  critical hit before beat 11.
- Lesson 5 beat 4: Caedan swings Caedan's Quickstep, which does not raise his own Fervor; another
  Pommel Bash would take him to 5 and climb him.
- Lesson 5 beats 7 and 9: Caedan stops both Twin Claws swings with Riposte. He has no Energy left,
  and a landed swing would be 8 wounds.
- Lesson 5: Twin Claws and Routing Roar come to hand through Emrys' Power rather than the draw, so
  no free Discard-step keep can throw either away.
- Lesson 5 beat 3: nothing Caedan holds could try to stop the Focused Flourish and fail (his only
  stop, Riposte, answers a Strike and would work), so Focused is taught by the one note as the card
  is played.

### The 2026-09-30 pass: a live fight instead of a slideshow

- 51 stops became 14, and 846 words on screen became 548. The cuts: the draw, Non-Combat and
  Power Up callouts before the first move (they play out on screen), the second and third
  reminders that declaring makes the rival draw, every "keep one card" after the first, the Remain
  follow-ups, the Hardscale callout that repeated lesson 4, the "Not every Art is a spell" line,
  and the "calls a halt" and "calls the session" narration.
- The two ways to win are said where they first happen, in lesson 1: the Life Deck on the first
  wounds, the Fervor meter on the first Attune. Lesson 5's closing callout only reminds the Fervor
  win at the last Aspect.
- "Is it GOOD?!" stays in the plate stop: "Let's find out. Again." answers it.
- Lobbed Bolt stays as it was: an Art can be mundane for a fighter who casts nothing, like
  Caedan's shouted Declaration.
- Caedan's signature card `signature_strike_13` is named "Vale's Sword Draw" throughout.
