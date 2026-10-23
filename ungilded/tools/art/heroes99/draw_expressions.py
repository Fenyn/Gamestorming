"""Draw the authored expression cells (rows 4-18) for every face, jaw and eye shape, colour c1.

Each authored cell starts from a cell of the purchased _c1 sheet and applies edits in order:
- (y, x, "codes") writes the codes left to right from (x, y). A digit is a 1-based index into the
  shape's palette, which is the colours of its purchased _c1 file sorted by RGBA. A letter names a
  colour (LETTERS); a colour the shape lacks falls back through FALLBACK. "." writes transparency.
- ("fill", (r, c)) copies purchased cell (r, c) into every transparent pixel of the eye band
  (FILL_BOX) where that cell is opaque. Blink cells use it to close eye holes.
- ("mouthless", box, edits) copies box from the jaw's neutral cell with its mouth erased by edits.
- ("swap", y, x0, x1, a, b) turns colour a into colour b on row y, columns x0..x1-1.
- ("lift", y, x0, x1) moves row y up one row and row y+1 into row y, columns x0..x1-1. Raising a
  lid row this way opens one more eye row.
A cell marked CLEAR gets a #FF00FF top-left pixel, which build_extended.py turns into an empty cell.
Cells not listed stay empty, so the build keeps its recipe cell there.

    python draw_expressions.py <purchased FaceGen> <authored folder> [<sheet_layout.json>]

The script checks every authored pixel against the shape's palette, then checks that every jaw
frame in rows 4-18 (authored or recipe) holds exactly one 8-connected mouth shape inside the jaw's
mouth box. It exits 1 on any failure. The layout defaults to sheet_layout.json beside the
authored folder.
"""
import json
import os
import sys
from PIL import Image

FRAME, COLUMNS, ROWS = 48, 4, 19
REST, TALK_A, TALK_B, BLINK = 0, 1, 2, 3
HAPPY, ANGRY, SHOCK, SAD, DETERMINED, WORRIED, SMIRK, THINKING = range(4, 12)
EXASPERATED, GRIN, AWE, RELIEVED, SUSPICIOUS, SOLEMN, HURT = range(12, 19)
NEW = (DETERMINED, WORRIED, SMIRK, THINKING)
NEW2 = (EXASPERATED, GRIN, AWE, RELIEVED, SUSPICIOUS, SOLEMN)
CLEAR = "clear"
MAGENTA = (255, 0, 255, 255)
FILL_BOX = (10, 20, 30, 27)

# Purchased cells used as starting points.
NEUTRAL, HALF_LID, CLOSED = (0, 0), (0, 1), (0, 2)
SRC_HAPPY, SRC_ANGRY, SRC_SHOCK = (3, 0), (3, 1), (3, 2)
SRC_HURT = (2, 3)

# Named colours. Skin layers: o outline, d dark, q red-dark, m mid, c red-mid, s shadow, l light,
# w skin. Eyes: k iris dark, i iris, r iris bright, g eye white (grey), W eye white.
LETTERS = {
    "o": "#522c2c", "d": "#885038", "q": "#954e30", "m": "#b1704f", "c": "#c17353", "s": "#d08860",
    "l": "#e3aa7b", "w": "#f8d098",
    "k": "#760a09", "i": "#a81e1d", "r": "#ff0000", "g": "#d6d3e2", "W": "#ffffff",
}
FALLBACK = {"g": "W", "q": "d", "c": "m"}


def rows(y0, *lines, x=19):
    """Consecutive full rows starting at y0, each written from column x."""
    return [(y0 + i, x, line) for i, line in enumerate(lines)]


def face_table(det, det_blink, worried, worried_blink, smirk, smirk_blink, thinking, thinking_blink,
               smirk_base=HALF_LID):
    table = {
        (DETERMINED, REST): (NEUTRAL, det),
        (DETERMINED, BLINK): (CLOSED, det_blink),
        (WORRIED, REST): (NEUTRAL, worried),
        (WORRIED, BLINK): (CLOSED, worried_blink),
        (SMIRK, REST): (smirk_base, smirk),
        (SMIRK, BLINK): (CLOSED, smirk_blink),
        (THINKING, REST): (NEUTRAL, thinking),
        (THINKING, BLINK): (CLOSED, thinking_blink),
    }
    for row in NEW:
        for col in (TALK_A, TALK_B):
            table[(row, col)] = table[(row, REST)]
    return table


def eye_table(worried, thinking, smirk_base=HALF_LID, extra_clear=()):
    table = {(WORRIED, REST): (NEUTRAL, worried), (THINKING, REST): (NEUTRAL, thinking)}
    if smirk_base is not None:
        table[(SMIRK, REST)] = (smirk_base, [])
    for row in (WORRIED, SMIRK, THINKING):
        if (row, REST) in table:
            for col in (TALK_A, TALK_B):
                table[(row, col)] = table[(row, REST)]
    for row in (*extra_clear, ANGRY, SHOCK, *NEW):
        table[(row, BLINK)] = CLEAR
    return table


