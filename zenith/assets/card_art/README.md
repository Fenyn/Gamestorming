# Card art

One PNG per card, named by the card's id, in the folder named by the id's first word: `pyre/pyre_strike_07.png`, `signature/signature_art_03.png`, `personality/personality_17.png`. Ids are generic (since 2026-09-23) and never follow a card's title, so renaming a card never moves its art. Which id is which card, with its art brief, is in `docs/card_roster.md`.

Folders: `pyre`, `steel`, `tide`, `storm`, `shade`, `root` (school cards and that school's Masteries), `freestyle`, `signature` (cards tied to a named character), `personality` (one file per Aspect card), `seal`, `grounds`, `relic`. The test suite fails if a file here does not name a card or sits in the wrong folder.

An `.svg` of the same name is used when no PNG is there. The house crests in here are placeholders in that form: one per character, a base crest per house with a difference for each variant. Drop a PNG in beside one and the PNG wins, so the crest can stay until the painting arrives.

Personality portraits can have a transparent background. The face fills the art box behind them with the Mastery school hue of the deck the card is shown for, darkened (`CardFace.mastery_backdrop`), so one portrait suits any deck the character leads. In a duel each seat uses its own deck's colour.

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
