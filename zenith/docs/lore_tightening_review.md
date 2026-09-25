# Lore tightening and lead-ins, proposals for sign-off

2026-09-24. From an adversarial review by four reviewers (fighting-game dialogue, fragmented
lore, continuity, narrative systems). Nothing here is applied. Mark each item yes, no or change.
Items marked [NEW] add lore that is not in `cast.md` today.

## 1. How lead-ins work (settled by the reviewers, needs your yes)

1. Narration is a short stage direction, at most 90 characters. It never explains a link.
2. Lore hints live only in spoken lines, never in narration, so a speaker can be wrong or lying.
3. A first meeting is plain. Meeting again, losing to them, or levelling the main brings in the
   hints. This needs a small new save file that counts meetings, wins, losses and lines seen.
4. Lines are chosen by the opponent's deck, not only the character. Edric in his fire deck gets
   different lines from Edric in his Tide deck; the same goes for Siphon's two decks.
5. General replies are tagged by what the opponent's call is (a challenge, a demand, a warning),
   so "Lord Mourne, if you please" never answers "Give it." At least 6 replies per main, plus
   extra replies that open as the main levels up.
6. An Ally in play (a guest, or Emrys and Kell after they join) can add a third line, once per act.
7. Quarr gets lines for when he turns up mid-run as an elite. He can, today.
8. Five scenes per connected pair to start: first meeting, two repeats, boss first, boss repeat.
9. Eidolons are described on screen, never named. The player matches them up.
10. A lead-in does not pop up achievement teasers. Hints stay hints.

## 2. Mistakes in the draft lead-ins (to fix)

- Caedan taught Emrys the sword. Edric did not (`cast.md` Emrys).
- The Vales' one exception was "a swordsman of Rooke blood". Edric was born a Hask, so that
  reads as Emrys. The Caedan scenes treated Edric as the exception. See question A.
- Caedan is not "the last of them": Tavin Vale and Caedan's mother are alive.
- Siphon drinks for itself now. It slipped the Collegium's leash.
- Edric cannot know Mourne sold his regret. The line becomes "They say you sleep well, Mourne."
- Marrow's act 1 boss scene had it backwards: the design doc says she wants to hire Mourne and
  they fight over his price.
- Sable's "made her offer twice" breaks if the road meeting never happened. It needs a version
  for each case.
- "Thirty years married" was invented. "Long married" is enough.
- Mourne and Ashmark went *to* the toll gate, not through it.
- The general replies clash: Emrys "You'll do." answered by Ashmark "You'll do."

## 3. Clean-up in cast.md (no new lore)

- Relations are listed one way only in three places. Add Ashmark to Siphon's list, Alder to
  Osric's, and Edric and Alder to Emrys'.
- The relations section says "Settled" and then "(first draft)". Pick one.
- Caedan "The last of the line" becomes "The last Vale to carry the sword".
- Ansel is "the middle son", but only two sons are recorded.
- Mercy is "she" in one column and "it" in the next.
- Mourne "A lord with the company at his disposal" is present tense; he lost that. "Once a lord".
- The toll-gate agent is described twice (Two elsewheres, and Agreed and not yet named).
- The relations network could become one symmetric list in data, so lead-ins, Key nodes and Ally
  introductions all read the same source.

## 4. Lore decisions (yours)

**Answers, 2026-09-24** (proposed wording still needs your sign-off):

- **A.** The Vales are old family friends of the Rookes, war companions. A Vale taught Edric the
  sword, and when Emrys was born the Vales promised him the same teaching, which Caedan gave.
  Tavin is Caedan's son, fostered with Edric because Caedan's life is too dangerous for a child.
  That is where Ansel and Tavin's back-to-back bond comes from. Replaces "taught to blood, one
  exception, do not discuss why".
- **B.** Left open. Quarr stays mysterious and says little about the Heart.
- **C.** The Pact leans toward the demons. Some of its members deal with them, not all.
- **D.** Ashmark keeps no Allies. He absorbs the people he beats, and they surface in his
  lead-ins as whispers of their memories coming up against his will. They are not helpers and
  do not act in the duel.
- Caedan becomes older. His mother stays off screen.

### Wording (applied 2026-09-24, with section 3's clean-up)

The war is the two kings' war, formal name pending.

`docs/cast.md`, and the matching strings in `tools/gen_roster.py` (CAST, ART), which feed the
art pipeline:

- **Vale line intro:** "A family sword art, nearly extinct, taught to blood and once to a
  friend. The Vales and the Rookes are old friends from the war: Caedan fought beside Edric and
  taught him the Vale cut. When Emrys was born, Caedan promised the boy the same teaching, and
  kept the promise." The line about Caedan's mother keeping the records stays.
- **Edric:** "The Vales made one exception ... and do not discuss why" becomes "Caedan Vale
  fought beside him in the war and taught him the Vale sword, the only time the Vales have
  taught it outside the blood."
- **Caedan look:** "Slight man in his late twenties" becomes "Lean man in his mid forties".
  Aspect 1 "young and exact" becomes "exact, every angle correct" (`gen_roster.py` ART
  `personality_16` too). The later Aspects already grey him.
- **Caedan who:** "The last of the line" becomes "The last Vale to carry the sword", plus "His son
  Tavin is fostered with the Rookes, because his father's road is no place for a child."
- **Tavin:** "A Vale cousin fostered with the Rookes" becomes "Caedan's son, fostered with the
  Rookes since he was small because his father's road is no place for a child. He grew up beside
  Ansel." (`gen_roster.py` CAST too.)
- **Relations:** Edric gains "Caedan (old war companion, taught him the sword)". Caedan becomes
  "Tavin (son), Emrys (pupil), Edric (war companion)".
- **The Pact** (world in ten lines): add "It leans toward the demons. Some of its members deal
  with them and the Pact does not stop them, and the Vigil holds that against the whole side."
- **Ashmark:** "He fields no Allies" stays, plus "**Absorption.** He takes in the people he beats.
  They do not fight for him. What surfaces is memory: their whispers, and his own, coming up
  against his will. Pieces of who he was can surface the same way."

- **A. The Vale exception.** Emrys (three reviewers), or Edric through a hidden tie between the
  Vale and Hask families [NEW].
- **B. How Quarr got the Heart.** One true answer written in the bible first. Then either Quarr
  tells each main a different story (one of them an obvious boast), or he never says. Nobody
  fetched it from across the wall until you decide whether a gate has ever opened before.
- **C. Pact against the demon mark.** Today Ashmark's and Quarr's arcs say "The Pact shows as",
  and nobody says who a Pact duelist signs with. Proposal: the Pact is signed at a place of power
  with the Eidolon behind that gate, and a mark is a private deal with a demon [NEW].
- **D. Ashmark's thin runs.** He fields no Allies and has no Encounter guests, so his runs get
  the fewest scenes and hints. Proposal: hostile construct guests who fight beside him for a
  share of the feed [NEW], or more scene variants for him instead.
- **E. Mourne in Marrow's deck.** Scrap Requiem fields a Mourne card (`personality_48`), so
  Mourne's act 1 boss puts a Mourne on Marrow's side. Drop it from her boss deck, or give Marrow
  a line about it ("Some of me already fights for you").
- **F. Hedge constructs.** Nobody is Hedge today. Make Mercy and Cull Hedge [NEW]. Changes data.
- **G. "Retained".** Mourne betrayed "the king who had retained him", and Pim "came out of the
  retained guard". Same power, which links Pim to Mourne [NEW], or change one word.
- **H. New links** [NEW], each separately:
  - Draik Company against the Collegium: Sable sells what the Collegium meters.
  - Quarr and Torvan Hask were Pact together. Ties Quarr to Edric.
  - Edric fought on the other side of Mourne's betrayal in the two kings' war. Gives the kneeling
    feud a cause.
  - Corin Thrace is rumoured to be the one who got his mark out.

## 5. Rejected by the reviewers

- "Toll" as the word for every price in the setting. It blurs the Pact, the mark and mana.
- Marrow's Breaker's Yard as the toll-gate agent's yard. A construct cannot be marked.
- Torvan Hask marked at the toll gate.
- Cull as Corven, the Collegium's founder. Cull is "Collegium-trained".
- Quarr "has not left the gatehouse in a year". He can appear on the road.

## 6. Code findings

- An Encounter guest can be the same character as the opponent (`adventure/adventure_map.gd:473`
  picks a guest with no check). Edric's guests include Caedan and Emrys; Mourne's include Marrow,
  Sable and Kell.
- Quarr (`steel_beatdown`) can be drawn as a mid-run elite, since he is only held back while the
  stronger band has other decks left.