def shifted(edits, dx=0, dy=0, digit_map=None):
    out = []
    for y, x, digits in edits:
        if digit_map:
            digits = "".join(digit_map.get(d, d) for d in digits)
        out.append((y + dy, x + dx, digits))
    return out


# ==== face5 (round 1) =====================================================================

DETERMINED_BROW = [
    (20, 22, "77766555"),
    (21, 21, "654333345"),
    (22, 20, "6322223335"),
]
WORRIED_BROW = [
    (19, 21, "643566"),
    (20, 21, "75323445"),
    (21, 21, "77653234"),
]
WORRIED_LIDS = [(22, 21, "63222233"), (23, 21, "54...35")]
SMIRK_BROW = [
    (19, 22, "65433455"),
    (20, 21, "643222345"),
    (21, 21, "776666545"),
]
THINKING_BROW = [
    (18, 26, "4355"),
    (19, 22, "6543325"),
    (20, 21, "64322345"),
    (21, 21, "776666545"),
]
CLOSED_FAR_EYE = [(23, 13, "26"), (24, 13, "25"), (25, 13, "12")]

FACE5 = face_table(
    DETERMINED_BROW + [(23, 20, "64222225")], DETERMINED_BROW + [(23, 21, "5")],
    WORRIED_BROW + WORRIED_LIDS, WORRIED_BROW,
    SMIRK_BROW, SMIRK_BROW,
    THINKING_BROW, THINKING_BROW,
)
FACE5[(ANGRY, BLINK)] = (SRC_ANGRY, [(23, 22, "54445"), (24, 22, "42223"), (25, 23, "666"),
                                     (24, 13, "25"), (25, 13, "12")])
FACE5[(SHOCK, BLINK)] = (SRC_SHOCK, [(22, 21, "566655"), (23, 22, "76666"), (24, 22, "76666"),
                                     (25, 21, "522223")] + CLOSED_FAR_EYE)

EYE3 = {
    (WORRIED, REST): (NEUTRAL, [(23, 23, "335")]),
    (SMIRK, REST): (HALF_LID, []),
    (THINKING, REST): (NEUTRAL, [(24, 23, "125"), (25, 23, "555"), (25, 13, ".")]),
}
for _row in (WORRIED, SMIRK, THINKING):
    for _col in (TALK_A, TALK_B):
        EYE3[(_row, _col)] = EYE3[(_row, REST)]
for _row in (ANGRY, SHOCK, *NEW):
    EYE3[(_row, BLINK)] = CLEAR

# Every authored jaw cell first erases its mouth box back to the jaw's mouthless skin, then draws
# exactly one mouth, so a talk frame never shows the rest mouth beside the opening.
# Mouths are drawn in jaw3 coordinates inside x17-22, y32-35, which every jaw's box holds after
# its move. A value is a list of edits on the neutral cell, or (base cell, edits).
# Mouths use only the pack's own mouth colours: q #954e30, c #c17353, s #d08860, l #e3aa7b
# (jaw3 digits 3, 5, 6, 7). SOFT_MOUTH and check_mouths enforce it.
JAW3_NEW = {
    # Angry is a tight, flat, clenched mouth; the eyes carry the anger, as in the pack's own angry.
    (ANGRY, REST): [(34, 19, "cqqc")],
    (ANGRY, TALK_A): [(34, 19, "qqqq"), (35, 20, "cc")],
    (ANGRY, TALK_B): [(34, 19, "cqqc"), (35, 20, "s")],
    (DETERMINED, REST): [(34, 18, "qqqqq"), (35, 19, "sss")],
    (DETERMINED, TALK_A): [(33, 19, "ccc"), (34, 18, "qqqqq"), (35, 19, "sss")],
    (DETERMINED, TALK_B): [(33, 19, "sss"), (34, 18, "qqqqq"), (35, 19, "sss")],
    (WORRIED, REST): [(34, 19, "533"), (35, 22, "5")],
    (WORRIED, TALK_A): [(33, 20, "55"), (34, 20, "33"), (35, 20, "55")],
    (WORRIED, TALK_B): [(34, 20, "33"), (35, 20, "66")],
    (SMIRK, REST): [(32, 23, "6"), (33, 22, "3"), (34, 19, "653")],
    (SMIRK, TALK_A): [(33, 21, "53"), (34, 19, "6335")],
    (SMIRK, TALK_B): [(33, 22, "3"), (34, 19, "6535")],
    (THINKING, REST): [(34, 21, "6556")],
    (THINKING, TALK_A): [(33, 22, "66"), (34, 21, "6335"), (35, 22, "7")],
    (THINKING, TALK_B): [(34, 21, "6535")],
    (EXASPERATED, REST): [(34, 19, "cqc")],
    (EXASPERATED, TALK_A): [(33, 19, "sss"), (34, 18, "cqqqc")],
    (EXASPERATED, TALK_B): [(34, 18, "scqcs")],
    (AWE, REST): [(33, 20, "ss"), (34, 20, "cc")],
    (AWE, TALK_A): [(33, 20, "ss"), (34, 20, "qq"), (35, 20, "ss")],
    (AWE, TALK_B): [(33, 20, "ss"), (34, 20, "qc")],
    (SUSPICIOUS, REST): [(34, 18, "qqc")],
    (SUSPICIOUS, TALK_A): [(33, 18, "ss"), (34, 18, "qqq")],
    (SUSPICIOUS, TALK_B): [(34, 18, "cqq")],
    (SOLEMN, REST): [(34, 19, "qqq")],
    (SOLEMN, TALK_A): [(33, 19, "sss"), (34, 19, "qqq")],
    (SOLEMN, TALK_B): [(34, 19, "qqq"), (35, 20, "s")],
}
for _row in (ANGRY, *NEW, EXASPERATED, AWE, SUSPICIOUS, SOLEMN):
    JAW3_NEW[(_row, BLINK)] = JAW3_NEW[(_row, REST)]

