# Eidolarch

A two-player dueling card game. Two duelists, mages or plain fighters, contest a place of power where a gate to elsewhere can be opened. Beyond it waits an Eidolon, an otherworldly entity. The one who takes the site becomes its **Eidolarch**, the master of the gate and of what comes through it. Each duelist follows one school of magic, or none. A duel is fought with Strikes and Arts, and it wears down the duelist's Energy and then their mind. A duelist becomes Eidolarch by ascending through every Aspect until the site answers to them, by carving all seven seals into the gate so the Eidolon comes through and answers to them, or by breaking the rival's mind so no one else is left to claim it.

Named Eidolarch on 2026-09-17 (formerly Zenith). The folder, project and code name stay `zenith`. One web search found no game using the name; the "eidol" root is crowded (Eidolon, Eidols, and EIDOL, an early-access card game), and no trademark or store check has been done.

**Engine:** Godot 4.6, GDScript, 3D playspace with 2D hand and HUD
**Genre:** Collectible card duel, Arena-style client
**Players:** 2 (hotseat first, online later), plus AI opponents for an adventure mode
**Presentation target:** a full digital client in the style of MTG Arena: a 3D table, animated card movement, response prompts, combat log
**Rules baseline:** the reference game's final pre-reboot rulebook (2003) and its rulings document, plus four rules from the 2014 relaunch: a mandatory Mastery with nothing declared at setup, the Ascension win at max Fervor on the top aspect, critical damage, and Duelist Powers that do not refresh on an aspect change. Two house rules on top of those: the Most Powerful Personality win (see Winning) and, **decided 2026-09-21, that every Ally rule is per player** and nothing in play reads the other side of the table (see Personalities). That second one is a house rule and not an adopted one: the relaunch rulebook sets no in-play Ally uniqueness rule at all, only a one-copy-per-deck limit, and the older rulings document's cross-table restriction is what we dropped. Ally legality by aspect is not a house rule; it follows the rulings document's Aspect 1-to-3 rule (see Deck construction, corrected 2026-09-21). Nothing else from the relaunch is adopted: deck sizes stay variable, Duelists keep 3 to 5 aspects (mostly 3), and Surge Rates and Might ladders stay varied per duelist. Card text beats rulebook (the Golden Rule). Reboot-era changes (16 stages, no Fervor leveling) are out of scope.

**IP rule:** all names, characters, art, styles, and lore are original. No source-material terms appear in code, data, assets, or this doc. Mechanics are emulated; flavor is not.

---

## Setting

Rethemed 2026-09-17 from a king's tournament of spellsword houses to mage duels. There is no court, no king and no tourney. The world is kept abstract: places of power sit on the leylines, and at each one the wall between worlds is thin enough to cut a gate. The Eidolons are otherworldly entities waiting on the far side. Seven seals carved into a gate open it for one of them, and duelists fight each other for the right to carve. Inside the duel, everything is the duelist.

The rename pass ran on 2026-09-17: this doc, the code, the data and the card text all use the terms below. Card ids, deck ids and art file names were renamed the same day (`sun_seal_3`, `blank_mask`, `root_seals`). Personality ids and their art were renamed again on 2026-09-21, when each Aspect became its own card: `personality_bram_ashmark_1_starved`, with art at `<id>.png` like every other card. The old-to-new map is `zenith/data/migrations/personality_split.json`.

| Mechanic | In-world |
|---|---|
| Duelist | A named duelist. Portrait, school, side |
| Aspects | How deeply the duelist is attuned to the site's leylines, and what that is doing to them. Every duel starts at the first Aspect. Each Aspect card carries its own title |
| Fervor 0 to 5 | Battle fervor. It builds through the exchange, and at 5 the duelist ascends one Aspect |
| Ascending sets Energy to full | The leyline floods in as the attunement deepens |
| Ascending discards Drills | The old rituals were tuned to a shallower attunement and lapse |
| Losing an Aspect | The duelist's hold on the leyline slips |
| Energy stages, Might rating | The duelist's own internal store of energy, and how hard they hit while holding that much |
| Strike | Melee spellwork: a spell carried by hand, staff or blade, or a plain blow. Base damage from the Strike Table, dealt to Energy first |
| Art | Ranged spellwork. Spends 2 Energy, wounds directly. Every school has both Strikes and Arts; the schools differ in how they lean |
| Life Deck, life cards | The duelist's mental fortitude. The cards in it are the spells and moves they know. Every card lost is a spell shaken out of their head |
| Hand | The spells held in focus right now |
| Discard pile, removed pile | Spells shaken loose, and spells forgotten for the rest of the duel |
| Allies | Apprentices, familiars, constructs and hired blades who take a wound for you or step in when your Energy is spent |
| Drills | Rituals and standing workings |
| Seals, seven per set | Seals carved into the gate. Placing one is carving a seal. Capture is overwriting a rival's seal with your own mark. Four sets for four Eidolons, each with its own seven seals: Maruth, Ysmere, Korrag and Thessa (see The Eidolons below) |
| Grounds | Which place of power this duel is over |
| Relic, Reserve | A relic of great power that the duelist wears, usable by any school or by none. Its Reserve is the spare spells and techniques it lets the wearer hold beyond their own mind. Relic powers channel the artifact itself |
| Mastery, Style | The school a duelist follows. Every deck follows one Style and carries that school's Mastery |
| Alignment | Vigil, Pact, or Hedge (declares at setup). See The Vigil and the Pact below |
| Ascension win | Full attunement, by either road. The duelist reaches their last Aspect and the fervor peaks once more; **or** they stand on an Aspect above everything the rival can reach, and the site answers to them |
| Unsealing win | All seven seals of one set are carved, the gate opens, and the Eidolon comes through answering to the one who carved them |
| Survival win | The rival's mind gives out and they have nothing left to cast |

Term history (all approved and applied 2026-09-17):

