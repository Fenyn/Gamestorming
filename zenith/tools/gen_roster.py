"""Rebuilds docs/card_roster.csv and docs/card_roster.md from the shipped data.

Run tools/dump_cards.gd first (it writes cards.jsonl from the engine's own rules text), then:
    python tools/gen_roster.py <cards.jsonl>

Rules text, types, sections and deck usage come from the data. The source-card column is kept
from the existing CSV by id. Everything an image generator needs lives in this file: the shared
STYLE clause, a FRAMING clause per card type, a PALETTE clause per school, a fixed identity
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
                  "tide": "Tide (Rooke)", "storm": "Storm (Corven)", "root": "Root (Thornwald)"}
SECTION_ORDER = ["Duelists", "Allies", "Relics and Masteries", "Pyre (Ashmark and Rooke)", "Steel (Quarr)",
                 "Shade (Draik and Salvage)", "Tide (Rooke)", "Storm (Corven)", "Root (Thornwald)",
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

# Character identities: a fixed string reused verbatim on every card that shows the character,
# so a generator keeps them consistent. (name, school/side, deck, identity, note for the md)
CAST = [
    ("Bram Ashmark", "Pyre · Pact", "Ashmark the Pyromancer",
     "Bram Ashmark: man in his early twenties, lean, soot-streaked pale skin, singed short dark hair, half-plate over a scorched gambeson, plain longsword with a heat shimmer.",
     "The Pact shows as light under the skin: faint at Kindled, cracks by Unquenchable."),
    ("Halden Quarr", "Steel · Pact", "Quarr the Ironblood",
     "Halden Quarr: huge man in his forties, shaved head, brawler's build, bare arms, skin greying to iron in patches, black knuckles, raised welded scars, no armour.",
     "The Pact shows as iron spreading over more of him each Aspect."),
    ("Sable Draik", "Shade · Pact", "The Draik Company",
     "Sable Draik: woman in her thirties, brown skin, tattooed forearms, long dark coat, a bottle at her hip, sardonic half-smile.",
     "The Pact shows as shadow pooling around her and the light leaving her eyes."),
    ("Vesna Draik", "Shade · Pact", "The Draik Company", "Vesna Draik: wiry hooded woman, two knives, face half hidden.", "The ambusher."),
    ("Brann Draik", "Shade · Pact", "The Draik Company", "Brann Draik: broad bald man, leather vest, heavy hands, easy menace.", "The muscle."),
    ("Halvard Draik", "Shade · Pact", "The Draik Company", "Halvard Draik: tall man, red cloak, twin curved swords, duellist's poise.", "The swordsman."),
    ("Quill Draik", "Shade · Pact", "The Draik Company", "Quill Draik: thin young man, spectacles, ink-stained fingers, satchel of pages.", "The hexer proper."),
    ("Pim", "Shade · Pact", "The Draik Company", "Pim: small quick youth, patched clothes, sack over one shoulder.", "The scavenger, no surname."),
    ("Dame Alder Rooke", "Tide · Vigil", "The Rooke Coven",
     "Dame Alder Rooke: woman in her sixties, straight-backed, long grey hair, red gown over grey mail, round shield and longsword.",
     "The Vigil shows as water: climbing her, filling her, then she is the flood."),
    ("Wren Rooke", "Tide · Vigil", "The Rooke Coven", "Wren Rooke: teenage girl, red-brown hair, blue coat, satchel of loose pages.", "Youngest of the coven."),
    # The element is the printing's, not the man's: he carries water in his wife's line and fire in
    # his own, and each card's art takes it from that card's effects. See docs/cast_backlog.md.
    ("Sir Edric Rooke", "Vigil", "Edric the Ember Knight", "Sir Edric Rooke: knight in grey mail, plain longsword, open helm under one arm, weathered and unhurried.", "The knight. Fields Pyre in his own list and Tide beside the coven."),
    ("Emrys Rooke", "Vigil", "(no deck yet)", "Emrys Rooke: serious young man, dark hair, grey fencing doublet over mail, longsword held two-handed.", "The eldest son, and a swordsman where his parents are casters."),
    ("Torvan Hask", "Pact", "(no deck yet)", "Torvan Hask: heavy-shouldered man in scarred riding leathers, long unbound hair, a hand axe at the belt, Edric's face ten years harder.", "Edric's elder brother, from the line Edric left."),
    ("Ansel Rooke", "Tide · Vigil", "The Rooke Coven", "Ansel Rooke: young man, broad shoulders, blue-grey gambeson, round shield.", "The middle son."),
    ("Tavin Vale", "Tide · Vigil", "The Rooke Coven", "Tavin Vale: slim young man, dark hair tied back, blue robe over a fencing doublet, hands open for casting.", "A Vale cousin fostered with the Rookes."),
    ("Ansel and Tavin, Back to Back", "Tide · Vigil", "The Rooke Coven", "Ansel Rooke and Tavin Vale standing back to back, shield and water between them.", "The Bond."),
    ("Caedan Vale", "Freestyle · Vigil", "Vale the Swordmaster",
     "Caedan Vale: slight man in his late twenties, dark hair, grey fencing doublet, one longsword, no magic.",
     "Aspects stay human: stiller each time, grey at the temples by Peerless."),
    ("Siphon", "Storm · Pact", "The Corven Collegium",
     "Siphon: humanoid construct of grey stone and copper wire, sigils cut into its chest, a smooth faceless head, a glass core at the sternum.",
     "Dormant it is a statue, charged it hums, unbound it arcs."),
    ("Tithe", "Storm · Pact", "The Corven Collegium",
     "Tithe: smaller stone-and-copper construct, cruder sigils than Siphon's, a cracked shoulder never repaired, a slot in its chest where cards go in.",
     "Works from the side and never asks to lead. It takes one, and it is paid."),
    # Constructs from outside the Collegium. One word each, naming what they are for.
    ("Sledge", "Freestyle · Pact", "(unaffiliated construct)",
     "Sledge: broad pit-fighting construct of riveted plate over a squat frame, one arm heavier than the other, dents never beaten out.",
     "Built to win bouts, and named by the crowd that bet on him."),
    ("Mercy", "Freestyle · Pact", "(unaffiliated construct)",
     "Mercy: very tall construct of pale stone and worn brass, a broad blunt face, hands too big and too careful, no weapon anywhere on it.",
     "Made for work rather than war, and slow to agree to this."),
    ("Scorn", "Freestyle · Pact", "(unaffiliated construct)",
     "Scorn: lean construct of blackened iron, hands in its pockets, head tilted, a face cast with a permanent half-smile.",
     "Kin to Marrow, and bored by all of it."),
    ("Marrow", "Shade · Pact", "Marrow the Amalgam",
     "Marrow: a construct assembled out of several older ones, no two pieces matching: a war-frame torso in scorched plate, one slender arm and one heavy, a face-plate of pale stone with the old owner's name still stamped under the jaw.",
     "Not one construct and never was. The Pact shows as more of her each Aspect: crude at Patchwork, past what any part was built for by Overwrought, all of it at once at the end."),
    ("Cull", "Shade · Pact", "Marrow the Amalgam",
     "Cull: elderly wright in a construct's body, a stooped brass frame over a spine of copper, spectacles wired to the face-plate, a roll of instruments open at the hip.",
     "Collegium-trained, and put himself in a frame rather than keep building them for other people. They do not claim him."),
    ("Orvath Kell", "Shade · Pact", "Marrow the Amalgam",
     "Orvath Kell: gaunt man in a high-collared grey coat, shaven head, an officer's gorget he has not taken off, both hands bare and raised.",
     "Not a construct. Last officer of a company that fielded them and left them where they fell, walking the same ground for his own reasons."),
    ("Gideon Mourne", "Shade · Pact", "Marrow the Amalgam",
     "Gideon Mourne: proud man in his thirties, scarred brow, black brigandine with a broken crest still riveted to the chest, a signet he has not sold, hands crackling.",
     "Not a construct. A lord who was stripped of it, still signs himself Lord Mourne, and nobody corrects him to his face. Sells the craft cheap now, to whoever is going somewhere."),
    ("Osric Thornwald", "Root · Vigil", "The Thornwald Grove",
     "Osric Thornwald: old man, long grey beard, ranger's leathers gone green with moss, a staff strung as a bow, bark growing over one hand.",
     "The Vigil shows as the grove taking him: more tree and less man each Aspect."),
]
IDENTITY = {c[0]: c[3] for c in CAST}
CAST_SCHOOL = {c[0]: c[1].split(" ")[0].lower() for c in CAST}   # a Freestyle character keeps ""
SEAL_PALETTE = {
    "sun": "Accent old gold, a thin line of green seawater, warm torchlight.",
    "moth": "Accent bone white and silver, pale dust, cold torchlight.",
    "marble": "Accent veined grey marble, raw scaffold wood, neutral torchlight.",
    "salt": "Accent salt white and dull steel, damp grey stone, a low clean light.",
}

# Which named character each character-bound card shows. Cards not listed take the character
# from their data (`character`) or none.
SHOWS = {
    "duelist_alpha": "Bram Ashmark", "duelist_epsilon": "Halden Quarr", "duelist_delta": "Sable Draik",
    "duelist_beta": "Dame Alder Rooke", "duelist_eta": "Osric Thornwald", "duelist_gamma": "Siphon",
    "duelist_zeta": "Caedan Vale",
    "henchman_alpha": "Vesna Draik", "henchman_beta": "Brann Draik", "henchman_delta": "Halvard Draik",
    "henchman_epsilon": "Pim", "henchman_gamma": "Quill Draik", "henchman_zeta": "Tithe",
    "companion_alpha": "Wren Rooke", "companion_beta": "Sir Edric Rooke", "companion_delta": "Ansel Rooke",
    "companion_gamma": "Tavin Vale", "bonded_pair": "Ansel and Tavin, Back to Back",
    "black_hands": "Sable Draik", "draiks_reckoning": "Sable Draik", "lingering_curse": "Sable Draik",
    "branns_shakedown": "Brann Draik", "halvards_twin_cut": "Halvard Draik", "vesnas_ambush": "Vesna Draik",
    "quarrs_crushing_blow": "Halden Quarr", "quarrs_roar": "Halden Quarr", "shrugs_it_off": "Halden Quarr",
    "rookes_deluge": "Dame Alder Rooke", "edrics_vow": "Sir Edric Rooke",
    "scatters_the_ashes": "Bram Ashmark", "stokes_the_coals": "Bram Ashmark", "wall_of_flame": "Bram Ashmark",
    "will_not_break": "Bram Ashmark",
    "vales_pommel_bash": "Caedan Vale", "vales_quickstep": "Caedan Vale", "vales_riposte": "Caedan Vale",
    "vales_sword_draw": "Caedan Vale", "vales_insight": "Caedan Vale", "heirloom_blade": "Caedan Vale",
    "sledges_stance": "Sledge", "siphons_sidestep": "Siphon", "mercy_smiles": "Mercy", "scorn_smirks": "Scorn",
    "duelist_theta": "Marrow", "marrows_retinue": "Marrow", "cold_appraisal": "Marrow",
    "mournes_stance": "Gideon Mourne", "mournes_quickness_drill": "Gideon Mourne", "mournes_jolting_arc": "Gideon Mourne",
    "mourne_takes_measure": "Gideon Mourne", "mournes_frantic_rush": "Gideon Mourne", "mournes_smirk": "Gideon Mourne",
    "mournes_plans": "Gideon Mourne",
    "salvage_alpha": "Cull", "salvage_beta": "Orvath Kell", "salvage_gamma": "Gideon Mourne",
    "scattered_ashes": "Bram Ashmark", "sabotage": "Siphon", "absorbing_drill": "Cull",
    "committed_cut": "Sir Edric Rooke", "quick_retreat": "Sir Edric Rooke",
    "first_cut": "Sir Edric Rooke", "keepers_drill": "Sir Edric Rooke",
    "duelist_iota": "Sir Edric Rooke", "edrics_truce": "Sir Edric Rooke",
    "edrics_opening_strike": "Sir Edric Rooke", "edrics_training": "Sir Edric Rooke",
    "companion_epsilon": "Dame Alder Rooke", "hasks_flying_kick": "Torvan Hask",
}

# Slot brief per card: subject, action, two or three concrete details, mood. Short, visual, no rules.
ART = {
    # Duelists
    "duelist_alpha_a1": "Kindled. Grinning, blood on his knuckles, embers in his eyes, heat shimmer off the blade, no open flame yet.",
    "duelist_alpha_a2": "Wildfire. Flame licking off his shoulders, cracks of orange light along his forearms, sword raised overhead, coals glowing in the steel.",
    "duelist_alpha_a3": "Unquenchable. Fully wreathed in fire, face barely visible in it, caught mid-charge, sparks trailing.",
    "duelist_epsilon_a1": "The Grinder. Brawler's crouch, fists up, black knuckles, breath steaming, hungry look.",
    "duelist_epsilon_a2": "Tempered. Chest and shoulders greyed to iron, veins like solder, one foot on a discarded page.",
    "duelist_epsilon_a3": "Ironheart. Chest plated in living iron, a dull red heart glowing through it, both fists cocked.",
    "duelist_delta_a1": "Captain. Coat open, boot on a crate, a torn company flag behind her, crew silhouettes at the edges, amused.",
    "duelist_delta_a2": "Shrouded. Shadow pooled at her feet and climbing her coat, half her face in darkness, one hand out.",
    "duelist_delta_a3": "Lightless. Eyes fully black, the light in the frame dying toward her, shadow streaming off her arms.",
    "duelist_iota_a1": "The Hero. Standing easy, sword point down, hand raised to hold a line back, no fire on him yet.",
    "duelist_iota_a2": "The Stranger. Helm off, looking at his own hands, a thin orange seam of heat along one forearm, the Hask axe on the ground behind him.",
    "duelist_iota_a3": "The Realm's Hero. Mid-stride into a burning street, coals under his boots, shield arm shielding somebody out of frame.",
    "duelist_iota_a4": "Kindled Through. Fire running up the blade and along the mail seams, teeth set, one fist cocked.",
    "duelist_iota_a5": "The All Powerful. Wreathed to the shoulders, the sword a bar of white heat, everything around him going to ash.",
    "duelist_beta_a1": "Matriarch. Shield up, sword low, three hooded coven figures behind her, stern.",
    "duelist_beta_a2": "Rising Water. Water climbing her mail to the waist, eyes gone sea-glass green, a knight at her shoulder.",
    "duelist_beta_a3": "The Flood. A wave rising off her shoulders, face calm as deep water, the ground at her feet awash.",
    "duelist_eta_a1": "Greybeard. Sitting on his heels, staff across his knees, moss on the leathers, reading a torn page.",
    "duelist_eta_a2": "Overgrown. Bark up both forearms, leaves in the beard, staff mid-swing, green pushing through grey.",
    "duelist_eta_a3": "Deep-Rooted. Roots running from his boots into the ground, a staff blow landing, a cut on his arm closing over in bark.",
    "duelist_eta_a4": "Heartwood. Torso gone to living wood, ribs of bark, leaves budding at the shoulders, staff planted.",
    "duelist_eta_a5": "Grovelord. A standing tree with a bearded face, arms become boughs, one hand still holding the staff.",
    "duelist_gamma_a1": "Dormant. Standing still as a statue, sigils dark, one hand raised palm out catching a fading bolt.",
    "duelist_gamma_a2": "Charged. Sigils lit blue-white, a haze of static around it, a blade sliding off a ward of light.",
    "duelist_gamma_a3": "Unbound. Arcs jumping between its limbs, the glass core bare and blazing, both hands throwing charge.",
    "duelist_zeta_a1": "Last Heir. Longsword in a textbook guard, chin up, young and exact, a worn sword-school crest on the doublet.",
    "duelist_zeta_a2": "Unparried. Mid-lunge, the point leading, no wasted motion, a ribbon of displaced air.",
    "duelist_zeta_a3": "Spellcutter. A cut finishing through a fading spell, the rival's hand at the frame edge pinned.",
    "duelist_zeta_a4": "The Quiet Blade. Standing still, point steady, grey at the temples, the air around him clear while spells break at a distance.",
    "duelist_zeta_a5": "Peerless. Older, sword lowered, walking forward unhurried, three faint ghost images of the next moves ahead of him.",
    "duelist_theta_a1": "Patchwork. Standing square in a field of broken constructs, held together with strap and wire, the stamped name under her jaw catching the light.",
    "duelist_theta_a2": "Rebuilt. Properly seated joints and beaten-out plate, a struck blade skidding off her shoulder without leaving a mark on it.",
    "duelist_theta_a3": "Overwrought. Built past what any part was for: too many plates, too much arm, a seam glowing where it should not.",
    "duelist_theta_a4": "Fury Amalgam. All of it moving at once, mid-swing, pieces of a dozen constructs in one shape and none of them idle.",
    # Allies
    "henchman_alpha": "Coming in from the frame edge, knives out, hood up.",
    "henchman_beta": "Cracking his knuckles, leaning over the viewer.",
    "henchman_delta": "Both swords drawn in a crossed guard, cloak lifting.",
    "henchman_epsilon": "Crouched over a pile of torn pages, holding one up to the light.",
    "henchman_gamma": "Reading a hex off a page, one finger tracing it, purple ink glowing.",
    "henchman_zeta": "Stepping in front of the viewer, shoulder first, a spark at the cracked joint.",
    "companion_alpha": "Gathering loose pages into her satchel, some floating back to her.",
    "companion_beta": "Sword raised, a focused jet of water along the blade.",
    "companion_delta": "Shield braced, water refilling a cracked flask at his hip.",
    "companion_epsilon": "Stepping in front of a blow meant for someone else, shield up, no water raised at all, furious.",
    "companion_gamma": "Hands open, a globe of water between them, pages settling into a deck at his feet.",
    "bonded_pair": "Back to back, water curling around the shield, both looking outward.",
    "salvage_alpha": "Selecting an instrument from the open roll without looking down, mild and unhurried.",
    "salvage_beta": "Both palms raised over a fallen construct, the hex uncoiling between them, the gorget still buckled on.",
    "salvage_gamma": "Mid-cast, the broken crest on his chest turned to the viewer, light bleeding off his knuckles.",
    # Relics and Masteries
    "blank_mask": "A featureless white porcelain mask, no eye holes, on black cloth.",
    "debtors_ring": "A heavy iron ring pressed with someone else's mark, a wax seal beside it.",
    "lodestone_heart": "A dark magnetic stone on a chain, iron filings drawn to it, on grey cloth.",
    "freestyle_mastery": "A worn leather training manual, spine cracked, a single steel pin holding a page.",
    "pyre_mastery": "A brazier of coals with a single tongue of flame, a burnt page curling in it.",
    "steel_mastery": "A clenched iron fist with a single card turned face up beneath it.",
    "shade_mastery": "A hand of cards seen through a black veil, one card rotting at the corner.",
    "tide_mastery": "A tide line on stone, water drawing back, a single coin left behind.",
    "storm_mastery": "A copper coil with a spark jumping across the gap.",
    "root_mastery": "A page half buried in soil with a root growing through it, a green shoot rising.",
    # Pyre
    "pyre_ashfall": "Grey ash raining down on a burning circle of runes, embers in the fall.",
    "pyre_backdraft": "A door thrown open, fire rushing out and swallowing a bolt of light.",
    "pyre_blazing_charge": "A running figure wreathed in flame, sword forward, cutting through a raised guard.",
    "pyre_cinder_guard": "A guard of drifting cinders catching a blade, the edge glowing where it touches.",
    "pyre_comet_fall": "A fist of fire brought down from above, a trail of sparks behind it.",
    "pyre_firestorm": "A whirl of flame across a stone floor, rune circles and a hooded figure caught in it.",
    "pyre_flame_lash": "A whip of flame at full extension, coiling back on itself.",
    "pyre_flashover": "A room igniting all at once, a dropped card at the centre.",
    "pyre_furnace_breath": "A figure exhaling a gout of heat, the air rippling.",
    "pyre_immolation": "A rune circle wrapped in flame, burning down to nothing.",
    "pyre_kindling": "A small sharp fire lit at the tip of a blade, lighting the whole edge.",
    "pyre_rekindling": "Coals stirred back to flame, a burnt card lifting from the ash whole.",
    "pyre_scouring_flame": "A tongue of fire scouring a rune circle off a stone floor.",
    "pyre_searing_guard": "A raised forearm glowing red, a blade stopping against it and smoking.",
    "pyre_snuffing": "A fist closing on a small flame, the smoke of it.",
    "pyre_twin_flames": "Two flames from one motion, a sword and an open hand both lit.",
    # Steel
    "steel_battering_ram": "A shoulder charge, iron skin, the impact ringing.",
    "steel_bracing": "Iron forearms crossed, feet set, a blow absorbed.",
    "steel_bull_charge": "Head down, charging, a shockwave off the brow.",
    "steel_crushing_weight": "A grapple bringing a heavy body down on a rune circle, the stone cracking.",
    "steel_dead_weight": "A hit landing on the chest, the air knocked out in a visible cloud.",
    "steel_forearm_guard": "An iron forearm turning a blade, sparks.",
    "steel_hammer_blow": "Both fists together coming down, the ground cracking under the target.",
    "steel_headbutt": "An iron forehead meeting a rune circle, the runes shattering.",
    "steel_immovable_guard": "A wide stance, unmoved, a blade bent against an iron shoulder.",
    "steel_iron_fist": "A straight punch, the fist solid iron, mid-flight.",
    "steel_iron_jab": "A short jab, the knuckles iron, the rival's guard buckling.",
    "steel_iron_knee": "A rising knee, iron kneecap, a seal glowing on the gate behind.",
    "steel_ironhide": "Skin gone to iron plate across the chest, a blade skating off.",
    "steel_piston_slam": "A downward slam with the whole arm, the shockwave sending cards skidding.",
    "steel_scar_tissue": "Old scars knitted into iron plates, a fist raised.",
    "steel_shockwave": "A pulse of force from an open palm, dust and pages blown back.",
    "steel_skull_crack": "A crack of iron on a helm, the helm splitting.",
    "steel_standoff": "Two heavy figures a pace apart, neither moving, dust settling.",
    "steel_tempering": "A fist glowing orange at the knuckles, steam rising.",
    "steel_triple_shock": "Three pulses of force from the chest, rings in the air.",
    "quarrs_crushing_blow": "An overhand hammer-fist coming down, a rune circle breaking under it.",
    "quarrs_roar": "Roaring, chest out, the shout visible as a shockwave.",
    "shrugs_it_off": "Taking a blow to the shoulder and rolling it off, unbothered.",
    # Shade
    "shade_composure_drill": "A row of cards laid face down on iron, one hand resting flat across them.",
    "shade_cutting_hand": "A flat hand cutting through a bolt of light, the bolt splitting around it.",
    "shade_gathering_dark": "Shadow drawn in from the whole frame toward one closed fist.",
    "shade_rending_palm": "An open palm driven forward, the air torn in a ring around it.",
    "shade_snaring_web": "A web of black filament strung across the frame, a bolt tangled and dying in it.",
    "shade_takedown_drill": "A felled figure and a hand already reaching past them for a card.",
    "shade_warding_burst": "A short shove of dark force at close range, the rival's guard thrown wide.",
    "shade_dread_grip": "A hand of shadow closing on a throat, a card slipping from the victim's fingers.",
    "shade_hex_recall": "A veil of shadow thrown up, a card drawn back through it.",
    "shade_mind_rot": "Dark threads reaching into a figure's temples, two cards blackening in their hand.",
    "shade_nightmare_hold": "A figure held rigid in a grip of shadow, eyes open, dreaming badly.",
    "shade_oblivion_touch": "A fingertip touching a card, the card fading to nothing.",
    "shade_umbral_lash": "A whip of shadow catching a blade mid-swing.",
    "shade_unraveling": "A rune circle and a card unpicking into black thread.",
    "shade_veil": "A curtain of shadow drawn across the frame, a blade lost in it.",
    "black_hands": "Her hands black to the elbow, six knives of shadow flying from them.",
    "draiks_reckoning": "Holding a ledger open, two columns of coins swept level, shadowed crew standing behind her.",
    "lingering_curse": "A hex settling like ink on a figure's shoulders, staining down.",
    "branns_shakedown": "One hand tearing a rune circle in half, the other holding a stolen seal.",
    "halvards_twin_cut": "Two cuts in one motion, one turning a blade, the other taking a card from a hand.",
    "vesnas_ambush": "Dropping from above with both knives, hooded figures below frozen mid-step.",
    # Tide
    "tide_breakwater": "A wall of standing water, a bolt of light breaking on it.",
    "tide_confluence": "Two currents meeting head-on, a rune circle swept away in the join.",
    "tide_depths": "A hand reaching down into dark water and closing on a card.",
    "tide_drowning": "A rune circle pulled under a rising pool.",
    "tide_ebb": "Water drawing back from a figure's feet, taking a glow with it.",
    "tide_high_water": "The tide at its mark on a stone gate, the ground changing under it.",
    "tide_springwater": "Clear water rising from cracked stone, a figure standing up out of it.",
    "tide_surge": "A surge of water hitting and parrying a blade at once.",
    "tide_torrent": "An open channel of water pouring from two hands, no end to it.",
    "tide_twin_breaker": "Two breakers crashing in from either side of the frame.",
    "tide_twin_swell": "Two swells rising one behind the other.",
    "tide_undertow": "A strike from below out of water, a bolt dragged down with it.",
    "rookes_deluge": "Arms raised, the coven's water released all at once across a stone floor, rune circles washing away.",
    "edrics_vow": "Kneeling, sword offered hilt first to a gauntleted hand, water running off the blade.",
    # Storm
    "storm_arc_bolt": "A single bright arc from a fingertip to the frame edge.",
    "storm_chain_lightning": "Lightning forking from one target to the next.",
    "storm_charged_ward": "A ward of static around a figure, a bolt dissolving on it.",
    "storm_maelstrom": "A storm brought down bodily onto a stone floor, rune circles blown away.",
    "storm_overcharge": "A punch with too much charge in it, arcs bleeding off the knuckles.",
    "storm_recharge": "A strike, then lightning drawn back into an open hand.",
    "storm_smiting_bolt": "A bolt from above striking a rune circle.",
    "storm_static_field": "A field of static, a blade stopping in it, hair standing up.",
    "storm_thunderhead": "A thunderhead building over a duelling floor, rune circles lifting in the wind.",
    "sledges_stance": "Squaring up in a fighting pit, weight set, the heavier arm cocked back.",
    "siphons_sidestep": "Stepping aside mechanically, a blade passing where it stood.",
    "mercy_smiles": "A huge blunt face looking down, almost apologetic, one big hand raised and a blade stopping against it.",
    # Root
    "root_bolt": "A volley of thorns from a swung staff.",
    "root_dash": "A boar's rush through undergrowth, leaves flying.",
    "root_destruction_blast": "A blast of splintering wood, a stump exploding outward.",
    "root_dragon_blast": "Old growth wood thrown as a spear, marble seals glowing on a gate behind.",
    "root_energy_catch": "Cupped bark hands catching rain and a bolt of light with it.",
    "root_energy_deflection": "Barkskin on a forearm turning a bolt aside.",
    "root_energy_focus": "A still moment in a grove, a single page rising from the leaf litter.",
    "root_firm_stance": "Feet rooted into stone, a blade stopping against a staff.",
    "root_preparation_drill": "A tracker's kneeling read of sign, five stones set in a row.",
    # Freestyle: Strikes and Arts
    "all_or_nothing": "A whole-body strike, feet leaving the ground, everything committed.",
    "blinding_flare": "A flare thrown in a figure's face, hands coming up too late.",
    "captains_barrage": "A volley of thrown knives from an unseen line of hands.",
    "clean_sweep": "A wide two-handed cut sweeping a row of rune circles off a floor.",
    "committed_cut": "A cut with the whole body behind it, the follow-through finishing at the floor.",
    "dead_air": "A bolt of light dying mid-air in a still room, dust hanging.",
    "declaration": "A figure shouting into the frame, a shockwave of sound, a hand raised.",
    "grounding_step": "A stamped foot, a bolt of light earthing into the stone.",
    "headlong_plunge": "A reckless dive into a raised guard, the guard breaking.",
    "hilt_guard": "A block with the crossguard, sparks, a card lifting from the floor.",
    "knife_volley": "Knives thrown from every direction at once.",
    "last_ward": "A last desperate guard, sword and empty hand both up.",
    "lobbed_bolt": "A bolt of light thrown in a high arc over a raised guard.",
    "no_quarter": "A strike thrown with a snarl, nothing held back, no exit in the frame.",
    "old_habit": "A backhand thrown without looking, a page fluttering back into a hand.",
    "overreach": "A figure reaching past their own light, the halo behind them tearing.",
    "mournes_stance": "Feet planted wide, a blade stopped, another blade stopping behind it.",
    "practiced_guard": "A drilled guard, a shield brace lifting from the floor as it holds.",
    "quick_retreat": "A step back out of reach, the blade passing a hand's width off.",
    "mournes_frantic_rush": "A lunge past the point of balance, landing anyway.",
    "relentless_fury": "A strike thrown mid-flurry, three more already in motion.",
    "sabotage": "A gloved hand cutting the threads of a rune circle.",
    "scattered_ashes": "A bolt of light hitting a pile of cards, the ash blowing away.",
    "scatters_the_ashes": "Swinging through a pile of burnt pages, ash scattering, embers taken into his blade.",
    "seal_seizure": "A blade prying a seal off a stone gate.",
    "second_wind": "A block, then a deep breath, a flask refilling.",
    "sharp_rebuke": "A bolt of light hitting a figure square, their halo stripped away.",
    "smoke_screen": "A bolt landing in smoke, two figures losing each other in it.",
    "suppressing_shot": "A bolt pinning a casting hand to a wall of light.",
    "sword_flourish": "A flourish of the sword, the arc leaving a bright trail.",
    "sword_lunge": "A long lunge, the point at a figure's chest, their light dimming.",
    "sword_sweep": "A low sweeping cut through a line of standing figures.",
    "sword_thrust": "A thrust through two rune circles at once.",
    "mournes_jolting_arc": "An arc of light thrown low, a rival's blade arm dropping out of the guard.",
    "threefold_bolt": "One bolt already landed, a second in flight, a third still forming at the hand.",
    "unerring_bolt": "A bolt of light flying dead straight through a guard.",
    "unyielding_guard": "A guard that does not move, blade after blade stopping on it.",
    "vales_pommel_bash": "The pommel driven into a face after a parry, the rival reeling.",
    "vales_quickstep": "A quick side-step and cut, a signature page lifting from the floor.",
    "vales_riposte": "A parry turning into the same cut thrown back.",
    "vales_sword_draw": "A draw cut from the scabbard, the blade catching light.",
    "wall_of_flame": "A wall of fire raised with one hand, a blade and a bolt both stopping in it.",
    # Freestyle: Combat cards
    "scorn_smirks": "Hands in pockets, head tilted, every rune circle on the floor cracking and going dark behind him.",
    "closing_ranks": "A line of allies closing shoulder to shoulder behind a duelist.",
    "cold_appraisal": "A gloved hand fanning another's cards, one pulled out.",
    "cut_short": "A hand catching a wrist mid-gesture.",
    "dismissal": "Every figure but two fading from a duelling floor.",
    "marrows_retinue": "Two made figures stepping out of the dark at once, already at full light.",
    "rites_unmade": "A floor of chalked rites scuffed through in one long drag.",
    "hired_blades": "A purse of coins handed over, a sellsword stepping into the frame.",
    "keen_eye": "A close eye reading the top card of a deck.",
    "kept_at_bay": "A sword point held level at a rival's chest, keeping them at a distance.",
    "last_gasp": "A figure on one knee, light gone out of them, a pile of cards burning beside them.",
    "mutual_escalation": "Two duelists both blazing with light, the ground between them cracking.",
    "old_trick": "A card slipped from a sleeve.",
    "parley": "Two blades lowered, a hand raised palm out.",
    "quiet_study": "A figure reading a card by candlelight.",
    "rallying_call": "A raised fist and a shout, an ally running in from the frame edge.",
    "reckless_ascent": "A figure dragged upward by their own light, feet leaving the ground, halo tearing.",
    "respite": "A figure sitting on stone catching their breath, two cards lifting from the floor.",
    "sever_the_leyline": "A line of pale light in the ground cut through with a blade, the far end going dark.",
    "stillness": "A duelling floor with every blade and bolt stopped mid-air.",
    "terms_of_the_pact": "A contract held up, one clause struck through.",
    "warding_call": "A shout, an ally arriving, seals falling from a stone gate.",
    "watchful_eye": "A single eye watching over the top of a fan of cards.",
    "will_not_break": "Standing in the middle of the frame with fire around him, unmoved, a blade stopped on his forearm.",
    "keepers_drill": "A hand resting flat over a carved seal, protective.",
    # Freestyle: Non-Combats and Drills
    "absorbing_drill": "A sponge-like stone drinking a bolt of light, two pages burning beside it.",
    "bonding_rite": "Two cards laid face to face under a third, a cord tied round them.",
    "bravado_drill": "A tankard slammed on a table, coins jumping.",
    "mournes_smirk": "A chisel and mallet on a stone gate, a fresh seal cut.",
    "clear_mind": "A still bowl of water with one card floating in it.",
    "counterplay_drill": "A card pinned to a board with a dagger.",
    "defacement": "A seal on a stone gate chiselled out, dust falling.",
    "eyes_beyond_the_gate": "A crack in a stone gate, a pale light and a shape on the far side.",
    "first_cut": "A chisel's first cut into a blank stone gate.",
    "foresight": "A card seen in a bowl of dark water before it is drawn.",
    "gates_boon": "A stone gate with three cards resting on its threshold, light from the crack.",
    "guardian_drill": "A hand placing a card on a stone floor, a shield propped behind.",
    "heirloom_blade": "An old longsword with a worn sword-school crest on the pommel, laid on a doublet.",
    "lone_blade_drill": "A single sword on an otherwise bare stone floor.",
    "lucky_find": "A card found under a loose flagstone.",
    "no_retreat_drill": "A door barred with a sword through the handles.",
    "open_challenge": "A gauntlet thrown down on stone, a card beside it.",
    "mournes_quickness_drill": "A card snatched from the bottom of a pile mid-fall.",
    "recalled_lesson": "A page of sword diagrams, one figure circled.",
    "revision_drill": "A card torn in half, two fresh ones beneath it.",
    "sleight": "A seal palmed in a gloved hand.",
    "spoiled_rite": "A rune circle scuffed out with a boot.",
    "mournes_plans": "A hand on a chisel, steady, a seal half cut.",
    "stokes_the_coals": "Crouched at a brazier, stirring coals, burnt cards lifting whole from the fire.",
    "swordplay_drill": "A page of sword drills pinned to a post, a practice blade below.",
    "vales_insight": "Reading a family sword manual, two pages glowing.",
    "wardens_measure": "A measuring cord stretched across a stone gate, a seal marked.",
    "warding_drill": "A stone gate with a chain across it.",
    "assembly_drill": "A workbench of jointed parts laid out in order, one limb already fitted and tested.",
    "breakers_yard": "A yard of broken constructs stacked against a wall, one frame already stripped to the spine, tools laid out on a block.",
    "mourne_takes_measure": "A ledger closed on a duelling floor, a figure's light dropping a rung.",
    "locked_gate_drill": "A side gate barred from the inside, figures waiting beyond it.",
    "kins_rescue": "A shield arm thrown across a kneeling figure, a blow landing on it.",
    # Grounds
    "ancient_grove": "A grove of old trees ringing a standing stone, a line of pale light in the roots.",
    "frostbound_moor": "A frozen moor under low cloud, a standing stone rimed with frost, the leyline dim.",
    "tollgate_yard": "A walled yard with an iron gate, a toll box, the leyline running under the gate.",
    "trampled_crossroads": "A crossroads trampled to bare mud, no grass, the leyline showing through.",
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
    # Red Goku v1.1, read off the sheet 2026-09-19.
    "duelist_iota_a1": "Goku, the Hero (Lv 1, Cell Saga)",
    "duelist_iota_a2": "Goku, the Saiyan (Lv 2, Cell Saga)",
    "duelist_iota_a3": "Goku, Earth's Hero (Lv 3, Cell Saga)",
    "duelist_iota_a4": "Goku (Lv 4, Cell Saga)",
    "duelist_iota_a5": "Goku, the All Powerful (Lv 5, Cell Saga)",
    "companion_epsilon": "Chi-Chi (Lv 1, Saiyan Saga)",
    "pyre_ember_mastery": "Red Style Mastery (Trunks Saga)",
    "braced_guard": "Prepared Dodge (Cell Games Saga)",
    "pyre_bellows_guard": "Red Offensive Stance (Cell Saga)",
    "pyre_ashen_veil": "Red Dodge (Cell Saga)",
    "pyre_hearthguard": "Red Energy Shield (Trunks Saga)",
    "pyre_flashpoint": "Red Eye Laser Assault (Trunks Saga)",
    "pyre_updraft": "Red Flight (Cell Saga)",
    "pyre_ember_strike": "Red Power Strike (Cell Saga)",
    "hasks_flying_kick": "Raditz Flying Kick (Saiyan Saga)",
    "edrics_opening_strike": "Goku's Physical Attack (Saiyan Saga)",
    "edrics_training": "Goku's Training (Androids Saga)",
    "edrics_truce": "Goku's Truce (Saiyan Saga)",
    "mournes_stance": "Vegeta's Physical Stance (Saiyan Saga)",
    "mournes_quickness_drill": "Vegeta's Quickness Drill (Saiyan Saga)",
    "mournes_jolting_arc": "Vegeta's Jolting Slash (Frieza Saga)",
    "mourne_takes_measure": "Vegeta Scans the City (Trunks Saga)",
    "mournes_frantic_rush": "Majin Vegeta's Frantic Attack (Babidi Saga)",
    "mournes_smirk": "Vegeta's Smirk (BK Promo BK7)",
    "mournes_plans": "Vegeta's Plans (Saiyan Saga)",
    "sledges_stance": "Android 13's Prepared Stance (BSMovie Promo)",
    "siphons_sidestep": "Android 19's Dodge (BSMovie Promo)",
    "mercy_smiles": "Android 16 Smiles (AS Promo)",
    "scorn_smirks": "Android 17 Smirks (Androids Saga)",
    "duelist_theta_a1": "Android 18 (Lv 1, Cell Saga)",
    "duelist_theta_a2": "Android 18, the Model (Lv 2, Cell Saga)",
    "duelist_theta_a3": "Android 18, the Machine (Lv 3, Cell Saga)",
    "duelist_theta_a4": "Android 18 (Lv 4, Cell Saga)",
    "salvage_alpha": "Android 20 (Lv 1, Cell Saga)",
    "salvage_beta": "Piccolo, the Avenger (Lv 1, Trunks Saga)",
    "salvage_gamma": "Vegeta, the Powerful (Lv 1, Cell Saga)",
    "salt_seal_1": "Dende Dragon Ball 1 (Cell Saga)",
    "salt_seal_2": "Dende Dragon Ball 2 (Cell Saga)",
    "salt_seal_3": "Dende Dragon Ball 3 (Cell Saga)",
    "salt_seal_4": "Dende Dragon Ball 4 (Cell Saga)",
    "salt_seal_5": "Dende Dragon Ball 5 (Cell Saga)",
    "salt_seal_6": "Dende Dragon Ball 6 (Cell Saga)",
    "salt_seal_7": "Dende Dragon Ball 7 (Cell Saga)",
    "marrows_retinue": "Looking Good (Cell Saga promo P9)",
    "rites_unmade": "Drills are for the Weak (Trunks Saga)",
    "mourne_takes_measure": "Vegeta Scans the City (Trunks Saga)",
    "breakers_yard": "The Car (Cell Saga)",
    "mournes_jolting_arc": "Vegeta's Jolting Slash (Frieza Saga)",
    "threefold_bolt": "Tien's Tri-Beam (Cell Saga)",
    "assembly_drill": "Android Attack Drill (Androids Saga)",
    "locked_gate_drill": "Gohan Spots the Imposter Drill (Trunks Saga)",
    "shade_rending_palm": "Black Fore Fist Punch (Saiyan Saga)",
    "shade_cutting_hand": "Black Knife Hand Strike (Saiyan Saga)",
    "shade_gathering_dark": "Black Physical Focus (Trunks Saga)",
    "shade_snaring_web": "Black Energy Web (Trunks Saga)",
    "shade_warding_burst": "Black Defensive Burst (Trunks Saga)",
    "shade_takedown_drill": "Black Takedown Drill (Saiyan Saga)",
    "shade_composure_drill": "Black Smoothness Drill (Trunks Saga)",
}


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
        if r.get("Source card", ""):
            out[cid] = r["Source card"]
    return out


def load_decks():
    used = {}
    for f in sorted(glob.glob("data/decks/*.json")):
        d = json.load(open(f, encoding="utf-8"))
        short = d["name"].replace("The ", "").split(" ")[0]

        def add(cid, what):
            used.setdefault(cid, []).append("%s %s" % (short, what))
        add(d["duelist"], "duelist")
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
        out.add(json.load(open(f, encoding="utf-8"))["duelist"])
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
        s, n = card["base"].rsplit("_seal_", 1)
        return SEAL_SETS[s] % (int(n), int(n))
    raise SystemExit("no art brief for %s" % cid)


def shows(card):
    return SHOWS.get(card["base"], card.get("character", "")) or ""


def palette_of(card, who):
    if card["type"] == "Seal":
        return SEAL_PALETTE[card["base"].rsplit("_seal_", 1)[0]]
    school = card["school"] or CAST_SCHOOL.get(who, "")
    if school == "freestyle":
        school = ""
    return PALETTE[school]


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
    aspect_count = collections.Counter(c["base"] for c in cards if c["aspect"])
    for c in cards:
        if c["type"] == "Personality" and aspect_count[c["base"]] == 1:
            # A personality printed at a single Aspect gets one art file, named by the bare id.
            # One printed at several gets `<id>_a<n>` per Aspect, whichever role it fills.
            c["id"] = c["base"]
            c["title"] = c["title"].removesuffix(", Aspect 1")
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
    for s, p in SEAL_PALETTE.items():
        out.append("- %s seals: %s" % (s.capitalize(), p))
    out += ["", "## Cast", "", "Identity strings are reused verbatim on every card that shows the character.", "",
            "| Character | School · Side | Deck | Identity | Across Aspects |", "|---|---|---|---|---|"]
    for name, side, deck, identity, note in CAST:
        out.append("| %s | %s | %s | %s | %s |" % (name, side, deck, esc(identity), esc(note)))
    out.append("")
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