# Grin, relieved and hurt are built from each jaw's own pack mouths (soft colours, no outline):
# ("packmouth", mouthless, cell, trim) copies the mouth pixels of a pack cell; trim "narrow" drops
# the mouth's rightmost column and "short" also its bottom row,
# ("grin", mouthless, variant) widens the pack happy mouth by one pixel a side and opens it to talk,
# ("relieved", mouthless) lifts both ends of the idle mouth by one pixel.
# Hurt talks with the pack shock mouth narrowed. The pack's own open hurt mouth (2, 2) sits on a
# frame whose chin drops a pixel, so it is not used.


def soft_rows(mouthless):
    return {
        (GRIN, REST): (NEUTRAL, [("grin", mouthless, REST)]),
        (GRIN, TALK_A): (NEUTRAL, [("grin", mouthless, TALK_A)]),
        (GRIN, TALK_B): (NEUTRAL, [("grin", mouthless, TALK_B)]),
        (GRIN, BLINK): (NEUTRAL, [("grin", mouthless, REST)]),
        (RELIEVED, REST): (NEUTRAL, [("relieved", mouthless)]),
        (RELIEVED, TALK_A): (NEUTRAL, [("packmouth", mouthless, (1, 1), "")]),
        (RELIEVED, TALK_B): (NEUTRAL, [("packmouth", mouthless, (1, 2), "")]),
        (RELIEVED, BLINK): (NEUTRAL, [("relieved", mouthless)]),
        (HURT, REST): (SRC_HURT, [("packmouth", mouthless, SRC_HURT, "")]),
        (HURT, TALK_A): (SRC_HURT, [("packmouth", mouthless, SRC_SHOCK, "narrow")]),
        (HURT, TALK_B): (SRC_HURT, [("packmouth", mouthless, SRC_SHOCK, "short")]),
        (HURT, BLINK): (SRC_HURT, [("packmouth", mouthless, SRC_HURT, "")]),
    }


def jaw_table(mouthless, happy_a, happy_b, shock_a, shock_b, dx=0, dy=0, digit_map=None, explicit=None):
    """jaw3's new-expression mouths moved by (dx, dy) onto this jaw, plus its own happy/shock talk.
    mouthless is (box, edits): the edits erase the neutral cell's mouth, and the box is the area
    every authored cell copies from that mouthless cell before its mouth is drawn. explicit gives a
    cell's final edits in this jaw's coordinates and palette."""
    erase = [("mouthless",) + mouthless]
    table = {
        (HAPPY, TALK_A): (SRC_HAPPY, erase + happy_a), (HAPPY, TALK_B): (SRC_HAPPY, erase + happy_b),
        (SHOCK, TALK_A): (SRC_SHOCK, erase + shock_a), (SHOCK, TALK_B): (SRC_SHOCK, erase + shock_b),
    }
    for key, value in JAW3_NEW.items():
        base, edits = value if isinstance(value, tuple) else (NEUTRAL, value)
        table[key] = (base, erase + shifted(edits, dx, dy, digit_map))
    for key, (base, edits) in soft_rows(mouthless).items():
        table[key] = (base, erase + edits)
    for (row, col), edits in (explicit or {}).items():
        table[(row, col)] = (NEUTRAL, erase + edits)
        if col == REST:
            table[(row, BLINK)] = (NEUTRAL, erase + edits)
    return table


# (x0, y0, x1, y1) mouth boxes, exclusive at the far edge, and the edits that erase the neutral mouth.
JAW3_MOUTHLESS = ((17, 32, 25, 36), [(34, 19, "888")])
JAW3 = jaw_table(
    JAW3_MOUTHLESS,
    [(33, 18, "753357"), (34, 19, "6556")], [(33, 19, "5335"), (34, 19, "7667")],
    [(33, 19, "6335"), (34, 19, "6335"), (35, 20, "656")], [(33, 20, "536"), (34, 20, "657")],
)

# ==== face1: brow y19-20, lid y22, eye y23-25 =============================================