| Before | Now | Note |
|---|---|---|
| Acclaim | Fervor | The 0 to 5 counter. Approved 2026-09-17 |
| Favor tiers (Noticed, Regarded, Esteemed, Honored, Chosen) | Aspects, numbered | Approved 2026-09-17. Each tier card is an Aspect of the duelist with its own title. Tier-up verb: Ascend |
| Favor win | Ascension win | Approved 2026-09-17 |
| Token, Token win | Seal, Unsealing win | Approved 2026-09-17 ("fine enough"). Approved before the seals became carvings that open a gate; "Unsealing" now fits poorly and "Summoning win" is the suggested replacement, not yet approved |
| Survival win | unchanged | |
| Knight, Knave, Hedge | Vigil, Pact, Hedge | Approved 2026-09-17. "Hedge" covers hedge mages and hedge knights |
| Master, Armory | Relic, Reserve | Approved 2026-09-17. Grimoire and Pages were used for part of that day and then dropped |
| Vigor | Energy | Approved 2026-09-17, read as approval of the change and not of "unchanged". Must suit mundane duelists too, which rules out Mana |
| Fighter | Duelist | Approved 2026-09-17. "Mage" does not suit a Freestyle swordmaster |
| Guild | School | Approved 2026-09-17 |
| Strike, Art, Drill, Ally, Grounds, Mastery, Life Deck | unchanged | |

Tone: earnest, a little grim, no jokes on the cards. Nothing with a voice gets written until approved.

### The Vigil and the Pact

Approved 2026-09-17 as the replacement for Knights and Knaves.

Two sides, open to mages and mundane duelists alike. Both want their own duelist made Eidolarch, for opposite reasons: the Vigil so that whatever comes through answers to someone who will hold it in check, the Pact so that it answers to them. **The Vigil** stands watch over the places where a gate can be cut. It would rather no gate opened at all, and when a Vigil duelist carves the seals it is because the gate will open either way and the Eidolon must not answer to the Pact. A watch needs swords as much as spells. **The Pact** has struck bargains with the Eidolons across the wall, passage in return for power, and fights to deliver on them. Anyone can sign. The Vigil goes first because it already stands at the site and the Pact comes to it. "Vigil only" cards are rites handed down with the watch; "Pact only" cards are workings the Vigil's vow forbids. A following shares its leader's vow or bargain, which is why Allies match alignment. **Hedge** duelists are hedge mages and hedge knights sworn to neither; they take a side for the duel at setup.

Starter duelists (names approved 2026-09-15; descriptions reworked for the retheme and pending approval; deck names in data: Ashmark the Pyromancer, Quarr the Ironblood, The Draik Company, The Rooke Coven, Vale the Swordmaster, The Corven Collegium, The Thornwald Grove):

| Following | Side | School | Duelist | Followers |
|---|---|---|---|---|
| none | Pact | Pyre | Bram Ashmark, a warlock who traded his humanity for power and is left hollow and hungry | none |
| none | Pact | Steel | Halden Quarr, an Ironblood grinder who reads the last blow | none |
| The Draik Company, hexers for hire | Pact | Shade | Sable Draik, captain | Vesna, Brann, Quill, Halvard Draik, and Pim |
| The Rooke coven, an old family of water mages | Vigil | Tide | Dame Alder Rooke, matriarch | Wren, Sir Edric, Ansel Rooke, Tavin Vale |
| none | Vigil | Freestyle | Caedan Vale, the last of a line of swordmasters, no magic at all | none |
| The Corven Collegium, scholars of the Tempest | Pact | Storm | Siphon, a warded construct | Tithe |
| The Thornwald Grove, druids whose rites regrow what is cut away (added 2026-09-17) | Vigil | Root | Osric Thornwald, an old druid who mends as he fights and outlasts | none |
| Marrow the Amalgam, a construct assembled from fallen ones and the crew that picks the field over (added 2026-09-18) | Pact | Shade | Marrow, who is not one construct and never was | Cull, Orvath Kell, Gideon Mourne, Pim |
| none (added 2026-09-20) | Pact | Shade | Gideon Mourne, marked and running his own list | none |
| none (added 2026-09-19) | Vigil | Pyre | Sir Edric Rooke, the Rooke coven's knight fighting his own fight | Dame Alder Rooke |

### Bloodlines

Approved 2026-09-18. A third axis under the other two, and the parallel for the reference game's Heritage.

The Vigil is power studied and the Pact is power bargained for. A **bloodline** is neither: it is power an ancestor's bargain left in the blood, so it descends whether or not the descendant wants it. That is why it cuts across both sides, and why a Vigil duelist can carry one. It is a property of the personality, not of the player and not of the school they trained in. A duelist and their following need not share it.

Two lines exist. **Draconic** is the fighting line, hot-blooded and hard to put down. **Verdant** is the old line that cut the first seals, patient, and regrows what is taken away.

In the data it is `bloodline` on a personality's card definition, `only: {"bloodline": ...}` to gate a card, `per_bloodline` on a modifier or a shuffle effect to count personalities carrying it, and `protect_allies: "<bloodline>"` to guard only kin. A gate reads the personality **in control of Combat**, not the duelist, so a leader of no line can still use a gated card while a kinsman holds the fight. The reference game kept this in a rulebook table and never printed it on the card, which is why it was invisible; here it goes on the type line of every personality that has one.

Carriers (in the data since 2026-09-19): Draconic are Halden Quarr, Caedan Vale, Sir Edric Rooke, Wren Rooke, Ansel Rooke, Tavin Vale, the bonded pair and Gideon Mourne. Verdant are Osric Thornwald and Orvath Kell, who share a line. Nobody else has one, Dame Alder Rooke included, though every one of her Allies does.

Dame Alder Rooke's first Aspect is the only card that reads a bloodline so far. Its `protect_allies` names Draconic rather than guarding everyone, so she shields kin and not every hireling she happens to lead. It covers the same four Allies either way, because all four are Draconic.

### Keywords

Documented 2026-09-18. A keyword is a word a group of cards share, and which other cards read off them. The reference game keyed these off a word in the card title; here the word goes in `tags` on the card definition, so nothing depends on how a title happens to be spelled.

**Construct** is the only one so far (chosen 2026-09-18 over "automaton", which was too narrow, and "Hollowed", which was tried and dropped the same day). A Construct is anything walking around that was made rather than born, by any tradition and out of anything: golems of clay and stone, clockwork automata, animate armour, wax and bone effigies, and whatever else later sets need. The word is deliberately wide, because it is a category and not a roster.

Two rules follow from that, and both matter more than the word itself:

- **A keyword is not a faction.** The Corven Collegium builds Constructs; so do other people, by other methods, for other reasons. A card that says "Construct" reads what a personality *is*, never whose side it is on. That is why `life_per_tag` counts personalities in play on both sides.
- **A keyword is not a school.** The Collegium's Constructs happen to field Storm today and Marrow's happen to field Shade, and neither of those facts belongs to the keyword. The same goes for followings in general: the table below records what a following currently fields, not what it is. A house may field more than one school later, and nothing in the data should assume otherwise.

