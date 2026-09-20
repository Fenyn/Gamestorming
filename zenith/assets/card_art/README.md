# Card art

One PNG per card id: `no_quarter.png`. Duelists may add `<id>_a<aspect>.png`; a missing Aspect file falls back to `<id>.png`. Ids and briefs: `docs/card_roster.md`.

An `.svg` of the same name is used when no PNG is there. The house crests in here are placeholders in that form: one per character, a base crest per house with a difference for each variant. Drop a PNG in beside one and the PNG wins, so the crest can stay until the painting arrives.

The image covers the art box and is cropped, so match the box's shape and keep the subject centred. The box is 452 wide and `CardFace.ART_HEIGHTS` tall, which at twice size gives:

| Card type | File size |
|---|---|
| Personality | 604 x 868 |
| Strike, Art, Seal | 904 x 640 |
| Combat | 904 x 600 |
| Non-Combat, Drill, Grounds | 904 x 480 |
| Mastery, Relic | 904 x 400 |

The roster's `Canvas` column is squarer than this for Combat and below, so a file cut to it loses its top and bottom.

The SVG rasterizer ignores `<text>` and `<pattern>`, so placeholder crests draw captions and fills as shapes. `tools/art_sheet.gd` renders any list of ids to one contact sheet for review. Open the project in the editor once (or run `--headless --path zenith --import`) after adding files.