F1_DET = rows(19, "77777765545", "77764322345", "77432222345")
F1_WOR = rows(18, "77643565555", "77753234455", "77776532345")
F1_RAISED = rows(18, "77764322345", "77432222345", "77777765555")
FACE1 = face_table(
    F1_DET + rows(22, "76322222455"), F1_DET + rows(22, "76577776555"),
    F1_WOR + rows(21, "77776544335", "77522222335"), F1_WOR,
    F1_RAISED, F1_RAISED,
    [(17, 26, "4355")] + F1_RAISED, [(17, 26, "4355")] + F1_RAISED,
)
FACE1[(HAPPY, BLINK)] = (SRC_HAPPY, [("fill", CLOSED)] + rows(23, "77777666555", "77654444455", "77532222665"))
FACE1[(ANGRY, BLINK)] = (SRC_ANGRY, [("fill", CLOSED), (23, 22, "54445"), (24, 22, "42223"), (25, 23, "666")])
FACE1[(SHOCK, BLINK)] = (SRC_SHOCK, [("fill", CLOSED), (22, 21, "566655"), (23, 22, "76666"),
                                     (24, 22, "76666"), (25, 21, "522223")])

# ==== face2: brow y19-20 with a tail into y21, lid y22, eye y23-25 =======================

F2_DET = rows(19, "66666666555", "66655554444", "65432112344")
F2_WOR = rows(18, "66532456555", "66642123344", "66665421234")
F2_RAISED = rows(18, "66655554444", "65432112344", "66666653234", "66666666554")
FACE2 = face_table(
    F2_DET + rows(22, "64321123434"), F2_DET + rows(22, "66466665434"),
    F2_WOR + rows(21, "65566543224"), F2_WOR,
    F2_RAISED, F2_RAISED,
    [(17, 26, "3244")] + F2_RAISED, [(17, 26, "3244")] + F2_RAISED,
)
FACE2[(ANGRY, BLINK)] = (SRC_ANGRY, [("fill", CLOSED), (23, 22, "43334"), (24, 22, "31112"), (25, 23, "555")])
FACE2[(SHOCK, BLINK)] = (SRC_SHOCK, [("fill", CLOSED), (22, 21, "455544"), (23, 22, "65555"),
                                     (24, 22, "65555"), (25, 21, "411112")])

# ==== face3: same layout as face5 (brow y20-21, lid y23, eye y24-25) =====================

F3_DET = rows(20, "66666666554", "66643333444", "66421122344")
F3_WOR = rows(19, "66532455554", "66642123344", "66665421234")
F3_RAISED = rows(19, "66643333444", "66421122344", "66665555434")
FACE3 = face_table(
    F3_DET + rows(23, "65321123554"), F3_DET + rows(23, "66455555554"),
    F3_WOR + rows(22, "66521111224", "6643...2454"), F3_WOR,
    F3_RAISED, F3_RAISED,
    [(18, 26, "3244")] + F3_RAISED, [(18, 26, "3244")] + F3_RAISED,
)
FACE3[(ANGRY, BLINK)] = (SRC_ANGRY, [("fill", CLOSED), (23, 22, "43334"), (24, 22, "31112"), (25, 23, "555")])
FACE3[(SHOCK, BLINK)] = (SRC_SHOCK, [("fill", CLOSED), (22, 21, "455544"), (23, 22, "65555"),
                                     (24, 22, "65555"), (25, 21, "411112")])

# ==== face4: heavy brow y21-22, lid y24, one-row eye y25, no half-lid cell ===============

F4_DET = rows(21, "66666665544", "66421123444", "64211112344")
F4_WOR = rows(20, "66532455544", "66641123344", "66665311234")
F4_RAISED = rows(20, "66421123444", "64211112344", "66666665544")
FACE4 = face_table(
    F4_DET + rows(24, "64321122444"), F4_DET + rows(24, "66455444444"),
    F4_WOR + rows(23, "65421111244", "6654...3444"), F4_WOR,
    F4_RAISED + rows(24, "65321111244") + [(25, 25, "2")], F4_RAISED,
    [(19, 26, "3244")] + F4_RAISED + rows(23, "65421122444", "6654...3444"), [(19, 26, "3244")] + F4_RAISED,
    smirk_base=NEUTRAL,
)
FACE4[(ANGRY, BLINK)] = (SRC_ANGRY, [("fill", CLOSED)] + rows(24, "55433344444", "65421122555"))
FACE4[(SHOCK, BLINK)] = (SRC_SHOCK, [("fill", CLOSED)] + rows(23, "55543334444", "55455555554", "65421122555"))

# ==== eyes ================================================================================

EYE1 = eye_table([(23, 23, "335")], [(23, 23, "125"), (24, 23, "245"), (25, 23, "555"), (25, 13, "..")],
                 extra_clear=(HAPPY,))
EYE2 = eye_table([(23, 23, "335")], [(23, 23, "125"), (24, 23, "245"), (25, 23, "555"), (25, 13, ".")])
EYE4 = eye_table([(24, 23, "444")], [(24, 23, "124"), (25, 23, "444")], smirk_base=None)
EYE5 = eye_table([(23, 23, "335")], [(24, 23, "125"), (25, 23, "555"), (25, 13, ".")])

