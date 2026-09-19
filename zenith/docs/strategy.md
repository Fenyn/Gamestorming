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

**Count the two ladders before turn one.** The Most Powerful Personality rule (house rule, 2026-09-19) means a duelist whose announced Aspect ladder is taller than the rival's wins by entering the first Aspect above the rival's top one, with no second Fervor peak. Five Aspects against three wins on Aspect 4. This makes the Aspect count a matchup fact rather than a deck stat: the same five-Aspect deck has a live Ascension route against every three-Aspect deck in the field and none at all against another five-Aspect one, where the old top-Aspect-plus-a-meter road is all there is.

The two roads cost about the same, so this rewards no one by default: five against three is three climbs (15 Fervor) and three against three is two climbs and a last meter (also 15). What it changes is *which* deck is racing. When your ladder is taller, Fervor is a win route and should be spent climbing; when it is level or shorter, Fervor is only a damage ramp toward the better Aspect Powers, and a profile that chases Ascension anyway will throw games away. Check `own.ascension` against the deck's Aspect count before anything else.

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

## 3. The nine decks

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
- **Line.** Edric's Retaining Drill down before Seals go down. Fetch Seals with the Non-Combat package, take
  the opponent's with Seal Seizure and Sleight, keep their Fervor at 0 with the stripping blocks and
  Seals 2 and 6. Arts are both the damage and half the Seal engine, since a successful Art turns
  Eyes Beyond the Gate into a free Seal.
- **Mistake.** Placing Seals before the guard. Also its own Frostbound Moor, which caps its climb as
  hard as the opponent's, on a duelist who badly wants aspect 4 and 5.

### Tide — Dame Alder Rooke, `tide_companions` (allies)

Wins by survival, by attrition. Aspect 1 carries `protect_allies`, so the deck wants to stay there;
Fervor and aspect gains are actively unwanted. Its own aspect 1 also advances on 5 Allies in play,
which is a hazard to stay under, not a goal: the deck ships four Ally cards on purpose. The Mastery
is a free block every Combat, paid for with a card from hand, and paid back double when the card
spent is a Tide card. It is not a damage engine; it is the reason the deck survives to assemble.

- **Lever.** The Bond. Two named Allies fuse into one card that enters at full Energy in band F,
  three bands above either partner and above anything else the deck fields. Everything else is
  setup for it.
- **Second lever.** Allies take control of Combat once the Duelist is at Energy 0 or 1, and then use
  their own Might rather than the Duelist's 3-to-12 ladder.
- **Line.** Allies out early, the Bonding card into play, fuse the moment both partners are there.
  Let the Duelist's Energy fall, hand Combat over, win on wounds from Allies' Arts. The Mastery and
  the Arts keep the opponent's Fervor down, so Ascension is the clock to police.
- **Mistake.** Defending the Duelist's Energy. Unlike every other deck, going to 0 is this deck's
  plan, not its failure state. Also climbing: the aspect 1 constant is the deck.
- **Measured 2026-09-18 with `tests/ally_probe.gd`.** Allies are not held back: the first lands on
  turn 2.5 in 99% of games and the Sensei is spent in 100%, which is right, because the aspect 1
  constant is what keeps them safe. The deck was losing 2.5 Allies a game out of four, which is
  what kept the fusion at 4%; with the guard actually holding it loses 0.25 and fuses in 33%. The
  residual is real and not a bug: a Constant Combat Power is a power, so an opponent card that
  forbids powers switches the guard off, and the guard is on aspect 1 only.

### Shade — the eighth deck, `shade_salvage` (art_beatdown)

Added 2026-09-18 from the second Shade sample deck; the duelist and following are placeholders
until the Construct rework lands. Same school and the same Mastery as the Draik Company, and a
different plan. **It is an Art beatdown, not an Ally deck**, which is the easiest thing to get
wrong about it: twenty-three of its twenty-nine attacks are Arts, and the Allies are a subtheme.
The Draiks empty their Duelist and fight from the board; this one stays in control and fights
itself, and the bodies on the table are there to make its numbers bigger.

- **Lever.** The **Construct** keyword. The Assembly Drill pays every attack +1 wound and a
  Construct personality's +2, and the second Ally's Art pays +1 for every Construct personality in
  play on either side. The Duelist is one, so the count is never zero, and each extra body raises
  the ceiling of every other.
- **Second lever.** Aspect 2's constant: no modifiers at all are added to Strikes aimed at the
  Duelist. Against Steel and Pyre, whose damage is almost entirely modifiers, that is the whole
  matchup. Aspects 3 and 4 hit harder while The Breaker's Yard is in play, so the Coach is worth
  keeping out and not spending on an empty board.
- **Line.** Assembly Drill down, a body or two out, the rival's following removed, then Arts. Hold
  Energy: Arts cost it and the deck has no way to make it back in bulk. The hand empties fast,
  which is what the Composure Drill and the Takedown Drill are for.
- **Mistake.** Playing it like the Draik deck and handing Combat to an Ally. Its Might ladder is
  better than theirs and the Drill pays the Duelist the most. Also spending The Breaker's Yard or
  Dismissal with nothing worth removing; both are limited, and the Coach is a condition two of the
  Aspects read.
