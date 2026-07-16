# Bulwark — Building Visual Stages & Overlays

How a building's look is stored, chosen, and swapped: tier upgrades, construction scaffolding,
seasonal reskins, event dressing, and permanent story modifications. Extends the shipped
BuildingInstance/BuildingLoader pattern — one premade scene per building, visibility-driven
swaps, everything derived at runtime (zero save impact).

## Decisions (locked with user, 2026-07-15)
- One `.tscn` per building stays the unit of authoring. All visual variants live inside it.
- Tier upgrades swap STAGES (exactly one visible). Events/seasons add OVERLAYS (zero or more
  visible on top of the stage).
- Drivers: seasons (auto-reverting), calendar event windows (auto-reverting), story flags
  (permanent by default — flags are one-way latches; a later flag can supersede an earlier
  rule). Story triggers can also permanently override the STAGE itself, not just dress it.

## Scene authoring contract (extends the shipped contract)

```
scenes/buildings/<id>.tscn          (root: BuildingInstance)
├── %Stages                          exactly ONE child visible at a time
│   ├── Stage0 (ruined site)         child order = stage index
│   ├── Stage1 (tier-1 look)
│   ├── Stage2 ...
│   └── Burned (story stages go here too — addressed by index like any other)
├── %Scaffold                        (optional) shown INSTEAD of the stage while under
│                                    construction; hidden otherwise
├── %Overlays                        (optional) zero or more children visible, by Name
│   ├── Winter                       season key (auto: Spring/Summer/Autumn/Winter)
│   ├── Festival_Harvest             event-window key (calendar-driven)
│   └── Memorial_Plaque              story key (flag-driven, permanent)
├── %Footprint                       StaticBody2D collision (shared across stages)
└── %Interact                        Marker2D (future diegetic interaction point)
```

- Every stage/overlay child is a plain Node2D group (sprites, lights, particles, animated
  Winlu props) authored at the same origin. Toggle visibility in-editor to preview any combo.
- A stage that changes the building's OUTLINE carries its own StaticBody2D inside the stage
  node; the swap disables collision shapes under hidden stages (hidden CanvasItems still
  collide in Godot — the code must toggle shapes, not just visibility). Unique collision
  shapes per node, never shared sub_resources.
- Missing containers are fine (null-safe): a building with no %Overlays simply never dresses.

## Selection model (runtime, all derived)

Priority for the STAGE, top wins:
1. **Story stage override** — ordered rules on the building definition; LAST matching rule
   wins (so `burned` can be superseded by `rebuilt` later): flag set → stage index.
2. **Under construction** — `%Scaffold` shown instead of any stage (commission + upgrade
   construction windows both count).
3. **Tier mapping** — the shipped `BuildingTier.StageIndex` (unchanged).

OVERLAYS are additive and independent of the stage decision. An overlay key is active when
its rule matches:
- `Season(season)` — active while the clock's season matches. Key convention: the season name.
- `Window(season, fromDay, toDay)` — active during the calendar window (festivals).
- `Flag(flagId)` — active once the story flag is set. Permanent by default (flags latch).
  A rule may also carry `unlessFlag` so a later flag retires an earlier overlay.

## Data model

Rules are data on the building definition (Buildings.cs), same declarative style as tiers:

```csharp
public sealed class BuildingVisualRule
{
    public string? OverlayKey;      // set for overlay rules
    public int? StageOverride;      // set for stage-override rules (mutually exclusive)
    public Season? Season;          // season / window driver
    public int? FromDay, ToDay;     // window driver (with Season)
    public string? FlagId;          // story driver
    public string? UnlessFlagId;    // retire clause (overlay active only while unset)
}

// BuildingDefinition gains:
public IReadOnlyList<BuildingVisualRule> VisualRules { get; init; } = [];
```

Season overlays need NO rules — the loader always feeds the current season name as an active
key; buildings that have a `Winter` overlay child use it, others ignore it. Rules exist for
event windows, story overlays, and stage overrides only.

## Runtime wiring

- `BuildingInstance` gains `Apply(int stageIndex, bool underConstruction, IReadOnlyCollection<string> overlayKeys)`
  — resolves scaffold-vs-stage, toggles per-stage collision, shows matching overlay children.
- `BuildingLoader` gains delegates for `isUnderConstruction(id)`, the clock (season + day),
  and `HasStoryFlag`; computes the active key set + stage decision per building in `Refresh`.
- Refresh triggers (all existing events): `BuildingChanged`, `ConstructionCompleted`,
  `DayStarted` (season/window boundaries), `StoryFlagChanged`.
- Nothing is persisted. Save/load replays flags + clock + tiers → identical visuals.

## Authoring workflows

- **New tier look**: paint a new child under %Stages, point the tier's `StageIndex` at it.
- **Seasonal reskin**: add a `Winter` child under %Overlays. Done — no data edit.
- **Festival dressing**: add `Festival_Harvest` child + one Window rule on the definition.
- **Permanent story change (dressing)**: add overlay child + one Flag rule; set the flag in
  the story beat (dialogue `flag` step, quest completion, etc.).
- **Permanent story change (structural)**: paint the new look as a %Stages child + one
  stage-override Flag rule. Supersede later with another rule below it (last match wins).

## Deferred
- Interior scene variants (same pattern when interiors exist)
- Night/lighting overlays driven by time-of-day (needs a cheaper refresh trigger than
  DayStarted — hour-level; defer until wanted)
- Overlay/stage transition effects (fade/particles on swap)