**Theming follows the card, not the person.** Ruled 2026-09-19. A character may field more than one school across their cards, so what a card looks like is read off that card's own effects and the deck it is fielded in, never off a fixed element attached to the character. Sir Edric Rooke is the case that forced it: he carries water as his wife's Ally and fire in his own list, and both are correct. In the data this means `CAST` in `tools/gen_roster.py` holds only a side and an identity, and the palette comes from the card's school or, for a schoolless card, from the one Style it is fielded in.

Keywords also sit on cards, not only on personalities. `marked` on a card means a card of the
bargain, which is what the source expresses by putting "Majin" in the title; `whisper` names the
Shade working the Black kicks all translate to. A card's play gate and its keyword are different
sets on purpose: a card can be marked-only without being one of the mark's own cards, which is why
a modifier can filter on `tag` or on `only_tag` and they do not mean the same thing.

In the data it is `tags: ["construct"]`, and cards reach it four ways: `search` with `tag`, a `when` of `performer_tag` (the personality swinging), `in_control_tag` (whoever holds Combat on that side) or `duelist_tag`, and an attack's `life_per_tag`.

Aspect titles (2026-09-17; in the data as `title` on each Aspect of a personality card). Each Aspect card carries its own title, as in "Bram Ashmark, Insatiable". A character with more than one personality card carries a `variant` as well, which names that card and is what tells two cards of one person apart. Vigil duelists harden into the watch: each tier has less of the person and more of the office or the element. Pact duelists come due: each tier shows more of the bargain. The school supplies the imagery and the tier's power supplies the meaning. A mundane duelist is changed by will, so his titles stay human.

| Duelist | Tier titles |
|---|---|
| Bram Ashmark, the Hollow | Starved, Leeching, Unstoppable |
| Bram Ashmark, the Glut | Starved, Gnawing, Gorging, Consuming, Insatiable |
| Halden Quarr | the Grinder, Tempered, Ironheart |
| Sable Draik | Captain, Shrouded, Lightless |
| Siphon | Dormant, Charged, Unbound |
| Dame Alder Rooke | Matriarch, Rising Water, the Flood |
| Osric Thornwald | Greybeard, Overgrown, Deep-Rooted, Heartwood, Grovelord |
| Caedan Vale | Last Heir, Unparried, Spellcutter, the Quiet Blade, Peerless |
| Marrow | Patchwork, Rebuilt, Overwrought, Fury Amalgam |
| Sir Edric Rooke | the Hero, the Stranger, the Realm's Hero, Kindled Through, the All Powerful |
| Gideon Mourne, Lord Mourne | the Marked Lord, Unflinching, Unfettered, Unrepentant |
| The Fortress | Foundation, Fortified, Unbreachable (held; he has no personality card yet) |

### The Eidolons

Chosen 2026-09-17. Physical, demigod-scale beings from elsewhere, one behind each set of seven seals (three at first, four since 2026-09-18). They are flavored by vibe, not by what their seals do. The pairing of Eidolon to set is a loose fit; it went into the data with the rename pass and can still be moved. The names are coined and unchecked.

| Eidolon | Set id in data | Body | Temperament |
|---|---|---|---|
| Maruth, the Drowned Sun | sun | A giant in gold plate, twice the height of a gate tower. The armor is full of seawater and there is no body inside. Light pours out of the visor and every joint | Regal and warm, and certain that everything it shines on belongs to it |
| Ysmere, the Moth Queen | moth | A tall pale woman-shape in a mantle of living white moths, with feathered antennae for a crown. Where the mantle brushes something, that thing fades | Soft-spoken, patient and tender, and always hungry |
| Korrag the Unfinished | marble | A titan that is half made. One side is flawless marble muscle; the other is scaffold, bare bone and gold wire. It carries the chisel that is carving it | Proud and restless. It wants to be completed and takes material wherever it finds it |
| Thessa, the Kind Hand (added 2026-09-18, name pending approval) | salt | A stooped surgeon's shape in a clean apron, taller than it should be, with more arms than it should have, each ending in an instrument instead of a hand. There is a low steady lamp where the face belongs | Gentle, tireless and entirely certain it is helping. It makes you well by taking out whatever in you was aching, and it does not distinguish between the ache and the part of you that was doing the aching |

