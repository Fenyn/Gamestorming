# Coinshot — Project Guidance for Claude Code

A first-person, low-poly 3D **traversal prototype** in Godot 4 inspired by Brandon Sanderson's *Mistborn*. The core verb is **steel-pushing** and **iron-pulling** on metal anchors. Read this whole file before making non-trivial changes — it captures decisions that aren't obvious from the code alone.

---

## Vision

Build the smallest playable slice that proves the *feel* of Allomantic traversal is fun. **Traversal only** — no combat, no enemies, no story. If the basic verb feels good, combat layers on top later.

The player is a **Mistborn** (can both push steel and pull iron), not a Steel-only Coinshot, since the prototype exposes both verbs.

---

## Tech Stack

- **Godot 4.6 stable** (4.4+ should also work). Picked over Unity 6.3 LTS and Unreal 5.7 because Jolt is the default 3D physics in 4.6 (perfect for mass-aware push/pull), iteration is fastest, and Unreal's strengths (Nanite, Lumen, Substrate) are wasted on a low-poly first-person prototype.
- **GDScript** throughout. No C# / GDExtension.
- **Jolt physics** is enabled in `project.godot`: `physics/3d/physics_engine="JoltPhysics3D"`.
- **No external assets** — everything is built from Godot primitives + procedural geometry. No Asset Library deps.

---

## Lore Reference (the parts that affect code)

