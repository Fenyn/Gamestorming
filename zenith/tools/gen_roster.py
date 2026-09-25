"""Rebuilds docs/card_roster.csv and docs/card_roster.md from the shipped data.

Run tools/dump_cards.gd first (it writes cards.jsonl from the engine's own rules text), then:
    python tools/gen_roster.py <cards.jsonl>

Rules text, types, sections and deck usage come from the data. The source-card column is kept
from the existing CSV by id. Everything an image generator needs lives in this file: the shared
STYLE clause, a FRAMING clause per card type, a PALETTE clause per school (personality cards
have one colour of their own and take no school's), a fixed identity
string per character (CAST) and a short slot brief per card (ART). The generator assembles them
into the Prompt column: style, framing, palette, identity, brief.
"""
import collections
import csv
import glob
import json
import sys

CANVAS = {"Personality": "151x217", "Strike": "226x160", "Art": "226x160", "Seal": "226x160",
          "Combat": "150x150", "Non-Combat": "120x120", "Drill": "120x120", "Grounds": "120x120",
          "Mastery": "100x100", "Relic": "100x100"}

SCHOOL_SECTION = {"pyre": "Pyre (Ashmark and Rooke)", "steel": "Steel (Quarr)", "shade": "Shade (Draik and Salvage)",
                  "tide": "Tide (Rooke)", "storm": "Storm (Collegium)", "root": "Root (Thornwald)"}
SECTION_ORDER = ["Duelists", "Allies", "Relics and Masteries", "Pyre (Ashmark and Rooke)", "Steel (Quarr)",
                 "Shade (Draik and Salvage)", "Tide (Rooke)", "Storm (Collegium)", "Root (Thornwald)",
                 "Freestyle: Strikes and Arts", "Freestyle: Combat cards", "Freestyle: Non-Combats and Drills",
                 "Seals", "Grounds"]
SEAL_RENAMES = {"crown_seal": "sun_seal", "signet_seal": "moth_seal", "scepter_seal": "marble_seal"}

# One style clause for every card. Same words every time so the set reads as one hand.
STYLE = ("Painted fantasy card illustration, grounded and earnest, muted palette with one accent colour, "
         "one strong light source, readable silhouette, subject centred with room to crop. "
         "No text, no card frame, no modern objects.")

# Framing per card type: what the picture is, its shape, where the subject sits.
FRAMING = {
    "Personality": "Portrait, three-quarter view, waist up, looking past the camera, plain dark background.",
    "Strike": "Landscape action shot, the caster mid-strike at close range, motion blur on the blow, the rival implied at the frame edge.",
    "Art": "Landscape action shot, the spell mid-flight between the caster's hands and the frame edge, the rival implied, not shown.",
    "Seal": "Landscape close-up of a carved stone gate, one seal cut into it, torchlight from one side.",
    "Combat": "Square shot of one moment in a duel, tight on hands, blade or face, shallow depth.",
    "Non-Combat": "Square still life of an object or a rite, one item on stone or cloth, no figures.",
    "Drill": "Square still life of an object or a rite, one item on stone or cloth, no figures.",
    "Grounds": "Square landscape of a place of power, no figures, the leyline hinted by a line of pale light in the ground.",
    "Mastery": "Square emblem of a school of magic, one symbolic object on a dark field, no figures.",
    "Relic": "Square still life of a worn artefact on dark cloth, no figures.",
}

# Palette per school. Matches Palette.SCHOOL_COLORS in the client.
PALETTE = {
    "pyre": "Accent scarlet and orange, soot black, ember glow.",
    "steel": "Accent bright silver and gunmetal, black, cold grey light.",
    "shade": "Accent plum and orchid, deep black, thin cold highlights.",
    "tide": "Accent sea teal and deep blue, white foam, wet reflections.",
    "storm": "Accent electric indigo and white, charcoal, arcs of light.",
    "root": "Accent leaf green and moss, bark brown, dappled light.",
    "": "Accent warm bronze, leather brown, plain steel, candle light.",
}

# One colour for every card that carries a character's name, portraits and signature cards alike,
# tied to no school. It matches the gold the client gives the personality type in Palette.type_ui.
PERSONALITY_PALETTE = "Accent warm gold and pale ivory, deep umber shadow, one warm key light."

# Character identities: a fixed string reused verbatim on every card that shows the character,
# so a generator keeps them consistent. (name, school/side, deck, identity, note for the md)
# docs/cast.md copies every identity and note by hand; change it there when this changes.
CAST = [
    ("Bram Ashmark", "Pact", "Ashmark the Pyromancer",
     "Bram Ashmark: man in his early twenties, lean, soot-streaked pale skin, singed short dark hair, half-plate over a scorched gambeson, plain longsword with a heat shimmer.",
     "The Pact shows as light under the skin: faint at Starved, cracks by Gorging, streaming inward by Insatiable."),
    ("Halden Quarr", "Pact", "Quarr the Ironblood",
     "Halden Quarr: huge man in his forties, shaved head, brawler's build, bare arms, skin greying to iron in patches, black knuckles, raised welded scars, no armour.",
     "The Pact shows as iron spreading over more of him each Aspect."),
    ("Sable Draik", "Pact", "The Draik Company",
     "Sable Draik: woman in her thirties, brown skin, tattooed forearms, long dark coat, a bottle at her hip, sardonic half-smile.",
     "The Pact shows as shadow pooling around her and the light leaving her eyes."),
    ("Vesna Draik", "Pact", "The Draik Company", "Vesna Draik: wiry hooded woman, two knives, face half hidden.", "The ambusher."),
    ("Brann Draik", "Pact", "The Draik Company", "Brann Draik: broad bald man, leather vest, heavy hands, easy menace.", "The muscle."),
    ("Halvard Draik", "Pact", "The Draik Company", "Halvard Draik: tall man, red cloak, twin curved swords, duellist's poise.", "The swordsman."),
    ("Quill Draik", "Pact", "The Draik Company", "Quill Draik: thin young man, spectacles, ink-stained fingers, satchel of pages.", "The hexer proper."),
    ("Pim", "Pact", "The Draik Company", "Pim: small quick youth, patched clothes, sack over one shoulder.", "The scavenger, no surname."),
    ("Dame Alder Rooke", "Vigil", "The Rooke Coven",
     "Dame Alder Rooke: woman in her sixties, straight-backed, long grey hair, red gown over grey mail, round shield and longsword.",
     "The Vigil shows as water: climbing her, filling her, then she is the flood."),
    ("Wren Rooke", "Vigil", "The Rooke Coven", "Wren Rooke: teenage girl, red-brown hair, blue coat, satchel of loose pages.", "Youngest of the coven."),
    # The element is the printing's, not the man's: he carries water in his wife's line and fire in
    # his own, and each card's art takes it from that card's effects. See docs/cast_backlog.md.
    ("Sir Edric Rooke", "Vigil", "Edric the Ember Knight", "Sir Edric Rooke: knight in grey mail, plain longsword, open helm under one arm, weathered and unhurried.", "The knight. Fields Pyre in his own list and Tide beside the coven."),
    # The sword is his Freestyle self. In his own list he fields Steel, which is the magic turned
    # inward, so his Aspect art is the metal arriving and never the blade.
    ("Emrys Rooke", "Vigil", "Emrys the Eldest", "Emrys Rooke: serious young man, dark hair, grey fencing doublet over mail, bare forearms plated in fitted grey metal that grows across him each Aspect.", "The eldest son, a swordsman where his parents are casters, who fights his own duels with no sword at all."),
    ("Torvan Hask", "Pact", "(no deck yet)", "Torvan Hask: heavy-shouldered man in scarred riding leathers, long unbound hair, a hand axe at the belt, Edric's face ten years harder.", "Edric's elder brother, from the line Edric left."),
    ("Ansel Rooke", "Vigil", "The Rooke Coven", "Ansel Rooke: young man, broad shoulders, blue-grey gambeson, round shield.", "The younger son."),
    ("Tavin Vale", "Vigil", "The Rooke Coven", "Tavin Vale: slim young man, dark hair tied back, blue robe over a fencing doublet, hands open for casting.", "Caedan's son, fostered with the Rookes since he was small."),
    ("Ansel and Tavin, Back to Back", "Vigil", "The Rooke Coven", "Ansel Rooke and Tavin Vale standing back to back, shield and water between them.", "The Bond."),
    ("Caedan Vale", "Vigil", "Vale the Swordmaster",
     "Caedan Vale: lean man in his mid forties, dark hair, grey fencing doublet, one longsword, no magic.",
     "Aspects stay human: stiller each time, grey at the temples by Peerless."),
    ("Siphon", "Pact", "The Collegium",
     "Siphon: humanoid construct of grey stone and copper wire, sigils cut into its chest, a smooth faceless head, a glass core at the sternum.",
     "Dormant it is a statue, charged it hums, unbound it arcs."),
    ("Tithe", "Pact", "The Collegium",
     "Tithe: smaller stone-and-copper construct, cruder sigils than Siphon's, a cracked shoulder never repaired, a slot in its chest where cards go in.",
     "Works from the side and never asks to lead. It takes one, and it is paid."),
    # Constructs from outside the Collegium. One word each, naming what they are for.
    ("Sledge", "Pact", "(unaffiliated construct)",
     "Sledge: broad pit-fighting construct of riveted plate over a squat frame, one arm heavier than the other, dents never beaten out.",
     "Built to win bouts, and named by the crowd that bet on him."),
    ("Mercy", "Pact", "(unaffiliated construct)",
     "Mercy: very tall construct of pale stone and worn brass, a broad blunt face, hands too big and too careful, no weapon anywhere on it.",
     "Made for work rather than war, and slow to agree to this."),
    ("Scorn", "Pact", "(unaffiliated construct)",
     "Scorn: lean construct of blackened iron, hands in its pockets, head tilted, a face cast with a permanent half-smile.",
     "Kin to Marrow, and bored by all of it."),
    ("Marrow", "Pact", "Marrow the Amalgam",
     "Marrow: a construct assembled out of several older ones, no two pieces matching: a war-frame torso in scorched plate, one slender arm and one heavy, a face-plate of pale stone with the old owner's name still stamped under the jaw.",
     "Not one construct and never was. The Pact shows as more of her each Aspect: crude at Patchwork, past what any part was built for by Overwrought, all of it at once at the end."),
    ("Cull", "Pact", "Marrow the Amalgam",
     "Cull: elderly wright in a construct's body, a stooped brass frame over a spine of copper, spectacles wired to the face-plate, a roll of instruments open at the hip.",
     "Collegium-trained, and put himself in a frame rather than keep building them for other people. They do not claim him."),
    ("Orvath Kell", "Pact", "Marrow the Amalgam",
     "Orvath Kell: gaunt man in a high-collared grey coat, shaven head, an officer's gorget he has not taken off, both hands bare and raised.",
     "Not a construct. Last officer of a company that fielded them and left them where they fell, walking the same ground for his own reasons."),
    ("Gideon Mourne", "Pact", "Marrow the Amalgam",
     "Gideon Mourne: proud man in his thirties, scarred brow, black brigandine with a broken crest still riveted to the chest, a signet he has not sold, hands crackling.",
     "Not a construct. A lord who was stripped of it, still signs himself Lord Mourne, and nobody corrects him to his face. Sells the craft cheap now, to whoever is going somewhere."),
    ("Osric Thornwald", "Vigil", "The Thornwald Grove",
     "Osric Thornwald: old man, long grey beard, ranger's leathers gone green with moss, a staff strung as a bow, bark growing over one hand.",
     "The Vigil shows as the grove taking him: more tree and less man each Aspect."),
    ("Corin Thrace", "Vigil", "(unaffiliated)",
     "Corin Thrace: spare, severe man in his forties, shaven head, a plain undyed wrap belted at the waist, bare feet, a third scar across the brow where a mark was cut out, hands open and empty.",
     "Pilots no deck of his own. An ascetic who teaches a discipline rather than a school, so his forms turn up in other people's hands all over the field."),
]
IDENTITY = {c[0]: c[3] for c in CAST}
SEAL_PALETTE = {
    "sun": "Accent old gold, a thin line of green seawater, warm torchlight.",
    "moth": "Accent bone white and silver, pale dust, cold torchlight.",
    "marble": "Accent veined grey marble, raw scaffold wood, neutral torchlight.",
    "salt": "Accent salt white and dull steel, damp grey stone, a low clean light.",
}