Seal names (applied 2026-09-17; Marble is the user's pick over Chisel). Each set is named loosely after its Eidolon, numbered 1 to 7, the way the old sets were "Crown Token 3":

| Eidolon | Seal names | Set id (`seal_set`) | Alternatives |
|---|---|---|---|
| Maruth, the Drowned Sun | Sun Seal 1 to 7 | sun | Gilded Seal, Brine Seal |
| Ysmere, the Moth Queen | Moth Seal 1 to 7 | moth | Pale Seal, Mantle Seal |
| Korrag the Unfinished | Marble Seal 1 to 7 | marble | Chisel Seal, Scaffold Seal |
| Thessa, the Kind Hand | Salt Seal 1 to 7 | salt | Linen Seal, Lamp Seal |

Card text builds the set name from the set id ("One of the seven Sun Seals", "for each Marble Seal in play"). The card ids are `sun_seal_N`, `moth_seal_N`, `marble_seal_N` and `salt_seal_N`, and the art files are named to match.

Seal 4 of the first three sets discards the opponent's Non-Combat cards in play: the gate's first shudder strips the standing rituals. **Thessa's set breaks that pattern**, and does so on purpose, because the source sets are not uniform either: every Salt Seal instead puts the carver back on their feet at full Energy, which is the one thing she does. Salt Seal 4 sweeps Allies off the table rather than Non-Combats.

Relics: the three Masters become three worn relics, none of them a weapon, so any duelist can carry one. The Blank Mask (`blank_mask`, Reserve 13, two uses) is a featureless face-plate, and whoever it looks at forgets their school for a turn. The Debtor's Ring (`debtors_ring`, Reserve 5, one use) is a signet pressed with someone else's mark, and turning it calls in the debt as an Ally. The Lodestone Heart (`lodestone_heart`, Reserve 10, no use) is a dark stone pendant that pulls the wearer toward the ground and toward themselves, so they cannot be dragged down in Fervor or Aspect and cannot win by Ascension. Names approved 2026-09-17.

---

## Setup

1. Aspects stacked face up, the first Aspect on top. Announce your highest aspect. That aspect is your Ascension win target, and both announcements together fix the Most Powerful Personality target for the duel.
2. Hedge duelists declare Vigil or Pact.
3. Place Relic and Mastery. The Mastery's school is the deck's Style. Nothing is declared.
4. Duelist starts at Energy 5 above 0. Fervor starts at 0.
5. **Bracket rule.** If only one duelist's starting Might sits in Strike Table band D or above, the weaker duelist goes first. Otherwise the Vigil goes first; same alignment goes random. No stage changes.
6. Shuffle the Life Deck. Opponent may cut.
7. Reserve swap: bring any number of Reserve cards into the Life Deck; each pushes a random Life Deck card into the Reserve. Shuffle.
8. No opening hand. First draw happens in the Draw Step.

---

## Personalities

Decided 2026-09-21. It replaces the older model where one card held a whole ladder of Aspects.

- **Each Aspect is its own card**, as in the printed game. A personality card has a character, a
  tier (its Aspect number), a title, a Surge Rate, a stage table, a Power and optionally a
  Constant Power. Alignment gate, bloodline and keywords sit on the card, so a character can
  change as they climb.
- **Duelist and Ally are roles, not kinds of card.** Any personality card can be used either way.
- **A stack** is a set of personality cards of one character with exactly one card per tier,
  consecutive from tier 1. Those two anchors are the whole rule. Cards from different lines of the
  same character mix freely: Bram Ashmark may climb Starved, Leeching, Gorging.
- **The Duelist** is a stack of 3 to 5 tiers (2 and up in adventure). The deck lists its cards.
- **An Ally** is a personality card in the Life Deck, at tier 1, 2 or 3, whatever height the
  Duelist runs. The tiers an Ally runs need not be consecutive and need not include tier 1:
  consecutive-from-1 is a Duelist rule only, and a deck may run a lone tier 2 card. One copy of
  each personality card, none sharing the Duelist's character, matching alignment. Two different
  cards of one character at one tier are not copies of each other, so a deck may run both.
  Checked against the later rulings revision 2026-09-21, which replaced an older "at least 2
  tiers below the Duelist's highest" rule and, with it, the 2026-09-20 house exemption for tier 1.
- **An Ally enters play** in the Non-Combat step at Energy 3, at any tier up to the Duelist's
  **current** tier, with no need for its lower tiers to have been played. It climbs by playing
  exactly its next tier on top, set to that card's highest stage; the tiers underneath are no
  longer in play. A climbing Ally **may** pass the Duelist's current tier, because only a fresh
  placement is capped. Card effects that put an Ally into play may overlay the same way.
- **Every Ally rule is per player.** The table across from you never restricts what you place: the
  rival's Allies and the rival's Duelist are not consulted. So a player gets one Ally per
  character and that is the whole of it, and both players may field the same character at once, at
  the same tier, even the same card. Your Ally may also share a name with the rival's Duelist.
  House rule, decided 2026-09-21. It replaces the older game's two cross-table restrictions: that
  the two sides could not hold the same tier of one Ally, and that no Ally could share a name with
  a Duelist in play. The relaunch rulebook sets no in-play Ally uniqueness rule at all, so there
  was nothing to copy and the choice is ours.
- **An Ally may not share your own Duelist's character**, which is a deck rule and lives only in
  deck construction. Nothing checks it again in play, because a personality reaches your side of
  the table only out of your own Life Deck or Reserve, and both are validated.
- **Ids:** `personality_<first>_<last>_<tier>_<title>`. A card with no title uses its variant
  word, or nothing: `personality_vesna_draik_1`, `personality_gideon_mourne_1_mercenary`.
  One-name characters skip the surname: `personality_siphon_1_dormant`. Honorifics are left out.
- Two lines that share an identical card share the card. Bram Ashmark's two lines both start
  from `personality_bram_ashmark_1_starved`.

## Duelist and Ascension

- **The personality used as Duelist** has 3 to 5 Aspects. Each aspect lists a Surge Rate, stages 0 to 10 each with a Might rating, a Power (once per turn, Combat only; an aspect change mid-Combat does not refresh it), and optionally a Constant Power (mandatory while that personality is in control of Combat).
- **Energy stage** is the current position on the stage table. **Might** is the number in that stage. Might feeds the Strike Table.
- **Wild Might.** A stage showing Wild instead of a number always yields base damage 2 on the Strike Table, attacking or defending. Double Power Rule ignores Wild.
- **Fervor** runs 0 to 5, tracked once per player. At 5 or more: put the current aspect at the bottom of the stack, reveal the next aspect, set Energy to highest, discard all your Drills, Fervor to 0. Excess does not carry over.
- **At top aspect** with Fervor 5 or more (or the current requirement): Ascension win. If a card effect has forbidden your Ascension win, instead set Energy to highest, Fervor to 0, keep Drills, no extra Power use.
- **Most Powerful Personality.** House rule, 2026-09-19. Entering an Aspect above every Aspect the rival can reach is itself an Ascension win, with no second Fervor peak. It is only available to a duelist whose announced ladder is taller than the rival's: with five Aspects against three, Aspect 4 wins. Level ladders leave no such Aspect and the Fervor road is the only one. It reads off what each side announced at setup, not where they stand, so the target does not move during the duel. It is the same win, so the same things gate it: a duelist forbidden the Ascension win cannot take this road, and a card that answers an Ascension win answers this one.
- The two roads cost about the same, which is why the rule balances rather than rewarding tall ladders. Five Aspects against three is three climbs, 15 Fervor; three Aspects against three is two climbs and a last full meter, also 15. Five against five is four climbs and a meter, 25, for both.
- **Losing an aspect** (card effects only): set Energy to 5 above 0, Fervor unchanged, discard Drills.
- Aspect changes by any means other than Fervor do not change Fervor.

---

## Turn (7 steps)

| Step | Who | What happens |
|---|---|---|
| 1 Draw | Active | Draw 3 |
| 2 Non-Combat | Active | Place Allies, Seals, Grounds, Non-Combat cards and Drills into play. Seal powers resolve immediately. Any number may be placed |
| 3 Power Up | Active | Duelist gains Energy equal to Surge Rate +1. Each Ally gains exactly 1. Never above highest stage |
| 4 Declare | Active | Choose Combat or skip. Playing Grounds this turn forces a skip |
| 5 Combat | Both | See below |
| 6 Discard | Both | Active player discards down to 1 card, then the opponent does the same. **Deliberate exception to "the later revision wins":** the 2003 rulebook says keep 1, Score's CRD v11.24.04 says keep 2, and we keep 1 as canonical for the period we are modelling (user's call, 2026-09-18). Measured at 756 matches, keep 2 narrows the top of the field and costs the Ally deck about 4 points. `DuelEngine.HAND_KEEP` |
| 7 Recover | Active | If Combat was not declared, may move the top discard card to the bottom of the Life Deck. The step always occurs; effects can hook it |

