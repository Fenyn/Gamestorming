# Strategy

How Eidolarch is actually played well, in the terms the engine uses. It exists so that AI profiles,
deck revisions and card costing all argue from the same model instead of from intuition. The
reasoning is drawn from the reference game's competitive play, translated to our names and numbers;
where our rules differ, our rules win.

Rules of record are `../../designs/zenith.md`. AI weights are `ai/ai_profile.gd`.

## 1. The resource model

Four resources, and confusing them is the root of most bad play.

| Resource | Renews | Runs out | What it really is |
| --- | --- | --- | --- |
| **Energy** | Power Up each turn: Surge Rate + 1 | Every turn, to attacks and costs | A per-turn budget, not hit points |
| **Life Deck** | Only through `recover` and `shuffle_discard` | Permanently | Hit points **and** every card you will ever draw |
| **Hand** | Draw step, Mastery, card effects | On use | Your options this Combat |
| **Fervor** | Card text only, never from a plain hit | Spent at 5 to ascend | A shared clock both players race |

Three facts follow, and they drive everything below.

**Energy is rented, life cards are owned.** Energy you did not spend this turn is largely Energy you
gave away, because Power Up refills toward the top of the stage table anyway and a Strike will take
the rest. Life cards never come back on their own.

**A wound is two losses.** The card leaves your Life Deck *and* it is a card you will never draw.
Damage is deck destruction; twenty wounds is twenty fewer draws for the rest of the game.

**Stage damage past 0 becomes wounds 1:1** (`designs/zenith.md`, "Energy damage past 0"). This is
the hinge of the whole game. A Strike against a full gauge is a tax; the same Strike against an
empty one is a kill. Everything about tempo below is really about who is standing at 0 when the big
Strike lands.

## 2. Tactics that hold for every deck

**Spend stages that were leaving anyway.** If the incoming attack cannot be stopped, the Energy
in your gauge is already the opponent's. Converting it into an Art first is free damage. The wrong
question is "how much Energy will I have left"; the right one is "will I still hold this Energy when
I next need it". Hold stages when you hold the block that protects them, and when you will still be
standing on them at the start of your own attack phase. Otherwise spend them.

**A low Might duelist attacks with Arts; a high Might duelist attacks with Strikes.** Arts skip the
Strike Table entirely and go straight at the Life Deck, so they are how an outgunned duelist
threatens a stronger one. Strikes read the table, so they reward whoever is already ahead on Energy
and push the loser toward the 1:1 conversion above. A deck whose duelist tops a band below the field
should be routing damage through Arts, not trying to win the table.

**Blocks are spent against the attack that matters, not the first one offered.** A block used on a
two-stage Strike is a block that is not there for the eight-stage one. The exceptions are blocks that
replace themselves (search, draw or recover on use) and blocks in play rather than in hand; those are
close to free and should be used freely.

**Count the opponent's hand.** Press hardest when they are empty, because every attack then lands.
Set up while they are full. This is the single most reliable read in the game.

**Fervor denial is worth as much as Fervor gain.** It is one meter per player toward one shared
clock. A deck that cannot use its own Fervor still wants the opponent's at 0, and a Grounds that caps
Fervor gain is a pure gift to whichever player is not climbing.

**Final Strike is a concession.** After it you neither attack nor defend for the rest of the Combat.
It is correct only when it wins, or when the Combat is already lost and the cards in hand are worth
less than the swing.

**Seals are pried out of the Life Deck.** A Seal in the Life Deck surfaces on a wound and returns, so
hitting a Seal deck churns its set. A Drill that guards Seals turns capture off completely, so it is
the piece to land first and the piece to remove first.

## 3. The seven decks

Each entry is: what it is trying to do, the lever that makes it work, the line to play, and the
mistake that loses the game.

### Steel — Halden Quarr, `steel_beatdown` (strike_beatdown)