# Which named character each character-bound card shows. Cards not listed take the character
# from their data (`character`) or none.
SHOWS = {
    "personality_01": "Bram Ashmark", "personality_13": "Halden Quarr", "personality_10": "Sable Draik",
    "personality_04": "Dame Alder Rooke", "personality_21": "Osric Thornwald", "personality_07": "Siphon",
    "personality_16": "Caedan Vale",
    "personality_40": "Vesna Draik", "personality_41": "Brann Draik", "personality_43": "Halvard Draik",
    "personality_44": "Pim", "personality_42": "Quill Draik", "personality_45": "Tithe",
    "personality_49": "Wren Rooke", "personality_50": "Sir Edric Rooke", "personality_52": "Ansel Rooke",
    "personality_51": "Tavin Vale", "personality_54": "Ansel and Tavin, Back to Back",
    "signature_strike_26": "Corin Thrace", "signature_art_13": "Corin Thrace", "signature_art_12": "Corin Thrace",
    "signature_art_08": "Corin Thrace", "signature_noncombat_02": "Corin Thrace",
    "signature_art_06": "Sable Draik", "signature_art_05": "Sable Draik", "signature_art_10": "Sable Draik",
    "signature_strike_16": "Brann Draik", "signature_strike_17": "Halvard Draik", "signature_strike_18": "Vesna Draik",
    "signature_strike_28": "Halden Quarr", "signature_strike_27": "Halden Quarr", "signature_strike_25": "Halden Quarr",
    "signature_combat_05": "Dame Alder Rooke", "signature_combat_06": "Sir Edric Rooke",
    "signature_strike_19": "Bram Ashmark", "signature_noncombat_04": "Bram Ashmark", "signature_strike_08": "Bram Ashmark",
    "signature_combat_02": "Bram Ashmark",
    "signature_strike_15": "Caedan Vale", "signature_strike_14": "Caedan Vale", "signature_strike_21": "Caedan Vale",
    "signature_strike_13": "Caedan Vale", "signature_noncombat_03": "Caedan Vale", "signature_noncombat_06": "Caedan Vale",
    "signature_art_11": "Sledge", "signature_strike_24": "Siphon", "signature_noncombat_01": "Mercy", "signature_combat_07": "Scorn",
    "personality_26": "Marrow", "signature_combat_09": "Marrow", "signature_combat_04": "Marrow",
    "signature_strike_03": "Gideon Mourne", "signature_drill_03": "Gideon Mourne", "signature_art_07": "Gideon Mourne",
    "signature_noncombat_05": "Gideon Mourne", "signature_strike_20": "Gideon Mourne", "signature_noncombat_09": "Gideon Mourne",
    "signature_noncombat_08": "Gideon Mourne",
    "personality_46": "Cull", "personality_47": "Orvath Kell", "personality_48": "Gideon Mourne",
    "signature_art_02": "Bram Ashmark", "signature_art_03": "Siphon", "signature_drill_02": "Cull",
    "signature_art_04": "Sir Edric Rooke", "signature_strike_23": "Sir Edric Rooke",
    "signature_noncombat_07": "Sir Edric Rooke", "signature_drill_05": "Sir Edric Rooke",
    "personality_30": "Sir Edric Rooke", "signature_combat_01": "Sir Edric Rooke",
    "signature_strike_05": "Sir Edric Rooke", "signature_strike_06": "Sir Edric Rooke",
    "personality_53": "Dame Alder Rooke", "signature_strike_07": "Torvan Hask",
    "signature_strike_09": "Emrys Rooke", "signature_strike_22": "Emrys Rooke", "signature_strike_01": "Emrys Rooke",
    "signature_strike_10": "Emrys Rooke", "signature_strike_11": "Emrys Rooke", "signature_strike_12": "Emrys Rooke",
    "signature_drill_04": "Emrys Rooke", "signature_drill_01": "Emrys Rooke",
    "personality_35": "Emrys Rooke",
}