---

## Combat (6 phases)

| Phase | What happens |
|---|---|
| a Active Prepares | Active player resolves all "when entering Combat" effects in any order |
| b Opposing Prepares | Opposing player does the same |
| c Opposing Draws | Opposing player draws 3 |
| d Attacker Attacks | Attack, use a card in place of an attack, or pass. Pass or non-attack goes straight to phase f |
| e Defender Defends | Only if an attack was performed. Play one thing that stops or prevents, or do nothing |
| f Fight Back | Swap roles and return to d. Combat ends when both players pass consecutively in phase d |

Player types (active, opposing) never change during Combat. Roles (attacker, defender) swap every phase f.

**Attack sources.** Strike and Art cards from hand, Duelist Power, Ally Power if that Ally is in control, or a **Final Strike**: discard any card from hand to perform a bare Strike with Strike Table damage plus Drill and other in-play modifiers, then pass for the rest of Combat. Once per player per Combat. Shields and floating effects still work after it.

**In place of an attack.** Non-attack Combat cards, non-attack Duelist or Ally Powers, Grounds effects, face-up Non-Combat cards in play (discarded after use), Relic power (each Relic says whether its power is a Non-Combat step action, a Combat action, or either).

**Ally control.** When the Duelist is at Energy 0 or 1, the player may put an Ally in control at the start of their own attack phase, and must say who is in control when defending (battle sequence step 4). Once the Duelist is back above that, it resumes control. After a Final Strike the player neither attacks nor defends for the rest of Combat. A skipped attack phase never happened, so passes around it are not consecutive.

**Defenses.** A Strike, Art, or Combat card from hand, a Duelist or in-control Ally Power, or a face-up Non-Combat in play, and only if it stops the attack or prevents damage. Then Defense Shields auto-activate on any still-unstopped attack, defender chooses order. Cards that end Combat can only be played as an attack action.

### Battle sequence (one attack)

1. Attacker plays or uses the card or Power, or passes.
2. Attacker pays costs, declares Empower.
3. Attacker's secondary effects resolve.
4. Defender declares which personality is in control (Ally takeover allowed only when the Duelist is at Energy 0 or 1).
5. Defender plays a defense.
6. Defender's secondary effects resolve.
7. If not stopped, Defense Shields activate.
8. If still not stopped, the attack is successful, even at 0 damage.
9. Base damage: Strike Table for a Strike, 4 life cards for an Art, or the printed number.
10. Modifiers: adds, reductions, one multiplier at most, then caps at deal time.
11. In-control Ally may choose Seal capture instead of life-card damage, if that Ally has the capture trait.
12. Energy damage is dealt.
13. Life card damage is dealt one card at a time. Endurance may be used as each card flips.
14. **Critical damage.** If the attack dealt 5 or more life cards, attacker may choose one: capture a Seal the defender controls, discard an Ally the defender controls, or lower the defender's Fervor by 1. Card text beats the rulebook, so a card that says an Ally cannot be discarded, or that Fervor cannot be lowered, stops that option here as it does anywhere else; the attacker picks from whatever is left. (Corrected 2026-09-18: this used to be treated as a game rule that overrode printed immunity, which contradicted the Golden Rule and was costing House Rooke 2.2 Allies a game.)
15. "If successful" effects resolve, attacker picks the order.

"Use when needed" cards fit between steps, never inside one. Outside Combat they can be used at any time.

---

## Attacks and damage

- **Strike.** Base damage from the Strike Table in Energy stages. Successful hits do not raise Fervor by themselves; Fervor comes from card text.
- **Art.** Costs 2 Energy, deals 4 life cards, unless printed otherwise. Cost is paid before any effect and is not refunded if stopped. Cannot perform if the cost would take you below 0.
- **Energy damage past 0** converts to life cards 1:1 at deal time, and counts as both damage types for prevention.
- **Life card damage** flips the top Life Deck card to discard. A Seal flipped this way does not count and goes to the bottom of the Life Deck (or is removed from the game if that Seal is in play). Life cards lost to non-damage effects do count Seals.
- **"+X" modifiers** add their type even if the attack does not deal that type.
- **Reduce** modifies damage. **Prevent** blocks it. Attacks can forbid either separately. Unstoppable attacks can still be "stopped" for the defense card's secondary effects.
- **Losing** happens when you must flip or draw a life card and cannot, or when only Seals remain and damage is dealt.

### Strike Table

Base damage = clamp(attackerBand - defenderBand + 1, 0, cap). Bands are index ranges over Might. Zenith keeps the final-era shape, nine bands A to I with cap 9, on a compact Might scale: band A is 0 and every ten points is a band (B 1 to 9, C 10 to 19, up to I at 70). Thresholds and cap live in `data/strike_table.json`.

Ladders follow the relaunch's lesson without its four aspects: duelists at the same aspect sit within a band or two of each other, so equal-Energy fights deal 0 to 2 stages and a fully charged duelist over an exhausted one deals 4 at most. Aspect 1 tops in C or D, aspect 2 in D or E, aspect 3 in E or F; a 5-aspect duelist climbs the same rungs more slowly. Each duelist keeps its own shape: a brute crosses into the aspect's band early, a caster late, and Surge runs the other way.

---

## Card types

There is one **Personality** type, not a Duelist type and an Ally type (merged 2026-09-19). A personality is a personality; the deck names one of them as its Duelist and every other one it runs fights as an Ally, so the same card can lead one deck and serve in another. Duelist and Ally below are roles, and the only thing separating them is deck construction.

