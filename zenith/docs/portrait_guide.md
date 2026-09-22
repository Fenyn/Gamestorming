# Aspect portrait guide

How to turn one hand-drawn duelist portrait into a set of Aspect portraits. Worked out on Bram
Ashmark, 2026-09-22 (his seven files in `assets/card_art/personality_bram_ashmark_*.png` are the
reference result). Read the character's entry in `cast.md` first: its Aspect table gives the look
of each rung.

## Inputs and outputs

- **Input:** the user's tier 1 bust, an `.aseprite` file with a transparent background. Never edit it.
- **Output per Aspect:** a layered `.aseprite` next to the base (`<Name>_T<n>_<Aspect>.aseprite`)
  plus a flat PNG at the base's size.
- **In game:** copy each PNG to `assets/card_art/<card id>.png`. The card id is in `card_roster.md`.
  A PNG takes priority over an SVG crest with the same name, so leave the crests in place. Run
  `--headless --path zenith --import` afterwards.
- **Background stays transparent.** The card face paints the deck's Mastery colour behind the
  portrait, so one image suits every deck the character leads. Never bake a backdrop into the file.

## Pipeline

1. Draw each effect as its own full-canvas PNG layer from a script (Python with numpy), using masks
   of the base: skin, hair, body, metal, and distance to the silhouette edge.
2. Stack the layers over the untouched base in Aseprite batch mode with a Lua script
   (`Aseprite.exe -b --script-param ... --script assemble.lua`). Give each layer a plain name
   ("Cloak edges burning", "Eyes dimmed") and a blend mode (Multiply grades, Overlay heat, Normal
   for everything else).
3. Preview at 3x to 4x, nearest-neighbour, on a dark background. Show tiers side by side, and zoom
   into the face.
4. Iterate on the script, not by hand. Keep one script per Aspect and share the helpers.

The Bram scripts are in `F:\UnityNVME\Art\_Zenith\Tests\_scripts`. `bram_fx.py` holds the masks,
the flame tongue, the burnt edge, the grade and the brand strokes, and `assemble.lua` is generic.
Face coordinates in them are specific to Bram's bust, so re-measure them for each new portrait
from a gridded close-up.

## Design rules

- **The pose and crop never change.** Each Aspect is carried by colour, light and accents.
- **Give each deck line one palette and move it steadily up the ladder.** On Bram, Wildfire Rush
  is gold heading toward white with fire pushing outward. Last Standing is crimson and char that
  darkens each tier, and the first white only arrives with the brand at tier 4.
- **Add one signature mark and grow it tier by tier.** Bram's Pact brand is a set of face marks:
  a dark scar at tier 2, orange lines at tier 3, white at tier 4, spread across the face at tier
  5. Draw every tier from one set of stroke shapes, so the marks sit in the same place and only
  grow.
- **Marks are skin-only.** Nothing crosses onto armour or clothing.
- **Keep the face readable.** Never put flames or veils over the eyes or cheek. Effects radiate
  out from the silhouette.
- **Leave the eyes almost untouched.** A shadow over them or a tint in the iris is fine, but the
  whites, iris shape and lash line stay whole at every tier. No black, blank or glowing-out eyes.
- **Grow effects by getting thicker, not more numerous.** Repeating the same strand three or four
  times reads as clutter. Tier up by merging strands into one heavier mass, and let one part of it
  turn into something new (Sable's shadow sheet curls up into a blade at tier 3).
- **Loose single-pixel particles read as noise** at card size. Use shapes with a few pixels of body
  and a lit edge, or leave them out.
- **No symbols that read as real-world icons.** A ring with a bar through it read as a peace sign.
- **No soft round glows.** An airbrushed bloom looks pasted on over pixel art. Use one step of
  tinted heat around a mark, or stepped alpha rings.
- **Fire is a mass of tongues, not tubes.** Streams drawn as ribbons read as tentacles. Use
  billowing gout shapes (narrow at the source, rolling edges, fraying tips), or overlapping flame
  tongues with a single colour ramp by distance from the source. For an eruption, use a core blob
  with rings of tongues stacked outward.
- **Heat fades by distance.** The hottest colour sits at the source and cools outward. Keep the
  outer band one step brighter than the darkest cloth, or the tips vanish against the body.

## Clean pixel work

- Build shapes from hard-edged nested bands (outer dark rim, then mid, then core), never gradients.
- Add a one-pixel dark outline round a flame mass where it leaves the silhouette.
- After compositing, merge lone pixels into their most common neighbour. A 3x3 median suits broad
  shapes but eats thin tongues.
- Step every alpha falloff in fixed increments, for example multiples of 24 or 40.
- Ignore loose single pixels in the source art when finding edges, or they sprout their own
  flames and halos.

## Check before handing over

- Compare the tiers of each line side by side at the same zoom, so the progression reads.
- In game: `res://scenes/select/versus.tscn -- --dev-pick=A,B --dev-ai --dev-aspect=N
  --dev-screenshot=<png>` shows the card at a real size. The art box crops the right edge a little,
  so keep key detail away from it.
- List the guesses you made (mark designs, colour calls, anything the cast doc does not specify)
  in your report, and update `cast.md` if the art changes a described look.