# Slot brief per card: subject, action, two or three concrete details, mood. Short, visual, no rules.
ART = {
    # Duelists
    "personality_02": "Leeching. Flame licking off his shoulders, cracks of orange light along his forearms, sword raised overhead, coals glowing in the steel.",
    "personality_03": "Unstoppable. Fully wreathed in fire, face barely visible in it, caught mid-charge, sparks trailing.",
    "personality_13": "The Grinder. Brawler's crouch, fists up, black knuckles, breath steaming, hungry look.",
    "personality_14": "Tempered. Chest and shoulders greyed to iron, veins like solder, one foot on a discarded page.",
    "personality_15": "Ironheart. Chest plated in living iron, a dull red heart glowing through it, both fists cocked.",
    "personality_10": "Captain. Coat open, boot on a crate, a torn company flag behind her, crew silhouettes at the edges, amused.",
    "personality_11": "Shrouded. Shadow pooled at her feet and climbing her coat, half her face in darkness, one hand out.",
    "personality_12": "Lightless. Eyes fully black, the light in the frame dying toward her, shadow streaming off her arms.",
    "personality_30": "The Hero. Standing easy, sword point down, hand raised to hold a line back, no fire on him yet.",
    "personality_31": "The Stranger. Helm off, looking at his own hands, a thin orange seam of heat along one forearm, the Hask axe on the ground behind him.",
    "personality_32": "The Realm's Hero. Mid-stride into a burning street, coals under his boots, shield arm shielding somebody out of frame.",
    "personality_33": "Kindled Through. Fire running up the blade and along the mail seams, teeth set, one fist cocked.",
    "personality_34": "The All Powerful. Wreathed to the shoulders, the sword a bar of white heat, everything around him going to ash.",
    "personality_35": "The Eldest. Empty-handed and still, sleeves pushed up, bare forearms, borrowed stances in the set of his feet, no metal anywhere.",
    "personality_36": "First Plate. Fitted grey metal closed over both forearms like bracers he grew, flexing one hand to test it, surprised at it.",
    "personality_37": "Edged. The forearm plate drawn out into a working edge along the ulna, held low and ready, one clean cut in the air behind it.",
    "personality_38": "Shaped. Metal running to the shoulders and moving where he looks, a plate sliding across his chest mid-step, hands open and unhurried.",
    "personality_39": "Scaleclad. Plated head to boot in overlapping grey scale, the pattern finally reading as a dragon's, one gauntlet cocked, calm.",
    "personality_04": "Matriarch. Shield up, sword low, three hooded coven figures behind her, stern.",
    "personality_05": "Rising Water. Water climbing her mail to the waist, eyes gone sea-glass green, a knight at her shoulder.",
    "personality_06": "The Flood. A wave rising off her shoulders, face calm as deep water, the ground at her feet awash.",
    "personality_21": "Greybeard. Sitting on his heels, staff across his knees, moss on the leathers, reading a torn page.",
    "personality_22": "Overgrown. Bark up both forearms, leaves in the beard, staff mid-swing, green pushing through grey.",
    "personality_23": "Deep-Rooted. Roots running from his boots into the ground, a staff blow landing, a cut on his arm closing over in bark.",
    "personality_24": "Heartwood. Torso gone to living wood, ribs of bark, leaves budding at the shoulders, staff planted.",
    "personality_25": "Grovelord. A standing tree with a bearded face, arms become boughs, one hand still holding the staff.",
    "personality_07": "Dormant. Standing still as a statue, sigils dark, one hand raised palm out catching a fading bolt.",
    "personality_08": "Charged. Sigils lit blue-white, a haze of static around it, a blade sliding off a ward of light.",
    "personality_09": "Unbound. Arcs jumping between its limbs, the glass core bare and blazing, both hands throwing charge.",
    "personality_16": "Last Heir. Longsword in a textbook guard, chin up, exact, every angle correct, a worn sword-school crest on the doublet.",
    "personality_17": "Unparried. Mid-lunge, the point leading, no wasted motion, a ribbon of displaced air.",
    "personality_18": "Spellcutter. A cut finishing through a fading spell, the rival's hand at the frame edge pinned.",
    "personality_19": "The Quiet Blade. Standing still, point steady, grey at the temples, the air around him clear while spells break at a distance.",
    "personality_20": "Peerless. Older, sword lowered, walking forward unhurried, three faint ghost images of the next moves ahead of him.",
    "personality_26": "Patchwork. Standing square in a field of broken constructs, held together with strap and wire, the stamped name under her jaw catching the light.",
    "personality_27": "Rebuilt. Properly seated joints and beaten-out plate, a struck blade skidding off her shoulder without leaving a mark on it.",
    "personality_28": "Overwrought. Built past what any part was for: too many plates, too much arm, a seam glowing where it should not.",
    "personality_29": "Fury Amalgam. All of it moving at once, mid-swing, pieces of a dozen constructs in one shape and none of them idle.",
    # Allies
    "personality_40": "Coming in from the frame edge, knives out, hood up.",
    "personality_41": "Cracking his knuckles, leaning over the viewer.",
    "personality_43": "Both swords drawn in a crossed guard, cloak lifting.",
    "personality_44": "Crouched over a pile of torn pages, holding one up to the light.",
    "personality_42": "Reading a hex off a page, one finger tracing it, purple ink glowing.",
    "personality_45": "Stepping in front of the viewer, shoulder first, a spark at the cracked joint.",
    "personality_49": "Gathering loose pages into her satchel, some floating back to her.",
    "personality_50": "Sword raised, a focused jet of water along the blade.",
    "personality_52": "Shield braced, water refilling a cracked flask at his hip.",
    "personality_53": "Stepping in front of a blow meant for someone else, shield up, no water raised at all, furious.",
    "personality_51": "Hands open, a globe of water between them, pages settling into a deck at his feet.",
    "personality_54": "Back to back, water curling around the shield, both looking outward.",
    "personality_46": "Selecting an instrument from the open roll without looking down, mild and unhurried.",
    "personality_47": "Both palms raised over a fallen construct, the hex uncoiling between them, the gorget still buckled on.",
    "personality_48": "Mid-cast, the broken crest on his chest turned to the viewer, light bleeding off his knuckles.",
    # Relics and Masteries
    "relic_01": "A featureless white porcelain mask, no eye holes, on black cloth.",
    "relic_02": "A heavy iron ring pressed with someone else's mark, a wax seal beside it.",
    "relic_03": "A dark magnetic stone on a chain, iron filings drawn to it, on grey cloth.",
    "freestyle_mastery_01": "A worn leather training manual, spine cracked, a single steel pin holding a page.",
    "pyre_mastery_01": "A brazier of coals with a single tongue of flame, a burnt page curling in it.",
    "pyre_mastery_02": "A single ember lifted off a spent pile on a knife point, the pile going cold behind it.",
    "steel_mastery_01": "A clenched iron fist with a single card turned face up beneath it.",
    "shade_mastery_01": "A hand of cards seen through a black veil, one card rotting at the corner.",
    "tide_mastery_01": "A tide line on stone, water drawing back, a single coin left behind.",
    "storm_mastery_01": "A copper coil with a spark jumping across the gap.",
    "root_mastery_01": "A page half buried in soil with a root growing through it, a green shoot rising.",
    # Pyre
    "pyre_art_02": "Grey ash raining down on a burning circle of runes, embers in the fall.",
    "pyre_strike_03": "A door thrown open, fire rushing out and swallowing a bolt of light.",
    "pyre_strike_07": "A running figure wreathed in flame, sword forward, cutting through a raised guard.",
    "pyre_strike_01": "A guard of drifting cinders catching a blade, the edge glowing where it touches.",
    "pyre_strike_04": "A fist of fire brought down from above, a trail of sparks behind it.",
    "pyre_strike_06": "A whirl of flame across a stone floor, rune circles and a hooded figure caught in it.",
    "pyre_strike_11": "A whip of flame at full extension, coiling back on itself.",
    "pyre_strike_10": "A room igniting all at once, a dropped card at the centre.",
    "pyre_strike_08": "A figure exhaling a gout of heat, the air rippling.",
    "pyre_art_01": "A rune circle wrapped in flame, burning down to nothing.",
    "pyre_strike_12": "A small sharp fire lit at the tip of a blade, lighting the whole edge.",
    "pyre_strike_13": "Coals stirred back to flame, a burnt card lifting from the ash whole.",
    "pyre_strike_14": "A blow caught on a bracer and the impact blown back out as a gout of flame.",
    "pyre_strike_15": "A wall of ash thrown up between two fighters, old burnt pages whirling away in it.",
    "pyre_art_03": "A low banked hearth flaring up as a spell breaks on it, a figure straightening in the light.",
    "pyre_strike_16": "Air going over all at once at a single point, the fighter already through it.",
    "pyre_strike_17": "A rising column of heat carrying a fighter off the ground mid-strike.",
    "pyre_strike_18": "A plain punch landing, embers thrown off the knuckles on impact.",
    "freestyle_combat_02": "Both feet set, weight low, a blow turning aside off a raised guard, no magic anywhere.",
    "signature_combat_01": "A blade stopped a hand's width short, both fighters' eyes meeting over it.",
    "signature_strike_05": "The first blow of a long fight, thrown flat and hard, a burnt card lifting out of the ash behind him.",
    "signature_strike_06": "A practice yard at dawn, a post splintering under a strike, breath fogging.",
    "signature_strike_07": "A flying kick landing full in the chest, the ground cracking away under the man taking it.",
    "pyre_strike_05": "A tongue of fire scouring a rune circle off a stone floor.",
    "pyre_strike_02": "A raised forearm glowing red, a blade stopping against it and smoking.",
    "pyre_strike_09": "A fist closing on a small flame, the smoke of it.",
    "pyre_combat_01": "Two flames from one motion, a sword and an open hand both lit.",
    # Steel
    "steel_strike_06": "A shoulder charge, iron skin, the impact ringing.",
    "steel_strike_16": "A plated fist landing square, the whole arm grey metal to the shoulder, the air split behind it.",
    "steel_strike_17": "Four drawn-out scale edges raking across a guard, three bright scores left in it.",
    "steel_strike_18": "A boot coming down from above, the toes grown into hooked grey talons, the ground cratering.",
    "steel_strike_19": "A head turning aside by an inch, the blow sliding off a cheek of grey plate.",
    "steel_strike_20": "A plated heel driven down onto a fallen guard, weight fully committed.",
    "steel_strike_21": "A back kick turned out of nowhere, the heel plated, the twist carrying everything.",
    "steel_strike_22": "A low charge under a spell, shoulder first, both arms closing.",
    "steel_art_05": "A bolt of light going into a plated chest and not coming out, the metal dulling where it landed.",
    "steel_art_06": "Plates closing over a raised forearm and across the body, a spell breaking apart on them.",
    "steel_drill_01": "A set of graded iron weights on a worn bench, one lifted clear of its slot.",
    "steel_art_01": "Iron forearms crossed, feet set, a blow absorbed.",
    "steel_strike_12": "Head down, charging, a shockwave off the brow.",
    "steel_strike_15": "A grapple bringing a heavy body down on a rune circle, the stone cracking.",
    "steel_strike_08": "A hit landing on the chest, the air knocked out in a visible cloud.",
    "steel_strike_04": "An iron forearm turning a blade, sparks.",
    "steel_strike_14": "Both fists together coming down, the ground cracking under the target.",
    "steel_strike_11": "An iron forehead meeting a rune circle, the runes shattering.",
    "steel_strike_02": "A wide stance, unmoved, a blade bent against an iron shoulder.",
    "steel_strike_13": "A straight punch, the fist solid iron, mid-flight.",
    "steel_strike_09": "A short jab, the knuckles iron, the rival's guard buckling.",
    "steel_strike_05": "A rising knee, iron kneecap, a seal glowing on the gate behind.",
    "steel_strike_03": "Skin gone to iron plate across the chest, a blade skating off.",
    "steel_strike_10": "A downward slam with the whole arm, the shockwave sending cards skidding.",
    "steel_art_03": "Old scars knitted into iron plates, a fist raised.",
    "steel_art_02": "A pulse of force from an open palm, dust and pages blown back.",
    "steel_strike_01": "A crack of iron on a helm, the helm splitting.",
    "steel_combat_01": "Two heavy figures a pace apart, neither moving, dust settling.",
    "steel_strike_07": "A fist glowing orange at the knuckles, steam rising.",
    "steel_art_04": "Three pulses of force from the chest, rings in the air.",
    "signature_strike_28": "An overhand hammer-fist coming down, a rune circle breaking under it.",
    "signature_strike_27": "Roaring, chest out, the shout visible as a shockwave.",
    "signature_strike_25": "Taking a blow to the shoulder and rolling it off, unbothered.",
    # Shade
    "shade_drill_02": "A row of cards laid face down on iron, one hand resting flat across them.",
    "shade_art_04": "A flat hand cutting through a bolt of light, the bolt splitting around it.",
    "shade_strike_07": "Shadow drawn in from the whole frame toward one closed fist.",
    "shade_art_03": "An open palm driven forward, the air torn in a ring around it.",
    "shade_art_05": "A web of black filament strung across the frame, a bolt tangled and dying in it.",
    "shade_art_06": "Both hands drawn back to the hip, dark light gathering between them, eyes fixed on one point.",
    "shade_art_07": "A bolt of dark light leaving the palm and a thread of stolen light running back up the arm.",
    "shade_drill_01": "A felled figure and a hand already reaching past them for a card.",
    "shade_strike_06": "A short shove of dark force at close range, the rival's guard thrown wide.",
    "shade_strike_03": "A hand of shadow closing on a throat, a card slipping from the victim's fingers.",
    "shade_strike_02": "A veil of shadow thrown up, a card drawn back through it.",
    "shade_art_02": "Dark threads reaching into a figure's temples, two cards blackening in their hand.",
    "shade_strike_05": "A figure held rigid in a grip of shadow, eyes open, dreaming badly.",
    "shade_strike_04": "A shadow slipping a card out of a held hand and back into the deck, a new one pushed into its place.",
    "shade_art_01": "A whip of shadow catching a blade mid-swing.",
    "shade_strike_01": "A rune circle and a card unpicking into black thread.",
    "shade_combat_01": "A curtain of shadow drawn across the frame, a blade lost in it.",
    "signature_art_06": "Her hands black to the elbow, six knives of shadow flying from them.",
    "signature_art_05": "Holding a ledger open, two columns of coins swept level, shadowed crew standing behind her.",
    "signature_art_10": "A hex settling like ink on a figure's shoulders, staining down.",
    "signature_strike_16": "One hand tearing a rune circle in half, the other holding a stolen seal.",
    "signature_strike_17": "Two cuts in one motion, one turning a blade, the other taking a card from a hand.",
    "signature_strike_18": "Dropping from above with both knives, hooded figures below frozen mid-step.",
    # Tide
    "tide_art_01": "A wall of standing water, a bolt of light breaking on it.",
    "tide_art_08": "Two currents meeting head-on, a rune circle swept away in the join.",
    "tide_art_06": "A hand reaching down into dark water and closing on a card.",
    "tide_strike_03": "A rune circle pulled under a rising pool.",
    "tide_strike_01": "Water drawing back from a figure's feet, taking a glow with it.",
    "tide_art_07": "The tide at its mark on a stone gate, the ground changing under it.",
    "tide_art_05": "Clear water rising from cracked stone, a figure standing up out of it.",
    "tide_art_02": "A surge of water hitting and parrying a blade at once.",
    "tide_art_04": "An open channel of water pouring from two hands, no end to it.",
    "tide_art_09": "Two breakers crashing in from either side of the frame.",
    "tide_art_03": "Two swells rising one behind the other.",
    "tide_strike_02": "A strike from below out of water, a bolt dragged down with it.",
    "signature_combat_05": "Arms raised, the coven's water released all at once across a stone floor, rune circles washing away.",
    "signature_combat_06": "Kneeling, sword offered hilt first to a gauntleted hand, water running off the blade.",
    # Storm
    "storm_art_06": "A single bright arc from a fingertip to the frame edge.",
    "storm_mastery_02": "A squall line rolling in over flat ground, rain already falling in a wall.",
    "storm_art_07": "A whip of white light cracking out level with the ground.",
    "storm_art_08": "An open palm held out, the air in front of it going white.",
    "storm_art_09": "An iron rod driven into wet ground, a bolt running harmlessly down it.",
    "storm_art_10": "A narrow beam punching through the rain, the target already turning away.",
    "storm_art_03": "Lightning forking from one target to the next.",
    "storm_art_01": "A ward of static around a figure, a bolt dissolving on it.",
    "storm_strike_01": "A storm brought down bodily onto a stone floor, rune circles blown away.",
    "storm_strike_02": "A punch with too much charge in it, arcs bleeding off the knuckles.",
    "storm_strike_03": "A strike, then lightning drawn back into an open hand.",
    "storm_art_04": "A bolt from above striking a rune circle.",
    "storm_art_02": "A field of static, a blade stopping in it, hair standing up.",
    "storm_art_05": "A thunderhead building over a duelling floor, rune circles lifting in the wind.",
    "signature_art_11": "Squaring up in a fighting pit, weight set, the heavier arm cocked back.",
    "signature_strike_24": "Stepping aside mechanically, a blade passing where it stood.",
    "signature_noncombat_01": "A huge blunt face looking down, almost apologetic, one big hand raised and a blade stopping against it.",
    # Root
    "root_combat_01": "A volley of thorns from a swung staff.",
    "root_strike_01": "A boar's rush through undergrowth, leaves flying.",
    "root_art_03": "A blast of splintering wood, a stump exploding outward.",
    "root_art_04": "Old growth wood thrown as a spear, marble seals glowing on a gate behind.",
    "root_art_02": "Cupped bark hands catching rain and a bolt of light with it.",
    "root_art_01": "Barkskin on a forearm turning a bolt aside.",
    "root_combat_02": "A still moment in a grove, a single page rising from the leaf litter.",
    "root_strike_02": "Feet rooted into stone, a blade stopping against a staff.",
    "root_drill_01": "A tracker's kneeling read of sign, five stones set in a row.",
    # Freestyle: Strikes and Arts
    "signature_strike_09": "A whole-body strike, feet leaving the ground, everything committed.",
    "freestyle_art_08": "A flare thrown in a figure's face, hands coming up too late.",
    "freestyle_art_06": "A volley of thrown knives from an unseen line of hands.",
    "freestyle_strike_02": "A wide two-handed cut sweeping a row of rune circles off a floor.",
    "signature_art_04": "A cut with the whole body behind it, the follow-through finishing at the floor.",
    "freestyle_art_01": "A bolt of light dying mid-air in a still room, dust hanging.",
    "signature_art_09": "A figure shouting into the frame, a shockwave of sound, a hand raised.",
    "signature_art_01": "A stamped foot, a bolt of light earthing into the stone.",
    "freestyle_strike_03": "A reckless dive into a raised guard, the guard breaking.",
    "signature_strike_22": "A block with the crossguard, sparks, a card lifting from the floor.",
    "freestyle_art_05": "Knives thrown from every direction at once.",
    "freestyle_strike_05": "A last desperate guard, sword and empty hand both up.",
    "freestyle_art_03": "A bolt of light thrown in a high arc over a raised guard.",
    "signature_strike_01": "A strike thrown with a snarl, nothing held back, no exit in the frame.",
    "freestyle_strike_01": "A backhand thrown without looking, a page fluttering back into a hand.",
    "freestyle_art_04": "A figure reaching past their own light, the halo behind them tearing.",
    "signature_strike_03": "Feet planted wide, a blade stopped, another blade stopping behind it.",
    "signature_strike_26": "A drilled guard, a shield brace lifting from the floor as it holds.",
    "signature_strike_23": "A step back out of reach, the blade passing a hand's width off.",
    "signature_strike_20": "A lunge past the point of balance, landing anyway.",
    "signature_strike_02": "A strike thrown mid-flurry, three more already in motion.",
    "signature_art_03": "A gloved hand cutting the threads of a rune circle.",
    "signature_art_02": "A bolt of light hitting a pile of cards, the ash blowing away.",
    "signature_strike_19": "Swinging through a pile of burnt pages, ash scattering, embers taken into his blade.",
    "freestyle_combat_19": "A blade prying a seal off a stone gate.",
    "freestyle_strike_06": "A block, then a deep breath, a flask refilling.",
    "freestyle_art_07": "A bolt of light hitting a figure square, their halo stripped away.",
    "signature_art_13": "A bolt landing in smoke, two figures losing each other in it.",
    "signature_art_12": "A bolt pinning a casting hand to a wall of light.",
    "signature_strike_10": "A flourish of the sword, the arc leaving a bright trail.",
    "freestyle_strike_04": "A long lunge, the point at a figure's chest, their light dimming.",
    "signature_strike_11": "A low sweeping cut through a line of standing figures.",
    "signature_strike_12": "A thrust through two rune circles at once.",
    "signature_art_07": "An arc of light thrown low, a rival's blade arm dropping out of the guard.",
    "signature_art_08": "One bolt already landed, a second in flight, a third still forming at the hand.",
    "freestyle_art_02": "A bolt of light flying dead straight through a guard.",
    "signature_strike_04": "A guard that does not move, blade after blade stopping on it.",
    "signature_strike_15": "The pommel driven into a face after a parry, the rival reeling.",
    "signature_strike_14": "A quick side-step and cut, a signature page lifting from the floor.",
    "signature_strike_21": "A parry turning into the same cut thrown back.",
    "signature_strike_13": "A draw cut from the scabbard, the blade catching light.",
    "signature_strike_08": "A wall of fire raised with one hand, a blade and a bolt both stopping in it.",
    # Freestyle: Combat cards
    "signature_combat_07": "Hands in pockets, head tilted, every rune circle on the floor cracking and going dark behind him.",
    "freestyle_combat_11": "A line of allies closing shoulder to shoulder behind a duelist.",
    "signature_combat_04": "A gloved hand fanning another's cards, one pulled out.",
    "signature_combat_03": "A hand catching a wrist mid-gesture.",
    "freestyle_combat_17": "Every figure but two fading from a duelling floor.",
    "signature_combat_09": "Two made figures stepping out of the dark at once, already at full light.",
    "freestyle_noncombat_01": "A floor of chalked rites scuffed through in one long drag.",
    "freestyle_combat_13": "A purse of coins handed over, a sellsword stepping into the frame.",
    "freestyle_combat_16": "A close eye reading the top card of a deck.",
    "freestyle_combat_07": "A sword point held level at a rival's chest, keeping them at a distance.",
    "freestyle_combat_09": "A figure on one knee, light gone out of them, a pile of cards burning beside them.",
    "freestyle_combat_14": "Two duelists both blazing with light, the ground between them cracking.",
    "freestyle_combat_10": "A card slipped from a sleeve.",
    "freestyle_combat_18": "Two blades lowered, a hand raised palm out.",
    "signature_combat_08": "A figure reading a card by candlelight.",
    "freestyle_combat_12": "A raised fist and a shout, an ally running in from the frame edge.",
    "freestyle_combat_15": "A figure dragged upward by their own light, feet leaving the ground, halo tearing.",
    "freestyle_combat_05": "A figure sitting on stone catching their breath, two cards lifting from the floor.",
    "freestyle_combat_04": "A line of pale light in the ground cut through with a blade, the far end going dark.",
    "freestyle_combat_01": "A duelling floor with every blade and bolt stopped mid-air.",
    "freestyle_combat_03": "A contract held up, one clause struck through.",
    "freestyle_combat_08": "A shout, an ally arriving, seals falling from a stone gate.",
    "freestyle_combat_06": "A single eye watching over the top of a fan of cards.",
    "signature_combat_02": "Standing in the middle of the frame with fire around him, unmoved, a blade stopped on his forearm.",
    "signature_drill_05": "A hand resting flat over a carved seal, protective.",
    # Freestyle: Non-Combats and Drills
    "signature_drill_02": "A sponge-like stone drinking a bolt of light, two pages burning beside it.",
    "freestyle_noncombat_08": "Two cards laid face to face under a third, a cord tied round them.",
    "freestyle_drill_01": "A tankard slammed on a table, coins jumping.",
    "signature_noncombat_09": "A chisel and mallet on a stone gate, a fresh seal cut.",
    "freestyle_noncombat_03": "A still bowl of water with one card floating in it.",
    "freestyle_drill_04": "A card pinned to a board with a dagger.",
    "freestyle_noncombat_10": "A seal on a stone gate chiselled out, dust falling.",
    "freestyle_noncombat_17": "A crack in a stone gate, a pale light and a shape on the far side.",
    "signature_noncombat_07": "A chisel's first cut into a blank stone gate.",
    "freestyle_noncombat_04": "A card seen in a bowl of dark water before it is drawn.",
    "freestyle_noncombat_05": "A worn practice floor under a ring of burnt-down candles, twelve months of scuffs in one night's dust.",
    "freestyle_noncombat_13": "A stone gate with three cards resting on its threshold, light from the crack.",
    "signature_drill_06": "A hand placing a card on a stone floor, a shield propped behind.",
    "signature_noncombat_06": "An old longsword with a worn sword-school crest on the pommel, laid on a doublet.",
    "freestyle_drill_03": "A single sword on an otherwise bare stone floor.",
    "freestyle_noncombat_06": "A card found under a loose flagstone.",
    "signature_noncombat_02": "A shaven-headed ascetic seated on bare stone before dawn, breath steady, eyes shut.",
    "freestyle_noncombat_07": "A struck face turning back into the blow, teeth bared.",
    "freestyle_drill_05": "A door barred with a sword through the handles.",
    "freestyle_noncombat_09": "A gauntlet thrown down on stone, a card beside it.",
    "signature_drill_03": "A card snatched from the bottom of a pile mid-fall.",
    "freestyle_noncombat_02": "A page of sword diagrams, one figure circled.",
    "freestyle_drill_02": "A card torn in half, two fresh ones beneath it.",
    "freestyle_noncombat_15": "A seal palmed in a gloved hand.",
    "freestyle_noncombat_12": "A rune circle scuffed out with a boot.",
    "signature_noncombat_08": "A hand on a chisel, steady, a seal half cut.",
    "signature_noncombat_04": "Crouched at a brazier, stirring coals, burnt cards lifting whole from the fire.",
    "signature_drill_01": "A page of sword drills pinned to a post, a practice blade below.",
    "signature_noncombat_03": "Reading a family sword manual, two pages glowing.",
    "freestyle_noncombat_14": "A measuring cord stretched across a stone gate, a seal marked.",
    "freestyle_drill_06": "A stone gate with a chain across it.",
    "freestyle_drill_07": "A workbench of jointed parts laid out in order, one limb already fitted and tested.",
    "freestyle_noncombat_11": "A yard of broken constructs stacked against a wall, one frame already stripped to the spine, tools laid out on a block.",
    "signature_noncombat_05": "A ledger closed on a duelling floor, a figure's light dropping a rung.",
    "signature_drill_04": "A side gate barred from the inside, figures waiting beyond it.",
    "freestyle_noncombat_16": "A shield arm thrown across a kneeling figure, a blow landing on it.",
    # Grounds
    "grounds_02": "A grove of old trees ringing a standing stone, a line of pale light in the roots.",
    "grounds_06": "A watchpost on a spur above the cloud line, one cold lamp lit, the whole valley laid out below it.",
    "grounds_04": "A frozen moor under low cloud, a standing stone rimed with frost, the leyline dim.",
    "grounds_05": "A shallow stone hollow where the air visibly presses down, dust hanging low and refusing to rise.",
    "grounds_03": "A walled yard with an iron gate, a toll box, the leyline running under the gate.",
    "grounds_01": "A crossroads trampled to bare mud, no grass, the leyline showing through.",
    # Backlog: cards added by the tournament imports that the roster was never rebuilt for. The
    # generator refuses to run while any card lacks a brief, so these were written here to unblock
    # the rebuild. They follow the house pattern but have not been reviewed.
    "personality_01": "Starved. Gaunt and low to the ground, blade held loose, the fire in him down to a few coals, eyes fixed on something out of frame.",
    "personality_55": "Gnawing. Hunched mid-step, small flames chewing along the blade's edge, a brand showing dark on his forearm.",
    "personality_56": "Gorging. Fire pouring into him rather than off him, the light around him drawn inward, mouth open.",
    "personality_57": "Consuming. Wreathed and still, everything near him blackening at the edges, the brand burning white.",
    "personality_58": "Insatiable. Fully ablaze and empty with it, the fire streaming inward through a hollow at his chest, nothing in his face.",
    "personality_59": "The Marked Lord. Standing square in a ruined hall, brigandine closed, a dark brand across the back of one crackling hand, chin up.",
    "personality_60": "Unflinching. Taking a blow on the shoulder without moving his feet, the brand spreading up the forearm, jaw set.",
    "personality_61": "Unfettered. The broken crest torn off his chest and dropped, both hands lit, moving forward.",
    "personality_62": "Unrepentant. The brand covering half his face, arms wide, the hall behind him going dark, no shame in it.",
    "signature_strike_30": "A hold locked on from behind, an arm across the throat, heat shimmer rising off the grip.",
    "signature_art_14": "A spray of embers thrown flat from an open hand, a brand glowing on the wrist.",
    "signature_strike_31": "A blow landing and the air behind it coming apart in black threads, embers going out.",
    "signature_strike_29": "A rising punch thrown from a low stance, grey metal closing over the forearm mid-swing.",
    "signature_noncombat_10": "A shoreline at the lowest tide, seven things left uncovered on the flats, a figure walking out to them.",
    "freestyle_art_09": "A shout tearing a standing rune circle out of a stone floor, the stone going with it.",
    "relic_04": "A plain iron clasp lying open on dark cloth, two cut cords beside it.",
    "freestyle_combat_20": "An empty brazier and a spent figure kneeling beside it, everything on the floor knocked flat.",
    "freestyle_noncombat_18": "Seven carved stones going dark at once along a wall, the last light leaving the grooves.",
    "grounds_07": "A duelling ring cut into stone with a brand burnt into the centre of it.",
    "freestyle_art_11": "A brand on a palm dimming as the blow it threw is pulled back.",
    "freestyle_art_10": "A brand flaring white and throwing a short arc, struck right after a fist landed.",
    "freestyle_strike_07": "A braced shoulder driving through, the brand on the arm burning brighter with the effort.",
    "pyre_strike_19": "A knee driven up into a guard, flame bursting off the impact.",
    "pyre_strike_21": "A burning sword brought down through a shield rim, the cut glowing.",
    "pyre_strike_20": "A low stance with both forearms crossed, a bolt of light breaking apart on them.",
    "shade_strike_14": "A card torn in half over a black veil, the halves drifting apart.",
    "shade_strike_11": "A hand of cards pulled out of a grip one by one by nothing visible.",
    "shade_drill_03": "A lamp guttering on an iron stand, the wick eating itself down.",
    "shade_art_10": "A black veil settling over a face and staying there, eyes fixed through it.",
    "shade_strike_08": "A whisper still hanging in the air after the mouth has closed, black threads.",
    "shade_strike_13": "An open hand held out over a stripped table, a coin and a broken drill on it.",
    "shade_art_11": "A bolt of light turned back on itself, the caster stepping away from it.",
    "shade_strike_09": "Black threads drawn back out of a discard heap and into a closed hand.",
    "shade_strike_12": "A hand of cards fanned face up under a black veil, one finger picking through them.",
    "shade_strike_10": "A card pulled from a grip and going to nothing between two fingers.",
    "shade_strike_15": "A flat palm landing hard, black rings spreading from the point of contact.",
    "shade_art_09": "A whisper swelling into a dark wave, the veil billowing with it.",
    "shade_art_08": "A bolt of light meeting a black veil and turning aside along it.",
    "tide_strike_09": "A wall of heavy water bearing down slow, everything under it already bending.",
    "tide_art_11": "Black water standing dead still, no reflection in it at all.",
    "tide_art_10": "Deep water pressing a hull in, rivets starting along the seam.",
    "tide_strike_08": "A dead weight of water dropping on a raised arm, the arm going down with it.",
    "tide_strike_06": "An anchor set deep in black silt, the chain drawn tight upward.",
    "tide_strike_11": "A standing sheet of water taking a bolt of light and swallowing it.",
    "tide_strike_14": "A sweep of heavy water taking legs out from under, low and fast.",
    "tide_strike_07": "A dredge chain hauling silt and objects up out of black water.",
    "tide_mastery_02": "A sounding line run out into deep water, the marks on it counting down.",
    "tide_art_12": "The full weight of a wave landing at once, spray driven flat.",
    "tide_drill_07": "A vessel of water too heavy for its size, the table under it bowing.",
    "tide_combat_01": "A shape held under the surface, hands flat on it from above.",
    "tide_strike_10": "A pressure wave running out under water, the surface lifting in a ring.",
    "tide_strike_04": "Water closing over something and taking it down, one arm still showing.",
    "tide_strike_13": "A blow swept aside by a curl of heavy water, the water keeping the shape of it.",
    "tide_strike_12": "An undertow taking the feet out from under, the surface unbroken above.",
    "tide_strike_05": "Deep water welling up through a crack in stone, rising fast and clear.",
    # Storm expansion. Weather and charge only: no figures, no places anyone would recognise.
    "storm_strike_04": "A gust veering a falling blow aside, dust lifting off the ground in a rising spiral, grey light.",
    "storm_strike_05": "Two thin bolts earthing into the same scorched patch, twin glass scars in the dirt, the air still crackling.",
    "storm_art_11": "A coil of blue charge collapsing inward, sparks dying at the edges, cold grey air.",
    "storm_noncombat_01": "A weather front curling back on itself over open ground, the cloud wall turning, light behind it.",
    "storm_drill_01": "A standing mantle of charge around an empty space, blue filaments held in a shell, steady.",
    "storm_drill_02": "Charge spread thin across a wide coil, light bleeding outward, nothing concentrated.",
    "storm_drill_03": "A tightly wound copper coil glowing white at the core, arcs jumping between the turns.",
    "storm_drill_04": "A clean bright channel cut through cloud, charge running down it without resistance.",
    "storm_noncombat_02": "A single peal rolling out across a dark plain, cloud banks answering it, ranked shapes at the horizon.",
    "storm_combat_01": "A gale tearing carved stone markers loose and flinging them low across wet ground.",
    "storm_combat_02": "An open current running through clear air with nothing in its path, a faint blue trail.",
    "storm_art_12": "A bolt caught and held in a bowl of charge, its light pooling instead of earthing.",
    "storm_strike_06": "An arc bending back into its own source, the origin point brightening as it feeds.",
    "storm_strike_07": "The return stroke running back up a lightning channel, white core, everything around it dark.",
    "storm_strike_08": "A squall twisting a sheet of rain into a wrung spiral, water driven out of it.",
    "storm_art_13": "One peal breaking into the next across stacked cloud, each louder, the air shaking.",
    "storm_art_14": "A small spark jumping off an idle coil, one thin blue thread, almost nothing.",
    "storm_art_15": "Charge penned behind a dark cloud wall letting go all at once, one hard white flash.",
    "storm_strike_09": "The first stroke burning an open channel through dark air, the edges glowing.",
    "storm_art_16": "A flash with no earth to take it, light spreading flat and unbroken, no strike point.",
    "storm_art_17": "One narrow bolt held dead straight between two fingers, the air around it perfectly still.",
    "storm_art_18": "An arc leaping from the caster to the frame edge and dragging a second, thinner arc back with it.",
    "storm_art_19": "A bolt loosed sideways off a raised palm, bending mid-air toward a target the caster is not looking at.",
    "storm_art_20": "A pinpoint of light at the fingertip, the rest of the frame dim, a single thin line leaving it.",
    "storm_strike_10": "A gust flattening a standing row, one shape going off its feet, debris low and fast.",
    "storm_art_21": "Residual charge still crawling through wet ground after the strike, faint blue veins.",
    "storm_strike_11": "Wind laying a whole stand flat in one pass, everything bent the same way.",
    "storm_strike_12": "A following wind pushing a cloud front forward, streaks trailing behind it.",
    "storm_art_22": "A cold front sliding over warm ground, the line of it sharp, colour draining below.",
    "storm_art_23": "Static washing over one clear signal until it is gone, grey hiss, nothing left.",
    # Root expansion. Grove, timber, thorn and frost only.
    "root_drill_02": "A planted hedgerow standing against driven wind, branches locked, the ground calm behind it.",
    "root_drill_03": "A dense canopy catching what falls from above, light broken into pieces on the floor.",
    "root_drill_04": "A cleared sightline down a narrow forest trail, the way ahead visible to the bend.",
    "root_noncombat_01": "Roots drinking deep from dark water, the grove above drawn green and full.",
    "root_noncombat_02": "A thorn hedge tearing at whatever forced through it, torn strands caught on the spines.",
    "root_strike_03": "A long branch reaching across a gap toward a carved stone, bark splitting with the strain.",
    "root_strike_04": "Standing timber coming down full length, the trunk splitting at the base, dust off the floor.",
    "root_strike_05": "A millstone turning slow and heavy, grain crushed to powder beneath it.",
    "root_strike_06": "Sap drawing back up a cut trunk, pale beads gathering along the wound.",
    "root_strike_07": "A clean pruning cut on a green limb, the stub already swelling toward regrowth.",
    "root_strike_08": "Deadfall cleared off a forest floor, dry branches heaped and going to nothing.",
    "root_strike_09": "A briar tangle catching again and again on whatever tries to pass, thorns bent back.",
    "root_strike_10": "Sap quickening through a whole trunk at once, bark straining, green light under it.",
    "root_strike_11": "A snare of root and cord springing shut around empty air, a whip of motion.",
    "root_strike_12": "A wedge driven deep into built timber, the joint opening along the grain.",
    "root_strike_13": "A grove bending and thrashing in its own temper, branches lashing, leaves torn loose.",
    "root_strike_14": "Bindweed wound tight around a held shape, green coils drawing closed.",
    "root_strike_15": "Pale sapwood taking a blow and holding, the mark shallow, the fibres unbroken.",
    "root_strike_16": "A taproot braced deep in dark soil, the trunk above unmoved.",
    "root_combat_03": "A heavy bough barred across a forest trail at chest height, the way shut.",
    "root_combat_04": "Bark closing slowly over an old wound in a trunk, the seam almost gone.",
    "root_combat_05": "One obstacle cut clean out of a forest path ahead, the gap left open.",
    "root_combat_06": "A cleared glade with the undergrowth stripped back to bare earth, a ring of standing trunks.",
    "root_art_05": "A thin first frost edging green leaves white, the morning light low.",
    "root_art_06": "A splinter boring straight through a plank, the exit hole clean on the far side.",
    "root_art_07": "A stone hurled flat and hard, knocking a standing post over.",
    "root_art_08": "Seed thrown wide over broken ground, some catching, some lost on stone.",
    "root_art_09": "The oldest wood in a grove, vast and dark, the ground beneath it bare.",
    "root_art_10": "A killing frost blackening growth overnight, stems collapsed, white rime on everything.",
    # Pyre expansion, 2026-09-23. Fire that feeds and consumes; figures only where the card is a blow.
    "pyre_strike_22": "A forearm crusted in glowing coal like a second skin, a blade skidding off it in sparks.",
    "pyre_strike_23": "A bank of black smoke rolling over a bolt of light and smothering it, soot falling out of it.",
    "pyre_strike_24": "A great pyre going up all at once, five braziers around it catching from the same flame.",
    "pyre_strike_25": "A fist landing, and where the sparks fall a small brazier already burning on the stone.",
    "pyre_strike_26": "A heap of old burnt pages collapsing into white ash under a single blow of flame.",
    "pyre_strike_27": "Air shimmering with heat over hot stone, a bolt of light bending away and breaking up in it.",
    "pyre_strike_28": "A blade stopped in a gout of flame that rolls back up the arm that swung it.",
    "pyre_art_04": "A chimney flue drawing hard, the fire at its foot roaring higher the more it pulls.",
    "pyre_art_05": "A bolt of fire punching clean through a raised shield, the rim of the hole still burning.",
    "pyre_art_06": "Three flares thrown in quick succession, arcing red across a dark sky.",
    "pyre_art_07": "A burst of flame rising in the shape of spread wings out of a heap of ash.",
    "pyre_art_08": "A single spark struck off flint, caught in the air and already growing.",
    "pyre_art_09": "A flare going off at close range, too fast for the raised arm in front of it.",
    "pyre_art_10": "A column of fire so hot its heart is dark, a crowned figure's shape unmaking inside it.",
    "pyre_art_11": "A white flame with no smoke and no colour, what it touches gone without ash.",
    "pyre_combat_02": "A whole hall on fire from floor to rafters, banners and furniture going up together.",
    "pyre_combat_03": "Coals raked up under a bellows, the fire turning from red to yellow to white.",
    "pyre_drill_01": "A column of heat rising off banked coals, the air above it wavering higher and higher.",
    "pyre_drill_02": "Coals banked under a heap of ash, a red glow still steady beneath.",
    "pyre_drill_03": "Cards dropped into a brazier by the handful, the flame rising into a wall.",
    "pyre_drill_04": "A hand sifting cinders through a grate, one unburnt card left in the palm.",
    "pyre_drill_05": "A curtain of low flame hung across a doorway, a bolt of light guttering out against it.",
    "pyre_drill_06": "A hearthstone set in a floor, the fire on it carried whole to a new hearth.",
    "pyre_drill_07": "A kiln door open on white-hot shelves, the heat pouring out of it.",
    "pyre_drill_08": "A smoldering heap that never goes out, the edge of it eating slowly into a pile of pages.",
    "pyre_mastery_03": "Dry tinder catching from a spent page laid on top, the first flame just rising.",
    "pyre_mastery_04": "Cinders drifting down onto a raised guard, the guard smoking where they land.",
    # Steel expansion, 2026-09-23. A human fighter with the dragon surfacing in them for the fight:
    # scales, talons, horns, fangs, a tail, breath. Never wings, never a whole dragon.
    "steel_strike_23": "A scaled tail lashing out from behind a fighter and smashing a small brazier off its stand.",
    "steel_strike_24": "A fighter grown a head taller mid-swing, horned and scaled, a smaller foe caught under the blow.",
    "steel_strike_25": "Old scales flaking off a fighter's forearm as it takes a hit, new ones bright beneath.",
    "steel_strike_26": "A fighter's arm swelling into scale and talon as the punch lands, a torn card fluttering behind.",
    "steel_strike_27": "A taloned hand closed on a throat, the held figure's glow draining out between the fingers.",
    "steel_strike_28": "A horned fighter charging shoulder-first through a line of lesser fighters, scattering them.",
    "steel_art_07": "Blood-red breath pouring from a fanged mouth, scale spreading up the neck as it goes.",
    "steel_art_08": "A gout of breath so hot the ground under it turns to glass and the ash lifts away.",
    "steel_art_09": "Breath of fire from a fighter looking down at a smaller one, flames licking up a raised arm.",
    "steel_art_10": "A hoard of old weapons and cards dragged up out of ash by a taloned hand.",
    "steel_art_11": "A tail sweeping low across a floor, bracing posts and small braziers knocked flying.",
    "steel_art_12": "A roar from a fanged mouth sending a crowd of lesser fighters back on their heels.",
    "steel_art_13": "A cornered fighter hunched behind a scaled arm, eyes slitted, a bolt gathering in the other hand.",
    "steel_art_14": "Scale rippling up a fighter's whole body at once, the eyes gone gold.",
    "steel_combat_02": "A fighter drawing a huge breath, chest swelling, scale rising along the throat.",
    "steel_drill_02": "A slitted golden eye in a human face, the one it looks at shrinking back.",
    "steel_drill_03": "A horned figure standing over a kneeling one, the kneeling one's glow guttering.",
    "steel_drill_04": "A forearm of hard grey scale raised as a shield, a blade glancing off it.",
    "steel_noncombat_01": "A fighter with eyes shut and scale showing at the temples, old battles flickering around them.",
    "steel_noncombat_02": "A grin splitting into fangs, the fighter sweating and paling as the scale comes in.",
    "steel_mastery_02": "A shadow on a wall behind a fighter, horned and far bigger than the fighter casting it.",
    "steel_mastery_03": "A scaled back turned to a strike, the blade breaking on it.",
    "steel_mastery_04": "A fighter mid-roar with blood in the eyes, scale and horn tearing through the skin.",
    # Tide expansion, 2026-09-23. Water that drags, drowns and carries.
    "tide_strike_15": "A wave frozen solid mid-break, a fighter's raised fist locked in the ice.",
    "tide_strike_16": "A wall of sea coming down on a jetty, planks and posts splintering under it.",
    "tide_strike_17": "A weighted line dropped into dark water, three shapes rising on it to the surface.",
    "tide_strike_18": "Flat grey water under a windless sky, a figure sinking without a ripple.",
    "tide_strike_19": "Wreckage washing back up onto a beach, spars and crates tumbling in the foam.",
    "tide_strike_20": "Surf hammering a rock again and again, the rock worn to a stump.",
    "tide_strike_21": "A blow driving a figure down through the surface, bubbles streaming up around them.",
    "tide_art_13": "A wave running back down a beach, dragging stones and shells back into the sea.",
    "tide_art_14": "A high spring tide flooding over a sea wall, the water glittering in low sun.",
    "tide_art_15": "A thin film of brine creeping up a figure's legs, the skin under it greying.",
    "tide_combat_02": "A flood sweeping through a yard, braziers and posts carried off in it.",
    "tide_combat_03": "The tide coming back in over sand, filling footprints one by one.",
    "tide_combat_04": "A sea parting around a figure standing in a dry channel, walls of water either side.",
    "tide_drill_01": "A shoal of small silver fish turning together around a swimmer.",
    "tide_drill_02": "Boats moored to a stone quay with heavy ropes, the storm pulling at them.",
    "tide_drill_03": "Salt crusting white on a wound, the skin around it raw.",
    "tide_drill_04": "A current carrying a line of small boats behind a larger one.",
    "tide_drill_05": "A sea wall taking a wave full on, spray bursting high over it.",
    "tide_drill_06": "A narrow channel between two rocks, only one small boat able to pass.",
    "tide_noncombat_02": "Figures rising out of shallow water at a call, dripping, ready.",
    "tide_noncombat_03": "A rip current dragging a swimmer out past the breakers.",
    "tide_noncombat_04": "A cliff foot hollowed by the sea, the stone above it slumping in.",
    "tide_mastery_03": "An eddy turning in a river pool, a leaf held circling in it.",
    "tide_mastery_04": "A flood tide rising over a causeway, the path under it gone.",
    # Shade expansion, 2026-09-23. Shadow, hexes and the whispered word.
    "shade_strike_16": "A whisper of shadow coiling round a lantern on a table, its flame going still.",
    "shade_strike_17": "A dark mark spreading on a fighter's forearm, the arm hanging heavier.",
    "shade_strike_18": "A shadow drinking in a blow as it lands, growing darker where it struck.",
    "shade_strike_19": "Old hex-scraps drawn up out of ash and gathering into a black knot in the air.",
    "shade_strike_20": "A single whispered word opening the fight, the opponent flinching before anything else moves.",
    "shade_strike_21": "A name written on a card in ink that runs black, the card crumbling in a deck.",
    "shade_strike_22": "A shadowed hand turning a fist aside and drawing a little light out of it.",
    "shade_strike_23": "A shadow stretching far past its caster, taking hold and pulling strength back along it.",
    "shade_art_12": "A black hex settling over a lesser figure, who sinks into the dark.",
    "shade_art_13": "A shadow offering two closed hands, a figure hesitating between them.",
    "shade_combat_02": "A name scratched out of a ledger, every copy of it on the shelves turning to blank paper.",
    "shade_combat_03": "Darkness creeping across a stack of cards, the top ones fading as it passes.",
    "shade_combat_04": "A shadow reading over a figure's shoulder, the cards in their hand lit for it alone.",
    "shade_combat_05": "A sneering shadow mask, the figure before it throwing down their cards.",
    "shade_noncombat_01": "A thin shadow hand slipping into a sealed deck box and drawing two cards out.",
    "shade_noncombat_02": "A figure resting in deep shade, strength seeping back into them.",
    "shade_drill_04": "A hand of cards blurring and shifting, one sliding back into the deck.",
    "shade_drill_05": "A disc of total dark hung in the air, a bolt of light vanishing into it.",
    "shade_drill_06": "A shadow wiping a rune from a stone as though it had never been carved.",
    "shade_drill_07": "Old hexes swept from the floor and tucked back beneath a stack of cards.",
    "shade_mastery_02": "A coin offered into darkness, a card taken back out of it.",
    "shade_mastery_03": "Black rot spreading over a planted rune stone.",
    "shade_mastery_04": "An eclipse, the sun's rim burning round a black disc.",
    "root_drill_05": "Sap welling from a cut in green bark, running bright down the trunk.",
    "root_combat_07": "Soft earth folding over a glowing seal-stone, swallowing it from sight.",
    "root_mastery_02": "A compost heap steaming in cold air, a seedling pushing out of its top.",
    "root_mastery_03": "A taproot plunging deep through layered soil into dark water below.",
    "root_mastery_04": "A ring of ancient trees round a mossy clearing, lit by a single shaft of sun.",
    "root_noncombat_03": "A great oak fallen across a clearing, its roots torn up and still clutching earth.",
    "root_noncombat_04": "Saplings leaning together in a tight grove, their branches woven into one canopy.",
    "root_combat_08": "Pale green shoots breaking through a charred forest floor.",
    "root_strike_17": "A vine snaking low across the ground and hooking round an ankle.",
    "root_art_11": "A seed pod bursting mid-air, seeds scattering like shot.",
    "root_strike_18": "A stone-edged hand chopping down, splitting a boulder clean in two.",
    "root_drill_06": "A lone watcher on a frosted ridge, breath misting, eyes on the valley below.",
    "root_art_12": "A spray of hard thorns flung from an outstretched palm.",
    "root_noncombat_05": "Thick vines coiling round an iron gear, locking it still.",
    "root_strike_19": "A fighter braced behind an oak's broad trunk as a blow glances off the bark.",
    "storm_drill_05": "A bolt striking a figure and arcing back out of them into the ground behind.",
    "storm_drill_06": "A thin spark threading through a stack of papers, burning one sheet away.",
    "storm_drill_07": "A copper rod driven into wet earth, lightning pouring down it and vanishing.",
    "storm_drill_08": "Two hands clasped, a crackling wall of charge rising between them and a coming blow.",
    "storm_strike_13": "A shoulder driving forward into a gust, storm clouds massing behind the charge.",
    "storm_strike_14": "A lone iron rod on a hilltop as the first lightning of a storm finds it.",
    "storm_art_24": "A steady ribbon of current humming between two posts, unbroken in the rain.",
    "storm_mastery_03": "A gale bending a field of grass flat, one runner sprinting with it at their back.",
    "storm_mastery_04": "A conductor's baton raised before rows of crackling coils, all lit at once.",
    "freestyle_noncombat_19": "A spell unravelling in mid-air into loose threads of light, a calm hand closing on it.",
    "freestyle_noncombat_20": "Two duellists frozen mid-stride under a vast reptilian eye opening in the sky.",
    "freestyle_combat_21": "A fighter stooping to gather spent scraps and fallen weapons from the ground as they run.",
}