Wins by survival, on force. The ladder is on spec (aspect 1 tops C, aspect 2 E, aspect 3 F) and the
Mastery draws one card per Combat, two on a Steel flip, so it enters Combat every turn for free
cards and turns them into Strikes. Endurance stands in for blocks.

- **Lever.** It is normally the higher band, so every Strike both wounds and strips the Energy that
  would let the opponent answer. The 1:1 conversion works for it and against everyone else.
- **Line.** Declare every turn. Strip Energy first, then land the modified Strike into the empty
  gauge. Remove Seals and Non-Combats, because it has no other answer to them.
- **Mistake.** Sitting a turn out. Its card engine only runs inside Combat.

### Pyre — Bram Ashmark, `pyre_beatdown` (strike_beatdown)

Wins by Ascension, or by survival if the race is slow. Surge 2/5/6 is the fastest climb in the set
and the Mastery buys Focused attacks with life cards.

- **Lever.** Surge means it refills faster than anyone, so it can afford to spend to the floor every
  Combat.
- **Line.** Attack early and often, pay life for Focus on the attack that must land, climb on Fervor.
  Open with the forbids that shut off answers.
- **Mistake.** Paying life for Focus on an attack that was going to land anyway. Its Life Deck is its
  Ascension fuel and its clock.

### Shade — Sable Draik, `shade_henchmen` (allies)

Wins by survival, from the board. Its aspects all carry `allies_share` and `ally_control_any_stage`,
so Allies can take Combat at any Energy rather than waiting for the Duelist to be emptied.

- **Lever.** It is the Ally deck that does not have to go to 0 first. It keeps its own Energy and
  still attacks from the board.
- **Line.** Allies down early, keep the hand full going into Combat, spend disruption on the
  opponent's Drills, Allies and Non-Combats, save the few blocks for the large hits.
- **Mistake.** Trading Allies off one for one. Each is a body that absorbs a whole attack.

### Freestyle — Caedan Vale, `freestyle_swords` (drills)

Wins by survival, on card advantage. The aspect 1 power digs eight cards deep for a Sword card on
entering Combat and the Mastery protects Drills.

- **Lever.** Sixteen blocks, several of which replace themselves, plus a Drill board that nothing
  can discard while the Mastery stands. It wins the long Combat.
- **Line.** Drills and the Heirloom Blade onto the table, enter Combat every turn for the dig, turn
  the card advantage into Sword Strikes the Drills make heavy. Take aspects as they come; five is
  too long a road to chase.
- **Mistake.** Letting the Mastery be shut off. Advancing an aspect normally discards your Drills
  (`designs/zenith.md`, Fervor at 5), but this Mastery guards them "for any reason", the aspect
  change included, so this is the one Drill deck that can climb and keep its board. A card that
  forbids the Mastery for a turn takes that away and makes the climb cost the board again.

### Storm — The Ninth Vessel, `storm_volley` (art_beatdown)

Wins by survival, by barrage. The Relic rules out its Ascension win and shields its Fervor and
aspect, so Fervor is only fuel for the climb to aspect 3, whose power is a free Art that draws two
every Combat. The Mastery makes Arts cost 1 instead of 2 and adds a life card to each.

- **Lever.** Arts ignore the Strike Table, which is the only reason this deck is playable: its ladder
  tops in D at aspect 3, a full band under Steel and Pyre. It must not try to win the table.
- **Line.** Race to aspect 3, then fire discounted Arts every Combat off the free Art and the draw.
  Blocks that search replace themselves, so defend freely. Stage damage is not the goal; wounds are.
- **Mistake.** Hoarding Energy. At Surge 1 to 2 it is never going to out-Energy anyone, and stages
  held back are stages a Strike takes for free. Spend them on Arts.

### Root — Osric Thornwald, `root_seals` (seals)

Wins by the full Marble set, or by survival in a very long game. Deliberately low Might for its
aspect all the way up; the aspect powers feed on the discard pile instead.

- **Lever.** The discard pile is a second Life Deck. The Mastery, Second Wind, the Root blocks and
  the aspect 4 power all pull cards back out of it, so spent blocks are not really spent.