# ==== jaws: jaw3's mouths moved to each jaw's mouth position ==============================

JAW1_MOUTHLESS = ((16, 32, 24, 36), [(34, 18, "888")])
JAW2_MOUTHLESS = ((16, 32, 25, 36), [(34, 18, "8888")])
JAW4_MOUTHLESS = ((16, 32, 24, 36), [(34, 18, "8888"), (35, 19, "88")])
JAW5_MOUTHLESS = ((15, 31, 22, 35), [(33, 17, "999")])
JAW_MOUTHLESS = {"jaw1": JAW1_MOUTHLESS, "jaw2": JAW2_MOUTHLESS, "jaw3": JAW3_MOUTHLESS,
                 "jaw4": JAW4_MOUTHLESS, "jaw5": JAW5_MOUTHLESS}

JAW1 = jaw_table(
    JAW1_MOUTHLESS,
    [(33, 17, "755557"), (34, 17, "753357"), (35, 18, "7667")], [(33, 17, "76557"), (34, 18, "6557")],
    [(33, 16, "86333578"), (34, 16, "86333568"), (35, 18, "6556")], [(33, 16, "88755788"), (34, 16, "88635688")],
    dx=-1,
    # The pack's talk B also moves a chin pixel at (22, 35), which reads as a second mark beside
    # the mouth; sad's talk B keeps that mouth on the still chin.
    explicit={(SAD, TALK_B): [(33, 18, "777"), (34, 18, "766")]},
)
JAW2 = jaw_table(
    JAW2_MOUTHLESS,
    [(33, 18, "755557"), (34, 18, "753357"), (35, 19, "7667")], [(33, 18, "765567"), (34, 18, "76557")],
    [(33, 16, "86333578"), (34, 16, "86333568"), (35, 18, "6556")], [(33, 16, "88753578"), (34, 16, "88633688")],
)
JAW4 = jaw_table(
    JAW4_MOUTHLESS,
    [(33, 18, "755557"), (34, 18, "753357"), (35, 19, "7667")], [(33, 18, "76557"), (34, 19, "6557")],
    [(33, 17, "86333578"), (34, 17, "86333568"), (35, 19, "6556")], [(33, 17, "88753578"), (34, 17, "88633688")],
)
# jaw5's box stops at x21 because of its cheek crease at x22, so the lopsided mouths sit one pixel
# further left than the plain move would put them.
JAW5 = jaw_table(
    JAW5_MOUTHLESS,
    [(32, 17, "755557"), (33, 17, "753357"), (34, 18, "7667")], [(32, 17, "76557"), (33, 18, "6557")],
    [(32, 17, "7667"), (33, 16, "9633359"), (34, 17, "633357")], [(33, 16, "9975579"), (34, 17, "96357")],
    dx=-1, dy=-1, digit_map={"8": "9"},
    explicit={
        (SMIRK, REST): [(31, 21, "6"), (32, 20, "3"), (33, 17, "653")],
        (SMIRK, TALK_A): [(32, 19, "53"), (33, 17, "6335")],
        (SMIRK, TALK_B): [(32, 20, "3"), (33, 17, "6535")],
        (THINKING, REST): [(33, 19, "655")],
        (THINKING, TALK_A): [(32, 20, "66"), (33, 19, "633"), (34, 20, "7")],
        (THINKING, TALK_B): [(33, 19, "653")],
    },
)

# ==== round 4: angry redraw and rows 12-18 for every face and eye shape ===================


def round4_face(table, raised, worried, lowered, lid, half, brow_top, angry_lid, hurt=None, lid_lowers=True):
    """raised/worried/lowered are the face's brow edits, lid its neutral upper-lid row, half the
    (base, edits) of its lowered-lid look, brow_top its neutral brow's top row, angry_lid the upper
    lid row of its angry cell. hurt replaces the pack's hurt cell when that cell shows no pain.
    lid_lowers is False for a one-row eye, which a lowered lid would close."""
    half_base, half_edits = half
    crease = [("swap", 26, 22, 27, "w", "l")]
    # Angry: the upper lid slants down to the inner corner and cuts the iris, the inner brows pinch
    # into a furrow, and the cheek tightens under the eye.
    furrow = [(brow_top, 21, "m"), (brow_top + 1, 20, "m"), (brow_top + 1, 21, "oo")]
    angry = [(angry_lid, 21, "oo"), (angry_lid + 1, 21, "ooo")] + furrow + crease
    blink_base, blink_edits = table[(ANGRY, BLINK)]
    table[(ANGRY, BLINK)] = (blink_base, blink_edits + furrow + crease)
    # Determined: a level lid one row lower across the whole eye, under the lowered brow.
    if lid_lowers:
        base, edits = table[(DETERMINED, REST)]
        level = edits + [(lid, 22, "mmmmm"), (lid + 1, 22, "ooooo")]
        for col in (REST, TALK_A, TALK_B):
            table[(DETERMINED, col)] = (base, level)
    rest = {
        ANGRY: (SRC_ANGRY, angry),
        EXASPERATED: (half_base, half_edits + raised),
        GRIN: (NEUTRAL, [(25, 25, "l")] + crease),
        AWE: (NEUTRAL, raised + [("lift", lid, 20, 29)]),
        RELIEVED: (NEUTRAL, worried + [("swap", lid, 20, 29, "o", "d")]),
        SUSPICIOUS: (half_base, half_edits + lowered),
        SOLEMN: (half_base, half_edits + worried),
    }
    blink = {EXASPERATED: raised, GRIN: crease, AWE: raised, RELIEVED: worried, SUSPICIOUS: lowered,
             SOLEMN: worried}
    if hurt:
        rest[HURT] = hurt
        blink[HURT] = worried
    else:
        table[(HURT, BLINK)] = (SRC_HURT, [("fill", CLOSED)])
    for row, spec in rest.items():
        for col in (REST, TALK_A, TALK_B):
            table[(row, col)] = spec
    for row, edits in blink.items():
        table[(row, BLINK)] = (CLOSED, edits)