| Type | Zone | Rules |
|---|---|---|
| Personality as Duelist | Aspect stack | Not in the Life Deck. Counts toward deck size |
| Personality as Ally | In play | Placed in Non-Combat at Energy 3, at any aspect up to the Duelist's current aspect, whether or not its lower aspects were ever played. Climbs by overlaying exactly its next aspect, set to highest stage, and may pass the Duelist's aspect that way; the aspects underneath leave play and follow it wherever it goes, so a card that discards the Ally discards all of them. Powers up 1 per turn. Absorbs all damage of one attack when chosen at step 4 or after damage calculation; any personality may be the one that takes it, so an Ally holding Combat can push the hit back onto the Duelist. Takes over Combat when the Duelist is at Energy 0 or 1, at the start of an attack phase, at battle step 4, and once per card whenever the opponent plays or uses a card outside their Defender Defends phase. Then uses its own Might. Power once per Combat. Fervor never applies to Allies, so it never moves an Ally's aspect. **Every Ally rule is per player:** one Ally per character per player, and the table across from you never restricts what you place. Both players may field the same character at once, at the same aspect, even the same card, and your Ally may share a name with the rival's Duelist. Not sharing your **own** Duelist's character is a deck rule, checked at construction and never again in play (house rule 2026-09-21, see the baseline note) |
| Strike | Hand | Performs or stops a Strike, or a utility. Endurance often printed |
| Art | Hand | Performs or stops an Art. Non-attack uses cost no Energy |
| Combat | Hand | Utility. All effects are secondary. Used in place of an attack or as a defense if it stops or prevents |
| Non-Combat | In play | Placed in Non-Combat, used once in Combat in place of an attack, then discarded. Cannot be used during the Non-Combat step. Cards drawn in Combat wait for the next Non-Combat step |
| Drill | In play | Non-Combat that stays. One school of Drills per player at a time. No duplicate school Drill. Freestyle and Signature Drills unrestricted. Restricted Drills (cannot be used with other X Drills). Always-active Drills are mandatory. All Drills discard when the Duelist changes aspect. An unplayable drawn Drill may be shown and shuffled back |
| Seal | In play | Three sets of seven. One set per deck, one copy each. Power resolves on play, must be used. Unique in play. Immune to card effects unless named, random effects excepted. Capturable |
| Grounds | In play, shared | Placed in Non-Combat, forces Combat skip that turn. New Grounds removes the old one from the game. No duplicate Grounds in play |
| Mastery | Side card | Exactly one per deck. Its school is the deck's Style. Never discarded or removed. Effects come from the Mastery, not the cards it modifies |
| Relic | Side card | One per deck. Holds Reserve up to its printed size, outside deck size. Only "Reserve" cards live there. Owner may look through it any time |

---

## Schools and Style

Signature identity is recorded in a card's `character` metadata regardless of card type. Named Drills and Non-Combats qualify for their Duelist's signature discard and search effects, including Freestyle Mastery. Searching into hand does not require the card to be playable in the current phase.

The first word of a card title sets its school. Everything else is Freestyle. Signature cards carry a duelist's name anywhere in the title. Each school is a school of magic (retheme 2026-09-17), and the six read as six elements: fire, water, storm, shadow, metal and wood. Every school has both melee and ranged spellwork; the schools differ in how they lean and in which win they play toward. Freestyle is mundane skill with no magic in it.

| Style word | School | Doctrine | Identity | Leans | Plays toward | Trades away |
|---|---|---|---|---|---|---|
| Pyre | Pyromancy | Fire takes the site's power greedily and burns what it has to | Fervor engine. Strikes that raise Fervor, cards that protect it, fast aspect climbs. Mastery burns a known spell to make an Pyre attack Focused | Melee | Ascension win | Thin defense, weak Arts |
| Tide | Hydromancy | Ebb and flow. Pull energy out of the rival and return your own | Guard and leverage. Blocks and sidesteps, Energy manipulation on both duelists, stop-all-attacks floats, a coven of Allies. Mastery is a standing block or Energy swing | Ranged | Survival win by attrition | Slow damage, few Fervor gains |
| Storm | Tempest | Charge is built through ritual and then released | Arts. Cheaper and bigger Arts, Drill support, Focused Arts. Mastery discounts or boosts Arts | Ranged | Survival win by barrage | Poor Strikes, dry-Energy weakness |
| Shade | Umbramancy | Attack the mind directly | Hand peeks, forced and random discards, removal from the game, denial. These hit the same thing the Life Deck stands for. Mastery taxes the opponent's hand | Mixed | Survival win by denial | Modest raw damage |
| Steel | Ironblood | Magic turned inward. The spell is the body: hardened skin, weight, strength. Steel Arts are force released from the body, never a thrown bolt | Brute Might. Biggest Strike modifiers, Energy gains, Strikes that also wound, critical damage. Mastery boosts or shields the first attack each Combat | Melee | Survival win by force | Little disruption, no recovery |
| Root | Druidry | What is cut away grows back | Regeneration and foresight. Known spells return from discard to the deck bottom, top-deck looks and reorders, 90-card allowance. Mastery recovers cards every Combat. The druids are the patient seal openers | Mixed | Seal win | Low burst |
| Freestyle | none, mundane | Will, footwork and steel. Every mage carries some; a swordmaster carries nothing else | Signature cards, Allies, Seals, unstyled Drills, Desperation moves. Fits any deck | Melee | any | Weak Mastery |

The old school labels (Berserker, Warden, Evoker, Rogue, Juggernaut, Ranger-Druid) are retired. Card naming pass done 2026-09-17 for all seven decks: each title marries the mechanic to the school's doctrine (Pyre burns and rekindles, Tide ebbs and floods, Storm charges and releases, Shade hexes the mind, Root regrows, Freestyle stays mundane). Steel alone keeps hand-to-hand names, because the Ironblood body is the spell. Titles are short move names, never sentences.

- **Style.** Every deck carries exactly one Mastery, and that Mastery's school is the deck's Style. All school cards in the deck share that school. A Freestyle Mastery allows no school cards. Nothing is declared at setup. The old single-school Surge bonus stays as a flat +1 at Power Up for every deck.
- **No gates.** Any duelist may train in any school. "School only" text does not exist; gating comes from alignment and duelist names only.
- **Alignment.** Vigil, Pact, or Hedge. Allies must match the Duelist. "Vigil only" and "Pact only" text.
- **Bloodline.** Draconic, Verdant, or none. Sits on the personality, not the deck, so Allies need not match the Duelist. "Draconic only" and "Verdant only" text, read off whoever is in control of Combat. See Bloodlines above.

---

## Deck construction

