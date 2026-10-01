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

## 3. The fourteen decks

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

### Storm — Siphon, `storm_volley` (art_beatdown)

Wins by survival, by barrage. The Relic rules out its Ascension win and shields its Fervor and
aspect, so Fervor is only fuel for the climb to aspect 3, whose power is a free Art that draws two
every Combat. The Mastery makes Arts cost 1 instead of 2 and adds a life card to each.

- **Lever.** Arts ignore the Strike Table, which is the only reason this deck is playable: its ladder
  tops in D at aspect 3, a full band under Steel and Pyre. It must not try to win the table.
- **Line.** Race to aspect 3, then fire discounted Arts every Combat off the free Art and the draw.
  Blocks that search or refill replace themselves (Siphon's Sidestep, Storm Drawn Charge, the Second
  Winds), so defend freely. Weighted Hollow taxes the rival's Strikes 2 Energy. Stage damage is not
  the goal; wounds are.
- **The 2026-09-29 revision.** Trampled Crossroads was locking the deck out of its own Non-Combats,
  and the AI never plays Raised Stakes or Respite (both hand the rival something), so they, the Sun
  Seals and the three-Strike packages went for Weighted Hollow, Storm Drawn Charge, Storm Idle Spark,
  Storm Jolt, Storm Residual Shock and more Static Field, Chain Lightning and Earthing blocks.
  Measured 2026-09-30 (scorer, seed 4242): 33.9% against the whole field and 40.2% against the
  eleven decks from Storm Mentor down, up from 29%.
- **Mistake.** Hoarding Energy. At Surge 1 to 2 it is never going to out-Energy anyone, and stages
  held back are stages a Strike takes for free. Spend them on Arts.

### Storm — Siphon the Unbound, `storm_unbound` (art_beatdown)

The same construct as the Collegium list, wound the other way, and the first two decks in the set to
share a duelist. No Relic, so unlike `storm_volley` its Ascension win is live and aspect 3 is worth
climbing for itself. It wins by making the rival's Strikes unaffordable and then out-trading.

- **Lever.** Three ways to shut a Strike down at once. Weighted Hollow taxes every Strike 2 Energy,
  the Squall Mastery locks Strike cards out of the rest of the Combat after any landed Storm Art,
  and Terms of the Pact and Stillness cover what gets through. Against a Strike deck that is the
  whole game.
- **Line.** Hollow down early, then land any Storm Art to spring the Mastery. Every Art in the list
  pays Fervor, so damage and the climb are one action; Provocation and Corin's Conditioning top the
  Fervor up out of the discard pile.
- **Mistake.** Treating it like `storm_volley` and hoarding for a barrage. It has no Relic shielding
  its Fervor and no discount on its Arts, so held Energy is wasted. Also playing the Hollow against
  an Art deck, where it does nothing at all and costs a turn of Combat.