# Seals: one brief per set, the number added by the generator.
SEAL_SETS = {
    "sun": "Sun seal %d of 7: a sun disc cut into the stone, %d of seven rays finished, a thin line of seawater in the grooves.",
    "moth": "Moth seal %d of 7: a moth wing cut into the stone, %d of seven pattern rings finished, white dust in the grooves.",
    "marble": "Marble seal %d of 7: a chiselled block cut into the stone, %d of seven faces finished, the chisel left in the last cut.",
    "salt": "Salt seal %d of 7: an open hand cut into the stone, %d of seven fingers and marks finished, salt crusting white in the grooves.",
}


def load_cards(path):
    return [json.loads(line) for line in open(path, encoding="utf-8")]


# The printed card each new id stands in for, seeded here the first time so the CSV has something
# to carry forward. The CSV wins once it has a value, which is where corrections go.
NEW_SOURCES = {
    # Saiyan Gohan, read off the sheet 2026-09-19.
    "personality_35": "Super Saiyan Gohan (Lv 1, Cell Saga IR2)",
    "personality_36": "Gohan, the Swift (Lv 2, Cell Saga)",
    "personality_37": "Gohan, Super Saiyan (Lv 3, Cell Saga)",
    "personality_38": "Gohan, Ascendant (Lv 4, Cell Saga)",
    "personality_39": "Gohan, the Winner (Lv 5, Cell Saga)",
    "steel_strike_16": "Saiyan Cross Punch (Capsule Corp Power Pack)",
    "steel_strike_17": "Saiyan Triple Kick (Cell Saga 41)",
    "steel_strike_18": "Saiyan Flying Kick (Cell Saga 60)",
    "steel_strike_19": "Saiyan Lightning Dodge (Androids Saga 111)",
    "steel_strike_20": "Saiyan Face Stomp (Androids Saga 110)",
    "steel_strike_21": "Saiyan Left Kick (Androids Saga 79)",
    "steel_strike_22": "Saiyan Flying Tackle (Androids Saga 76)",
    "steel_art_05": "Saiyan Focus (Androids Saga 77)",
    "steel_art_06": "Saiyan Planet Explosion (Frieza Saga 34)",
    "steel_drill_01": "Saiyan Power Drill (Saiyan Saga 236)",
    "grounds_06": "Kami's Floating Island (Androids Saga 94)",
    "freestyle_noncombat_05": "Time Chamber Training (Cell Saga 79)",
    # Orange Android 19, read off the sheet 2026-09-19.
    "storm_mastery_02": "Orange Style Mastery (Cell Saga 140)",
    "grounds_05": "Gravity Chamber (Androids Saga 8)",
    "storm_art_07": "Orange Strike (Cell Saga 29)",
    "storm_art_08": "Orange Palm Blast (Androids Saga 28)",
    "storm_art_09": "Orange Energy Deflection (Cell Saga 31)",
    "storm_art_10": "Orange Power Beam (Androids Saga 69)",
    "signature_noncombat_02": "Tien's Mental Condition (Androids Saga 86)",
    "freestyle_noncombat_07": "Enraged! (Saiyan Saga 190)",
    # Red Goku v1.1, read off the sheet 2026-09-19.
    "personality_30": "Goku, the Hero (Lv 1, Cell Saga)",
    "personality_31": "Goku, the Saiyan (Lv 2, Cell Saga)",
    "personality_32": "Goku, Earth's Hero (Lv 3, Cell Saga)",
    "personality_33": "Goku (Lv 4, Cell Saga)",
    "personality_34": "Goku, the All Powerful (Lv 5, Cell Saga)",
    "personality_53": "Chi-Chi (Lv 1, Saiyan Saga)",
    "pyre_mastery_02": "Red Style Mastery (Trunks Saga)",
    "freestyle_combat_02": "Prepared Dodge (Cell Games Saga)",
    "pyre_strike_14": "Red Offensive Stance (Cell Saga)",
    "pyre_strike_15": "Red Dodge (Cell Saga)",
    "pyre_art_03": "Red Energy Shield (Trunks Saga)",
    "pyre_strike_16": "Red Eye Laser Assault (Trunks Saga)",
    "pyre_strike_17": "Red Flight (Cell Saga)",
    "pyre_strike_18": "Red Power Strike (Cell Saga)",
    "signature_strike_07": "Raditz Flying Kick (Saiyan Saga)",
    "signature_strike_05": "Goku's Physical Attack (Saiyan Saga)",
    "signature_strike_06": "Goku's Training (Androids Saga)",
    "signature_combat_01": "Goku's Truce (Saiyan Saga)",
    "signature_strike_03": "Vegeta's Physical Stance (Saiyan Saga)",
    "signature_drill_03": "Vegeta's Quickness Drill (Saiyan Saga)",
    "signature_art_07": "Vegeta's Jolting Slash (Frieza Saga)",
    "signature_noncombat_05": "Vegeta Scans the City (Trunks Saga)",
    "signature_strike_20": "Majin Vegeta's Frantic Attack (Babidi Saga)",
    "signature_noncombat_09": "Vegeta's Smirk (BK Promo BK7)",
    "signature_noncombat_08": "Vegeta's Plans (Saiyan Saga)",
    "signature_art_11": "Android 13's Prepared Stance (BSMovie Promo)",
    "signature_strike_24": "Android 19's Dodge (BSMovie Promo)",
    "signature_noncombat_01": "Android 16 Smiles (AS Promo)",
    "signature_combat_07": "Android 17 Smirks (Androids Saga)",
    "personality_26": "Android 18 (Lv 1, Cell Saga)",
    "personality_27": "Android 18, the Model (Lv 2, Cell Saga)",
    "personality_28": "Android 18, the Machine (Lv 3, Cell Saga)",
    "personality_29": "Android 18 (Lv 4, Cell Saga)",
    "personality_46": "Android 20 (Lv 1, Cell Saga)",
    "personality_47": "Piccolo, the Avenger (Lv 1, Trunks Saga)",
    "personality_48": "Vegeta, the Powerful (Lv 1, Cell Saga)",
    "seal_01": "Dende Dragon Ball 1 (Cell Saga)",
    "seal_02": "Dende Dragon Ball 2 (Cell Saga)",
    "seal_03": "Dende Dragon Ball 3 (Cell Saga)",
    "seal_04": "Dende Dragon Ball 4 (Cell Saga)",
    "seal_05": "Dende Dragon Ball 5 (Cell Saga)",
    "seal_06": "Dende Dragon Ball 6 (Cell Saga)",
    "seal_07": "Dende Dragon Ball 7 (Cell Saga)",
    "signature_combat_09": "Looking Good (Cell Saga promo P9)",
    "freestyle_noncombat_01": "Drills are for the Weak (Trunks Saga)",
    "signature_noncombat_05": "Vegeta Scans the City (Trunks Saga)",
    "freestyle_noncombat_11": "The Car (Cell Saga)",
    "signature_art_07": "Vegeta's Jolting Slash (Frieza Saga)",
    "signature_art_08": "Tien's Tri-Beam (Cell Saga)",
    "freestyle_drill_07": "Android Attack Drill (Androids Saga)",
    "signature_drill_04": "Gohan Spots the Imposter Drill (Trunks Saga)",
    "shade_art_03": "Black Fore Fist Punch (Saiyan Saga)",
    "shade_art_04": "Black Knife Hand Strike (Saiyan Saga)",
    "shade_strike_07": "Black Physical Focus (Trunks Saga)",
    "shade_art_05": "Black Energy Web (Trunks Saga)",
    "shade_art_06": "Black Preparation (Cell Games 3)",
    "shade_art_07": "Black Energy Blast (Trunks Saga)",
    "shade_strike_06": "Black Defensive Burst (Trunks Saga)",
    "shade_drill_01": "Black Takedown Drill (Saiyan Saga)",
    "shade_drill_02": "Black Smoothness Drill (Trunks Saga)",
    # The Storm expansion, read off tools/source_candidates.tsv 2026-09-21.
    "storm_strike_04": "Orange Sidestep (Cell Saga)",
    "storm_strike_05": "Orange Deflection (Cell Saga)",
    "storm_art_11": "Orange Fist Detonation (Frieza Saga)",
    "storm_noncombat_01": "Orange Gaze (Cell Saga)",
    "storm_drill_01": "Orange Burning Aura Drill (Cell Games)",
    "storm_drill_02": "Orange Steady Drill (Cell Games)",
    "storm_drill_03": "Orange Aura Drill (Androids Saga)",
    "storm_drill_04": "Orange Body Shifting Drill (Saiyan Saga)",
    "storm_noncombat_02": "Orange Friendship (World Games)",
    "storm_combat_01": "Orange Dragon Aid (Cell Games)",
    "storm_combat_02": "Orange Gambit (Buu Saga)",
    "storm_art_12": "Orange Energy Stance (Tuff Enuff)",
    "storm_strike_06": "Orange Dashing Gut Punch (Trunks Saga)",
    "storm_strike_07": "Orange Flying Drop Kick (World Games)",
    "storm_strike_08": "Orange Beatdown (Cell Games)",
    "storm_art_13": "Orange Mouth Shot (Buu Saga)",
    "storm_art_14": "Orange Power Blast (Cell Saga)",
    "storm_art_15": "Orange Energy Concentration (Cell Games)",
    "storm_strike_09": "Orange Aggressive Technique (Cell Games)",
    "storm_art_16": "Orange Energy Discharge (Cell Saga)",
    "storm_art_17": "Orange Focused Attack (Cell Games 110)",
    "storm_art_18": "Orange Ki Assailment (Kid Buu Saga 110)",
    "storm_art_19": "Orange Trick Shot (Buu Saga)",
    "storm_art_20": "Orange Energy Focus (Cell Saga)",
    "storm_strike_10": "Orange Knockout (World Games)",
    "storm_art_21": "Orange Energy Shot (Cell Games)",
    "storm_strike_11": "Orange Carnage (Kid Buu Saga)",
    "storm_strike_12": "Orange Flight (Buu Saga)",
    "storm_art_22": "Orange Taunting Attack (Frieza Saga)",
    "storm_art_23": "Orange Sneak Attack (Buu Saga)",
    # The Root expansion, read off tools/source_candidates.tsv 2026-09-21.
    "root_drill_02": "Namekian Power Stance Drill (Cell Games)",
    "root_drill_03": "Namekian Ready Drill (Cell Games)",
    "root_drill_04": "Namekian Knowledge Drill (Babidi Saga)",
    "root_noncombat_01": "Namekian Fusion (Cell Saga)",
    "root_noncombat_02": "Namekian Finishing Effort (Androids Saga)",
    "root_strike_03": "Namekian Head Strike (Trunks Saga)",
    "root_strike_04": "Namekian Power Kick (Cell Saga)",
    "root_strike_05": "Namekian Rock Crush (Cell Saga)",
    "root_strike_06": "Namekian Upward Dash (Cell Saga)",
    "root_strike_07": "Namekian Side Kick (Cell Saga)",
    "root_strike_08": "Namekian Flying Kick (Cell Games)",
    "root_strike_09": "Namekian Combo (World Games)",
    "root_strike_10": "Namekian Focused Kick (World Games)",
    "root_strike_11": "Namekian Surprise Attack (World Games)",
    "root_strike_12": "Namekian Shield Destruction (Buu Saga)",
    "root_strike_13": "Namekian Tornado Attack (World Games)",
    "root_strike_14": "Namekian Crushing Hold (Cell Games)",
    "root_strike_15": "Namekian Fist Block (Cell Saga)",
    "root_strike_16": "Namekian Charging Stance (Tuff Enuff)",
    "root_combat_03": "Namekian Pikkon's Defense (World Games)",
    "root_combat_04": "Namekian Restoration (Cell Games)",
    "root_combat_05": "Namekian Scouting (Cell Games)",
    "root_combat_06": "Namekian Frendship (Androids Saga)",
    "root_art_05": "Namekian Energy Ray (Cell Saga)",
    "root_art_06": "Namekian Focused Blast (World Games)",
    "root_art_07": "Namekian Double Blast (World Games)",
    "root_art_08": "Namekian Eye Beam (World Games)",
    "root_art_09": "Namekian Energy Beam (Cell Saga)",
    "root_art_10": "Namekian Piercing Beam (Cell Games)",
    # Three Pyre cards the tournament import added with no source recorded, matched by their text
    # in the Pyre review of 2026-09-23.
    "pyre_strike_19": "Red Knee Bash (Androids Saga)",
    "pyre_strike_20": "Red Energy Defensive Stance (World Games)",
    "pyre_strike_21": "Red Sword Cleave (Kid Buu Saga)",
    # The Pyre expansion, read off tools/source_candidates.tsv 2026-09-23.
    "pyre_drill_01": "Red Blowing Steam Drill (Irwin IR12)",
    "pyre_drill_02": "Red Tactical Drill (Androids Saga)",
    "pyre_drill_03": "Red Gravity Drill (Trunks Saga)",
    "pyre_drill_04": "Red Hunting Drill (Androids Saga)",
    "pyre_drill_05": "Red Energy Drill (Cell Games)",
    "pyre_drill_06": "Red Meditation Drill (Babidi Saga)",
    "pyre_drill_07": "Red Implosion Drill (Frieza Saga)",
    "pyre_drill_08": "Red Kaio-Ken Drill (Kid Buu Saga)",
    "pyre_strike_22": "Red Torso Chop (Babidi Saga Preview 6)",
    "pyre_strike_23": "Red Slide (Babidi Saga)",
    "pyre_strike_24": "Red Pulverize (Buu Saga Preview 1)",
    "pyre_strike_25": "Red Power Punch (Cell Games)",
    "pyre_strike_26": "Red Feint (Cell Saga)",
    "pyre_strike_27": "Red Rapid Deflection (Fusion Saga)",
    "pyre_strike_28": "Red Counter Strike (Androids Saga)",
    "pyre_art_04": "Red Arm Cannon (CCPP2 CCPP7)",
    "pyre_art_05": "Red Static Shot (Fusion Saga)",
    "pyre_art_06": "Red Repeating Flares (Fusion Saga)",
    "pyre_art_07": "Red Cross Slash (Fusion Saga)",
    "pyre_art_08": "Red Energy Charge (Androids Saga)",
    "pyre_art_09": "Red Energy Surprise (Cell Games)",
    "pyre_art_10": "Red Mouth Cannon (Fusion Saga)",
    "pyre_art_11": "Red Left Bolt (Kid Buu Saga)",
    "pyre_combat_02": "Red King Cold Observation (Trunks Saga)",
    "pyre_combat_03": "Red Energy Focus (World Games)",
    "pyre_mastery_03": "Red Style Mastery (Cell Saga)",
    "pyre_mastery_04": "Red Style Mastery (World Games)",
    # The Steel expansion, read off tools/source_candidates.tsv 2026-09-23.
    "steel_strike_23": "Saiyan Pride (Cell Games)",
    "steel_strike_24": "Saiyan Clothesline (Broly Movie M14)",
    "steel_strike_25": "Saiyan Neckbreaker (Fusion Saga)",
    "steel_strike_26": "Saiyan Blitz (Fusion Saga)",
    "steel_strike_27": "Saiyan Lurch (Kid Buu Saga)",
    "steel_strike_28": "Saiyan Surprise (Broly Movie M17)",
    "steel_art_07": "Saiyan Two Gun Woo (Fusion Saga)",
    "steel_art_08": "Saiyan Energy Bullet (Kid Buu Saga)",
    "steel_art_09": "Saiyan Energy Toss (Broly Movie M35)",
    "steel_art_10": "Saiyan Energy Bomb (Buu Saga)",
    "steel_art_11": "Saiyan Strength Blast (Buu Saga)",
    "steel_art_12": "Saiyan Ki Ball (Buu Saga)",
    "steel_art_13": "Saiyan Desperation (Kid Buu Saga)",
    "steel_art_14": "Saiyan Power (Fusion Saga)",
    "steel_combat_02": "Saiyan Power Stance (Broly Movie promo M17)",
    "steel_drill_02": "Saiyan Jeering Drill (Kid Buu Saga)",
    "steel_drill_03": "Saiyan Aggression Drill (Kid Buu Saga)",
    "steel_drill_04": "Saiyan Protection Drill (Cell Games)",
    "steel_noncombat_01": "Saiyan Enraged (Broly Movie M15)",
    "steel_noncombat_02": "Saiyan Offensive Rush (Cell Saga)",
    "steel_mastery_02": "Saiyan Style Mastery (Trunks Saga)",
    "steel_mastery_03": "Saiyan Style Mastery (World Games)",
    "steel_mastery_04": "Saiyan Style Mastery (Buu Saga)",
    # Tide review 2026-09-23: shipped Tide cards matched by their text, and two Mastery labels that
    # named the wrong printing.
    "tide_mastery_01": "Blue Style Mastery (Trunks Saga)",
    "tide_mastery_02": "Blue Style Mastery (Buu Saga)",
    "tide_art_10": "Blue Energy Blast (Cell Games)",
    "tide_art_11": "Blue Glare Attack (Androids Saga)",
    "tide_art_12": "Blue Energy Outburst (Frieza Saga)",
    "tide_combat_01": "Blue Softening Stance (Trunks Saga)",
    "tide_drill_07": "Blue Off-Balancing Opponent Drill (Saiyan Saga)",
    "tide_strike_04": "Blue Trapped Strike (Babidi Saga)",
    "tide_strike_05": "Blue Knockdown (Fusion Saga)",
    "tide_strike_06": "Blue Multi-Jab (Fusion Saga)",
    "tide_strike_07": "Blue Lunge (Fusion Saga)",
    "tide_strike_08": "Blue Stomach Eruption (Trunks Saga)",
    "tide_strike_09": "Blue Fist Strike (Cell Saga)",
    "tide_strike_10": "Blue Smirk (Androids Saga)",
    "tide_strike_11": "Blue Sidestep (Androids Saga)",
    "tide_strike_12": "Blue Hip Spring Throw (Saiyan Saga)",
    "tide_strike_13": "Blue Backflip (Cell Saga)",
    "tide_strike_14": "Blue Flight (Cell Saga)",
    # The Tide expansion, read off tools/source_candidates.tsv 2026-09-23.
    "tide_drill_01": "Blue Allies Drill (Frieza Saga)",
    "tide_drill_02": "Blue Saving Catch Drill (Irwin IR8)",
    "tide_drill_03": "Blue Biting Drill (Kid Buu Saga)",
    "tide_drill_04": "Blue Assistance Drill (Cell Saga)",
    "tide_drill_05": "Blue Stamina Drill (Cell Games)",
    "tide_drill_06": "Blue Holding Drill (Androids Saga)",
    "tide_noncombat_02": "Blue Battle Readiness (Androids Saga)",
    "tide_noncombat_03": "Blue Happiness (Capsule Corp Power Pack GB2)",
    "tide_noncombat_04": "Blue Idea (Androids Saga)",
    "tide_combat_02": "Blue Total Resistance (Cell Games)",
    "tide_combat_03": "Blue Awakening (Trunks Saga)",
    "tide_combat_04": "Blue Shifting Maneuver (Babidi Saga)",
    "tide_strike_15": "Blue Head Charge (Cell Saga)",
    "tide_strike_16": "Blue Sledgehammer (Kid Buu Saga)",
    "tide_strike_17": "Blue Leverage (Babidi Saga)",
    "tide_strike_18": "Blue Left Cross Punch (Cell Saga)",
    "tide_strike_19": "Blue Stopping Technique (Fusion Saga)",
    "tide_strike_20": "Blue Beatdown (Fusion Saga)",
    "tide_strike_21": "Blue Elbow Drop (Cell Saga)",
    "tide_art_13": "Blue Impulse (Kid Buu Saga)",
    "tide_art_14": "Blue Stance (Frieza Saga)",
    "tide_art_15": "Blue Electrical Gunk (Buu Saga)",
    "tide_mastery_03": "Blue Style Mastery (Cell Saga)",
    "tide_mastery_04": "Blue Style Mastery (World Games)",
    # Shade review 2026-09-23: shipped Shade cards matched by their text.
    "shade_art_08": "Black Axe Heel Kick (Saiyan Saga)",
    "shade_art_09": "Black Back Kick (Saiyan Saga)",
    "shade_art_10": "Black Exertion (Kid Buu Saga)",
    "shade_art_11": "Black Recovery (Cell Games)",
    "shade_drill_03": "Black Weakness Drill (Buu Saga)",
    "shade_strike_08": "Black Shift Kick (Fusion Saga)",
    "shade_strike_09": "Black Spin Kick (Fusion Saga)",
    "shade_strike_10": "Black Swivel Kick (Kid Buu Saga)",
    "shade_strike_04": "Black Gut Wrench (Androids Saga)",
    "shade_strike_11": "Black Drop Kick (Kid Buu Saga)",
    "shade_strike_12": "Black Bicycle Kick (Kid Buu Saga)",
    "shade_strike_13": "Black Front Punch (Buu Saga)",
    "shade_strike_14": "Black Head Crush (Buu Saga)",
    "shade_strike_15": "Black Face Slap (Cell Games)",
    # The Shade expansion, read off tools/source_candidates.tsv 2026-09-23.
    "shade_strike_16": "Black Snap Kick (Buu Saga)",
    "shade_strike_17": "Black Jawbreaker (Fusion Saga)",
    "shade_strike_18": "Black Side Kick (Saiyan Saga)",
    "shade_strike_19": "Black Parry (Kid Buu Saga)",
    "shade_strike_20": "Black Super Kick (World Games)",
    "shade_strike_21": "Black Side Thrust (Androids Saga)",
    "shade_strike_22": "Black Elbow Counter (World Games)",
    "shade_strike_23": "Black Arm Stretch (Buu Saga)",
    "shade_art_12": "Black Explosion (Cell Games)",
    "shade_art_13": "Black Energy Assault (Androids Saga)",
    "shade_combat_02": "Black Scout Maneuver (Androids Saga)",
    "shade_combat_03": "Black Magic (Kid Buu Saga)",
    "shade_combat_04": "Black Secret (Buu Saga)",
    "shade_combat_05": "Black Taunting Attack (Androids Saga)",
    "shade_noncombat_01": "Black Searching Technique (Androids Saga)",
    "shade_noncombat_02": "Black Power Up (Androids Saga)",
    "shade_drill_04": "Black Confusion Drill (Androids Saga)",
    "shade_drill_05": "Black Anticipation Drill (Cell Games)",
    "shade_drill_06": "Black Erasing Drill (Frieza Saga)",
    "shade_drill_07": "Black Conservation Drill (Babidi Saga)",
    "shade_mastery_02": "Black Style Mastery (Cell Saga)",
    "shade_mastery_03": "Black Style Mastery (World Games)",
    "shade_mastery_04": "Black Style Mastery (Buu Saga)",
    "root_drill_05": "Namekian Remedy Drill (Kid Buu Saga 18)",
    "root_combat_07": "Namekian Offense (World Games Saga 77)",
    "root_mastery_02": "Namekian Style Mastery (Cell Saga)",
    "root_mastery_03": "Namekian Style Mastery (World Games)",
    "root_mastery_04": "Namekian Style Mastery (Buu Saga)",
    "root_noncombat_03": "Namekian Fighting (Trunks Saga 52)",
    "root_noncombat_04": "Namekian Teamwork (Androids Saga 103)",
    "root_combat_08": "Namekian Regeneration (Cell Saga 111)",
    "root_strike_17": "Namekian Foot Lunge (Cell Games 13)",
    "root_art_11": "Namekian Quick Blast (Cell Games 65)",
    "root_strike_18": "Namekian Shuto (Buu Saga 80)",
    "root_drill_06": "Namekian Precise Aim Drill (Movie promo M33)",
    "root_art_12": "Namekian Final Flash (World Games Saga 70)",
    "root_noncombat_05": "Namekian Blocking Stance (Androids Saga 21)",
    "root_strike_19": "Namekian Fist Dodge (Cell Games 11)",
    "personality_14": "Broly, the Enraged Saiyan (Lv 2, BMovie M2)",
    "freestyle_noncombat_19": "This Too Shall Pass (Frieza Saga 121)",
    "freestyle_noncombat_20": "Dragon's Glare (Frieza Saga Promo 4)",
    "freestyle_combat_21": "Feeding Frenzy (League promo L2-5)",
    "storm_drill_05": "Orange Spontaneous Drill (Saiyan Saga 137)",
    "storm_drill_06": "Orange Energy Dan Drill (Trunks Saga 138)",
    "storm_drill_07": "Orange Protection Drill (Fusion Saga 68)",
    "storm_drill_08": "Orange Hand-Clasp Drill (Kid Buu Saga 21)",
    "storm_strike_13": "Orange Car Push (Buu Saga 81)",
    "storm_strike_14": "Orange Searching Maneuver (Androids Saga 106)",
    "storm_art_24": "Orange Energy Break (Fusion Saga 65)",
    "storm_mastery_03": "Orange Style Mastery (World Games)",
    "storm_mastery_04": "Orange Style Mastery (Buu Saga)",
}