- 50 to 85 cards including Duelist aspects, Mastery, Relic. A Root Mastery allows 90.
- Exactly one Mastery. Its school is the deck's Style.
- At least 3 consecutive Duelist aspects from Aspect 1, up to 5.
- 3 copies max. 4 for Signature cards matching your Duelist. "Limit N per deck" and the restricted list override.
- Allies: every personality card of Aspect 1, 2 or 3 is legal in any deck, whatever height the Duelist runs. 1 copy of each personality card, none sharing the Duelist's character, matching alignment. The Aspects an Ally runs need not be consecutive and need not include Aspect 1. **Corrected 2026-09-21** against the later rulings revision, which is the basis: this replaces an older "at least 2 aspects below the Duelist's highest" rule and the 2026-09-20 house exemption for Aspect-1 Allies, which the flat rule now covers on its own.
- Seals: one set, no duplicates.
- Reserve must obey the same Style and construction rules.

---

## Win conditions

| Win | Condition |
|---|---|
| Survival | Opponent cannot flip or draw a life card |
| Ascension | Your Duelist is at your highest aspect and reaches Fervor 5 (or the current requirement). A 3-aspect stack needs 15 Fervor in all, a 5-aspect stack 25 |
| Seal | You control all 7 Seals of one set. If you placed the 7th yourself, instant. If you captured it, you win at the start of your next turn if you still hold all 7 |

Seal capture: critical damage (battle sequence step 14), an in-control capture-trait Ally choosing capture over damage, or card text. Captured Seal powers may be used on capture. Floating effects from a captured Seal end.

---

## Keywords and text patterns

| Keyword | Meaning |
|---|---|
| Endurance N | When this card flips as attack damage, may prevent N of the remaining damage and remove this card from the game. Not against unpreventable damage, not for non-damage discards. Endurance X reads a game value |
| Focused (attack) | Cannot be stopped by Defense Shields, Masteries, or cards that stop both attack types. Triggers all matching Shields |
| Empower N | On attack, may add N life cards and drop all text after the Empower |
| Defense Shield | Auto-stops the first unstopped attack of its type. Types: Strike, Art, both |
| Constant Power | Continuous, only while that personality is in control, mandatory |
| Floating effect | "For the remainder of Combat / turn / game". Card discards when its last effect resolves; the effect persists |
| Use when needed | Between battle sequence steps, or any time outside Combat. Can be answered by another Use when needed |
| Remain N | Stays in play to be used N more times this Combat |
| Secondary effect | Anything not the attack, its cost, Endurance, "if successful", a stop, or parenthetical text. Resolves before the opponent acts |
| If successful | Resolves at step 15 |
| Unstoppable / cannot be prevented / cannot be reduced | Three separate flags |
| Cost vs requirement | Only the word "cost" makes a cost. Cost-modifying effects ignore requirements |
| "X only" | Duelist name or alignment gate. For Strike, Art, and Combat cards the gated personality must be in control; Non-Combats may be placed but not used otherwise |
| Remove from the game after use, Limit N per deck | Self explanatory |
| Desperation moves | Freestyle cards with heavy costs, tagged so cards can reference them |
| Cards under cards | Face-down stacks under an in-play card, discarded when the host leaves play |
| Copied attacks | A virtual card with the copied text, vanishes after use |
| Cherry picking | Deck searches reveal the chosen cards and reshuffle |
| Bond | Two named Allies fight back to back as one. A Bonding card folds them under their Bond card, which enters at full Energy with its own power. At the start of each of the owner's turns a life card goes under it; at 5 the Bond ends, the Allies return at 3 Energy, and the Bond card goes back to the Reserve. A Bond that leaves play takes both Allies with it. Implemented 2026-09-15 for House Rooke (Ansel and Tavin) |

**Timing rules.** No simultaneous effects: the active player resolves all of theirs first in any order, then the opponent. "Entering Combat" effects resolve before the opposing player draws. Card effects resolve in printed order. Cards discard immediately after their last effect. Skipped phases never happened for "beginning of phase" effects. Only one damage multiplier applies.

---

## Engine hooks

The rules engine exposes these as trigger windows, prompts, or state flags. Every card effect attaches to one of them.

**Trigger windows**
turn_start, draw, noncombat_place, powerup_begin, powerup_end, declare, entering_combat (active, then opposing), opposing_draw (replaceable), attack_phase_begin, attack_declared, costs_paid, secondary_resolved, control_choice, defense_window, shields, attack_resolved (successful or stopped), base_damage, modify_damage, energy_damage, life_card_flip (per card), capture_window, if_successful, attack_end, fight_back, combat_end, discard_step, recover_step, turn_end, fervor_changed, aspect_up, aspect_down, seal_placed, seal_captured, card_placed, card_leaves_play, search, reveal, use_when_needed (between steps).

**Prompts**
choose action (attack / in place / pass / Final Strike), choose defense or nothing, choose in-control personality, redirect damage to an Ally, Endurance yes/no per flipped card, capture Seal yes/no and which, order If-successful effects, order Shields, order simultaneous own effects, Empower yes/no, choose targets, choose "or" branches, look-at and rearrange top N, random discard, Recover yes/no, Discard down to 1.

**State flags and counters**
must_pass_rest_of_combat, skip_next_attack_phase, cannot_declare_combat, cannot_play (card type / attack type / end-Combat cards), power_used_this_turn per aspect, ally_power_used_this_combat, final_strike_used per player, once_per_combat and once_per_turn per card, floating effects with duration and owner, attachments to personalities, cards_under host, seal_victory_pending (captured 7th), hand and Life Deck as hidden information with reveal permissions.

**Replacement effects**
draw 3 from discard instead of Life Deck, damage caps, convert damage type, keep cards in Discard step, alternative cost payment, blank text boxes.

---

## Client architecture

Rules engine and presentation are separate so the same engine drives hotseat, AI, online, and adventure.

