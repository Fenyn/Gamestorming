# PolyBlocks EffectBlocks PixelRenderer v2

A desktop tool that plays a 3D EffectBlocks particle effect in front of an
orthographic camera, runs the render through a pixel-art post shader, and saves
the result as a numbered sequence of PNG files.

Package location:
`F:\UnityNVME\Art\GodotVFX\PolyBlocks_EffectBlocks_PixelRenderer_v2\PolyBlocks_EffectBlocks_PixelRenderer`

Three folders:

- `EffectBlocks-PixelRenderer [Windows standalone]`: one file,
  `EffectBlocks-PixelRenderer.exe`, 134 MB, pck embedded.
- `EffectBlocks-PixelRenderer [Linux standalone]`:
  `EffectBlocks-PixelRenderer.x86_64` (70 MB) plus
  `EffectBlocks-PixelRenderer.pck` (37 MB). Both files must stay together.
- `PolyBlocks [Pixel Renderer Project]`: the Godot source, as
  `PolyBlocks/PixelRenderer` and `PolyBlocks/EffectBlocks`.

Built with Godot 4.4.1 stable (version string read out of the Linux binary).

## It does not make a sprite sheet

The name suggests a sheet. It writes one PNG per frame and stops there. There is
no packing step anywhere in the code. You assemble the sheet yourself, or import
the loose frames straight into `SpriteFrames`.

## Launching

Standalone: double-click `EffectBlocks-PixelRenderer.exe`. Nothing to install.
The window wants roughly 1900x1100, because the preview canvas alone is 1024x1024
with a control column beside it.

From source: there is **no `project.godot`** in
`PolyBlocks [Pixel Renderer Project]`. It is a drop-in folder, not a project.
To open it:

1. Make an empty Godot 4.4+ project using Forward+.
2. Copy the whole `PolyBlocks` folder into the project root, so paths resolve as
   `res://PolyBlocks/PixelRenderer/...` and `res://PolyBlocks/EffectBlocks/...`.
   The hardcoded `preload()` paths in the scripts assume exactly this layout.
3. Set the main scene to `res://PolyBlocks/PixelRenderer/PixelRenderer.tscn`,
   or just open that scene and press F6.

## The UI, left to right

**Preview canvas**: a 1024x1024 `TextureRect` showing the `SubViewport`
texture with the pixel-art shader applied. Its refresh is driven by a `Timer`,
not by the engine frame rate.

**Effect picker**: a Category dropdown and an Effect dropdown, plus a search
box that matches on effect or category name. 67 effects across Attacks, Energy,
Explosions, Fire, Impacts, Loot, Muzzle Flash, Nature, Other, Smoke, Splashes.
Until you pick something, the scene shows a mock skeleton holding a lit torch.

**Output row**: Start, End, FPS, Prefix.

**Resolution row**: Resolution (px), "Export preiew" checkbox (sic),
"Background color" checkbox and colour picker.

**Transform block**: Position X/Y/Z, Zoom, Reset; Rotation X/Y/Z, four arrow
buttons that step 90 degrees, Reset.

**Pixel block**: Color steps, Edge strength, Sharpness, Hue shift, Saturation,
Value, Contrast, Gamma, Brightness, Outline, outline colour, "Use palette" plus
eight colour swatches, Reset.

**Export**: a folder button, a path label, an Export button, a progress bar and
a console log.

## What each setting actually does

| Control | Effect |
| --- | --- |
| Resolution | Two jobs. It sets the shader's `target_pixel_count` (how chunky the pixels look) *and* the nearest-neighbour downscale applied to the saved PNG. Output is always square. Default 512. |
| Color steps | Per-channel quantisation, 2 to 32. At 32 the quantise step is skipped. |
| Edge strength | Sobel threshold above which a pixel counts as an edge. Only matters when Outline is above 0. |
| Sharpness | Unsharp mask strength on the pixelated sample. |
| Hue shift / Saturation / Value | HSV adjustment, applied before quantisation. |
| Contrast / Gamma / Brightness | Standard tone tweaks, also before quantisation. |
| Outline | Blend amount toward the outline colour on detected edges, 0 to 5. |
| Use palette + 8 swatches | Snaps every pixel to the nearest of eight colours by RGB distance. Defaults are the SLSO8 ramp. |
| Background color | Unchecked, the PNG keeps its alpha. Checked, a `ColorRect` of the chosen colour sits behind the effect and the frame comes out opaque. |
| Position X/Y/Z, Rotation X/Y/Z, arrow buttons | Move and rotate the effect node, not the camera. Reset puts it back to 0,0,0. |
| Zoom | Sets the orthographic camera's `size`. Default 4.0. Smaller means closer. |
| Prefix | Filename prefix. Empty falls back to `frame`. |
| FPS | See the gotcha below. It does not control capture timing. |
| Export preiew | Checked, the 1024x1024 capture is saved as-is and Resolution is ignored for the file. |

There is no camera-angle preset, no light control and no palette file import.
Lighting is fixed: one `DirectionalLight3D` with shadows, a `WorldEnvironment`
with a grey procedural sky, filmic tonemapping and glow on.

## Output

- Individual PNGs, RGBA8, square, written straight into the folder you picked.
- Naming: `<prefix>_%04d.png`, so `fireball_0000.png` through `fireball_0030.png`.
- Written with `Image.save_png()` to a real filesystem path. The file dialog uses
  `ACCESS_FILESYSTEM`, so you can pick anywhere you have write permission.
- Shader settings persist between runs in `user://material_config.cfg`.

## How capture works