CARD_RENAMES = json.load(open("data/migrations/card_renames.json", encoding="utf-8"))["ids"]


def load_sources(path):
    out = dict(NEW_SOURCES)
    try:
        rows = list(csv.DictReader(open(path, encoding="utf-8")))
    except FileNotFoundError:
        return out
    for r in rows:
        cid = r["id"]
        for old, new in SEAL_RENAMES.items():
            if cid.startswith(old):
                cid = new + cid[len(old):]
        # A roster written before the generic ids of 2026-09-23 is keyed by the old ids.
        cid = CARD_RENAMES.get(cid, cid)
        # A source written into NEW_SOURCES is a correction or an addition and wins over the roster.
        if r.get("Source card", "") and cid not in NEW_SOURCES:
            out[cid] = r["Source card"]
    return out


def load_decks():
    used = {}
    for f in sorted(glob.glob("data/decks/*.json")):
        d = json.load(open(f, encoding="utf-8"))
        short = d["name"].replace("The ", "").split(" ")[0]

        def add(cid, what):
            used.setdefault(cid, []).append("%s %s" % (short, what))
        for cid in d["duelist"]:
            add(cid, "duelist")
        if d.get("mastery"):
            add(d["mastery"], "Mastery")
        if d.get("relic"):
            add(d["relic"], "Relic")
        for cid in sorted(set(d.get("reserve", []))):
            add(cid, "Reserve")
        for e in d["cards"]:
            add(e["id"], "x%d" % e["count"])
    return used


