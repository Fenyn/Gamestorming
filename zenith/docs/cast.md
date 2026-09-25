# Cast

Who exists, what they are, who they belong to, what they look like, and every form they take. This
is the record for people and places. It absorbed `world.md` on 2026-09-22 (settled 2026-09-19) and
the cast table that `card_roster.md` used to print. Mechanics live in `../../designs/zenith.md`:
the Vigil and the Pact, Bloodlines, Keywords and the Eidolons' seal sets all have entries there.
Where the two disagree, the design doc wins on rules and this one wins on who somebody is.

Identity strings and art briefs are copied from `tools/gen_roster.py`, which is what the art
pipeline reads. When `CAST` or `ART` changes there, change the matching line here. Naming rules
and the reference-game mapping live in `cast_backlog.md` and stay there. Per `../CLAUDE.md` no
reference-game names appear in this doc.

## The world in ten lines

- Places of power sit on the leylines. At each one the wall between worlds is thin enough to cut a gate.
- Seven seals carved into a gate open it for one Eidolon, an elder god waiting on the far side.
- Duelists fight for the right to carve. Inside the duel, everything is the duelist.
- **The Vigil** stands watch so that whatever comes through answers to someone who will hold it in check.
- **The Pact** bargained passage for power and fights to deliver on it. Anyone can sign. It leans toward the demons: some of its members deal with them and the Pact does not stop them, and the Vigil holds that against the whole side.
- **Hedge** duelists are sworn to neither and pick a side at setup.
- An **Aspect** is how deep the duelist is attuned to the site, and what that is doing to them. Every duel starts at the first.
- **Bloodlines** are power an ancestor's bargain left in the blood. Two exist, Draconic and Verdant. They cross both sides.
- **Constructs** are made, not born, and run on mana. The **marked** carry a demon's mark, laid at a toll gate, and someone on the other plane holds the far end.
- A clan is a social fact. A school is what someone fields today, never what they are.

## Origins

Three tiers, and a character sits in exactly one of them.

| tier | where it lives in data | values | what it means |
|---|---|---|---|
| Born lines | `bloodline` on a personality | `draconic`, `verdant` | Power an ancestor's bargain left in the blood. Inherited whether or not the descendant wants it |
| Made kinds | `tags` on a personality | `construct`, `marked` | Not born. Built by a wright, or marked by a demon |
| No line | absent | — | Human. Most people |

**Born lines stay at two.** Draconic is the fighting line, hot-blooded and hard to put down.
Verdant is the old line that cut the first seals, patient, and regrows what is taken away. A line
crosses the Vigil and the Pact freely, because it is not a choice anybody made. A duelist and
their following need not share one.

**Made kinds are not a school.** A `construct` is anything walking around that was made rather
than born, by any tradition and out of anything. A `marked` personality is a living person
carrying a demon's mark, and somebody on the other plane holds the far end of it. A construct was
made whole; a marked person was taken over.

**Constructs are a loose faction of their own** (2026-09-24). Nobody leads them and they want
different things, but they keep turning up together, and any of them slots in as a villain. What
they share is hunger:

- A construct runs on **mana**, leyline power stored as charge. It burns mana just to keep moving,
  and faster when it fights or casts. It cannot make its own. It gets mana from the Collegium, from
  a leyline, or by taking it out of a duelist or another construct.
- Fed, a construct thinks clearly. Starving, it turns feral and single-minded, and it loses its
  manners before its mind. Every construct is dangerous while it feeds.
- They work together the way scavengers share a carcass: while the supply lasts. When it runs
  short they turn on each other.
- Mana is also the run currency. A duelist on the road gathers the same charge the constructs
  hunt, and a well-stocked duelist is prey to them.

**No line is a fact, not a gap.** Unlined duelists hold their own against Draconic ones, and the
most dangerous thing about the Rooke Coven is that its matriarch has no line while every one of
her followers does.

## Two elsewheres

**The Eidolons** are elder gods, one behind each set of seven seals, and all of them are still on
their side of the wall. Nothing comes through except by a gate, and a gate opens only when seven
seals are carved into it. They are patient because they have to be. Their bodies are at the end of
this doc; their seal sets are in the design doc.

**The demons** work a different plane, and the wall between it and this one is not a gate. They
reach through. They can lay a mark on a person who lets them, and afterwards that person carries
some of what they are. It needs no seals and nobody can see it being done. The agent who lays the
mark is a man with a toll gate and a yard, who does this for others and takes payment in the usual
way. He is unnamed.

A demon takes the part of the trade that other people could hold the person to, and leaves whatever
they were using to hold themselves together. Ashmark traded his humanity, so it took the part of him
that could be satisfied, and there was nothing left, which is why he is a shell. Gideon Mourne traded
his claim, so it took every other person's power to give it back, and what was left was pride. The
same mark produced two different men, and `marked` is not one condition.

## The Lodestone Heart

Settled 2026-09-23. The thing everyone on the road is after, and the thread that ties every
storyline together.

- A stone that can open or close any gate between worlds. Whoever holds it decides what comes
  through and what never will. That is why everyone is seeking it.
- Worn, it pulls the wearer toward themselves: nothing drags them down, and nothing lifts them past
  what they are. In the data it is the Relic `lodestone_heart`, and its flags are that pull.
