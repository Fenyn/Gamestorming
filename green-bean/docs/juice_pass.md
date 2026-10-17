# Juice Pass — Effects, Shaders and Feel

Visual feedback added on top of the grey-box gameplay. None of it changes scoring or timing. Sound was left out on purpose.

Every number below is a first guess meant to be tuned in the editor. The project was checked with Godot 4.6 in a cloud session: assets import cleanly, the shop scene runs headless with no script errors, and the screenshot tour below renders. That session had no GPU, so it used the Compatibility renderer, which has no SSAO and draws glow differently from Forward+.

## Screenshot tour

`scenes/debug/screenshot_tour.tscn` stages a scene and saves PNGs from fixed camera spots. It sets up customers, tickets, filled cups, a scalding pitcher, a kettle pour and a tip. It unlocks all stations in memory only and never saves.

```
godot --path . --resolution 1280x720 res://scenes/debug/screenshot_tour.tscn -- --out=/some/folder
```

On Linux without a GPU, run it under Xvfb with Mesa's software OpenGL:

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 res://scenes/debug/screenshot_tour.tscn -- --out=/some/folder
```

## Where things live

| File | What it does |
|---|---|
| `scripts/autoload/fx.gd` (autoload `Fx`) | Shared helpers: soft particle texture and material, `coin_burst`, `sparkle_burst`, `float_text`, `pop`, `make_specks` |
| `scripts/fx/steam_puffs.gd` (`SteamPuffs`) | Steam particles with `set_level(0..1, harsh)` |
| `scripts/fx/pour_stream.gd` (`PourStream`) | Liquid stream drawn between a source point and a target, shown while `flow_check` returns true |
| `scripts/shops/day_lighting.gd` | On the `Sun` node. Moves and tints the sun, sky horizon and ambient light over the day |
| `assets/shaders/liquid.gdshader` | Liquid in cups and the pitcher: sloshing surface and a foam band |
| `assets/shaders/hover_rim.gdshader` | Pulsing rim glow on whatever the crosshair can act on |
| `assets/shaders/pour_stream.gdshader` | Wavering, banded water stream |

## What each effect is tied to

**Environment** (`espresso_stand.tscn` → `Environment`)
- Procedural sky, filmic tonemap, SSAO, glow, +8% saturation. MSAA 4x in `project.godot`.
- The day runs from cool morning light (prep) through midday to orange golden hour at the end of the day timer. Keyframes are the `KEYS` table in `day_lighting.gd`.

**Steam station**
- Steam thickens while stretching and as the milk heats.
- Past the target temperature it gets faster and greyer. At scald it stays harsh. This is the visual half of the scald warning in CLAUDE.md.
- Milk in the pitcher is visible now (the pitcher is hollow). It warms in colour, rises as foam builds, and turns tan when scalded.

**Cups**
- Cups are hollow, so the drink inside shows. Liquid sloshes when the cup is carried or moved.
- Lattes and cappuccinos show a foam band sized from the pitcher's foam level.
- Hot drinks steam. `Cup.heat` drops from 1 to 0 over `COOL_TIME` (60 s), and the pour-over sets it from its freshness while the cup is still on the station. A lid cuts the steam to about a third.
- The lid is now visible and pops on.
- Each cup has a paper sticker with its ticket code.

**Pours**
- Kettle pours (pour-over bloom and main pour, shot press water) draw a stream from the spout while the mouse is held.
- The hot water station draws a stream into the held cup or kettle.
- Pour-over draw-down drips coffee into the cup.

**Grinder**
- A crank handle on the side turns with the player's mouse circles.
- Grounds fall into the device while cranking.

**Orders and money**
- Printed tickets pop up on a rail above the cup stack, oldest on the left (from the barista's side). Grabbing a cup tears off the oldest one.
- The register shows a floating `+$price` when an order is sent.
- The hand-off review label pops. 4.5+ stars throws sparkles. A tip throws coins and a floating `+$tip`.
- The 2D review popup scales in with an overshoot.

**Player**
- The camera eases into station views (0.25 s) and back out (0.15 s) instead of snapping. Mouse look is ignored during the ease.
- Held items lag behind fast turns and bob while walking.
- Picked-up items fly into the hand from where they were.
- Items placed on a station slot drop the last 4 cm with a small bounce.
- Whatever the crosshair can act on gets a warm rim glow. Items sitting on a station are not lit with it.

**Customers**
- Two eyes on the front, so facing reads.
- They turn toward where they walk, and toward the player while waiting.
- They hop and waddle while walking and breathe while idle. Below 35% patience they start swaying.
- Patience bars blend green to yellow to red. Below 25% the bar shakes and pulses.

## Tuning knobs

| What | Where |
|---|---|
| Sun path and colours | `KEYS` in `scripts/shops/day_lighting.gd` |
| SSAO, glow, tonemap | `Environment` sub-resource in `scenes/shops/espresso_stand.tscn` |
| Hover glow colour and strength | uniforms in `assets/shaders/hover_rim.gdshader` |
| Held item sway and bob | `SWAY_*` and `BOB_*` constants in `scripts/player/player.gd` |
| Camera ease times | `CAMERA_ENTER_TIME`, `CAMERA_EXIT_TIME` in `player.gd` |
| Slosh springiness | `SLOSH_STIFFNESS`, `SLOSH_DAMPING` and the `-0.0006` push factor in `scripts/items/cup.gd` `_process` |
| Drink cooling time | `Cup.COOL_TIME` |
| Steam amount and size | `SteamPuffs.new(amount, size, rise)` calls in `cup.gd` and `steam_station.gd` |

## Things that need a look in the editor

- Steam drawn right in front of the camera when carrying a hot cup may be too strong.
- Customers face +Z by their eyes now. If the face ends up on the back, flip the eye z or the `atan2` in `customer.gd`.
- The hover glow is additive and may look loud on white items.
- The pour stream starts from a guessed spout tip, `StationUtils.KETTLE_SPOUT_TIP`. It may need moving once the kettle tilt is visible.
- The camera ease tweens a whole `Transform3D`. If the view squashes mid-move or logs "det == 0" errors, switch it to a `tween_method` that slerps a Quaternion and lerps the position.
- The water stream at the hot water station aims at the held item, which floats at the hold point during the camera lock. It may look odd until the station has a real model.
