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

> **This describes the published 1.2.0.** 1.3.0 (in development, in `unified-mod/`) merges
> both halves into ONE install that enables whichever half the machine needs, so every
> role installs the same thing. It refuses to start while the old `PalPriorityUI` mod is
> still present rather than let two engines fight over the same pals.

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
- **No save-file writes**: priorities live in a Lua file the mod owns (in its mod folder,
  mirrored to `%LOCALAPPDATA%\Pal\Saved\` so a mod-manager reinstall cannot wipe them);
  all game-state changes go through the game's own replicated toggle RPC. The game's save
  files are never touched.

## Install

> These steps are for the **published 1.2.0**, which is a pair of mods. For 1.3.0
> (`unified-mod/`) install the single `PalPriority` package on every machine and
> **remove any existing `PalPriorityUI` folder** — 1.3.0 refuses to start while the
> old interface mod is present, rather than let two engines fight over the same pals.

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
- **Config mirror (1.3.0).** Every save is also written to
  `%LOCALAPPDATA%\Pal\Saved\PalPriority-priorities.lua`, outside the mod folder, and
  restored from there if the mod-folder copy comes back empty — which is what happens
  when a mod manager reinstalls the package over your settings. If you ever want a
  genuinely clean slate, delete both files.

### Dev diagnostics (disabled in release — no F-keys ship active)
There is a `DEBUG` flag at the top of `main.lua` (ships `false`; 1.2.0 had one in
each of its two mods). Flip it to `true` to enable **F8** (reload `priorities.lua`
+ reset internal state), **F9** (full roster dump: priorities, supervisor plan,
off-list vs shadow, pending work) and **F10** (interface pipeline diagnostic).
`VERBOSE`, alongside it in the same `main.lua`, turns on routine per-operation
logging (cycles, deltas, config saves) for both halves — off in release so the
server log stays quiet; `DEBUG = true` implies it. In release, hand-edits to
`priorities.lua` are picked up at game/server start.

## Compatibility & maintenance

- Targets Palworld 1.0 + the matching Okaetsu UE4SS build. **Game patches can silently
  break function hooks** — after an update, verify with F9 and watch the UE4SS console
  for `HOOK FAILED` lines; expect to wait for a fresh UE4SS build after big patches.
- Dedicated servers: the engine mod runs fine under the Windows server build (Linux
  hosts need the Windows build under Wine/Proton, standard for UE4SS).

## Repo layout (developers)

- `unified-mod/PalPriority/` — **source of truth for 1.3.0**: the single-install mod, both
  halves in one. Make changes here.
- `workshop/PalPriority/` — Steam Workshop packaging copy: the same six scripts plus
  `Info.json`. Kept byte-identical to `unified-mod`, so re-sync it after any edit.
- `server-mod/`, `client-mod/`, `release/` — the superseded 1.2.0 two-mod line, kept
  because it is what is published on Nexus today. Not where changes go; 1.3.0 replaces
  all three with `unified-mod/` + `workshop/`.
- `docs/callpath-map.md` — every verified game API, the crash rules (READ THIS before
  touching the Lua), which findings are proven vs merely inferred, and the discovery
  history.
- `tests/planner_test.lua` — `planner.lua` is a pure function over plain tables, so it
  runs in a bare interpreter: `cd palworld-priority-mod && lua tests/planner_test.lua`.
  Covers eligibility, allocation, tie-breaks, preemption and the level-major ordering
  property. Behaviour the redesign still owes is listed there as PENDING.
- `probe/` — in-game reflection probes (dev only, never shipped). Install one alongside
  PalPriority; each writes a dump file next to itself.
  - `TransportLoadProbe/` — run this one. Measures what a high-output station does to the
    pending-work tracker (hook A pulses/sec with a peak, distinct unfilled jobs per camp
    per work type), and — **F5** — verifies the step-3 architecture the 1.3 redesign is
    gated on: the Lua TArray index base, the `WaitingWorkerIndividualIds` idle list, the
    per-slot occupancy chain that replaces `GetWorkAssignInfo`, and whether Lua can key or
    iterate `UPalWorkProgressManager`'s TMaps. **F8** dumps every distinct job signature with
    `RequiredWorkAmount`, which is how unmapped stations and never-completing work get
    found. F6 = per-pal ranks + idle signals, F7 = `UnregisterHook` test, F9 = fixed-assign
    reachability (reports only, never sends — the probe writes no game state at all).
    Run it on the machine that owns the pals (single-player / host / server) — the hook is
    server-internal, so a remote client correctly reports zero.
  - `WorkTypeProbe/` — play a couple of minutes with a furnace/bench/ranch/plot running
    and it writes `worktype-dump.txt`. That dump closed the station-work gap.
- `attic/` — archived experimental builds (e.g. the removed force-job feature).
- `nexus/` — Nexus page copy (`description.bbcode`, `summary.txt`), the changelogs, and
  the published zips. `UPLOAD-NOTES.txt` is the upload checklist.