- **The 2026-09-29 revision.** Respite (the AI never plays it), Sun Seal 5, Rites Unmade, Foresight,
  The Fortress' Arcane Aegis and the Storm Earthing Rods went for Storm Ungrounded Flash, Storm
  Residual Shock and Storm Drawn Charge. That cleared dead cards but moved the win rate by less than
  the noise: no card-only change measured lifts this list, and the only change that did (The
  Champion's Laurel as a Relic, about +13) was ruled out to keep it Relic-free. Measured 2026-09-30
  (scorer, seed 4242): 33.2% against the whole field and 39.4% against the eleven decks from Storm
  Mentor down.

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
which is a hazard to stay under, not a goal: the deck ships four personalities to field as Allies on
purpose. The Mastery,
Tide's second since 2026-09-29, gives Tide Strikes +2 wounds and lets the deck buy wounds off with
the Tide cards already in its discard pile instead of defending, so every spent Tide card is armour
for later. It is the reason the deck survives to assemble. (Tide Undertow, the Mastery it shipped
with, is now the first Tide Mastery a player unlocks in the adventure rather than a starting card.)

- **Lever.** The Bond. Two named Allies fuse into one card that enters at full Energy in band F,
  three bands above either partner and above anything else the deck fields. Everything else is
  setup for it.
- **Second lever.** Allies take control of Combat once the Duelist is at Energy 0 or 1, and then use
  their own Might rather than the Duelist's 3-to-12 ladder.
- **Line.** Allies out early, the Bonding card into play, fuse the moment both partners are there.
  Let the Duelist's Energy fall, hand Combat over, win on wounds from Allies' Arts. Burn Tide cards
  from the discard pile against the big hits and keep the hand's blocks for the rest. The Arts keep
  the opponent's Fervor down, so Ascension is the clock to police.
- **Hold back until the Bond.** Declaring Combat more readily before the fusion measured 9 points
  worse (2026-09-29), so the profile's pre-Bond caution is right.
- **Mistake.** Defending the Duelist's Energy. Unlike every other deck, going to 0 is this deck's
  plan, not its failure state. Also climbing: the aspect 1 constant is the deck.
- **Measured 2026-09-18 with `tests/ally_probe.gd`.** Allies are not held back: the first lands on
  turn 2.5 in 99% of games and The Debtor's Ring is spent in 100%, which is right, because the aspect 1
  constant is what keeps them safe. The deck was losing 2.5 Allies a game out of four, which is
  what kept the fusion at 4%; with the guard actually holding it loses 0.25 and fuses in 33%. The
  residual is real and not a bug: a Constant Combat Power is a power, so an opponent card that
  forbids powers switches the guard off, and the guard is on aspect 1 only.
- **Measured 2026-09-30** (scorer, seed 4242, 672 games against the whole field and 960 against the
  eleven decks from Storm Mentor down): 50.0% and 55.7%, up from 33% and 38% with Undertow. The
  Mastery swap alone did it; the card swaps tried on this list all measured flat.

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
  matchup. Aspects 3 and 4 hit harder while The Breaker's Yard is in play, so the Yard is worth
  keeping out and not spending on an empty board.
- **Line.** Assembly Drill down, a body or two out, the rival's following removed, then Arts. Energy
  is the fuel and, since the 2026-09-29 revision, the list makes it back: three Shade Shadow Respite,
  Centering, Bravado Drill and the Second Winds all refill the Duelist, so spend it on Arts rather
  than hoard it. The hand empties fast; the Strikes (Shade Dread Grip, Slipping Thought, Silenced
  and Lingering Whisper) empty the rival's in return.
- **Mistake.** Playing it like the Draik deck and handing Combat to an Ally. Its Might ladder is
  better than theirs and the Drill pays the Duelist the most. Also spending The Breaker's Yard or
  Dismissal with nothing worth removing; both are limited, and the Yard is a condition two of the
  Aspects read.
- **Measured 2026-09-18.** 18 to 24% depending on the sample, bottom of the field alongside Tide,
  and untuned. It does do its thing: the Retinue lands 0.7 times a game, the Assembly Drill about
  0.5, and the Allies reach play in most games. Re-pointing the profile from Allies to Arts halved
  its Ally-held attack phases (4.9 to 2.4 a game) without moving the win rate, which is the profile
  doing what it now says.
- **Measured 2026-09-30**, after the revision (same method as Tide above): 38.4% against the whole
  field and 41.7% against the lower eleven, up from 20%. The four Salt Seals, the situational
  one-offs and the Umbra Drills went for Energy refills and hand-attacking Strikes.

### Pyre — the ninth deck, Sir Edric Rooke, `pyre_ascent` (strike_beatdown)

Added 2026-09-19 from the Red starter sheet. Same school as Ashmark and a different Mastery: this one
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

### Steel — the eleventh deck, Emrys Rooke, `steel_heir` (strike_beatdown)

Added 2026-09-19 from a reference starter sheet. The same school and the same Mastery as Quarr, and a
completely different deck around them. Quarr grinds with the Mastery's two cards a Combat; this
list stacks damage modifiers and then cashes them in with a duelist Power that swings twice. Five
Aspects, 79 life cards, no Relic, no Reserve, one Ally, one Seal. **The distinguishing fact is that
its damage comes from what is already on the table** by the time the cards are played.

- **Lever.** Stacked modifiers. Three copies of The Long Year give +1 Energy to every attack for the
  rest of the game, and they stay through every climb. Three Steel Clawed Hands Drills add +2
  Energy to every Strike, but climbing an Aspect discards all Drills (`designs/zenith.md`, Fervor at
  5), so they pay only until the next climb. With The Long Year and two Drills down on one Aspect a
  Strike is at +7 Energy before the card in hand counts; after a climb it is back to +3 until a
  Drill lands again.
- **Second lever.** Card flow. The Mastery draws one a Combat and two on a Steel flip, and Aspect 1
  draws again whenever he is the attacker. Mourne's Quickness Drill and Foresight pull from the
  discard pile. Aspect 2 then fetches the exact Strike or Art it wants.
- **The 2026-09-29 revision.** Barrage, Edric's Training and six situational one-offs (Rites
  Unmade, Mourne Takes the Measure, Spoiled Rite, Emrys Spots the Fraud Drill, Caedan's
  Declaration, Steel Kindred Standoff) made way for a third Clawed Hands Drill line, three Steel
  Ironscale Hide (stops any attack, refills 7) and six Endurance Strikes (Steel Scalebound Blow,
  Steel Taloned Fist). Plain heavy Strikes and blocks beat the utility cards by a wide margin.
  Measured 2026-09-30 (scorer, seed 4242): 48.5% against the whole field and 56.9% against the
  eleven decks from Storm Mentor down, up from 34%.