- **Halden Quarr** wears it now and is its protector. He fights only to keep it from others. He
  knows he would never use it himself, which makes him the only safe owner.
- Each side wants it for its own reason. The Vigil wants it out of Pact hands. The Pact wants the
  gates open. Outlaws want to sell it or use it as leverage. Ashmark wants to feed on what is behind
  the gates.

## Storylines and relations

Settled 2026-09-23. Three viewpoints on the same road to the Heart. The shared thread is loose,
and everyone has a reason to fight everyone, friends included.

| Viewpoint | Who | Wants the Heart to |
|---|---|---|
| The good side | Sir Edric Rooke, with the Rooke and Vale families around him | Keep it from anyone who would use it |
| The outlaw side | Gideon Mourne, spiteful and disgraced, out for himself | Profit from it, or extort anyone he can |
| The villain | Bram Ashmark, marked and mostly monster | Open gates and consume the Eidolons behind them |

Friendly tests are a normal part of this. Family and allies fight each other to prove something,
and nobody is off limits, Edric's own family included.

**Relations network.** Who is connected to whom. Meeting one character can bring their
connections onto the road; how that works in play is in `../../designs/zenith_adventure.md`. Every
link is listed on both sides.

- **Edric**: Alder (wife), Emrys and Ansel (sons), Wren (kin), Tavin (fostered, Caedan's son),
  Caedan (war companion, taught him the sword), Mourne (a man who serves against one who would not
  kneel), Ashmark (hero and monster).
- **Alder**: the Rooke family, Osric (taught her son), Sable (matriarch and captain).
- **Emrys**: Edric and Alder (parents), Caedan and Osric (his teachers), Quarr (both field Steel).
- **Caedan**: Tavin (son), Emrys (pupil), Edric (war companion).
- **Osric**: Emrys (pupil), Alder, Orvath Kell (the same Verdant line).
- **Mourne**: Kell (the broken company), Marrow (her crew), Ashmark (the same toll gate), Edric,
  Sable (she wants him in the Draik Company, or as a partner for the Heart).
- **Marrow**: Cull, Kell, Mourne, Pim, Scorn (kin), Siphon.
- **Sable**: her crew, Pim, Alder, Mourne.
- **Siphon**: Tithe, Cull, Pim, Marrow, Ashmark (rivals for the same feed).
- **Ashmark**: Mourne, Siphon, Edric.
- **Pim**: the Draiks, Marrow's crew and the Collegium; the bridge from the outlaw side to the rest.
- **Quarr**: everyone, through the Heart.
- **Constructs**: all loosely related to one another, since made things recognise each other and
  feed at the same sources. See The Collegium for the closer links.

Characters without a deck (Torvan Hask, The Fortress, Corin Thrace, the toll-gate agent) stay off
the network until they have one.

## Clans

A clan is a social fact. It grants nothing mechanically and it is not a school. **What a clan
fields today is not what it is.** The index below records current practice only, and a clan may
field more than one school later; Sir Edric Rooke already does.

| clan | fields now | side | what they are |
|---|---|---|---|
| The Rooke Coven | Tide, and Pyre and Steel in its sons' own lists | Vigil | An old family of water mages |
| The Vale line | Freestyle | Vigil | A family sword art, nearly extinct, taught to blood and once to a friend |
| The Draik Company | Shade | Pact | Mercenary hexers, pirates by trade and warlocks by method |
| The Collegium | Storm | Pact | Artificer wizardry: wrights who build, charge and repair |
| The Thornwald Grove | Root | Vigil | Druids whose rites regrow what is cut away |
| The Kingsguard | Freestyle | neither | A martial order. Teaches fighting, not magic |

## Index

| Character | Side | Origin | Belongs to | Fields | In the game as |
|---|---|---|---|---|---|
| Bram Ashmark | Pact | marked | no one | Pyre | Duelist, 2 decks |
| Halden Quarr | Pact | Draconic | no one | Steel | Duelist |
| Sable Draik | Pact | none | The Draik Company | Shade | Duelist |
| Vesna, Brann, Halvard, Quill Draik | Pact | none | The Draik Company | Shade | Allies |
| Pim | Pact | none | The Draik Company, ex retained guard | Shade | Ally, 3 decks |
| Dame Alder Rooke | Vigil | none | The Rooke Coven | Tide | Duelist, and Ally in Edric's deck |
| Sir Edric Rooke | Vigil | Draconic | The Rooke Coven, Kingsguard-trained, born a Hask | Pyre own, Tide beside the coven | Duelist, 2 decks, and Ally |
| Emrys Rooke | Vigil | Draconic | The Rooke Coven, Vale- and Grove-taught | Steel | Duelist |
| Wren Rooke, Ansel Rooke | Vigil | Draconic | The Rooke Coven | Tide | Allies |
| Tavin Vale | Vigil | Draconic | The Vale line, fostered with the Rookes | Tide | Ally, plus the Ansel-and-Tavin bond card |
| Torvan Hask | Pact | Draconic | The line Edric left | none yet | One named card, no personality |
| Caedan Vale | Vigil | Draconic | The Vale line | Freestyle | Duelist |
| Osric Thornwald | Vigil | Verdant | The Thornwald Grove | Root | Duelist |
| Corin Thrace | Vigil | none | no house | teaches a discipline | Five named cards, no personality |
| Siphon | Pact | construct | The Collegium | Storm | Duelist, 2 decks |
| Tithe | Pact | construct | The Collegium | Storm | Ally |
| Marrow | Pact | construct | Marrow's crew | Shade | Duelist |
| Cull | Pact | construct | Marrow's crew, Collegium-trained | Shade | Ally, 2 decks |
| Orvath Kell | Pact | Verdant | The broken company | Shade | Ally, 2 decks |
| Gideon Mourne | Pact | Draconic, marked | The broken company | Shade | Duelist, and Ally in Marrow's deck |
| The Fortress | Pact | Draconic | The broken company | Freestyle | Two named cards, no personality |
| Sledge, Mercy, Scorn | Pact | construct | no one | Freestyle | One named card each, no personality |

Duelist decks in data: Wildfire Rush and Last Standing (Ashmark), Ironblood Onslaught (Quarr),
Hexbound Company (Sable), Tidesworn Coven (Alder), Ember Ascendant and Crushing Depths (Edric),
Steel Inheritance (Emrys), Blade Legacy (Caedan), Sevenfold Grove (Osric), Tempest Engine and
Stormlock (Siphon), Scrap Requiem (Marrow), Mind Siege (Mourne).

---

## The Pact, unattached

### Bram Ashmark

**Look.** Man in his early twenties, lean, soot-streaked pale skin, singed short dark hair,
half-plate over a scorched gambeson, plain longsword with a heat shimmer.

**Who he is.** A warlock who traded his humanity for power at the toll gate. The demon took the
part of him that could be satisfied and left the mark. The trade was honoured in full: he has the
power, and what remains is a hollow shell that hungers for more strength and cannot be filled, so he
takes it wherever he can. He fields no Allies. He takes in the people he beats, and they do not
fight for him: what surfaces is memory, their whispers and pieces of who he was, coming up against
his will. What he traded away still exists elsewhere, and a
future character is "the humanity Ashmark traded away, returned as a person" (unplaced, origin
undecided).

**In the story** (2026-09-23). The villain's viewpoint. He is marked from his first duel and his
motives are simple: consume and grow stronger. He wants the Lodestone Heart so he can open gates
and feed on any Eidolon he meets, until he is a world-ending force. His humanity is a husk. Pieces
of who he was can surface in dialogue, but he is mostly monster by now.

**Arc across Aspects.** The bargain coming due, not skill improving. The Pact shows as light under
the skin, then cracks, then the fire streaming inward through a hollow at his chest.

| Aspect | Deck | Look | Does |
|---|---|---|---|
| 1 Starved | both | Gaunt and low to the ground, blade loose, the fire down to a few coals, eyes fixed out of frame | Strike +3, gain 5 Energy, draw if stopped |
| 2 Gnawing | Last Standing | Hunched mid-step, small flames chewing the blade's edge, a brand dark on his forearm | Strike +3, Fervor +1, attacks +1 wound |
| 2 Leeching | Wildfire Rush | Flame off the shoulders, cracks of orange light along the forearms, sword overhead | Free Focused Art, lowers rival Fervor 2 |
| 3 Gorging | Last Standing | Fire pouring into him, the light drawn inward, mouth open | Doubles Energy gained, Fervor gains +1, attacks +3 wounds |
| 3 Unstoppable | Wildfire Rush | Fully wreathed, face barely visible, mid-charge, sparks trailing | First school attack each Combat cannot be stopped |
| 4 Consuming | Last Standing | Wreathed and still, everything near him blackening, the brand burning white | Shuffle 8 discards into the Life Deck |
| 5 Insatiable | Last Standing | Ablaze and empty with it, fire streaming inward through a hollow at his chest, nothing in his face | Focused Strike 10, or shuffle 10 discards back |

**Named cards.** Ashmark's Relentless Fury, Ashmark Leaves Nothing.

### Halden Quarr

**Look.** Huge man in his forties, shaved head, brawler's build, bare arms, skin greying to iron in
patches, black knuckles, raised welded scars, no armour.

**Who he is.** Draconic, and belongs to no one. An Ironblood grinder who reads the last blow. Steel
is magic turned inward until the body is the spell, and he hits harder than anyone at the same
Energy. Few tricks, no recovery, only weight.

He was Pact before he took the Lodestone Heart. Since then he has no use for factions and looks
only at what the Heart could do in the wrong hands. He wears it, fights only to keep it, and would
never use it himself, so he is the one safe owner. He stays Pact in the data.

**Arc.** The Pact shows as iron spreading over more of him each Aspect.

| Aspect | Look | Does |
|---|---|---|
| 1 The Grinder | Brawler's crouch, fists up, black knuckles, breath steaming, hungry | Fervor +1 on every attack |
| 2 Tempered | Chest and shoulders greyed to iron, veins like solder, one foot on a discarded page | Burns a Steel discard for Fervor 2 and Strike +2 |
| 3 Ironheart | Chest plated in living iron, a dull red heart glowing through it, both fists cocked | Strike +4 twice a Combat, +2 wounds off a Steel discard |

---

## The Draik Company

Mercenary hexers, pirates by trade and warlocks by method. They take contracts, keep what they take,
and have no origin layer and want none. The company is the whole of what its members belong to.
Deck: Hexbound Company. Every hex is aimed at the rival's mind.

The company trades in stolen mana and pays its hired constructs in it, which makes it the easiest
place for a starving construct to find work. Constructs work for the Draiks and never trust them:
Sable would sell a construct's core without a second thought.

### Sable Draik

**Look.** Woman in her thirties, brown skin, tattooed forearms, long dark coat, a bottle at her hip,
sardonic half-smile.

**Who she is.** Captain of a crew of five. Fights with the company beside her. Her Aspects let the
crew take control of Combat at any Energy.

**Arc.** The Pact shows as shadow pooling around her and the light leaving her eyes.

| Aspect | Look | Does |
|---|---|---|
| 1 Captain | Coat open, boot on a crate, a torn company flag behind her, crew silhouettes, amused | Attacks +1 Energy per Ally, Allies share it |
| 2 Shrouded | Shadow pooled at her feet and climbing her coat, half her face dark, one hand out | Wounds she deals are removed from the game, attacks +3 |
| 3 Lightless | Eyes fully black, the light in the frame dying toward her, shadow streaming off her arms | All attacks Focused |

### The crew

| Name | Look | Role | Aspect 1 card |
|---|---|---|---|
| Vesna Draik | Wiry hooded woman, two knives, face half hidden | The ambusher | Art 6, hit discards a rival Ally |
| Brann Draik | Broad bald man, leather vest, heavy hands, easy menace | The muscle | Strike +5, hit discards a rival Drill |
| Halvard Draik | Tall man, red cloak, twin curved swords, duellist's poise | The swordsman | Strike +5, hit discards from the rival's hand |
| Quill Draik | Thin young man, spectacles, ink-stained fingers, satchel of pages | The hexer proper | Art 6, hit locks a card type out |
| Pim | Small quick youth, patched clothes, sack over one shoulder | The scavenger, no surname. Came out of the retained guard and does not talk about it. Also runs with Marrow's crew and the Collegium | Strike, hit draws 2 from the bottom of the discard |

**The `draik` keyword** (2026-09-24) marks the blood company: Sable and the four crew who carry the
name. Cards that count "the company" read it, so Pim, who runs with them but came out of the retained
guard, is not counted, and neither is anyone who only fights alongside them. His own home is the
retained guard, still to be developed.

---

## The Rooke Coven

An old family of water mages. Vigil, because a gate held by the Pact answers to the Pact, not because
the coven wants to open anything. The matriarch carries no line while every one of her followers is
Draconic. Deck: Tidesworn Coven, where the coven takes the wounds and the Arts drain the rival.

### Dame Alder Rooke

**Look.** Woman in her sixties, straight-backed, long grey hair, red gown over grey mail, round
shield and longsword.

**Who she is.** Matriarch. No bloodline, which is the most dangerous thing about the coven. Married
to Sir Edric, mother of Emrys and Ansel, grandmother or kin to Wren. Her first Aspect guards
Draconic Allies, so she shields kin and not every hireling she happens to lead.

**Arc.** The Vigil shows as water climbing her, filling her, then she is the flood.

| Aspect | Look | Does |
|---|---|---|
| 1 Matriarch | Shield up, sword low, three hooded coven figures behind her, stern | Draconic Allies cannot be removed; 5 Allies in play advances an Aspect |
| 2 Rising Water | Water climbing her mail to the waist, eyes sea-glass green, a knight at her shoulder | Strike, +4 with Edric in play |
| 3 The Flood | A wave rising off her shoulders, face calm as deep water, the ground awash | Entering Combat strips all rival Non-Combats |

**Second Aspect 1 card** (`personality_53`, fielded in Ember Ascendant): stepping in front of a blow meant for someone else, shield up, no
water raised, furious. Stops a Strike aimed at Edric or Emrys.

### Sir Edric Rooke

**Look.** Knight in grey mail, plain longsword, open helm under one arm, weathered and unhurried.

**Who he is.** Draconic. Born a Hask, from a line he left; his elder brother Torvan Hask still
carries it. Trained with the Kingsguard before he married into the coven, which is the coven's
only tie to the order. Caedan Vale fought beside him in the two kings' war and taught him the Vale
sword, the only time the Vales have taught it outside the blood. Fields Pyre in his own list and Tide beside his
wife. He is the first character to field two schools, which settled the rule that a card's look
comes from the card and not from a fixed element on the person.

**Arc** (Ember Ascendant, Crushing Depths). The knight finds the fire in himself, and it costs the
realm around him. The Stranger Aspect has him looking at his own hands with the Hask axe on the
ground behind him.

| Aspect | Look | Does |
|---|---|---|
| 1 The Hero | Standing easy, sword point down, hand raised to hold a line back, no fire yet | Draws on entering Combat, more with Alder and Emrys in play |
| 2 The Stranger | Helm off, looking at his own hands, a seam of heat along one forearm, the Hask axe on the ground | Lowers rival Fervor 1, draws from the bottom of the discard |
| 3 The Realm's Hero | Mid-stride into a burning street, coals under his boots, shielding somebody out of frame | Reveals a draw, 3 wounds if Strike or Art |
| 4 Kindled Through | Fire up the blade and along the mail seams, teeth set, one fist cocked | Strike 5 Energy and 3 wounds |
| 5 The All Powerful | Wreathed to the shoulders, the sword a bar of white heat, everything going to ash | Strike +5 Energy and +5 wounds |

**Second Aspect 1 card** (`personality_50`, fielded in Tidesworn Coven): sword raised, a focused jet of water along the blade. Focused
Strike, +2 wounds per rival Seal.

**Named cards.** Edric's Committed Cut, Edric Gives Ground, Edric Carves First, Edric's Retaining
Drill.

### Emrys Rooke

**Look.** Serious young man, dark hair, grey fencing doublet over mail, bare forearms plated in
fitted grey metal that grows across him each Aspect.

**Who he is.** The eldest son, Draconic. Rooke by blood, Vale-trained in the sword, Thornwald-taught
in the rest, and a swordsman where his parents are casters. In his own duels he carries no sword
at all: Steel is the magic turned inward, so the list is him putting metal on and hitting with it.
Deck: Steel Inheritance.

**Arc.** The plate grows from bracers to full scale, and the pattern finally reads as a dragon's.

| Aspect | Look | Does |
|---|---|---|
| 1 The Eldest | Empty-handed and still, sleeves up, bare forearms, borrowed stances, no metal | May draw when attacking |
| 2 First Plate | Grey metal closed over both forearms like bracers he grew, flexing a hand, surprised | Searches a Strike or Art on entering Combat |
| 3 Edged | The forearm plate drawn out into a working edge along the ulna | Strike +5, may remove a Non-Combat |
| 4 Shaped | Metal to the shoulders and moving where he looks, a plate sliding across his chest | Free Art, 4 Energy and 4 wounds |
| 5 Scaleclad | Plated head to boot in overlapping grey scale, the pattern a dragon's, calm | Strike 5 wounds, twice a Combat |

**Named cards.** Emrys Gives No Quarter, Emrys Risks It All, Emrys' Hilt Guard, Emrys' Sword
Flourish, Sweep and Thrust, Emrys' Swordplay Drill, Emrys Spots the Fraud Drill. His name is on a
card in six decks. The "Sword" and "Swordplay" substrings in these titles are matched by other
cards, so any retitle has to keep them.

### Ansel Rooke

**Look.** Young man, broad shoulders, blue-grey gambeson, round shield. Ally art: shield braced,
water refilling a cracked flask at his hip.

**Who he is.** The younger son, Draconic. Strike 5, refills to full Energy if stopped.

### Wren Rooke

**Look.** Teenage girl, red-brown hair, blue coat, satchel of loose pages. Ally art: gathering
loose pages into her satchel, some floating back to her.

**Who she is.** Youngest of the coven, Draconic. Shuffles a discard back per personality in play.

### Tavin Vale

**Look.** Slim young man, dark hair tied back, blue robe over a fencing doublet, hands open for
casting. Ally art: a globe of water between his hands, pages settling into a deck at his feet.

**Who he is.** Caedan's son, fostered with the Rookes since he was small because his father's road
is no place for a child. He grew up beside Ansel. Draconic, and fielding Tide rather than the
family sword. Art 6, puts two discards under the Life Deck.

**Ansel and Tavin, Back to Back.** The Bond. Standing back to back, shield and water between them,
both looking outward. Strike 7, Focused for a discard, twice a Combat.

### Torvan Hask

**Look.** Heavy-shouldered man in scarred riding leathers, long unbound hair, a hand axe at the
belt, Edric's face ten years harder.

**Who he is.** Edric's elder brother, from the line Edric left. Pact. One card only, Hask's Flying
Kick, a Strike at triple base damage, and no personality card or deck. Draconic, because a line is
inherited and Edric carries it; recorded here 2026-09-22, and it goes into the data when he gets a
personality card.

---

## The Vale line

A family sword art, nearly extinct, taught to blood and once to a friend. The Vales and the Rookes
are old friends from the two kings' war: Caedan fought beside Edric and taught him the Vale cut.
When Emrys was born, Caedan promised the boy the same teaching, and kept the promise. Caedan's
mother keeps the line's measures and
records, and her rites are Vigil rites handed down with the watch. She is agreed but unnamed.

### Caedan Vale

**Look.** Lean man in his mid forties, dark hair, grey fencing doublet, one longsword, no magic. A
worn sword-school crest on the doublet.

**Who he is.** The last Vale to carry the sword, Draconic, and fights with no magic at all. His son
Tavin is fostered with the Rookes, because his father's road is no place for a child. Deck: Blade Legacy.
Drills stack until every cut lands heavier and the signature moves punish anyone who blinks. No
school means no crutch.

**Arc.** The Aspects stay human. He gets stiller each time and grey at the temples by Peerless,
and by the end the air around him is clear while spells break at a distance.

| Aspect | Look | Does |
|---|---|---|
| 1 Last Heir | Longsword in a textbook guard, chin up, exact, every angle correct | Digs a Sword card from the top 8 |
| 2 Unparried | Mid-lunge, point leading, no wasted motion, a ribbon of displaced air | Opening Strike that takes 2 stops |
| 3 Spellcutter | A cut finishing through a fading spell, the rival's casting hand pinned | Strike +5, hit shuts off rival Arts |
| 4 The Quiet Blade | Standing still, point steady, grey at the temples, spells breaking at a distance | Rival may not perform Arts |
| 5 Peerless | Older, sword lowered, walking forward unhurried, three ghost images of the next moves ahead | Draws 3 when attacking |

**Named cards.** Vale Cuts It Short, Vale's Heirloom Blade, Vale's Sword Draw.

---

## The Thornwald Grove

Druids whose rites regrow what is cut away. The grove wants a healer, and the one it wants is a
child who carved a set of seals, Verdant, name pending.

### Osric Thornwald

**Look.** Old man, long grey beard, ranger's leathers gone green with moss, a staff strung as a bow,
bark growing over one hand.

**Who he is.** Verdant, the only carrier of the old line on the Vigil side. He mends as he fights
and outlasts. He has taught outside the grove at least once, and Emrys Rooke is the known pupil.
Deck: Sevenfold Grove, which recycles spent spells and carves the seven seals while the rival tires.

**Arc.** The Vigil shows as the grove taking him, more tree and less man each Aspect, until he is a
standing tree with a bearded face.

| Aspect | Look | Does |
|---|---|---|
| 1 Greybeard | Sitting on his heels, staff across his knees, moss on the leathers, reading a torn page | Draws from the bottom of the discard when defending |
| 2 Overgrown | Bark up both forearms, leaves in the beard, staff mid-swing | Strike 6 wounds |
| 3 Deep-Rooted | Roots from his boots into the ground, a cut on his arm closing over in bark | Strike +6, hit draws from the discard bottom |
| 4 Heartwood | Torso gone to living wood, ribs of bark, leaves budding at the shoulders, staff planted | Strike, returns 3 discards under the deck |
| 5 Grovelord | A standing tree with a bearded face, arms become boughs, one hand still holding the staff | Strikes +5 |

---

## The Kingsguard and the unattached Vigil

Formally the Kingsguard, now called the Kingless Guard, which its older members resent. There were
two kings. They fell out, then they died, and the order that served both of them split down the
middle and went on training people. None of that is on screen and none of it gets explained. It
survives as a line in a relic description, a form somebody was taught, and a grudge between two
halves of a building.

The order teaches fighting and not magic, so it has no position on gates, seals or the Vigil and
the Pact, and its graduates turn up on every side of all three. Its people tend to field Freestyle
because that is what they were taught, not because the order requires it.

Two forms survive the split, names pending, and neither half will say the other lost.

- Form A, at contact: pressure, improvisation, work inside the rival's guard.
- Form B, at distance: guards, screens, suppressing fire, control of the ground between.

A famous member claims a form he was never taught and sells the name rather than the craft.

### Corin Thrace

**Look.** Spare, severe man in his forties, shaven head, a plain undyed wrap belted at the waist,
bare feet, a third scar across the brow where a mark was cut out, hands open and empty.

**Who he is.** An ascetic of no house who teaches a discipline rather than a school. He was the
Kingsguard's form at distance. He pilots no deck and has no personality card, so his forms turn up
in other people's hands all over the field. The scar says he once carried a mark and had it cut
out; nothing else about that is written.

**Named cards.** Corin's Practiced Guard, Corin Throws Smoke, Corin's Suppressing Shot, Corin's
Threefold Bolt, Corin's Conditioning (a shaven-headed ascetic seated on bare stone before dawn).

---

## The Collegium

Founded by a wright named Corven, whose name has come off the title. Its people build constructs,
charge them and repair them, and treat the leylines as a supply rather than a mystery. It fields
Storm because charging a construct and throwing an arc are the same craft. It builds constructs but
does not own the idea of them, and is stiff about this. Decks: Tempest Engine, Stormlock.

**What it wants** (2026-09-24). The Collegium sells the charge, so every construct it built is on
its leash. Its goal is to keep that monopoly on mana. That sets it against Ashmark, who burns the
leylines it draws from, against runaways like Cull, who feed themselves, and in the end against
the Heart, a source it cannot meter.

Working links for the relations network:

- Siphon and Tithe are both Collegium; Tithe works from Siphon's side.
- Cull is the bridge between the Collegium and Marrow's crew.
- Marrow is built partly from Collegium work; the name under her jaw may be a Collegium wright's.
- Mercy may be Collegium-built and let go. The Collegium repairs Sledge for pay.
- The Collegium may have supplied the broken company's front-rank constructs, which links it to
  Mourne and Kell. Pim already runs with it.
- The Collegium treats the leylines as a supply, which makes it prey to Ashmark. Ashmark burns
  the leylines and Siphon drinks them, so the two are rivals for the same feed.

### Siphon

**Look.** Humanoid construct of grey stone and copper wire, sigils cut into its chest, a smooth
faceless head, a glass core at the sternum.

**Who it is.** A warded construct that charges through ritual and releases all at once. In
Stormlock it is instead built to make swinging at it expensive. The hungriest of them: built to
hold more than it is ever given, and named for what it does. It is the Collegium's showpiece and
has outgrown the leash.

**Arc.** Dormant it is a statue, charged it hums, unbound it arcs.

| Aspect | Look | Does |
|---|---|---|
| 1 Dormant | Still as a statue, sigils dark, one hand raised palm out catching a fading bolt | Stops an Art, gains 3 Energy |
| 2 Charged | Sigils lit blue-white, a haze of static, a blade sliding off a ward of light | Gains 5 on entering Combat, shield stops the first Strike |
| 3 Unbound | Arcs between its limbs, the glass core bare and blazing, both hands throwing charge | Free Art, draws 2 |

### Tithe

**Look.** Smaller stone-and-copper construct, cruder sigils than Siphon's, a cracked shoulder never
repaired, a slot in its chest where cards go in. Ally art: stepping in front of the viewer,
shoulder first, a spark at the cracked joint.

**Who it is.** Works from the side and never asks to lead. It takes one, and it is paid. It feeds
on what Siphon leaves, keeps count of its cut, and the slot in its chest is where the mana goes. Strike
+2 wounds for a discard, usable out of control.

---

## The broken company and Marrow's crew

**The broken company** fought the two-kings war with constructs in its front rank, because
constructs are cheap and a destroyed one is not worth going back for. Three survivors are on the
board. Between a man who sold his name's worth and a man who never gave his, nothing of the
company is on record except Kell's gorget.

**Marrow's crew** picks the field over and keeps what is worth keeping. Deck: Scrap Requiem.

### Marrow

**Look.** A construct assembled out of several older ones, no two pieces matching: a war-frame
torso in scorched plate, one slender arm and one heavy, a face-plate of pale stone with the old
owner's name still stamped under the jaw.

**Who she is.** Not one construct and never was. She reads six moves ahead because some of her has
already been here. Nothing a spell fastens to stays fastened, and every made thing still standing
makes the rest of them hit harder. Every part she took came with its old owner's hunger, so she is
several appetites in one frame, and she salvages because the rest of her is still out there. She
wants the name under her jaw.

**Arc.** The Pact shows as more of her each Aspect: crude at Patchwork, past what any part was
built for by Overwrought, all of it at once at the end.

| Aspect | Look | Does |
|---|---|---|
| 1 Patchwork | Standing in a field of broken constructs, held together with strap and wire, the stamped name catching the light | Orders the top 6, draws |
| 2 Rebuilt | Properly seated joints and beaten-out plate, a blade skidding off her shoulder | No modifiers on Strikes against her |
| 3 Overwrought | Too many plates, too much arm, a seam glowing where it should not | Art 7 wounds, more with The Breaker's Yard |
| 4 Fury Amalgam | All of it moving at once, mid-swing, a dozen constructs in one shape | Strike +6, +5 wounds with the Yard, lowers rival Fervor 3 |

**Named card.** Marrow's Appraisal.

### Cull

**Look.** Elderly wright in a construct's body, a stooped brass frame over a spine of copper,
spectacles wired to the face-plate, a roll of instruments open at the hip. Ally art: selecting an
instrument from the roll without looking down, mild and unhurried.

**Who he is.** Collegium-trained, and put himself in a frame rather than keep building them for
other people. The Collegium does not claim him. Art, +1 wound per construct in play. He now lives
with the hunger he used to fill for others, rations himself on purpose, and is ashamed when he
slips. He wants made things out of Collegium hands, and often ends up standing with villains
because of it.

**Named card.** Cull's Absorbing Drill.

### Orvath Kell

**Look.** Gaunt man in a high-collared grey coat, shaven head, an officer's gorget he has not taken
off, both hands bare and raised. Ally art: palms raised over a fallen construct, the hex uncoiling
between them.

**Who he is.** Not a construct. The broken company's last officer, still wearing the gorget,
walking the same ground for his own reasons. Verdant, the same line as the Thornwald Grove, with
nothing else in common with it. Art 6 wounds.

### Gideon Mourne

**Look.** Proud man in his thirties, scarred brow, black brigandine with a broken crest still
riveted to the chest, a signet he has not sold, hands crackling.

**Who he is.** Draconic, and marked since the toll gate. Once a lord with the company and its
constructs at his disposal. The enemy king bought him and he betrayed the king who had retained him. Both
kings died, so nobody was left who owed him anything, and he was never paid. The title was taken
for the betrayal, which he has never denied. A new king would have reissued grants, but that meant
kneeling, so he went to the toll gate and traded the claim itself. No authority can restore him
now, including one that does not exist yet. He sold the regret with it, so the part of him that
knew the betrayal was wrong is gone and the rest of him is intact. He is not hollow the way Ashmark
is. He still signs himself Lord Mourne and nobody corrects him to his face. Sells the craft cheap
now, to whoever is going somewhere. Deck: Mind Siege, his own list for the first time.

**In the story** (2026-09-23). The outlaw viewpoint. Since his fall he hates everyone, and he is
spiteful and disgraced. He wants the Lodestone Heart to profit from it or to extort whoever he can.
The kings and the betrayal above are backstory, and the storylines do not explain them.

**Arc.** The brand spreads from the back of one hand to half his face, and the crest comes off.

| Aspect | Look | Does |
|---|---|---|
| 1 The Marked Lord | Square in a ruined hall, brigandine closed, a dark brand across one crackling hand, chin up | Stops a Strike, digs a Marked card |
| 2 Unflinching | Taking a blow on the shoulder without moving his feet, the brand up the forearm, jaw set | Base damage +2 dealt, -2 taken |
| 3 Unfettered | The broken crest torn off his chest and dropped, both hands lit, moving forward | Focused Art 6 wounds, twice for a Marked discard |
| 4 Unrepentant | The brand over half his face, arms wide, the hall going dark, no shame in it | Marked Strikes Focused and +3 |

**Second Aspect 1 card** (`personality_48`, fielded in Scrap Requiem): mid-cast, the broken crest turned to the viewer, light bleeding off
his knuckles. Art for 1 Energy.

**Named cards.** Seven across five decks, including Mourne's Jolting Arc.

### The Fortress

**Look.** No identity string yet. The only art is his cards: a guard that does not move, blade
after blade stopping on it; a stamped foot, a bolt of light earthing into the stone. He needs one
before a personality card can be briefed.

**Who he is.** The company's third survivor, Draconic, a heavy fighter whose whole method is
planting himself and not moving. He held ground the company had taken with nothing behind him,
which is why he wrote the two wards he is named for, one against what is swung at him and one
against what is cast. His real name is not recorded and he does not give it. No personality card;
Foundation / Fortified / Unbreachable is held as the Aspect chain for when he gets one.

**Named cards.** The Fortress' Iron Bulwark (ten decks), The Fortress' Arcane Aegis (eight decks).

---

## Unaffiliated constructs

Built by other people, by other methods, for other reasons than the Collegium's. One named card
each, no personality card, no deck. All field Freestyle for the Pact.

| Name | Look | Who |
|---|---|---|
| Sledge | Broad pit-fighting construct of riveted plate over a squat frame, one arm heavier than the other, dents never beaten out | Built to win bouts, and named by the crowd that bet on him. Fights for purses paid in mana; the crowd feeds him. Hired muscle for anyone |
| Mercy | Very tall construct of pale stone and worn brass, a broad blunt face, hands too big and too careful, no weapon anywhere on her | Made for work rather than war, and slow to agree to this. The friendly vampire: she will not take mana from anyone living, runs close to empty, and is the construct most likely to stand with the Vigil. The most dangerous of them if she ever breaks |
| Scorn | Lean construct of blackened iron, hands in its pockets, head tilted, a face cast with a permanent half-smile | Kin to Marrow, and bored by all of it. Has contempt for the born, feeds on duelists for sport and takes more than it needs |

---

## The Eidolons

Elder gods, one behind each set of seven seals, all still on their side of the wall. Flavoured by
vibe, not by what their seals do. Names coined and unchecked.

| Eidolon | Seals | Body | Temperament |
|---|---|---|---|
| Maruth, the Drowned Sun | Sun | A giant in gold plate twice a gate tower's height. The armour is full of seawater and there is no body inside. Light pours from the visor and every joint | Regal and warm, certain that everything it shines on belongs to it |
| Ysmere, the Moth Queen | Moth | A tall pale woman-shape in a mantle of living white moths, feathered antennae for a crown. Where the mantle brushes something, it fades | Soft-spoken, patient and tender, and always hungry |
| Korrag the Unfinished | Marble | A half-made titan. One side flawless marble muscle, the other scaffold, bare bone and gold wire. It carries the chisel that is carving it | Proud and restless. Wants to be completed and takes material wherever it finds it |
| Thessa, the Kind Hand (name pending) | Salt | A stooped surgeon's shape in a clean apron, taller than it should be, more arms than it should have, each ending in an instrument. A low steady lamp where the face belongs | Gentle, tireless and certain it is helping. It takes out whatever was aching without distinguishing the ache from the part of you doing the aching |

The demons are a different plane and a different mechanism; see Two elsewheres.

---

## Agreed and not yet named

| Role | Origin | Where |
|---|---|---|
| Keeper of the Vale measures, Caedan's mother | none | The Vale line |
| Close fighter, precise rather than strong | none | The Kingsguard, form at contact |
| The one who claims a form he was never taught | none | The Kingsguard, by his own account |
| Captain of the retained guard | none | The retained guard, a showy uniformed company kept by an unnamed larger power |
| The agent who lays the demon's mark | none | Works a toll gate |
| Highest office of the Vigil | none | The Vigil |
| The healer the grove wants, a child who carved a set of seals | Verdant | The Thornwald Grove |
| The humanity Ashmark traded away, returned as a person | undecided | none |

Three with no placement at all: a Pact-bound thing whose cards are contracts and severed leylines,
an outsider duelist from no country here, and a power large enough to retain a guard company.

## Open

- Names for the two Kingsguard forms.
- An identity string for The Fortress.
- What Corin Thrace's cut-out mark was, and who cut it.
- Whether the thing behind the contracts came through a gate once, which would mean a gate has
  opened before and the premise needs a line about it.
- The Collegium's working links to Marrow, Mercy, Sledge and the broken company (still provisional).
- How Quarr came to hold the Lodestone Heart, and where it came from. Left open on purpose
  (2026-09-24): Quarr stays quiet about it.
- A formal name for the two kings' war.

## Known gaps between this doc and the code

- Ten personalities carry a `bloodline`, set 2026-09-19. Only one card reads one: Dame Alder
  Rooke's first Aspect guards Draconic Allies. No card uses `only: {"bloodline"}` or
  `per_bloodline` yet, so for everyone else the line is a type-line fact and nothing more.
- `CAST_SCHOOL` in `tools/gen_roster.py` derives one school per character, so a character
  fielding a second school cannot be expressed there. Edric already does in the data.
- Torvan Hask's Draconic line is recorded here only; he has no personality card to carry it.
- The Lodestone Heart is one stone in the lore, but Tempest Engine (`storm_volley`) runs
  `lodestone_heart` in its precon and boss tier, and Quarr's Ironblood Onslaught runs
  `blank_mask`.