- **Measured 2026-09-18.** 18 to 24% depending on the sample, bottom of the field alongside Tide,
  and untuned. It does do its thing: the Retinue lands 0.7 times a game, the Assembly Drill about
  0.5, and the Allies reach play in most games. Re-pointing the profile from Allies to Arts halved
  its Ally-held attack phases (4.9 to 2.4 a game) without moving the win rate, which is the profile
  doing what it now says.

### Pyre — the ninth deck, Sir Edric Rooke, `pyre_ascent` (strike_beatdown)

Added 2026-09-19 from the Red Goku sheet. Same school as Ashmark and a different Mastery: this one
burns the top of the discard pile once a Combat for Fervor, double when what burns is Pyre. **The
distinguishing fact is that it has no Drills at all**, one Ally and one Seal, and that almost every
card in it pays Fervor, blocks included. Ashmark climbs by attacking; this deck climbs whatever
happens in the Combat.

- **Lever.** Fervor on defense. Four of the five block types raise it, so a Combat you spend
  entirely on your back foot still advances the Aspect ladder. That is what pays for a duelist
  whose first three Aspects add nothing at all to the damage.
- **Second lever.** Aspects 4 and 5. Aspect 4 is a flat 5 Energy and 3 wounds that ignores the
  Strike Table, and Aspect 5 is +5 and +5 on top of it. Everything before them is setup, so the
  win route is the climb and the Ascension win is live.
- **Third lever.** The Life Deck is a resource. Two of the Aspects and both of Edric's own attacks
  draw off the discard pile, and the Mastery eats it. Do not treat a wound taken as pure loss.
- **Line.** Block early and bank Fervor, keep Edric's Opening Strike for a Combat where the extra
  use matters (it stays out only while he is your duelist), and hold the Truce: it answers an
  attack that has already got through, which no other card in the set does.
- **Mistake.** Racing at Aspect 1 or 2. The damage is not there yet and the deck has no Drills to
  make it appear. The other mistake is spending the Ember Mastery on an empty or non-Pyre discard
  pile early, when one Pyre card on top later is two Fervor.

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
| Ally control is where the damage comes from | `own.ally_handover` up, `effect.energy_self` below zero |
| The payoff is a combo, so go and assemble it | `play.tutor_decay` above 0, plus whatever prices the payoff (`play.bond_band` for a fusion) |

**Never spend a card for no effect.** This is AI guidance, not a rule: a Bonding card played
without its partners is legal and resolves into nothing, so `AiScorer._bond_use_value` rules the
option out rather than merely discounting it. Before that the AI burned 0.29 Bonding cards a game
against 0.15 fusions landed. Keep this kind of thing in the scorer. Card text and the options the
engine offers are the printed rules, and inventing a restriction to make the AI play better is the
wrong trade.

**Tutor chains are derived, not listed.** `play.tutor_decay` above zero makes a searching card worth
a share of the best card it can reach, and that card's value includes its own search, three links
deep (`AiScorer.TUTOR_DEPTH`). Nothing anywhere names a card: a deck's tutor priorities fall out of
the weights it already has, so pricing the payoff is enough to make the AI go and fetch it. The
search prompt itself picks by the same number, so each link of the chain chooses the card that
carries it furthest. `DuelEngine.search_candidates` is public for this, and it is fair: a player
knows the contents of their own Life Deck, just not the order.

Two things the profile cannot currently say, and which need code if we want them:

- **"These stages were leaving anyway."** `play.attack_cost` is flat, so it charges the same for
  spending Energy that a Strike was about to take as for spending Energy that would have survived.
  `attack_forecasts` now reports `energy_left` per option, which is the input a better rule needs;
  the rule itself is not written. Any rule here must not punish an Art from a low gauge, which is
  correct play for Storm, Root and Tide.

Closed 2026-09-18: **"Ally control is where my damage comes from."** `AiEvaluator.handover_progress`
is 0 to 1 for how close a side is to fighting through an Ally that out-bands its Duelist, `own.ally_handover`
prices it, and `effect.energy_self` (blended in by that same 0-to-1, so it never fires with no Ally
out) makes the Duelist's own Energy something to spend. It moved Tide's Allies in play from 0.66 to
1.02 per turn and its Ally attacks from 0.65 to 1.01 per game, and its win rate not at all.

## Sources

Reference-game strategy reading behind section 2:

- [A beginner's guide to the Dragon Ball Z CCG](https://maskedcarnie.blogspot.com/2014/11/a-beginners-guide-to-dragon-ball-z-ccg.html)
- [The Mastery Race — RetroDBZccg](https://retrodbzccg.com/2012/07/13/the-mastery-race/)
- [The Strategies of Supreme West Kai — RetroDBZccg](https://retrodbzccg.com/2014/03/17/the-stragies-of-supreme-west-kai/)
- [Speedrun strats and notes](https://www.speedrun.com/dbzccc/guides/6ly6b)
- [Score Entertainment rulebook](https://lackeyccg.com/dbzccg/dbzccg_rules.pdf)