- **Third lever.** Life cards are ammunition. Steel Clawed Heel buys +3 wounds and Steel Clawed
  Pounce buys +3 Energy, each for the top card of the Life Deck, and the Mastery discards one more
  every Combat. With 79 cards it can afford that for a while.
- **Fourth lever.** Aspect 5 is a Strike dealing 5 wounds usable **twice per Combat**, and The Long
  Year applies to both uses. Aspect 4 before it is a free Art for 4 Energy and 4 wounds, and
  Aspect 3 is a Strike at +5 Energy that can also remove a Non-Combat card.
- **Line.** Spend the early turns getting the floor down. The Long Year first, because it survives
  the climb, then a Steel Clawed Hands Drill on the Aspect you expect to stay on. Enter Combat every turn for the draws even when the attack is poor. Save
  Steel Talon Cleave, which deals a flat 10 Energy and leaves the game, for a turn where a full
  drain means the rival cannot answer, not for a turn where they were already empty. From Aspect 4
  on, the Power is the main attack and the hand is support.
- **Mistake.** Holding The Long Year. It is worth the most on turn two and nothing on the last turn,
  and the instinct to keep a removed-after-use card back is wrong here. The second mistake is
  playing a Drill just before a climb, which throws it away. The third is paying a life card on an
  attack that was going to land anyway, the same trap as Ashmark, made worse because the Mastery is
  eating the deck from the other end. The fourth is racing at Aspects 1 and 2, where the Power adds
  no damage and the stack is not built yet.
- **Note on the gates.** Steel Raking Talons, Steel Rending Talon and Steel Dragonscale Mantle are
  Draconic only, and the gate reads the personality in control. Emrys is Draconic, so the gate
  never bites while he is in control. His one Ally, Dame Alder Rooke, has no bloodline, so those
  nine cards go dead in any Combat she controls. Her Power stops a Strike against him without her
  being in control, so she rarely needs to take it.

### Tide: Sir Edric Rooke, `tide_deepwater` (control)

The same knight as `pyre_ascent`, fighting from the Tide school with the Fathom Mastery. Five
Aspects, 75 life cards, The Blank Mask holding a 13-card Reserve, three Moth Seals, no Allies. Wins
by survival, slowly. **The distinguishing fact is that almost every attack also takes Fervor off the
rival**, so the damage race and the Fervor race are run by the same cards.

- **Lever.** Fervor denial on every Combat. Twenty cards in the list Disrupt, from Tide Black Water
  (3) down to Tide Wide Sweep (1), and the Bravado Drill Disrupts 2 each time he enters Combat.
  Three Frostbound Moors cap any single Fervor gain at 1, so the rival gains one point at a time and
  loses up to three at a time. Moth Seal 7 and the two uses of The Blank Mask take the rival's
  Mastery away as well.
- **Second lever.** The discard pile is armour. The Fathom Mastery gives every Tide Strike +2
  wounds and, instead of defending, removes Tide cards from the discard pile to prevent 2 wounds
  each. Every Tide card wounded off the Life Deck becomes a block for later. Tide Crushing Depth,
  Tide Waterlogged, Tide Pull Under and Tide Welling Deep leave the game or go under the Life Deck
  after use, so they never feed it.
- **Third lever.** Reckless Ascent. At the end of Combat it moves Edric to the Aspect equal to his
  Fervor and closes his own Ascension win for the rest of the game. Under his own Moor his Fervor
  comes one point at a time, so this is how he reaches Aspect 4 (a Strike for 5 Energy and 3
  wounds) or Aspect 5 (+5 Energy and +5 wounds) without four full climbs.
- **Line.** Bravado Drill into play before the first turn and a Moor down. Fetch a Seal with Edric
  Carves First, Mourne's Plans or Measure: Moth Seal 7 against a deck whose Mastery is its engine,
  Moth Seal 4 against Allies. Enter Combat every turn and Disrupt with every attack. Take mid-sized
  hits on the Mastery and keep Mourne's Stance, The Fortress' Iron Bulwark and Stillness for the
  large ones. Old Trick reaches into the Reserve for Tide Heavy Swell or Tide Cresting Wave.
