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

# One colour for every card that carries a character's name, portraits and signature cards alike,
# tied to no school. It matches the gold the client gives the personality type in Palette.type_ui.
PERSONALITY_PALETTE = "Accent warm gold and pale ivory, deep umber shadow, one warm key light."

# Character identities: a fixed string reused verbatim on every card that shows the character,
# so a generator keeps them consistent. (name, school/side, deck, identity, note for the md)
CAST = [
    ("Bram Ashmark", "Pact", "Ashmark the Pyromancer",
     "Bram Ashmark: man in his early twenties, lean, soot-streaked pale skin, singed short dark hair, half-plate over a scorched gambeson, plain longsword with a heat shimmer.",
     "The Pact shows as light under the skin: faint at Kindled, cracks by Unquenchable."),
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
    ("Ansel Rooke", "Vigil", "The Rooke Coven", "Ansel Rooke: young man, broad shoulders, blue-grey gambeson, round shield.", "The middle son."),
    ("Tavin Vale", "Vigil", "The Rooke Coven", "Tavin Vale: slim young man, dark hair tied back, blue robe over a fencing doublet, hands open for casting.", "A Vale cousin fostered with the Rookes."),
    ("Ansel and Tavin, Back to Back", "Vigil", "The Rooke Coven", "Ansel Rooke and Tavin Vale standing back to back, shield and water between them.", "The Bond."),
    ("Caedan Vale", "Vigil", "Vale the Swordmaster",
     "Caedan Vale: slight man in his late twenties, dark hair, grey fencing doublet, one longsword, no magic.",
     "Aspects stay human: stiller each time, grey at the temples by Peerless."),
    ("Siphon", "Pact", "The Corven Collegium",
     "Siphon: humanoid construct of grey stone and copper wire, sigils cut into its chest, a smooth faceless head, a glass core at the sternum.",
     "Dormant it is a statue, charged it hums, unbound it arcs."),
    ("Tithe", "Pact", "The Corven Collegium",
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
    "personality_bram_ashmark_1_starved": "Bram Ashmark", "personality_halden_quarr_1_the_grinder": "Halden Quarr", "personality_sable_draik_1_captain": "Sable Draik",
    "personality_alder_rooke_1_matriarch": "Dame Alder Rooke", "personality_osric_thornwald_1_greybeard": "Osric Thornwald", "personality_siphon_1_dormant": "Siphon",
    "personality_caedan_vale_1_last_heir": "Caedan Vale",
    "personality_vesna_draik_1": "Vesna Draik", "personality_brann_draik_1": "Brann Draik", "personality_halvard_draik_1": "Halvard Draik",
    "personality_pim_1": "Pim", "personality_quill_draik_1": "Quill Draik", "personality_tithe_1": "Tithe",
    "personality_wren_rooke_1": "Wren Rooke", "personality_edric_rooke_1": "Sir Edric Rooke", "personality_ansel_rooke_1": "Ansel Rooke",
    "personality_tavin_vale_1": "Tavin Vale", "personality_ansel_and_tavin_1_back_to_back": "Ansel and Tavin, Back to Back",
    "practiced_guard": "Corin Thrace", "smoke_screen": "Corin Thrace", "suppressing_shot": "Corin Thrace",
    "threefold_bolt": "Corin Thrace", "corins_conditioning": "Corin Thrace",
    "black_hands": "Sable Draik", "draiks_reckoning": "Sable Draik", "lingering_curse": "Sable Draik",
    "branns_shakedown": "Brann Draik", "halvards_twin_cut": "Halvard Draik", "vesnas_ambush": "Vesna Draik",
    "quarrs_crushing_blow": "Halden Quarr", "quarrs_roar": "Halden Quarr", "shrugs_it_off": "Halden Quarr",
    "rookes_deluge": "Dame Alder Rooke", "edrics_vow": "Sir Edric Rooke",
    "scatters_the_ashes": "Bram Ashmark", "stokes_the_coals": "Bram Ashmark", "wall_of_flame": "Bram Ashmark",
    "will_not_break": "Bram Ashmark",
    "vales_pommel_bash": "Caedan Vale", "vales_quickstep": "Caedan Vale", "vales_riposte": "Caedan Vale",
    "vales_sword_draw": "Caedan Vale", "vales_insight": "Caedan Vale", "heirloom_blade": "Caedan Vale",
    "sledges_stance": "Sledge", "siphons_sidestep": "Siphon", "mercy_smiles": "Mercy", "scorn_smirks": "Scorn",
    "personality_marrow_1_patchwork": "Marrow", "marrows_retinue": "Marrow", "cold_appraisal": "Marrow",
    "mournes_stance": "Gideon Mourne", "mournes_quickness_drill": "Gideon Mourne", "mournes_jolting_arc": "Gideon Mourne",
    "mourne_takes_measure": "Gideon Mourne", "mournes_frantic_rush": "Gideon Mourne", "mournes_smirk": "Gideon Mourne",
    "mournes_plans": "Gideon Mourne",
    "personality_cull_1": "Cull", "personality_orvath_kell_1": "Orvath Kell", "personality_gideon_mourne_1_mercenary": "Gideon Mourne",
    "scattered_ashes": "Bram Ashmark", "sabotage": "Siphon", "absorbing_drill": "Cull",
    "committed_cut": "Sir Edric Rooke", "quick_retreat": "Sir Edric Rooke",
    "first_cut": "Sir Edric Rooke", "keepers_drill": "Sir Edric Rooke",
    "personality_edric_rooke_1_the_hero": "Sir Edric Rooke", "edrics_truce": "Sir Edric Rooke",
    "edrics_opening_strike": "Sir Edric Rooke", "edrics_training": "Sir Edric Rooke",
    "personality_alder_rooke_1": "Dame Alder Rooke", "hasks_flying_kick": "Torvan Hask",
    "all_or_nothing": "Emrys Rooke", "hilt_guard": "Emrys Rooke", "no_quarter": "Emrys Rooke",
    "sword_flourish": "Emrys Rooke", "sword_sweep": "Emrys Rooke", "sword_thrust": "Emrys Rooke",
    "locked_gate_drill": "Emrys Rooke", "swordplay_drill": "Emrys Rooke",
    "personality_emrys_rooke_1_the_eldest": "Emrys Rooke",
}

# Slot brief per card: subject, action, two or three concrete details, mood. Short, visual, no rules.
ART = {
    # Duelists
    "personality_bram_ashmark_1_starved": "Kindled. Grinning, blood on his knuckles, embers in his eyes, heat shimmer off the blade, no open flame yet.",
    "personality_bram_ashmark_2_leeching": "Wildfire. Flame licking off his shoulders, cracks of orange light along his forearms, sword raised overhead, coals glowing in the steel.",
    "personality_bram_ashmark_3_unstoppable": "Unquenchable. Fully wreathed in fire, face barely visible in it, caught mid-charge, sparks trailing.",
    "personality_halden_quarr_1_the_grinder": "The Grinder. Brawler's crouch, fists up, black knuckles, breath steaming, hungry look.",
    "personality_halden_quarr_2_tempered": "Tempered. Chest and shoulders greyed to iron, veins like solder, one foot on a discarded page.",
    "personality_halden_quarr_3_ironheart": "Ironheart. Chest plated in living iron, a dull red heart glowing through it, both fists cocked.",
    "personality_sable_draik_1_captain": "Captain. Coat open, boot on a crate, a torn company flag behind her, crew silhouettes at the edges, amused.",
    "personality_sable_draik_2_shrouded": "Shrouded. Shadow pooled at her feet and climbing her coat, half her face in darkness, one hand out.",
    "personality_sable_draik_3_lightless": "Lightless. Eyes fully black, the light in the frame dying toward her, shadow streaming off her arms.",
    "personality_edric_rooke_1_the_hero": "The Hero. Standing easy, sword point down, hand raised to hold a line back, no fire on him yet.",
    "personality_edric_rooke_2_the_stranger": "The Stranger. Helm off, looking at his own hands, a thin orange seam of heat along one forearm, the Hask axe on the ground behind him.",
    "personality_edric_rooke_3_the_realms_hero": "The Realm's Hero. Mid-stride into a burning street, coals under his boots, shield arm shielding somebody out of frame.",
    "personality_edric_rooke_4_kindled_through": "Kindled Through. Fire running up the blade and along the mail seams, teeth set, one fist cocked.",
    "personality_edric_rooke_5_the_all_powerful": "The All Powerful. Wreathed to the shoulders, the sword a bar of white heat, everything around him going to ash.",
    "personality_emrys_rooke_1_the_eldest": "The Eldest. Empty-handed and still, sleeves pushed up, bare forearms, borrowed stances in the set of his feet, no metal anywhere.",
    "personality_emrys_rooke_2_first_plate": "First Plate. Fitted grey metal closed over both forearms like bracers he grew, flexing one hand to test it, surprised at it.",
    "personality_emrys_rooke_3_edged": "Edged. The forearm plate drawn out into a working edge along the ulna, held low and ready, one clean cut in the air behind it.",
    "personality_emrys_rooke_4_shaped": "Shaped. Metal running to the shoulders and moving where he looks, a plate sliding across his chest mid-step, hands open and unhurried.",
    "personality_emrys_rooke_5_scaleclad": "Scaleclad. Plated head to boot in overlapping grey scale, the pattern finally reading as a dragon's, one gauntlet cocked, calm.",
    "personality_alder_rooke_1_matriarch": "Matriarch. Shield up, sword low, three hooded coven figures behind her, stern.",
    "personality_alder_rooke_2_rising_water": "Rising Water. Water climbing her mail to the waist, eyes gone sea-glass green, a knight at her shoulder.",
    "personality_alder_rooke_3_the_flood": "The Flood. A wave rising off her shoulders, face calm as deep water, the ground at her feet awash.",
    "personality_osric_thornwald_1_greybeard": "Greybeard. Sitting on his heels, staff across his knees, moss on the leathers, reading a torn page.",
    "personality_osric_thornwald_2_overgrown": "Overgrown. Bark up both forearms, leaves in the beard, staff mid-swing, green pushing through grey.",
    "personality_osric_thornwald_3_deep_rooted": "Deep-Rooted. Roots running from his boots into the ground, a staff blow landing, a cut on his arm closing over in bark.",
    "personality_osric_thornwald_4_heartwood": "Heartwood. Torso gone to living wood, ribs of bark, leaves budding at the shoulders, staff planted.",
    "personality_osric_thornwald_5_grovelord": "Grovelord. A standing tree with a bearded face, arms become boughs, one hand still holding the staff.",
    "personality_siphon_1_dormant": "Dormant. Standing still as a statue, sigils dark, one hand raised palm out catching a fading bolt.",
    "personality_siphon_2_charged": "Charged. Sigils lit blue-white, a haze of static around it, a blade sliding off a ward of light.",
    "personality_siphon_3_unbound": "Unbound. Arcs jumping between its limbs, the glass core bare and blazing, both hands throwing charge.",
    "personality_caedan_vale_1_last_heir": "Last Heir. Longsword in a textbook guard, chin up, young and exact, a worn sword-school crest on the doublet.",
    "personality_caedan_vale_2_unparried": "Unparried. Mid-lunge, the point leading, no wasted motion, a ribbon of displaced air.",
    "personality_caedan_vale_3_spellcutter": "Spellcutter. A cut finishing through a fading spell, the rival's hand at the frame edge pinned.",
    "personality_caedan_vale_4_the_quiet_blade": "The Quiet Blade. Standing still, point steady, grey at the temples, the air around him clear while spells break at a distance.",
    "personality_caedan_vale_5_peerless": "Peerless. Older, sword lowered, walking forward unhurried, three faint ghost images of the next moves ahead of him.",
    "personality_marrow_1_patchwork": "Patchwork. Standing square in a field of broken constructs, held together with strap and wire, the stamped name under her jaw catching the light.",
    "personality_marrow_2_rebuilt": "Rebuilt. Properly seated joints and beaten-out plate, a struck blade skidding off her shoulder without leaving a mark on it.",
    "personality_marrow_3_overwrought": "Overwrought. Built past what any part was for: too many plates, too much arm, a seam glowing where it should not.",
    "personality_marrow_4_fury_amalgam": "Fury Amalgam. All of it moving at once, mid-swing, pieces of a dozen constructs in one shape and none of them idle.",
    # Allies
    "personality_vesna_draik_1": "Coming in from the frame edge, knives out, hood up.",
    "personality_brann_draik_1": "Cracking his knuckles, leaning over the viewer.",
    "personality_halvard_draik_1": "Both swords drawn in a crossed guard, cloak lifting.",
    "personality_pim_1": "Crouched over a pile of torn pages, holding one up to the light.",
    "personality_quill_draik_1": "Reading a hex off a page, one finger tracing it, purple ink glowing.",
    "personality_tithe_1": "Stepping in front of the viewer, shoulder first, a spark at the cracked joint.",
    "personality_wren_rooke_1": "Gathering loose pages into her satchel, some floating back to her.",
    "personality_edric_rooke_1": "Sword raised, a focused jet of water along the blade.",
    "personality_ansel_rooke_1": "Shield braced, water refilling a cracked flask at his hip.",
    "personality_alder_rooke_1": "Stepping in front of a blow meant for someone else, shield up, no water raised at all, furious.",
    "personality_tavin_vale_1": "Hands open, a globe of water between them, pages settling into a deck at his feet.",
    "personality_ansel_and_tavin_1_back_to_back": "Back to back, water curling around the shield, both looking outward.",
    "personality_cull_1": "Selecting an instrument from the open roll without looking down, mild and unhurried.",
    "personality_orvath_kell_1": "Both palms raised over a fallen construct, the hex uncoiling between them, the gorget still buckled on.",
    "personality_gideon_mourne_1_mercenary": "Mid-cast, the broken crest on his chest turned to the viewer, light bleeding off his knuckles.",
    # Relics and Masteries
    "blank_mask": "A featureless white porcelain mask, no eye holes, on black cloth.",
    "debtors_ring": "A heavy iron ring pressed with someone else's mark, a wax seal beside it.",
    "lodestone_heart": "A dark magnetic stone on a chain, iron filings drawn to it, on grey cloth.",
    "freestyle_mastery": "A worn leather training manual, spine cracked, a single steel pin holding a page.",
    "pyre_mastery": "A brazier of coals with a single tongue of flame, a burnt page curling in it.",
    "pyre_ember_mastery": "A single ember lifted off a spent pile on a knife point, the pile going cold behind it.",
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
    "pyre_bellows_guard": "A blow caught on a bracer and the impact blown back out as a gout of flame.",
    "pyre_ashen_veil": "A wall of ash thrown up between two fighters, old burnt pages whirling away in it.",
    "pyre_hearthguard": "A low banked hearth flaring up as a spell breaks on it, a figure straightening in the light.",
    "pyre_flashpoint": "Air going over all at once at a single point, the fighter already through it.",
    "pyre_updraft": "A rising column of heat carrying a fighter off the ground mid-strike.",
    "pyre_ember_strike": "A plain punch landing, embers thrown off the knuckles on impact.",
    "braced_guard": "Both feet set, weight low, a blow turning aside off a raised guard, no magic anywhere.",
    "edrics_truce": "A blade stopped a hand's width short, both fighters' eyes meeting over it.",
    "edrics_opening_strike": "The first blow of a long fight, thrown flat and hard, a burnt card lifting out of the ash behind him.",
    "edrics_training": "A practice yard at dawn, a post splintering under a strike, breath fogging.",
    "hasks_flying_kick": "A flying kick landing full in the chest, the ground cracking away under the man taking it.",
    "pyre_scouring_flame": "A tongue of fire scouring a rune circle off a stone floor.",
    "pyre_searing_guard": "A raised forearm glowing red, a blade stopping against it and smoking.",
    "pyre_snuffing": "A fist closing on a small flame, the smoke of it.",
    "pyre_twin_flames": "Two flames from one motion, a sword and an open hand both lit.",
    # Steel
    "steel_battering_ram": "A shoulder charge, iron skin, the impact ringing.",
    "steel_cross": "A plated fist landing square, the whole arm grey metal to the shoulder, the air split behind it.",
    "steel_rake": "Four drawn-out scale edges raking across a guard, three bright scores left in it.",
    "steel_talon": "A boot coming down from above, the toes grown into hooked grey talons, the ground cratering.",
    "steel_slip": "A head turning aside by an inch, the blow sliding off a cheek of grey plate.",
    "steel_stamp": "A plated heel driven down onto a fallen guard, weight fully committed.",
    "steel_reverse": "A back kick turned out of nowhere, the heel plated, the twist carrying everything.",
    "steel_tackle": "A low charge under a spell, shoulder first, both arms closing.",
    "steel_sink": "A bolt of light going into a plated chest and not coming out, the metal dulling where it landed.",
    "steel_plating": "Plates closing over a raised forearm and across the body, a spell breaking apart on them.",
    "steel_conditioning_drill": "A set of graded iron weights on a worn bench, one lifted clear of its slot.",
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
    "storm_squall_mastery": "A squall line rolling in over flat ground, rain already falling in a wall.",
    "storm_lash": "A whip of white light cracking out level with the ground.",
    "storm_palm_surge": "An open palm held out, the air in front of it going white.",
    "storm_earthing_rod": "An iron rod driven into wet ground, a bolt running harmlessly down it.",
    "storm_plasma_beam": "A narrow beam punching through the rain, the target already turning away.",
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
    "the_long_year": "A worn practice floor under a ring of burnt-down candles, twelve months of scuffs in one night's dust.",
    "gates_boon": "A stone gate with three cards resting on its threshold, light from the crack.",
    "guardian_drill": "A hand placing a card on a stone floor, a shield propped behind.",
    "heirloom_blade": "An old longsword with a worn sword-school crest on the pommel, laid on a doublet.",
    "lone_blade_drill": "A single sword on an otherwise bare stone floor.",
    "lucky_find": "A card found under a loose flagstone.",
    "corins_conditioning": "A shaven-headed ascetic seated on bare stone before dawn, breath steady, eyes shut.",
    "provocation": "A struck face turning back into the blow, teeth bared.",
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
    "the_high_watch": "A watchpost on a spur above the cloud line, one cold lamp lit, the whole valley laid out below it.",
    "frostbound_moor": "A frozen moor under low cloud, a standing stone rimed with frost, the leyline dim.",
    "weighted_hollow": "A shallow stone hollow where the air visibly presses down, dust hanging low and refusing to rise.",
    "tollgate_yard": "A walled yard with an iron gate, a toll box, the leyline running under the gate.",
    "trampled_crossroads": "A crossroads trampled to bare mud, no grass, the leyline showing through.",
    # Backlog: cards added by the tournament imports that the roster was never rebuilt for. The
    # generator refuses to run while any card lacks a brief, so these were written here to unblock
    # the rebuild. They follow the house pattern but have not been reviewed.
    "personality_bram_ashmark_1_starved": "Starved. Gaunt and low to the ground, blade held loose, the fire in him down to a few coals, eyes fixed on something out of frame.",
    "personality_bram_ashmark_2_gnawing": "Gnawing. Hunched mid-step, small flames chewing along the blade's edge, a brand showing dark on his forearm.",
    "personality_bram_ashmark_3_gorging": "Gorging. Fire pouring into him rather than off him, the light around him drawn inward, mouth open.",
    "personality_bram_ashmark_4_consuming": "Consuming. Wreathed and still, everything near him blackening at the edges, the brand burning white.",
    "personality_bram_ashmark_5_insatiable": "Insatiable. Fully ablaze and empty with it, the fire streaming inward through a hollow at his chest, nothing in his face.",
    "personality_gideon_mourne_1_the_marked_lord": "The Marked Lord. Standing square in a ruined hall, brigandine closed, a dark brand across the back of one crackling hand, chin up.",
    "personality_gideon_mourne_2_unflinching": "Unflinching. Taking a blow on the shoulder without moving his feet, the brand spreading up the forearm, jaw set.",
    "personality_gideon_mourne_3_unfettered": "Unfettered. The broken crest torn off his chest and dropped, both hands lit, moving forward.",
    "personality_gideon_mourne_4_unrepentant": "Unrepentant. The brand covering half his face, arms wide, the hall behind him going dark, no shame in it.",
    "ashmarks_choke_hold": "A hold locked on from behind, an arm across the throat, heat shimmer rising off the grip.",
    "ashmarks_ember_spray": "A spray of embers thrown flat from an open hand, a brand glowing on the wrist.",
    "ashmarks_unmaking_whisper": "A blow landing and the air behind it coming apart in black threads, embers going out.",
    "emrys_rising_blow": "A rising punch thrown from a low stance, grey metal closing over the forearm mid-swing.",
    "edrics_low_water": "A shoreline at the lowest tide, seven things left uncovered on the flats, a figure walking out to them.",
    "riftcry": "A shout tearing a standing rune circle out of a stone floor, the stone going with it.",
    "severing_clasp": "A plain iron clasp lying open on dark cloth, two cut cords beside it.",
    "spent_to_the_last": "An empty brazier and a spent figure kneeling beside it, everything on the floor knocked flat.",
    "the_watch_goes_dark": "Seven carved stones going dark at once along a wall, the last light leaving the grooves.",
    "the_marked_ring": "A duelling ring cut into stone with a brand burnt into the centre of it.",
    "marked_demise": "A brand on a palm dimming as the blow it threw is pulled back.",
    "marked_lightning": "A brand flaring white and throwing a short arc, struck right after a fist landed.",
    "marked_strength": "A braced shoulder driving through, the brand on the arm burning brighter with the effort.",
    "pyre_knee_bash": "A knee driven up into a guard, flame bursting off the impact.",
    "pyre_sword_cleave": "A burning sword brought down through a shield rim, the cut glowing.",
    "pyre_warding_stance": "A low stance with both forearms crossed, a bolt of light breaking apart on them.",
    "shade_bitter_trade": "A card torn in half over a black veil, the halves drifting apart.",
    "shade_emptying_whisper": "A hand of cards pulled out of a grip one by one by nothing visible.",
    "shade_faltering_drill": "A lamp guttering on an iron stand, the wick eating itself down.",
    "shade_fixed_gaze": "A black veil settling over a face and staying there, eyes fixed through it.",
    "shade_lingering_whisper": "A whisper still hanging in the air after the mouth has closed, black threads.",
    "shade_ransoming_hand": "An open hand held out over a stripped table, a coin and a broken drill on it.",
    "shade_recoil": "A bolt of light turned back on itself, the caster stepping away from it.",
    "shade_returning_whisper": "Black threads drawn back out of a discard heap and into a closed hand.",
    "shade_sifting_whisper": "A hand of cards fanned face up under a black veil, one finger picking through them.",
    "shade_silenced_whisper": "A card pulled from a grip and going to nothing between two fingers.",
    "shade_stinging_palm": "A flat palm landing hard, black rings spreading from the point of contact.",
    "shade_swelling_whisper": "A whisper swelling into a dark wave, the veil billowing with it.",
    "shade_turned_whisper": "A bolt of light meeting a black veil and turning aside along it.",
    "tide_bearing_down": "A wall of heavy water bearing down slow, everything under it already bending.",
    "tide_black_water": "Black water standing dead still, no reflection in it at all.",
    "tide_crushing_depth": "Deep water pressing a hull in, rivets starting along the seam.",
    "tide_deadweight": "A dead weight of water dropping on a raised arm, the arm going down with it.",
    "tide_deep_anchor": "An anchor set deep in black silt, the chain drawn tight upward.",
    "tide_deep_guard": "A standing sheet of water taking a bolt of light and swallowing it.",
    "tide_deep_sweep": "A sweep of heavy water taking legs out from under, low and fast.",
    "tide_dredge": "A dredge chain hauling silt and objects up out of black water.",
    "tide_fathom_mastery": "A sounding line run out into deep water, the marks on it counting down.",
    "tide_full_weight": "The full weight of a wave landing at once, spray driven flat.",
    "tide_heavy_water": "A vessel of water too heavy for its size, the table under it bowing.",
    "tide_held_under": "A shape held under the surface, hands flat on it from above.",
    "tide_pressure_wave": "A pressure wave running out under water, the surface lifting in a ring.",
    "tide_pull_under": "Water closing over something and taking it down, one arm still showing.",
    "tide_sweep_aside": "A blow swept aside by a curl of heavy water, the water keeping the shape of it.",
    "tide_undersweep": "An undertow taking the feet out from under, the surface unbroken above.",
    "tide_welling_deep": "Deep water welling up through a crack in stone, rising fast and clear.",
    # Storm expansion. Weather and charge only: no figures, no places anyone would recognise.
    "storm_rising_gust": "A gust veering a falling blow aside, dust lifting off the ground in a rising spiral, grey light.",
    "storm_twin_earthing": "Two thin bolts earthing into the same scorched patch, twin glass scars in the dirt, the air still crackling.",
    "storm_damping_guard": "A coil of blue charge collapsing inward, sparks dying at the edges, cold grey air.",
    "storm_returning_front": "A weather front curling back on itself over open ground, the cloud wall turning, light behind it.",
    "storm_mantle_drill": "A standing mantle of charge around an empty space, blue filaments held in a shell, steady.",
    "storm_dispersal_drill": "Charge spread thin across a wide coil, light bleeding outward, nothing concentrated.",
    "storm_tight_coil_drill": "A tightly wound copper coil glowing white at the core, arcs jumping between the turns.",
    "storm_conduit_drill": "A clean bright channel cut through cloud, charge running down it without resistance.",
    "storm_mustering_peal": "A single peal rolling out across a dark plain, cloud banks answering it, ranked shapes at the horizon.",
    "storm_scattering_gale": "A gale tearing carved stone markers loose and flinging them low across wet ground.",
    "storm_free_current": "An open current running through clear air with nothing in its path, a faint blue trail.",
    "storm_catching_stance": "A bolt caught and held in a bowl of charge, its light pooling instead of earthing.",
    "storm_feeding_arc": "An arc bending back into its own source, the origin point brightening as it feeds.",
    "storm_return_stroke": "The return stroke running back up a lightning channel, white core, everything around it dark.",
    "storm_wringing_squall": "A squall twisting a sheet of rain into a wrung spiral, water driven out of it.",
    "storm_rolling_peal": "One peal breaking into the next across stacked cloud, each louder, the air shaking.",
    "storm_idle_spark": "A small spark jumping off an idle coil, one thin blue thread, almost nothing.",
    "storm_pent_discharge": "Charge penned behind a dark cloud wall letting go all at once, one hard white flash.",
    "storm_opened_channel": "The first stroke burning an open channel through dark air, the edges glowing.",
    "storm_ungrounded_flash": "A flash with no earth to take it, light spreading flat and unbroken, no strike point.",
    "storm_felling_gust": "A gust flattening a standing row, one shape going off its feet, debris low and fast.",
    "storm_residual_shock": "Residual charge still crawling through wet ground after the strike, faint blue veins.",
    "storm_levelling_wind": "Wind laying a whole stand flat in one pass, everything bent the same way.",
    "storm_tailwind": "A following wind pushing a cloud front forward, streaks trailing behind it.",
    "storm_cold_front": "A cold front sliding over warm ground, the line of it sharp, colour draining below.",
    "storm_silencing_static": "Static washing over one clear signal until it is gone, grey hiss, nothing left.",
    # Root expansion. Grove, timber, thorn and frost only.
    "root_windbreak_drill": "A planted hedgerow standing against driven wind, branches locked, the ground calm behind it.",
    "root_canopy_drill": "A dense canopy catching what falls from above, light broken into pieces on the floor.",
    "root_sightline_drill": "A cleared sightline down a narrow forest trail, the way ahead visible to the bend.",
    "root_deep_draught": "Roots drinking deep from dark water, the grove above drawn green and full.",
    "root_thorn_hedge": "A thorn hedge tearing at whatever forced through it, torn strands caught on the spines.",
    "root_carvers_reach": "A long branch reaching across a gap toward a carved stone, bark splitting with the strain.",
    "root_timber_blow": "Standing timber coming down full length, the trunk splitting at the base, dust off the floor.",
    "root_millstone": "A millstone turning slow and heavy, grain crushed to powder beneath it.",
    "root_rising_sap": "Sap drawing back up a cut trunk, pale beads gathering along the wound.",
    "root_pruning_cut": "A clean pruning cut on a green limb, the stub already swelling toward regrowth.",
    "root_deadfall": "Deadfall cleared off a forest floor, dry branches heaped and going to nothing.",
    "root_briar_tangle": "A briar tangle catching again and again on whatever tries to pass, thorns bent back.",
    "root_quickening": "Sap quickening through a whole trunk at once, bark straining, green light under it.",
    "root_snare": "A snare of root and cord springing shut around empty air, a whip of motion.",
    "root_splitting_wedge": "A wedge driven deep into built timber, the joint opening along the grain.",
    "root_grove_fury": "A grove bending and thrashing in its own temper, branches lashing, leaves torn loose.",
    "root_bindweed": "Bindweed wound tight around a held shape, green coils drawing closed.",
    "root_sapwood_guard": "Pale sapwood taking a blow and holding, the mark shallow, the fibres unbroken.",
    "root_taproot_brace": "A taproot braced deep in dark soil, the trunk above unmoved.",
    "root_barred_path": "A heavy bough barred across a forest trail at chest height, the way shut.",
    "root_closing_bark": "Bark closing slowly over an old wound in a trunk, the seam almost gone.",
    "root_trail_cut": "One obstacle cut clean out of a forest path ahead, the gap left open.",
    "root_kin_clearing": "A cleared glade with the undergrowth stripped back to bare earth, a ring of standing trunks.",
    "root_first_frost": "A thin first frost edging green leaves white, the morning light low.",
    "root_auger_splinter": "A splinter boring straight through a plank, the exit hole clean on the far side.",
    "root_flung_stone": "A stone hurled flat and hard, knocking a standing post over.",
    "root_scattered_seed": "Seed thrown wide over broken ground, some catching, some lost on stone.",
    "root_old_growth": "The oldest wood in a grove, vast and dark, the ground beneath it bare.",
    "root_culling_frost": "A killing frost blackening growth overnight, stems collapsed, white rime on everything.",
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
    "personality_emrys_rooke_1_the_eldest": "Super Saiyan Gohan (Lv 1, Cell Saga IR2)",
    "personality_emrys_rooke_2_first_plate": "Gohan, the Swift (Lv 2, Cell Saga)",
    "personality_emrys_rooke_3_edged": "Gohan, Super Saiyan (Lv 3, Cell Saga)",
    "personality_emrys_rooke_4_shaped": "Gohan, Ascendant (Lv 4, Cell Saga)",
    "personality_emrys_rooke_5_scaleclad": "Gohan, the Winner (Lv 5, Cell Saga)",
    "steel_cross": "Saiyan Cross Punch (Capsule Corp Power Pack)",
    "steel_rake": "Saiyan Triple Kick (Cell Saga 41)",
    "steel_talon": "Saiyan Flying Kick (Cell Saga 60)",
    "steel_slip": "Saiyan Lightning Dodge (Androids Saga 111)",
    "steel_stamp": "Saiyan Face Stomp (Androids Saga 110)",
    "steel_reverse": "Saiyan Left Kick (Androids Saga 79)",
    "steel_tackle": "Saiyan Flying Tackle (Androids Saga 76)",
    "steel_sink": "Saiyan Focus (Androids Saga 77)",
    "steel_plating": "Saiyan Planet Explosion (Frieza Saga 34)",
    "steel_conditioning_drill": "Saiyan Power Drill (Saiyan Saga 236)",
    "the_high_watch": "Kami's Floating Island (Androids Saga 94)",
    "the_long_year": "Time Chamber Training (Cell Saga 79)",
    # Orange Android 19, read off the sheet 2026-09-19.
    "storm_squall_mastery": "Orange Style Mastery (Cell Saga 140)",
    "weighted_hollow": "Gravity Chamber (Androids Saga 8)",
    "storm_lash": "Orange Strike (Cell Saga 29)",
    "storm_palm_surge": "Orange Palm Blast (Androids Saga 28)",
    "storm_earthing_rod": "Orange Energy Deflection (Cell Saga 31)",
    "storm_plasma_beam": "Orange Power Beam (Androids Saga 69)",
    "corins_conditioning": "Tien's Mental Condition (Androids Saga 86)",
    "provocation": "Enraged! (Saiyan Saga 190)",
    # Red Goku v1.1, read off the sheet 2026-09-19.
    "personality_edric_rooke_1_the_hero": "Goku, the Hero (Lv 1, Cell Saga)",
    "personality_edric_rooke_2_the_stranger": "Goku, the Saiyan (Lv 2, Cell Saga)",
    "personality_edric_rooke_3_the_realms_hero": "Goku, Earth's Hero (Lv 3, Cell Saga)",
    "personality_edric_rooke_4_kindled_through": "Goku (Lv 4, Cell Saga)",
    "personality_edric_rooke_5_the_all_powerful": "Goku, the All Powerful (Lv 5, Cell Saga)",
    "personality_alder_rooke_1": "Chi-Chi (Lv 1, Saiyan Saga)",
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
    "personality_marrow_1_patchwork": "Android 18 (Lv 1, Cell Saga)",
    "personality_marrow_2_rebuilt": "Android 18, the Model (Lv 2, Cell Saga)",
    "personality_marrow_3_overwrought": "Android 18, the Machine (Lv 3, Cell Saga)",
    "personality_marrow_4_fury_amalgam": "Android 18 (Lv 4, Cell Saga)",
    "personality_cull_1": "Android 20 (Lv 1, Cell Saga)",
    "personality_orvath_kell_1": "Piccolo, the Avenger (Lv 1, Trunks Saga)",
    "personality_gideon_mourne_1_mercenary": "Vegeta, the Powerful (Lv 1, Cell Saga)",
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
    # The Storm expansion, read off tools/source_candidates.tsv 2026-09-21.
    "storm_rising_gust": "Orange Sidestep (Cell Saga)",
    "storm_twin_earthing": "Orange Deflection (Cell Saga)",
    "storm_damping_guard": "Orange Fist Detonation (Frieza Saga)",
    "storm_returning_front": "Orange Gaze (Cell Saga)",
    "storm_mantle_drill": "Orange Burning Aura Drill (Cell Games)",
    "storm_dispersal_drill": "Orange Steady Drill (Cell Games)",
    "storm_tight_coil_drill": "Orange Aura Drill (Androids Saga)",
    "storm_conduit_drill": "Orange Body Shifting Drill (Saiyan Saga)",
    "storm_mustering_peal": "Orange Friendship (World Games)",
    "storm_scattering_gale": "Orange Dragon Aid (Cell Games)",
    "storm_free_current": "Orange Gambit (Buu Saga)",
    "storm_catching_stance": "Orange Energy Stance (Tuff Enuff)",
    "storm_feeding_arc": "Orange Dashing Gut Punch (Trunks Saga)",
    "storm_return_stroke": "Orange Flying Drop Kick (World Games)",
    "storm_wringing_squall": "Orange Beatdown (Cell Games)",
    "storm_rolling_peal": "Orange Mouth Shot (Buu Saga)",
    "storm_idle_spark": "Orange Power Blast (Cell Saga)",
    "storm_pent_discharge": "Orange Energy Concentration (Cell Games)",
    "storm_opened_channel": "Orange Aggressive Technique (Cell Games)",
    "storm_ungrounded_flash": "Orange Energy Discharge (Cell Saga)",
    "storm_felling_gust": "Orange Knockout (World Games)",
    "storm_residual_shock": "Orange Energy Shot (Cell Games)",
    "storm_levelling_wind": "Orange Carnage (Kid Buu Saga)",
    "storm_tailwind": "Orange Flight (Buu Saga)",
    "storm_cold_front": "Orange Taunting Attack (Frieza Saga)",
    "storm_silencing_static": "Orange Sneak Attack (Buu Saga)",
    # The Root expansion, read off tools/source_candidates.tsv 2026-09-21.
    "root_windbreak_drill": "Namekian Power Stance Drill (Cell Games)",
    "root_canopy_drill": "Namekian Ready Drill (Cell Games)",
    "root_sightline_drill": "Namekian Knowledge Drill (Babidi Saga)",
    "root_deep_draught": "Namekian Fusion (Cell Saga)",
    "root_thorn_hedge": "Namekian Finishing Effort (Androids Saga)",
    "root_carvers_reach": "Namekian Head Strike (Trunks Saga)",
    "root_timber_blow": "Namekian Power Kick (Cell Saga)",
    "root_millstone": "Namekian Rock Crush (Cell Saga)",
    "root_rising_sap": "Namekian Upward Dash (Cell Saga)",
    "root_pruning_cut": "Namekian Side Kick (Cell Saga)",
    "root_deadfall": "Namekian Flying Kick (Cell Games)",
    "root_briar_tangle": "Namekian Combo (World Games)",
    "root_quickening": "Namekian Focused Kick (World Games)",
    "root_snare": "Namekian Surprise Attack (World Games)",
    "root_splitting_wedge": "Namekian Shield Destruction (Buu Saga)",
    "root_grove_fury": "Namekian Tornado Attack (World Games)",
    "root_bindweed": "Namekian Crushing Hold (Cell Games)",
    "root_sapwood_guard": "Namekian Fist Block (Cell Saga)",
    "root_taproot_brace": "Namekian Charging Stance (Tuff Enuff)",
    "root_barred_path": "Namekian Pikkon's Defense (World Games)",
    "root_closing_bark": "Namekian Restoration (Cell Games)",
    "root_trail_cut": "Namekian Scouting (Cell Games)",
    "root_kin_clearing": "Namekian Frendship (Androids Saga)",
    "root_first_frost": "Namekian Energy Ray (Cell Saga)",
    "root_auger_splinter": "Namekian Focused Blast (World Games)",
    "root_flung_stone": "Namekian Double Blast (World Games)",
    "root_scattered_seed": "Namekian Eye Beam (World Games)",
    "root_old_growth": "Namekian Energy Beam (Cell Saga)",
    "root_culling_frost": "Namekian Piercing Beam (Cell Games)",
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
        s, n = card["base"].rsplit("_seal_", 1)
        return SEAL_SETS[s] % (int(n), int(n))
    raise SystemExit("no art brief for %s" % cid)


def shows(card):
    return SHOWS.get(card["base"], card.get("character", "")) or ""


def palette_of(card, who):
    if card["type"] == "Seal":
        return SEAL_PALETTE[card["base"].rsplit("_seal_", 1)[0]]
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
    out += ["", "## Cast", "", "Identity strings are reused verbatim on every card that shows the character.", "",
            "| Character | Side | Deck | Identity | Across Aspects |", "|---|---|---|---|---|"]
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
