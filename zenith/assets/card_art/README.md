# Card art

One PNG per card, named by card id: `breaching_kick.png`. Fighters and Allies may add one per tier, `fighter_zeta_t2.png`; a tier without its own file falls back to `<id>.png`. Ids and a brief for every card are in `docs/card_roster.md`.

The art box on the face is 452 x 230 at the 512 x 716 render size (about 2:1, landscape). The image is scaled to cover the box and cropped, so keep the subject centered and paint at 904 x 460 or larger. Missing art shows the type glyph instead.

Drop the file here and open the project in the editor once (or run `--headless --path zenith --import`) so Godot imports it; the client loads by id at render time, no data change needed.