- **Mistake.** Playing Reckless Ascent when his Fervor is below his current Aspect, which moves him
  down. Against a three-Aspect rival it also gives up the Most Powerful Personality win at Aspect 4,
  so there it has a price. The second mistake is burning the whole discard pile early: Foresight,
  Recalled Lesson, Moth Seal 3 and the Aspect 2 Power all draw from the same pile. The third is
  playing Emrys Gives No Quarter in a Combat that needs his own stop-all cards, because it forbids
  them for both players.
- **Measured 2026-09-26.** 42.7% under the scorer, 65.4% under search, 55.5% under the scorer on
  2026-09-20. The gap between the two policies is larger than the noise and is listed as open in
  `docs/deck_tournament_2026-09-26.md`.
- **Profile.** `own.aspect` 7.0 (default 4.0) with `own.ascension` 7.0 (default 30) prices the climb
  for the Aspect Powers and discounts the win, which fits Reckless Ascent. `foe.ascension` 24,
  `effect.fervor` 2.2 and `effect.forbid` 2.2 carry the denial. `play.damage_life` 1.2 over
  `play.damage_stage` 1.0, and `play.defend_card` 1.3 keeps hand blocks for the big hits. `own.seal`
  0.6 against a default of 25 treats the Moth Seals as utility. `effect.fervor_foe` 3.0 prices
  every point of the rival's Fervor taken away above the 2.2 for its own.

### Pyre: Bram Ashmark, `pyre_attrition` (strike_beatdown)

The second Ashmark list, on a longer road. It shares Aspect 1 with `pyre_beatdown` and the Ember
Mastery with `pyre_ascent`, then climbs four Aspects of its own. Five Aspects, 76 life cards, The
Severing Clasp holding a seven-card Reserve, and no Allies, Drills, Seals or Non-Combats in the main
list. Wins by Ascension against a shorter ladder and by survival otherwise.

- **Lever.** Fervor from nearly every card. The Mastery removes the top of the discard pile once a
  Combat for Attune 1, or Attune 2 when it is Pyre. Nearly every attack and block also Attunes, and
  Pyre Cinder Guard, Pyre Furnace Breath, Pyre Flashpoint, Ashmark's Ember Spray and Caedan's
  Declaration pay 2. Aspect 3 adds 1 to every gain. Against a three-Aspect rival, entering Aspect 4
  wins outright under the Most Powerful Personality rule; against a four-Aspect one, Aspect 5 does.
- **Second lever.** Stripping the table. Pyre Firestorm can trade its damage for all the rival's
  Allies or all their Drills, Pyre Immolation removes a Drill or Ally, Pyre Scouring Flame removes a
  Non-Combat on a hit, Headlong Plunge discards an Ally, and Spent to the Last clears every
  Non-Combat and Ally at once. The Severing Clasp removes two Non-Combats once a game and Riftcry
  discards the Grounds. Three Trampled Crossroads stop both players using Non-Combats, which costs
  the main list nothing.
- **Third lever.** The top Aspects refill the Life Deck. Aspect 4 shuffles the top 8 cards of the
  discard pile back in, and Aspect 5 chooses between a Focused Strike dealing 10 Energy and shuffling
  the top 10 back. Aspects 2 and 3 add +1 and +3 wounds to every attack on the way up.
- **Line.** Crossroads down early. Clear Allies, Drills and Non-Combats before pressing, because
  nothing else in the list answers them. Enter Combat every turn, since the Fervor is on the
  attacks, and use the Mastery every Combat, best with a Pyre card on top of the discard pile.
  Against a Seal deck, bring The Watch Goes Dark in from the Reserve; it removes every Seal in play
  and in both Life Decks. From Aspect 4 on, choose recovery or the 10-Energy Strike by how thin the
  Life Deck is.
- **Mistake.** Keeping Trampled Crossroads in play after swapping in The Watch Goes Dark or
  Defacement, which are Non-Combats and are then locked out. The second is Spent to the Last with a
  rival attack still to come: it sets his Energy to 0, so the next Strike turns into wounds one for
  one. The third is Emrys Gives No Quarter in a Combat that needs Mourne's Stance, The Fortress'
  Iron Bulwark or Stillness. Late in the game, each Mastery use removes a card that Aspects 4 and 5
  could have shuffled back.