# Which personalities a deck names as its Duelist. There is no Duelist card type any more, so the
# roster reads the role off the decks: a personality a deck names leads it, and every other
# personality is an Ally in whatever deck runs it.
def duelist_ids():
    out = set()
    for f in sorted(glob.glob("data/decks/*.json")):
        out.update(json.load(open(f, encoding="utf-8"))["duelist"])
    return out


DUELIST_IDS = duelist_ids()


def section_of(card):
    t = card["type"]
    if t == "Personality":
        return "Duelists" if card["base"] in DUELIST_IDS else "Allies"
    if t in ("Relic", "Mastery"):
        return "Relics and Masteries"
    if t == "Seal":
        return "Seals"
    if t == "Grounds":
        return "Grounds"
    if card["school"]:
        return SCHOOL_SECTION[card["school"]]
    if t in ("Strike", "Art"):
        return "Freestyle: Strikes and Arts"
    if t == "Combat":
        return "Freestyle: Combat cards"
    return "Freestyle: Non-Combats and Drills"


def brief_of(card):
    cid = card["id"]
    if cid in ART:
        return ART[cid]
    if card["type"] == "Seal":
        n = int(card["seal_number"])
        return SEAL_SETS[card["seal_set"]] % (n, n)
    raise SystemExit("no art brief for %s" % cid)