**Always-true rules** the simulation must respect:
- Push is straight-line *away* from the player's center; pull is straight-line *toward* it.
- Force is equal-and-opposite (Newton's 3rd). The player and target both feel an impulse, scaled inversely by mass.
- Heavy or anchored target → mostly the player moves. Light target → mostly the target moves.
- **Metal sense penetrates walls.** Inquisitors with no eyes still see the blue lines. Mist-vision is a sixth sense, not vision. Lines must render through geometry. *Do not* add line-of-sight raycasts to the mist-vision system.
- Coins are **dropped**, not "shot." The push provides all the motion.

**Deliberate prototype simplifications** (not lore violations — adapted for first-person FPS controls):
- Mist-vision is restricted to camera FOV (with ~10° pad). First-person has no shoulder-glance gesture; rendering off-screen lines would be invisible UI noise. Player turns their head to find anchors outside view.
- Active push/pull target is restricted to the camera-forward cone. In the books a Mistborn can push off anchors *behind* them; we defer that until we add a back-anchor hotkey or two-handed targeting.
- Single-anchor pushing only. Books describe a tripod of coins for stable flight — deferred.
- All metals push/pull identically. Books exclude aluminum; we don't model that yet.
- Brass/zinc/copper/bronze/etc. (emotional / cognitive metals) are out of scope.

---

## Project Layout

```
project.godot              Engine config, input map, Jolt enabled, gravity = 18 m/s²
icon.svg                   Project icon
README.md                  User-facing run instructions
scenes/
  Main.tscn                Root scene — single Node3D with world.gd attached
  Player.tscn              CharacterBody3D + Camera3D + AimRay + MistVision + Allomancy + HUD
  Coin.tscn                RigidBody3D, mass 0.5 kg, in "metal" group
  HUD.tscn                 Crosshair + translucent debug panel
scripts/
  world.gd                 Procedurally builds the playground at runtime
  player.gd                FPS controller, mouse look, coin spawning
  allomancy.gd             Targeting + push/pull math (the core)
  mist_vision.gd           ImmediateMesh blue line renderer, FOV-filtered
  coin.gd                  Coin lifecycle (despawn-after-rest)
  metal_anchor.gd          Metadata component on static metal props
  hud.gd                   Debug HUD readout
materials/
  mistline.tres            Additive depth-test-disabled blue line material
```

---

## Architecture

There's only one scene tree shape that matters at runtime:

```
Main (Node3D, world.gd)
├── WorldEnvironment            (built procedurally)
├── DirectionalLight3D
├── Ground / Building / Girder / Rail / Crate / Can / Coin instances  ("metal" group members)
└── Player (CharacterBody3D, player.gd)
    ├── CollisionShape3D
    ├── Camera3D
    │   ├── AimRay (RayCast3D, 50 m forward)
    │   └── MistVision (MeshInstance3D, mist_vision.gd)
    ├── Allomancy (Node, allomancy.gd)
    └── HUD (Control instance of HUD.tscn, hud.gd)
```

`world.gd` builds the level procedurally rather than hand-authored `.tscn` so we don't have to wrangle scene-file syntax for 30+ nodes. Treat it as the level definition — edit there to change the playground.

---

## Core Systems

### Push/pull math — `scripts/allomancy.gd:40` (`apply_push_pull`)

Pure Newton's 3rd. Per physics tick:

```
dir   = (target_pos - player_pos).normalized()
F     = BASE_FORCE * burn_intensity      # 2000 N at 1x burn
sign  = ±1                                # push: away; pull: toward
player.velocity += dir * (sign * F / PLAYER_MASS) * delta
if not anchored and target is RigidBody3D:
    target.apply_central_impulse(dir * -sign * F * delta)
    # Then clamp target.linear_velocity to LOOSE_TARGET_SPEED_CAP (80 m/s)
```

Why the speed cap exists: tiny-mass targets (coins) under high-burn flares would otherwise jump to hundreds of m/s in a single frame, which feels like a railgun. The cap is a safety net; at 1× burn on a 0.5 kg coin it doesn't trigger.

Player horizontal speed is capped at 25 m/s (`HORIZONTAL_SPEED_CAP`). Vertical is **uncapped on purpose** — a hard upward push should fling.

### Targeting — `scripts/allomancy.gd:104` (`_pick_target`)

Three-tier resolution per frame:

1. Aim ray hits something in `"metal"` group → that's the target.
2. Else, if a recently spawned coin (< 1 s old) is roughly under the crosshair → that. Auto-aim assist for the drop-and-push rhythm.
3. Else, nearest anchor inside a tight forward cone (cos > 0.94, ~20°).

`nearby_anchors` is rebuilt each `_process` from `get_tree().get_nodes_in_group("metal")`, filtered by distance ≤ 30 m and presence in the camera frustum + 10° pad, sorted nearest-first, capped at 32.

### Mist-vision — `scripts/mist_vision.gd:41` (`_process`)

Single `MeshInstance3D` with an `ImmediateMesh` rebuilt each frame. Lines run from camera origin to each `nearby_anchor`. Material has `no_depth_test = true` and additive blend so lines render *through* walls. Per-line alpha = `dist_alpha × brightness(mass)` — heavier anchors render brighter, matching the books' "thin like twine ... thick as yarn" description. Tab toggles the overlay; when off, `_process` short-circuits to skip the rebuild.

### Coin spawning — `scripts/player.gd:71` (`_spawn_coin`)

Two hotkeys with different intents:
- **Q (drop)** — spawns 0.4 m below the camera with v ≈ (0, −0.5, 0). Falls naturally. For vertical launches: drop → look down → push.
- **F (toss)** — spawns 0.6 m forward with v = forward × 3 + player_velocity × 0.5. For horizontal dashes / forward shots.

Coins despawn 10 s after coming to rest. Live cap is 32; oldest is freed when exceeded.

---

## Tuning Constants — Where to Look First

When the *feel* is wrong, edit these (all in `scripts/allomancy.gd` unless noted):

| Constant | Current | What it does |
|---|---|---|
| `BASE_FORCE` | 2000 N | Push/pull strength at 1× burn. Bigger = punchier. |
| `BURN_MIN` / `BURN_MAX` / `BURN_STEP` | 0.25 / 3.0 / 0.15 | Mouse-wheel modulation range. |
| `LOOSE_TARGET_SPEED_CAP` | 80 m/s | Safety clamp on coins / cans. Below this, pure Newton. |
| `HORIZONTAL_SPEED_CAP` | 25 m/s | Player horizontal cap. Vertical uncapped. |
| `PLAYER_MASS` | 80 kg | Authoritative — also baked into player physics feel. |
| `SEARCH_RADIUS` | 30 m | Mist-vision range. |
| `MAX_ANCHORS` | 32 | Cap on tracked anchors per frame. |
| `MOVE_SPEED` / `JUMP_VELOCITY` (player.gd) | 6 / 5 | Baseline locomotion feel. |
| `gravity` (project.godot) | 18 m/s² | Slightly heavier than Earth — feels better for vertical play. |
| `COIN_MASS` (coin.gd) | 0.5 kg | Heavier than a real "clip" so 1× burn doesn't trigger the speed cap. |

---

## Branch & Git Policy

- All work happens on `claude/mistborn-metal-game-x6bp6`. Don't push to other branches without explicit permission.
- Commit messages use a short subject + body explaining *why*, signed-off with the Claude Code session URL line.
- Don't `--amend` or force-push without a clear reason.
- No PRs unless the user asks.

---

## Known Caveats

These weren't verifiable in the original sandbox, so flag them if you hit them:

- **`.tscn` files were hand-written**, never opened in the Godot editor. If `Player.tscn` or `HUD.tscn` fail to parse on first import, suspect missing `ext_resource` IDs or wrong node-path `parent=` strings. Most likely failure point in the project.
- **Tuning is best-guess.** Force, gravity, speed caps, burn range — none of it has been felt in-game. Expect to iterate once you can actually play.
- **`_is_world_anchored` / `_node_position` are static helpers with leading underscores** but called from `hud.gd`. The underscore is convention-only in GDScript; not a bug, but if you rename them, update the HUD too.
- **`current_target` is computed in `_process` but consumed in `_physics_process`.** At 60 Hz this is a non-issue; at decoupled rates it's up to one tick stale.
- **Coin auto-target assist** (`_pick_target` step 2) relies on a coin being added to `nearby_anchors`. The FOV filter in `_refresh_nearby_anchors` could exclude a just-dropped coin if the player is staring straight up — minor edge case.

---

## What's Built vs. What's Deferred

**Done:**
- FPS controller, mouse look, jump, gravity
- Mist-vision blue lines, FOV-filtered, through walls, mass-coded brightness
- Push/pull with Newton's-3rd math + loose-target speed cap
- Burn intensity (mouse wheel)
- Drop coin (Q) / toss coin (F) with two distinct intents
- Procedural playground: 6 buildings with rooftop and wall girders, 3 rails, heavy crates, light cans, tutorial signpost
- Debug HUD: target name + mass + distance + anchored, force, velocity h/v split, coin count, mist-vision state
- Tab toggles mist-vision

**Deferred (in rough priority order):**
1. Audio — push/pull whoosh, coin drop/clink, footsteps. Critical for game feel.
2. Camera shake / FOV punch on big pushes. Sells the impact.
3. Coin-as-projectile damage + simple target dummies (combat tier 1).
4. Back-anchor hotkey or two-mouse-button targeting (push off anchors behind).
5. Multi-anchor / tripod pushing for stable flight.
6. Aluminum class on `MetalAnchor` (un-pushable).
7. Better playground geometry — handcrafted rooftops, alleys, gantries instead of cubes.

---

## Running

1. Install Godot 4.6 (or 4.4+).
2. Open `project.godot` from this directory.
3. F5 to play. Mouse is captured immediately. Esc to quit.

If `.tscn` parse errors appear on import, check the suspect file referenced in the error against the layout in this document.

---

## Pointers For Claude Code

- **Read `scripts/allomancy.gd` first** — it's where the physics-tuning conversations happen.
- The original step-by-step plan lived at `/root/.claude/plans/let-s-put-together-a-spicy-leaf.md` (sandbox-only). The relevant content is folded into this file.
- If asked to add a new metal type, the cleanest extension point is a property on `MetalAnchor` (e.g. `is_aluminum`) checked inside `apply_push_pull`. Resist scope creep into the full Mistborn metal table; the prototype is steel + iron only.
- If asked to add combat, prefer extending the existing coin system (coin-on-target collision damage) before introducing new projectile types.