- **Measured 2026-09-26.** 65.6% under the scorer and 80.8% under search, down from 73.8% under the
  scorer on 2026-09-20.
- **Profile.** `own.aspect` 8.0, double the default, carries the climb. `own.ascension` 9.0 and
  `foe.ascension` 20 both sit under the default 30. `effect.fervor` 2.8 prices every Attune,
  `effect.forbid` 2.4 covers Pyre Snuffing and Kept at Bay, and `play.damage_life` 1.3 and
  `play.declare_bias` 2.4 keep it attacking. `own.seal` is 0.0 because the list has none. There is
  no `reserve` block, so the Reserve swap runs on the defaults.

### Shade: Gideon Mourne, `shade_mind_siege` (strike_beatdown)

Mourne's own list, rated hard. Four Aspects, 76 life cards, The Blank Mask holding a 13-card
Reserve, the Nightfall Mastery (+1 Energy and +1 wound on every attack, +2 and +2 on Shade attacks),
no Allies and no Seals. Wins by survival after taking the rival's hand and table apart. **The
distinguishing fact is that almost every attack takes something that does not come back**: a card
from hand, a card in play, Fervor or an Aspect.

- **Lever.** The hand. Twenty-one cards take from it: Marrow's Appraisal, Shade Dread Grip, Shade
  Emptying Whisper, Shade Insistent Whisper, Shade Sifting Whisper, Shade Silenced Whisper, Shade
  Picking Shadow and Shade Rebounding Hex. Shade Hex Recall stops an attack and fetches one of them
  back from the discard pile. Section 2 says to press an empty hand; this deck empties it.
- **Second lever.** Fervor and Aspect denial. The Bravado Drill Disrupts 2 each time he enters
  Combat. Ashmark's Unmaking Whisper Disrupts 2 on a hit and then, if the rival's Fervor is 0, takes
  an Aspect from them, which also discards their Drills.
- **Third lever.** Marked attacks. Aspect 4 makes every Marked Strike Focused at +3 Energy. The
  Marked Ring adds +1 Energy and +1 wound to every Marked-only attack, discards an Ally in play when
  one is performed, and discards a Non-Combat in play on entering Combat. Aspect 3's Focused Art for
  6 wounds can be used a second time by discarding a Marked card, and Aspect 2 moves the Strike
  Table 2 in his favour both ways.
- **Fourth lever.** The Reserve is a second hand. Shade Ransoming Hand, swapped in at setup, lets him
  remove two cards left in the Reserve to remove a rival Drill in each attack phase for the rest of
  the Combat. Shade Prying Whisper, Dismissal, Defacement, Sever the Leyline and The Watch Goes Dark
  are answers to bring in against the decks that need them.
- **Line.** Bravado Drill into play before the first turn and The Marked Ring down. Strip the hand
  and the table in the early Combats, then attack into the empty hand. Keep their Fervor at 0 so each
  Unmaking Whisper hit costs them an Aspect. Climb for Aspect 4. Against a three-Aspect rival,
  entering it is the Most Powerful Personality win; against the rest it is where the Marked Strikes
  get past Shields and cards that stop both attack types.
- **Mistake.** Discarding Ashmark's Wall of Flame for Aspect 3's second use. It is the only card in
  the list that stops a Focused attack of either kind. The second is spending Reserve cards on Shade
  Ransoming Hand against a rival with no Drills. The third is Emrys Gives No Quarter in a Combat that
  needs Mourne's Stance, The Fortress' Iron Bulwark, The Fortress' Arcane Aegis or Stillness.
- **Measured 2026-09-26.** 85.5% under the scorer and 78.8% under search, first in the field under
  the scorer and third under search.
- **Profile.** `foe.hand` 2.4 and `effect.discard_hand` 2.6, against defaults of 1.0, make a card out
  of hand worth more than a wound. `effect.discard_in_play` 2.8 prices the table. `own.aspect` 8.0
  with `own.ascension` 6.0 prices the climb for the Aspect Powers. The `reserve` block (`tech` 3.4,
  `threshold` 0.8, `toolbox_keep` 1.5, `max_swaps` 5, against 3.0, 1.0, 2.0 and 4) swaps more
  readily than the default. `effect.remove_hand` 3.0 prices a card taken out of their hand for good
  above `discard_hand` 2.6. `effect.fervor` is 1.2, under the default 2.0, which
  undervalues the Disrupt that sets up Unmaking Whisper.

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
| Deny Fervor | `effect.fervor_foe` for the rival's Fervor taken away; `effect.fervor_self` separately if own Fervor is unwanted |
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