def round4_eyes(table, top, far_width, half_cell=True):
    """top is the eye's first iris row in its neutral cell, far_width the far eye's width at x13."""
    rolled = [(24, 23, "kiW"), (25, 23, "ggW"), (25, 13, "." * far_width)]
    if top <= 23:
        rolled.append((23, 23, "..."))
    wide = [(top - 1, 23, "ggW"), (25, 23, "gWW")] if top < 25 else [(24, 23, "WWW")]
    rest = {EXASPERATED: (NEUTRAL, rolled), SUSPICIOUS: (NEUTRAL, [(25, 23, "Wik")]), AWE: (NEUTRAL, wide)}
    if half_cell:
        rest[SOLEMN] = (HALF_LID, [])
    for row, spec in rest.items():
        for col in (REST, TALK_A, TALK_B):
            table[(row, col)] = spec
    for row in (*NEW2, HURT):
        table[(row, BLINK)] = CLEAR


round4_face(FACE5, SMIRK_BROW, WORRIED_BROW, DETERMINED_BROW, 23, (HALF_LID, []), 20, 23)
round4_face(FACE1, F1_RAISED, F1_WOR, F1_DET, 22, (HALF_LID, []), 19, 23)
round4_face(FACE2, F2_RAISED, F2_WOR, F2_DET, 22, (HALF_LID, []), 19, 23)
round4_face(FACE3, F3_RAISED, F3_WOR, F3_DET, 23, (HALF_LID, []), 20, 23)
F4_HALF = rows(24, "65321111244") + [(25, 25, "2")]
round4_face(FACE4, F4_RAISED, F4_WOR, F4_DET, 24, (NEUTRAL, F4_HALF), 21, 24,
            hurt=(NEUTRAL, F4_HALF + F4_WOR), lid_lowers=False)
round4_eyes(EYE1, 23, 2)
round4_eyes(EYE2, 23, 1)
round4_eyes(EYE3, 24, 1)
round4_eyes(EYE4, 25, 2, half_cell=False)
round4_eyes(EYE5, 24, 1)

SHAPES = {
    "face5": (os.path.join("face", "face5", "face5_c1.png"), FACE5),
    "jaw3": (os.path.join("jaw", "jaw3", "jaw3_c1.png"), JAW3),
    "eye3": (os.path.join("eyes", "eye3", "eye3_c1.png"), EYE3),
    "face1": (os.path.join("face", "face1", "face1_c1.png"), FACE1),
    "face2": (os.path.join("face", "face2", "face2_c1.png"), FACE2),
    "face3": (os.path.join("face", "face3", "face3_c1.png"), FACE3),
    "face4": (os.path.join("face", "face4", "face4_c1.png"), FACE4),
    "jaw1": (os.path.join("jaw", "jaw1", "jaw1_c1.png"), JAW1),
    "jaw2": (os.path.join("jaw", "jaw2", "jaw2_c1.png"), JAW2),
    "jaw4": (os.path.join("jaw", "jaw4", "jaw4_c1.png"), JAW4),
    "jaw5": (os.path.join("jaw", "jaw5", "jaw5_c1.png"), JAW5),
    "eye1": (os.path.join("eyes", "eye1", "eye1_c1.png"), EYE1),
    "eye2": (os.path.join("eyes", "eye2", "eye2_c1.png"), EYE2),
    "eye4": (os.path.join("eyes", "eye4", "eye4_c1.png"), EYE4),
    "eye5": (os.path.join("eyes", "eye5", "eye5_c1.png"), EYE5),
}


def palette_of(sheet):
    return sorted({p for p in sheet.get_flattened_data() if p[3]})


def cell_of(sheet, r, c):
    return sheet.crop((c * FRAME, r * FRAME, (c + 1) * FRAME, (r + 1) * FRAME))