The scene keeps a 1024x1024 `SubViewport` with `transparent_bg` on and an
orthographic `Camera3D` inside it. The effect nodes live in the main scene, and
the `SubViewport` shares that `World3D`, so the camera sees them. The preview
`TextureRect` displays the viewport texture through the pixel shader.

On export the tool does not read the `SubViewport` directly. For each frame it
creates a throwaway transparent `SubViewport`, duplicates the whole `Renderer`
panel (background rect plus the shaded canvas) into it, waits two process frames,
calls `get_texture().get_image()`, converts to RGBA8, then downscales with a
hand-written nearest-neighbour loop in GDScript. That is why the shader and the
background colour are baked into the PNG.

## Feeding it your own effect

There is no folder scan and no registration file. `effects_spawner.gd` holds a
list of `const NAME = preload("res://PolyBlocks/EffectBlocks/assets/.../x.tscn")`
plus a hand-written `effect_categories` dictionary. The standalone build cannot
be extended at all.

From the project copy you have two options.

**Option A, no code change.** Open `PixelRenderer.tscn`, find
`EffectsHandler/EffectsSpawner/MockEffect`, delete its children and instance your
own scene there. It is the default visible effect, so just run and export. Do not
touch the category dropdowns afterwards, because selecting an effect frees
`MockEffect`.

**Option B, add it to the menu.** In
`PolyBlocks/PixelRenderer/data/scripts/effects_spawner.gd` add a
`const MY_FX = preload("res://path/to/my_fx.tscn")` and an entry in
`effect_categories`, for example `"Fire": { ..., "My FX": MY_FX }`. It shows up
in the dropdown and in search on the next run.

### Using effects from the newer v4 package

The EffectBlocks copy bundled here is an older build than
`F:\UnityNVME\Art\GodotVFX\EffectBlocks v4`. Replacing it wholesale breaks the
tool, because 13 of the hardcoded preload paths were renamed or removed, and
`PixelRenderer.tscn` itself preloads `fire/fire_small.tscn` for the torch.

Renames, bundled name to v4 name:

`crystal_attack` / `earth_attack` / `fire_attack` → `attack_crystal` /
`attack_earth` / `attack_fire`; `electric_explosion` → `explosion_electric`;
`explosion_big` / `explosion_small` → `explosion_heavy` / `explosion_light`;
`fire_big` / `fire_small` → `fire_heavy` / `fire_light`;
`smoke_big` / `smoke_small` → `smoke_heavy` / `smoke_light`;
`portal` → `portal_fire` and `portal_magic`. `plasma_beam` has no v4 equivalent.

Safer path: keep the bundled EffectBlocks where it is and copy only the
individual v4 scenes you want into your project under a different folder, then
register them with Option B.

## Gotchas

- **Start and End are dead controls.** `StartFrameSpin` and `EndFrameSpin` exist
  in the scene but nothing in `PixelRenderer.gd` reads them. The export range
  comes from `@export var start_frame = 0` / `end_frame = 30`, so every export is
  31 frames, 0000 to 0030. Changing it means editing the script or setting the
  exported values on the root node in the editor.
- **FPS does not control capture timing.** It only sets the preview refresh
  timer. The export loop advances with `await get_tree().process_frame`, so
  consecutive PNGs are one engine frame apart at whatever rate the machine is
  running. A slower or faster GPU changes how much of the effect you capture. The
  FPS number is a label for your own playback rate, nothing more.
- **You cannot sync the capture to the start of the effect.** Export grabs 31
  frames of whatever is already playing. Looping effects are fine; one-shots need
  re-picking the effect and hitting Export quickly, or repeated attempts.
- **Resolution is overwritten on startup.** `PixelRenderer._ready()` forces the
  spin box to 512 after `pixel_material.gd` has loaded the saved config, so the
  persisted resolution never survives a restart. The other shader settings do.
- The downscale is a per-pixel GDScript loop over the target image. At high
  resolutions each frame takes a noticeable moment.
- The export runs on the main thread with the UI frozen except for the console.
- Needs a GPU that runs Forward+ (Vulkan). The shader is `canvas_item` and does
  not use `screen_texture`, so it is not exotic, but the 1024x1024 viewport plus
  glow is not a low-end load.
- The tool never deletes old frames. Re-exporting with the same prefix into the
  same folder overwrites 0000 to 0030 and leaves any longer old sequence behind.

## Using the output in a 2D Godot game

The frames are transparent RGBA PNGs of equal size, which is the easy case.

Loose frames into an `AnimatedSprite2D`:

1. Drop the PNG folder into your project.
2. In the Import dock set Filter to Nearest for those textures, otherwise the
   pixels blur when scaled.
3. Add an `AnimatedSprite2D`, create a new `SpriteFrames`, select all the PNGs in
   the FileSystem dock and drag them into the frames list. They sort by the
   `_0000` suffix.
4. Set the animation FPS to whatever you exported at conceptually, usually 12 to
   24, and set Loop off for one-shots.

If you want a single sheet instead, pack the frames with an external tool
(ImageMagick `montage`, TexturePacker, `aseprite --sheet`) into a fixed grid,
then in Godot use `SpriteFrames` "Add Frames from Sprite Sheet" and give it the
horizontal and vertical counts. A 6x6 grid holds the 31 frames with five spare.

For a one-shot effect, connect `animation_finished` to `queue_free()` on the
node. For additive-looking fire and explosions, set the sprite's
`CanvasItem.material` to a `CanvasItemMaterial` with Blend Mode set to Add, and
export with the background colour off so the alpha is intact.
