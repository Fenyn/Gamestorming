"""Generate crisp SVG nine-patches. Run from any directory with Python 3.

Geometry follows the existing fantasy controls; colors use the aubergine/persimmon UI palette.
The original Aseprite artwork remains available as an alternate treatment.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets" / "ui"


def save(name, width, height, body):
    (OUT / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" shape-rendering="crispEdges">\n{body}\n</svg>\n',
        encoding="utf-8",
    )


# Face, recess, outer edge, inner bevel. Hover changes both hue and brightness.
STATES = {
    "normal": ("3b2c40", "211925", "a18aa0", "513d55"),
    "hover": ("59405a", "3b2c40", "d5ef91", "92718e"),
    "pressed": ("211925", "19121e", "ff957d", "775f78"),
    "disabled": ("251e2b", "1c1722", "4c4052", "352b3c"),
    "accent": ("753e4c", "412735", "ff957d", "bb6472"),
}
for state, (face, recess, edge, bevel) in STATES.items():
    save(f"button_{state}", 96, 40, f'''
  <path fill="#140f18" d="M9 3H85L94 11V30L86 39H10L2 30V11Z"/>
  <path fill="#{edge}" d="M10 2H85L93 10V29L85 37H10L3 29V10Z"/>
  <path fill="#{face}" d="M11 4H84L91 11V28L84 35H11L5 28V11Z"/>
  <path fill="none" stroke="#{bevel}" d="M12 7H83L88 12V27L83 32H12L8 27V12Z"/>
  <path fill="#{recess}" d="M13 33H83V35H13Z"/>
  <path fill="#{edge}" d="M4 19L7 16L10 19L7 22ZM86 19L89 16L92 19L89 22Z"/>
''')
save("button_focus", 96, 40, '''
  <path fill="none" stroke="#d5ef91" stroke-width="2" d="M2 14V9L10 1H22M74 1H86L94 9V14M2 26V31L10 39H22M74 39H86L94 31V26"/>
''')
save("result_frame", 128, 128, '''
  <path fill="#140f18" d="M15 3H112L125 16V111L112 125H15L3 111V16Z"/>
  <path fill="#b66d76" d="M16 6H110L122 18V109L110 121H17L6 109V18Z"/>
  <path fill="#3b2c40" d="M17 8H109L120 19V108L109 119H18L8 108V19Z"/>
  <path fill="#775f78" d="M20 12H105L116 22V104L105 115H22L12 104V23Z"/>
  <path fill="#211925" d="M21 14H104L114 23V103L104 113H23L14 103V24Z"/>
  <g fill="#ff957d">
    <path d="M18 14L22 18L18 22L14 18Z"/>
    <path d="M110 14L114 18L110 22L106 18Z"/>
    <path d="M18 106L22 110L18 114L14 110Z"/>
    <path d="M110 106L114 110L110 114L106 110Z"/>
  </g>
''')
save("result_rule", 400, 20, '''
  <path fill="#a18aa0" d="M0 9H173V11H0ZM228 9H400V11H228Z"/>
  <path fill="none" stroke="#b66d76" d="M181 10L188 6L195 10L188 14ZM205 10L212 6L219 10L212 14Z"/>
  <path fill="#ff957d" d="M200 2L206 10L200 18L194 10Z"/>
''')