def rgba(hex_colour):
    h = hex_colour.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def colour(code, palette):
    if code == ".":
        return (0, 0, 0, 0)
    if code.isdigit():
        return palette[int(code) - 1]
    while rgba(LETTERS[code]) not in palette:
        if code not in FALLBACK:
            raise ValueError(f"colour {code} {LETTERS[code]} is not in this shape's palette")
        code = FALLBACK[code]
    return rgba(LETTERS[code])


def write(image, ox, oy, edits, palette):
    for y, x, codes in edits:
        for i, code in enumerate(codes):
            image.putpixel((ox + x + i, oy + y), colour(code, palette))


def mouthless_cell(sheet, edits):
    cell = cell_of(sheet, *NEUTRAL)
    write(cell, 0, 0, edits, palette_of(sheet))
    return cell


def pack_mouth(sheet, mouthless, cell):
    """{(x, y): colour} of the mouth in a pack cell: the largest 8-connected group of box pixels that
    differ from the jaw's mouthless cell and are not plain skin."""
    (x0, y0, x1, y1), erase = mouthless
    clean, source = mouthless_cell(sheet, erase), cell_of(sheet, *cell)
    plain_skin = {rgba("#f8d098"), rgba("#eebe8a")}
    found = {}
    for y in range(y0, y1):
        for x in range(x0, x1):
            p = source.getpixel((x, y))
            if p != clean.getpixel((x, y)) and p not in plain_skin:
                found[(x, y)] = p
    return largest_group(found)


def largest_group(found):
    best, todo = {}, set(found)
    while todo:
        group, stack = set(), [todo.pop()]
        while stack:
            x, y = stack.pop()
            group.add((x, y))
            for n in [(x + a, y + b) for a in (-1, 0, 1) for b in (-1, 0, 1)]:
                if n in todo:
                    todo.remove(n)
                    stack.append(n)
        if len(group) > len(best):
            best = {p: found[p] for p in group}
    return best


def soft_mouth(sheet, edit):
    """Pixels of a ("packmouth" | "grin" | "relieved", ...) edit."""
    palette = palette_of(sheet)
    kind, mouthless = edit[0], edit[1]
    (x0, y0, x1, y1), _ = mouthless
    inside = lambda x, y: x0 <= x < x1 and y0 <= y < y1
    if kind == "packmouth":
        _, _, cell, trim = edit
        pixels = pack_mouth(sheet, mouthless, cell)
        if trim in ("narrow", "short"):
            right = max(x for x, _ in pixels)
            pixels = largest_group({p: c for p, c in pixels.items() if p[0] != right}) or pixels
        if trim == "short":
            bottom = max(y for _, y in pixels)
            pixels = largest_group({p: c for p, c in pixels.items() if p[1] != bottom}) or pixels
        return pixels
    if kind == "relieved":
        pixels = pack_mouth(sheet, mouthless, NEUTRAL)
        left, right = min(pixels), max(pixels)
        for end in (left, right):
            pixels[(end[0], end[1] - 1)] = pixels.pop(end)
        return pixels
    variant = edit[2]
    pixels = pack_mouth(sheet, mouthless, SRC_HAPPY)
    inner = {colour(c, palette) for c in "dqmcs"}
    top = min(y for _, y in pixels)
    bottom = max(y for (_, y), c in pixels.items() if c in inner)
    top_xs = [x for x, y in pixels if y == top]
    for x in (min(top_xs) - 1, max(top_xs) + 1):
        if inside(x, top):
            pixels[(x, top)] = colour("l", palette)
    open_xs = [x for (x, y), c in pixels.items() if y == bottom and c in inner]
    if variant in (TALK_A, TALK_B):
        for x in open_xs:
            if variant == TALK_A:
                pixels[(x, bottom)] = colour("q", palette)
            if inside(x, bottom + 1):
                pixels[(x, bottom + 1)] = colour("c" if variant == TALK_A else "s", palette)
    return pixels


def draw(cells, sheet):
    palette = palette_of(sheet)
    out = Image.new("RGBA", (FRAME * COLUMNS, FRAME * ROWS))
    for (row, col), spec in sorted(cells.items()):
        ox, oy = col * FRAME, row * FRAME
        if spec == CLEAR:
            out.putpixel((ox, oy), MAGENTA)
            continue
        (sr, sc), edits = spec
        out.paste(cell_of(sheet, sr, sc), (ox, oy))
        for edit in edits:
            if edit[0] == "mouthless":
                _, box, erase = edit
                out.paste(mouthless_cell(sheet, erase).crop(box), (ox + box[0], oy + box[1]))
                continue
            if edit[0] == "fill":
                fr, fc = edit[1]
                x0, y0, x1, y1 = FILL_BOX
                for y in range(y0, y1):
                    for x in range(x0, x1):
                        source = sheet.getpixel((fc * FRAME + x, fr * FRAME + y))
                        if out.getpixel((ox + x, oy + y))[3] == 0 and source[3]:
                            out.putpixel((ox + x, oy + y), source)
                continue
            if edit[0] in ("packmouth", "grin", "relieved"):
                for (x, y), c in soft_mouth(sheet, edit).items():
                    out.putpixel((ox + x, oy + y), c)
                continue
            if edit[0] == "swap":
                _, y, x0, x1, a, b = edit
                for x in range(x0, x1):
                    if out.getpixel((ox + x, oy + y)) == colour(a, palette):
                        out.putpixel((ox + x, oy + y), colour(b, palette))
                continue
            if edit[0] == "lift":
                _, y, x0, x1 = edit
                for x in range(x0, x1):
                    out.putpixel((ox + x, oy + y - 1), out.getpixel((ox + x, oy + y)))
                    out.putpixel((ox + x, oy + y), out.getpixel((ox + x, oy + y + 1)))
                continue
            write(out, ox, oy, [edit], palette)
    return out