- **Line.** Keeper's Drill down before Seals go down. Fetch Seals with the Non-Combat package, take
  the opponent's with Seal Seizure and Sleight, keep their Fervor at 0 with the stripping blocks and
  Seals 2 and 6. Arts are both the damage and half the Seal engine, since a successful Art turns
  Eyes Beyond the Gate into a free Seal.
- **Mistake.** Placing Seals before the guard. Also its own Frostbound Moor, which caps its climb as
  hard as the opponent's, on a duelist who badly wants aspect 4 and 5.

### Tide — Dame Alder Rooke, `tide_companions` (allies)

Wins by survival, by attrition. Aspect 1 carries `protect_allies`, so the deck wants to stay there;
Fervor and aspect gains are actively unwanted.

- **Lever.** Allies take control of Combat once the Duelist is at Energy 0 or 1, and then use their
  own Might rather than the Duelist's 3-to-12 ladder.
- **Line.** Allies out early, let the Duelist's Energy fall, hand Combat to the Ally, bond the two
  named Allies when both are out, win on wounds from Allies' Arts. The Mastery and the Arts keep the
  opponent's Fervor down, so Ascension is the clock to police.
- **Mistake.** Defending the Duelist's Energy. Unlike every other deck, going to 0 is this deck's
  plan, not its failure state.

## 4. Where each principle lives in an AI profile

The profile is meant to be the strategy above, written as numbers. When a deck plays wrong, the fix
is usually one of these rather than new code.

| Principle | Weight |
| --- | --- |
| Wounds beat stage damage for this deck | `play.damage_life` up, `play.damage_stage` down |
| Enter Combat every turn | `play.declare_bias` up |
| Blocks are cheap because they replace themselves | `play.defend_card` down |
| Hold blocks for the big hit | `play.defend_card` up |
| This deck's win route | `own.seal`, `own.ascension`, `own.ally`, `own.drill` |
| The route to police on the other side | `foe.ascension`, `foe.seal`, `foe.ally` |
| Climb for the aspect powers, not the win | `own.aspect` up with `own.ascension` low |
| Deny Fervor | `effect.fervor` up; `effect.fervor_self` separately if own Fervor is unwanted |
| The discard pile is a resource | `own.discard` up, `effect.recover` up, `effect.remove_discard` up |
| Guard the Seals, or remove their guard | `own.seal_guard`, `foe.seal_guard` |
| A plan that pays off after the opponent answers | `think.turns` above 1 |
| Energy is worth keeping | `own.energy`, `play.attack_cost` |

Two things the profile cannot currently say, and which need code if we want them:

- **"These stages were leaving anyway."** `play.attack_cost` is flat, so it charges the same for
  spending Energy that a Strike was about to take as for spending Energy that would have survived.
  `attack_forecasts` now reports `energy_left` per option, which is the input a better rule needs;
  the rule itself is not written. Any rule here must not punish an Art from a low gauge, which is
  correct play for Storm, Root and Tide.
- **"Ally control is where my damage comes from."** `play.control_ally` biases the handover, but
  nothing values *getting* the Duelist to Energy 0 or 1 so that Tide's handover is legal at all.

## Sources

Reference-game strategy reading behind section 2:

- [A beginner's guide to the Dragon Ball Z CCG](https://maskedcarnie.blogspot.com/2014/11/a-beginners-guide-to-dragon-ball-z-ccg.html)
- [The Mastery Race — RetroDBZccg](https://retrodbzccg.com/2012/07/13/the-mastery-race/)
- [The Strategies of Supreme West Kai — RetroDBZccg](https://retrodbzccg.com/2014/03/17/the-stragies-of-supreme-west-kai/)
- [Speedrun strats and notes](https://www.speedrun.com/dbzccc/guides/6ly6b)
- [Score Entertainment rulebook](https://lackeyccg.com/dbzccg/dbzccg_rules.pdf)