def shows(card):
    return SHOWS.get(card["base"], card.get("character", "")) or ""


def palette_of(card, who):
    if card["type"] == "Seal":
        return SEAL_PALETTE[card["seal_set"]]
    # Three cases, in order. A card carrying a school takes that school's colour. A card carrying
    # a character's name takes the personality colour, which belongs to no school. Anything else
    # is Freestyle. A character is not a school, so the character never supplies one.
    school = card["school"]
    if school not in ("", "freestyle"):
        return PALETTE[school]
    if who:
        return PERSONALITY_PALETTE
    return PALETTE[""]


def prompt_of(card, brief):
    who = shows(card)
    parts = [STYLE, FRAMING[card["type"]], palette_of(card, who)]
    if who in IDENTITY:
        parts.append(IDENTITY[who])
    parts.append(brief)
    return " ".join(parts)


def main(dump):
    cards = load_cards(dump)
    sources = load_sources("docs/card_roster.csv")
    used = load_decks()
    rows = []
    # Each Aspect is its own card since 2026-09-21, so one card is one row and one art file,
    # named by that card's own id, whichever role it fills.
    for c in cards:
        brief = brief_of(c)
        rows.append({
            "Section": section_of(c), "id": c["id"], "Name": c["title"], "Type": c["type_line"],
            "Canvas": CANVAS[c["type"]], "Effect": c["text"], "Shows": shows(c), "Art brief": brief,
            "Prompt": prompt_of(c, brief), "Source card": sources.get(c["id"], ""),
            "Used by": ", ".join(used.get(c["base"], [])),
        })
    rows.sort(key=lambda r: (SECTION_ORDER.index(r["Section"]), r["id"]))
    for i, r in enumerate(rows, 1):
        r["#"] = i
    fields = ["#", "Section", "id", "Name", "Type", "Canvas", "Effect", "Shows", "Art brief", "Prompt", "Source card", "Used by"]
    with open("docs/card_roster.csv", "w", encoding="utf-8", newline="\n") as f:
        w = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    write_md(rows)
    missing = [r["id"] for r in rows if not r["Source card"]]
    print("%d rows, %d without a source card%s" % (len(rows), len(missing), (": " + ", ".join(missing)) if missing else ""))