def recipe_source(layout, row, col):
    """The pack cell the build's recipe copies into jaw cell (row, col)."""
    expression = next(e for e in layout["expressions"] if e["row"] == row)
    cols = layout["expression_columns"]
    return {cols["talk_a"]: (1, 1), cols["talk_b"]: (1, 2)}.get(col, tuple(expression["source"] or NEUTRAL))


def jaw_cell(purchased_sheet, authored_sheet, layout, row, col):
    """The c1 jaw cell the build produces at (row, col): the authored cell, else the recipe cell."""
    cell = cell_of(authored_sheet, row, col)
    if cell.getbbox() is not None and cell.getpixel((0, 0)) != MAGENTA:
        return cell
    return cell_of(purchased_sheet, *recipe_source(layout, row, col))


def mouth_components(cell, mouthless, box):
    """8-connected groups of pixels in box that differ from the jaw's mouthless cell."""
    x0, y0, x1, y1 = box
    todo = {(x, y) for y in range(y0, y1) for x in range(x0, x1)
            if cell.getpixel((x, y)) != mouthless.getpixel((x, y))}
    groups = 0
    while todo:
        groups += 1
        stack = [todo.pop()]
        while stack:
            x, y = stack.pop()
            for nx in (x - 1, x, x + 1):
                for ny in (y - 1, y, y + 1):
                    if (nx, ny) in todo:
                        todo.remove((nx, ny))
                        stack.append((nx, ny))
    return groups


def check_mouths(purchased, authored, layout):
    """Every expression frame of every jaw must show exactly one mouth, and no outline-colour pixel in
    the mouth box unless the pack cell the recipe copies has that pixel too. Returns the failures."""
    failures = []
    outline = rgba(LETTERS["o"])
    for name, (box, erase) in JAW_MOUTHLESS.items():
        rel = SHAPES[name][0]
        purchased_sheet = Image.open(os.path.join(purchased, rel)).convert("RGBA")
        authored_sheet = Image.open(os.path.join(authored, rel)).convert("RGBA")
        mouthless = mouthless_cell(purchased_sheet, erase)
        x0, y0, x1, y1 = box
        for row in range(4, ROWS):
            for col in range(COLUMNS):
                cell = jaw_cell(purchased_sheet, authored_sheet, layout, row, col)
                groups = mouth_components(cell, mouthless, box)
                if groups != 1:
                    failures.append(f"{name} row {row} col {col}: {groups} mouth shapes")
                source = cell_of(purchased_sheet, *recipe_source(layout, row, col))
                dark = [(x, y) for y in range(y0, y1) for x in range(x0, x1)
                        if cell.getpixel((x, y)) == outline and source.getpixel((x, y)) != outline]
                if dark:
                    failures.append(f"{name} row {row} col {col}: outline colour in the mouth at {dark[:4]}")
    return failures


def check(image, allowed):
    """Opaque pixels outside the palette, ignoring the magenta clear marker at a cell's top-left."""
    bad = set()
    for y in range(image.height):
        for x in range(image.width):
            p = image.getpixel((x, y))
            if p[3] == 0 or p in allowed:
                continue
            if p == MAGENTA and x % FRAME == 0 and y % FRAME == 0:
                continue
            bad.add(p)
    return bad


def main() -> int:
    purchased, authored = sys.argv[1:3]
    failed = False
    for name, (rel, cells) in SHAPES.items():
        sheet = Image.open(os.path.join(purchased, rel)).convert("RGBA")
        image = draw(cells, sheet)
        bad = check(image, set(palette_of(sheet)))
        if bad:
            print(f"FAIL {name}: off-palette colours {sorted(bad)}")
            failed = True
            continue
        target = os.path.join(authored, rel)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        image.save(target)
        print(f"OK {name} ({len(cells)} cells, palette check passed)")
    layout_path = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(authored)),
                                                                       "sheet_layout.json")
    layout = json.load(open(layout_path, encoding="utf-8"))
    failures = check_mouths(purchased, authored, layout)
    for line in failures:
        print("FAIL", line)
    if not failures:
        print(f"OK mouth check: one soft mouth, no added outline colour, in every frame of rows 4-{ROWS - 1} for {', '.join(JAW_MOUTHLESS)}")
    return 1 if failed or failures else 0


if __name__ == "__main__":
    sys.exit(main())
