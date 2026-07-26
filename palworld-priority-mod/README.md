# PalPriority — RimWorld-style Work Priorities for Palworld

Give every base pal a per-work-type priority instead of the vanilla on/off checkboxes,
on the RimWorld scale: 1 (highest) to 5 (lowest), X = never, color-coded green→red.
Pals work the most important thing that actually has work pending and fall down their
list as work dries up — like RimWorld's work tab.

Built for **Palworld 1.0** (Steam) on **UE4SS** (Okaetsu Palworld fork). Two Lua mods:

Both mods are required — the pair is the mod.

| Mod | Runs on | Does |
|---|---|---|
| `PalPriority` | server / host / single-player | The priority engine (assignment shaping, config, persistence) |
| `PalPriorityUI` | every player using the mod | Numbers on the vanilla work screen + click-to-cycle controls |

## Features

- **Per-pal, per-work-type priorities**: RimWorld scale — 1 highest, 5 lowest, X never;
  values color-coded green (1) through yellow to red (5). Unconfigured pals show their
  default values (3/X from current toggles) in dim neutral gray the moment the screen
  opens — display-only until first click activates the pal.
- **Integrated UI**: the vanilla Monitoring Stand work screen shows a number (or X)
  in place of each checkbox. Left-click cycles X→1→…→5→X, right-click cycles the other way.
- **Smart supervisor**: pals compete for the jobs that actually exist *at their own
  base*. Each camp's pending work is allocated down the priority levels — a pal that
  gets a job is fenced to its level, a pal that misses out stays free to do something
  else rather than idling next to work it is barred from. Pals already on a task keep
  it; more important work still preempts.
- **Works on dedicated servers**: the server holds the priorities and syncs them to
  each modded player over the game's own replicated RPC channel (`Notify_RequestClient_int32`),
  so the UI mod never needs access to the server's files. Unmodded players are never
  sent any mod traffic.
- **Safe with unmodded players**: their checkboxes behave 100% vanilla. If a modded
  player uninstalls the client mod, the first checkbox they touch on a configured pal
  returns that pal to plain vanilla on/off (with its work state restored sanely).
- **No save-file writes**: priorities live in a mod-folder Lua file on the server; all
  game-state changes go through the game's own replicated toggle RPC.

## Install

1. Install **UE4SS (Okaetsu Palworld fork)** into `Palworld\Pal\Binaries\Win64`
   (the `experimental-palworld` release: `dwmapi.dll` + `ue4ss\` next to
   `Palworld-Win64-Shipping.exe`).
2. Extract the release zip's `ue4ss` folder over the same `Win64` folder.
   Each mod ships with an `enabled.txt`, so no `mods.txt` editing is needed.
3. Both parts are required: the server/host runs `PalPriority`, and every player
   using the mod installs `PalPriorityUI`. Single-player: install both.

## Use

- Open the work suitability screen (Monitoring Stand / Palbox → base pals).
- Click any work cell: the pal is auto-configured (current toggles become 3/X) and the
  clicked type cycles. Right-click cycles down. X = never do this work.
- A pal does its most important (lowest-numbered) work type that has pending work; when none of
  that work exists (or another pal takes the last job), it moves down its list within a few
  seconds. Unconfigured pals are untouched.
- Priorities persist server-side in `ue4ss\Mods\PalPriority\priorities.lua`
  (auto-managed; also hand-editable — edits load at game/server start). The Steam
  Workshop UE4SS layout (`Mods\NativeMods\UE4SS\Mods\...`) is detected automatically.

### Dev diagnostics (disabled in release — no F-keys ship active)
Both mods have a `DEBUG` flag at the top of `main.lua` (ships `false`). Flip to
`true` to enable **F8** (reload `priorities.lua` + reset internal state), **F9**
(full roster dump: priorities, supervisor plan, off-list vs shadow, pending work)
and **F10** (client UI pipeline diagnostic). The engine also has a `VERBOSE`
flag for routine per-operation logging (cycles, deltas, config saves) — off in
release so the server log stays quiet; `DEBUG = true` implies it. In release,
hand-edits to `priorities.lua` are picked up at game/server start.

## Compatibility & maintenance

- Targets Palworld 1.0 + the matching Okaetsu UE4SS build. **Game patches can silently
  break function hooks** — after an update, verify with F9 and watch the UE4SS console
  for `HOOK FAILED` lines; expect to wait for a fresh UE4SS build after big patches.
- Dedicated servers: the engine mod runs fine under the Windows server build (Linux
  hosts need the Windows build under Wine/Proton, standard for UE4SS).

## Repo layout (developers)

- `server-mod/`, `client-mod/` — the two mods (source of truth).
- `docs/callpath-map.md` — every verified game API, the crash rules
  (READ THIS before touching the Lua), and the discovery history.
- `probe/` — in-game reflection probes (dev only, never shipped).
  `WorkTypeProbe/` is the current one: install it alongside PalPriority, play for a
  couple of minutes with a furnace/bench/ranch/plot running, and it writes
  `worktype-dump.txt` next to itself. That dump is what closes the station-work gap
  (see callpath-map). `PrioProbe/` is the older widget-discovery probe.
- `attic/` — archived experimental builds (e.g. the removed force-job feature).
- `release/` — the shippable `ue4ss/Mods` tree; zip it to share.