def esc(s):
    return s.replace("|", "\\|")


def write_md(rows):
    out = ["# Card roster", "",
           "Art pass roster, one row per image. Generated by `tools/gen_roster.py` from the shipped data; the "
           "prompt pieces (style, framing, palettes, cast identities, briefs) are edited in that file. The CSV's "
           "`Prompt` column is the assembled, ready-to-paste prompt for each row: style, framing for the card "
           "type, palette for the school, the character's identity string when one is shown, then the brief. "
           "Canvas sizes are the roster's own pixel canvases (the faces render them at twice that).", "",
           "Setting in one line: mages duel over a place of power on the leylines, where seven seals carved "
           "into a gate let an Eidolon through. The Vigil stands watch so that whatever comes answers to "
           "someone who will hold it in check; the Pact bargained passage for power. Tone: earnest, a little grim.", "",
           "## Prompt pieces", "", "**Style, every card:** " + STYLE, "", "**Framing by card type:**", ""]
    for t, f in FRAMING.items():
        out.append("- %s: %s" % (t, f))
    out += ["", "**Palette by school:**", ""]
    for s, p in PALETTE.items():
        out.append("- %s: %s" % (s or "Freestyle", p))
    out.append("- Cards carrying a character's name: %s" % PERSONALITY_PALETTE)
    for s, p in SEAL_PALETTE.items():
        out.append("- %s seals: %s" % (s.capitalize(), p))
    out += ["", "## Cast", "",
            "Identity strings are reused verbatim on every card that shows the character. They are listed",
            "with each character's lore and forms in `cast.md`; the source is `CAST` in `tools/gen_roster.py`.", ""]
    section = None
    for i, r in enumerate(rows):
        if r["Section"] != section:
            section = r["Section"]
            out += ["## %s" % section, "", "| # | id | Name | Type | Canvas | Effect | Shows | Art brief | Source card | Used by |",
                    "|---|---|---|---|---|---|---|---|---|---|"]
        out.append("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["#"], r["id"], esc(r["Name"]), r["Type"], r["Canvas"], esc(r["Effect"]), r["Shows"], esc(r["Art brief"]),
            esc(r["Source card"]), r["Used by"]))
        if i == len(rows) - 1 or rows[i + 1]["Section"] != section:
            out.append("")
    open("docs/card_roster.md", "w", encoding="utf-8", newline="\n").write("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1])