- **Engine** (`engine/`, RefCounted only, no Nodes). Game state, zones, card instances, phase machine, legality checks, effect resolver, seeded RNG. Input is a **Command** (play card, choose, pass). Output is an **Event** stream. Deterministic: same seed plus same commands gives the same game.
- **Card definitions** are JSON under `data/cards/<set>/`, loaded into `CardDef` at boot. Effects are lists of typed steps bound to the hooks above, with conditions and durations. A `script_hook` field covers the few cards that need custom code.
- **Card faces** render procedurally in v1: school color frame, name, type line, cost, text, Endurance badge. No art dependency. Each face is drawn once by a 2D `CardFace` control into a `SubViewport` and cached as a texture, so the same face serves the 2D hand and the 3D table.
- **Playspace** (`scenes/duel/`). A 3D table scene, the way a digital duel client stages a battlefield: fixed perspective `Camera3D` looking down the table toward the opponent, subtle camera drift on mouse position, a themed environment around the table (the Grounds card in play swaps the backdrop), lighting and ambient particles. Cards on the table are quads (`MeshInstance3D` with the cached face texture, unshaded, mipmapped) that tween through 3D space between zones. Zones are `Marker3D` layouts for both players: Duelist, Allies, Drills, Non-Combats, Seals, Grounds, Mastery, Relic, Life Deck, discard, removed pile, Fervor meter, Energy gauge. Stacks (Life Deck, discard) render as real stacks whose height tracks card count.
- **Hand and HUD** are 2D on a `CanvasLayer`: hand fan at the bottom, prompts, combat log, phase tracker, pass button. Dragging a card lifts it off the hand, raycasts onto the table plane, and hands it to the 3D layer when dropped in a legal zone. Hover on any card, 2D or 3D, shows a full-size 2D zoom. Hotseat hides the hand between turns.
- **Animation queue.** Events from the engine become queued 3D and 2D tweens: card flight, flip, attack lunge toward the target, wound flips off the Life Deck, Energy gauge slide, Fervor meter fill, aspect-up reveal. The queue can be skipped by the player.
- **Referee and seat views.** `Referee` owns the one engine and speaks to seats only in `SeatView` (zones as uids, hidden cards as uid plus zone), `PromptView` (labelled options) and `SeatUpdate` (lines, view, prompt). Clients render from views and never touch the engine. Uids are dealt after the shuffle. Same object in three placements: in-process for hotseat and AI, in the hosting client for P2P (the host can still read everything, so P2P is friends-only), in a headless process for hosted play.
- **Player drivers.** `LocalHuman`, `Ai`, `Remote`. Online, the joiner sends Commands over ENet and receives its own `SeatUpdate`; it never holds the seed or the other seat's hidden cards.

**Risks.** Card text legibility on 3D quads at table distance: mitigate with a high-resolution face texture and the hover zoom, and keep the camera angle shallow. `SubViewport` per card face is memory-heavy at scale: render once per card definition, not per instance. Spike the drag from 2D hand to 3D table early, since that hand-off is the piece most likely to feel wrong.

---

## Adventure mode (later)

- Node map across contested places of power. Each node is a duel against a fixed Duelist and deck.
- Rewards: cards, packs, new Duelists. Collection and deckbuilder screens.
- AI is one evaluator and a short lookahead search for every deck (`zenith/ai/`). An opponent's playstyle is a weight profile in `data/ai/profiles/`, tuned per opponent; no per-deck scripts.
- Saves through `godot-base` SaveFileHandler.

---

## Milestones

1. Engine plus headless test scene. Full 7-step turn, 6-phase Combat, 15-step battle sequence, all three wins reachable, Strike Table and damage conversion, Allies, Drills, Seals, Grounds. Done 2026-09-15.
2. Playspace spike: 3D table, camera, card faces rendered to texture, card flight tweens. Done 2026-09-15 with click-to-play; drag from the 2D hand is still open.
3. Hotseat duel client on the spike, with deck select and placeholder decks. Done 2026-09-15.
3b. Full rule support for the six starter decks: effect queue with choice prompts, Remain, Empower, counter window, floating forbids, attachments, constant powers, Relic powers, named-card locks, attack variants, "you may" and pay-any-Energy prompts, look-at-N inspection, chosen searches, instead-of-damage choices, two-stop attacks, Ally powers without control, Drill self-maintenance. Done 2026-09-15; the few remaining approximations are listed in `zenith/README.md`.
4. AI opponent. First pass done 2026-09-17: fair AI through `Referee.sim_for`, scorer plus lookahead search, Easy, Normal and Hard, Duel the AI on the title. Open: per-deck playstyle profiles, an offline weight tuner over `tests/ai_arena.gd`, memory of cards the AI has seen.
5. Online over ENet. Done 2026-09-15: host or join from the title, the select screen as lobby. Reworked 2026-09-16 from lockstep to host-authoritative seat views: the joiner holds no engine. Open: a headless referee process, encrypted transport, matchmaking or relay, reconnects and turn timers.
6. Deckbuilder and collection.
7. Adventure mode.
8. Later keywords: Brawl format (Survival only), Bond Duelists (a Bond that replaces the duelist rather than two Allies).

Starter pool as built 2026-09-15: six Duelists, ten Allies, three Relics, six Masteries, two Seal sets, and 193 functional-name cards in all, with six starter loadouts modelled card-for-card on a community set of sample decks for the reference game: two physical beatdowns, two ally decks, a Freestyle drill deck, and an energy deck. Counts and roles are kept and each card carries the real mechanics of the card it stands in for, written in the effect schema. The set is generated by `zenith/tools/gen_starters.py`.

---

## Open items

- Portraits and card flavor text. Duelist names for the starters are approved (see Setting); everything else waits on tone approval.
- Retheme follow-ups (2026-09-17). The rename pass is done. Still open: whether the Root deck should run the Marble Seals (Root Wyrmwood Blast counts them) or another set; "Summoning win" in place of "Unsealing win"; place-of-power names for the Grounds cards; a themed card naming pass for Pyre, Tide, Storm, Shade and Steel; rewriting the art briefs in `zenith/docs/card_roster.csv` and `.md`, which have the new ids and terms but still describe the old chivalric look (half-plate, heraldry, the king's gold coins).
- Game name settled 2026-09-17: Eidolarch, applied to the title screen, window title and README. Still to do: a trademark and store check.
- Deck size default for v1 (50 minimum is legal).
- Ascension pacing with unequal stacks: a 3-aspect Duelist wins Ascension at 15 Fervor, a 5-aspect one at 25. Accepted for now; taller stacks trade a slower Ascension win for stronger top aspects.
- Might ladders were compressed onto the compact scale on 2026-09-16 (Ashmark no longer reaches band H at aspect 2, Corven now climbs to D). Per-duelist variety in Surge and Might stays; tune further from play.
- Quarr's aspect 1 was pulled back to 3-12 on 2026-09-18, off the hand-raised 9-18 and onto the rung his source card sits at (it is the lowest aspect-1 ladder of the seven, as the printed card is). Over 756 matches it cost Steel 0.5 points of win rate, so Steel's lead is not coming from the Strike Table.
- Restricted list policy: none in v1.
- Tide or Bastion as the water school's style word.
