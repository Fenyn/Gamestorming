# Bulwark — Dialogue & Cutscene System

Stardew Valley-style dialogue and cutscene framework. Portrait box at screen bottom, typewriter
text reveal, player choices with branching, and simple staging commands (fades, actor movement,
camera pan) for heart events and story moments. **Framework only** — no event/dialogue content
shipped; content authoring follows the same pattern as character profiles (data-driven, per file).

## Decisions (locked with user, 2026-07-14)
- **Branching:** player choices supported (2–4 options per choice node). Choices can gate on story
  flags and branch to different continuations. Choices can award friendship, set flags, give items.
- **Cutscene scope:** dialogue + simple staging — fade in/out, actor enter/exit/move-to-marker,
  brief camera pan, wait. Enough for heart events. Extendable later (weather, lighting, spawns).
- **Authoring:** JSON files in `data/dialogues/`, one file per dialogue sequence or talk pool.
  Easy to track in git, easy to add/edit without rebuilding. Loaded at runtime by the dialogue
  database.
- **Presentation:** Stardew Valley style — portrait + speaker name + text box at screen bottom,
  typewriter text reveal, advance on input, choice buttons when branching.

## Integration points (all exist, waiting for this system)
- **Friendship heart events:** `HeartThresholdReached(charId, heart)` fires with `HeartUnlock.EventId`
  — the dialogue system resolves that id to a dialogue sequence and plays it.
- **Daily talk:** `OutpostScene.TryTalkToVillager()` currently shows a `Personality` one-liner toast.
  Replaced by: query the talk pool for the character, pick the highest-priority line whose conditions
  pass, play it in the dialogue box. Falls back to the old toast if no dialogue exists.
- **Story flags:** `StoryFlags.Has()/Set()` gate dialogue conditions and are set by dialogue effects.
- **CharacterProfile:** `Bio`, `Personality`, `Pronouns`, `PortraitId` feed the dialogue presenter.
- **Modal pattern:** dialogue box is another `CozyWorldScene` modal — `SetModalFreeze(true)` pauses
  clock + player, `CloseOtherModals()` closes economy panels, dialogue box is exclusive.

## Data model

### JSON dialogue format

Each `.json` file in `data/dialogues/` defines one dialogue sequence (heart event, story event) or
one talk pool (daily conversation lines). The `type` field discriminates.

**Dialogue sequence** (heart events, story events, quest dialogues):
```json
{
  "id": "tharr_heart_2",
  "type": "sequence",
  "conditions": {
    "hearts": { "tharr": 2 },
    "flags_required": ["command_post_built"],
    "flags_blocked": []
  },
  "once": true,
  "steps": [
    { "type": "line", "speaker": "tharr", "text": "When I was alone here...", "emotion": "sad" },
    { "type": "fade", "direction": "out", "duration": 0.5 },
    { "type": "fade", "direction": "in", "duration": 0.5 },
    { "type": "enter", "actor": "tharr", "marker": "campfire" },
    { "type": "move", "actor": "tharr", "marker": "bench", "speed": 80 },
    { "type": "camera", "marker": "campfire", "duration": 1.0 },
    { "type": "wait", "seconds": 0.5 },
    {
      "type": "choice",
      "speaker": "tharr",
      "text": "Something kept me going. What do you think it was?",
      "emotion": "neutral",
      "options": [
        {
          "text": "Stubbornness?",
          "next_id": "tharr_heart_2_stubborn"
        },
        {
          "text": "Hope.",
          "effects": [{ "type": "friendship", "character": "tharr", "amount": 20 }],
          "steps": [
            { "type": "line", "speaker": "tharr", "text": "...Maybe.", "emotion": "amused" }
          ]
        }
      ]
    },
    { "type": "flag", "set": "tharr_opened_up" },
    { "type": "exit", "actor": "tharr" }
  ]
}
```

**Talk pool** (daily conversation — replaces the Personality toast):
```json
{
  "id": "tharr_talk",
  "type": "talk_pool",
  "character": "tharr",
  "entries": [
    {
      "priority": 0,
      "conditions": {},
      "lines": [
        { "speaker": "tharr", "text": "The walls need mending. Always do.", "emotion": "neutral" }
      ]
    },
    {
      "priority": 10,
      "conditions": { "hearts": { "tharr": 4 }, "season": "summer" },
      "lines": [
        { "speaker": "tharr", "text": "Summer heat's good for the mortar.", "emotion": "amused" },
        { "speaker": "tharr", "text": "Reminds me of the quarries back home.", "emotion": "neutral" }
      ]
    }
  ]
}
```

### Step types

| Type | Fields | Effect |
|---|---|---|
| `line` | speaker, text, emotion? | Show dialogue line in the box |
| `choice` | speaker, text, emotion?, options[] | Show line then present player choices |
| `fade` | direction (in/out), duration? | Screen fade |
| `enter` | actor, marker? | Actor appears (walks in or pops) |
| `exit` | actor | Actor leaves the scene |
| `move` | actor, marker, speed? | Actor walks to a marker position |
| `camera` | marker, duration? | Pan camera to a marker |
| `wait` | seconds | Pause before next step |
| `flag` | set | Set a story flag |
| `friendship` | character, amount | Award friendship points |
| `emote` | actor, emotion | Change an actor's displayed emotion/expression |

### Choice options

Each option in a `choice` step:
- `text` — the button label the player sees
- `conditions?` — optional gate (flags_required, flags_blocked, hearts) — hidden if unmet
- `effects?` — array of effects applied when chosen (friendship, flag, item)
- `steps?` — inline continuation steps (play after this choice, before resuming the parent)
- `next_id?` — jump to another dialogue sequence by id (for longer branches)

### Conditions object

Used on sequences, talk pool entries, and choice options:
- `hearts?` — `{ "charId": minHearts }` — requires character at N+ hearts
- `flags_required?` — string[] — all must be set
- `flags_blocked?` — string[] — none may be set
- `season?` — "spring" / "summer" / "autumn" / "winter"

### Emotions

Enum: `neutral`, `happy`, `sad`, `angry`, `surprised`, `amused`, `tired`. Drives portrait variant
selection (when portrait variants exist) and a simple expression indicator.

## System architecture

### DialogueData.cs (scripts/data/dialogues/)
POCOs for JSON deserialization: `DialogueSequenceData`, `TalkPoolData`, `DialogueStep`,
`DialogueChoice`, `StepEffect`, `DialogueCondition`. No Godot dependencies — plain C#, testable.

### DialogueDatabase.cs (scripts/data/dialogues/)
Loads all `.json` files from `res://data/dialogues/` (recursive). Indexes by id. Queries:
- `TryGetSequence(id)` — look up a specific event/sequence
- `GetTalkLines(charId, conditionContext)` — from the character's talk pool, return the highest-
  priority entry whose conditions pass
- `IsAvailable(id, conditionContext)` — condition check without loading

### DialogueConditionContext
View-model carrying current state for condition evaluation: story flags (Has), friendship hearts
(per character), current season. Built from GameState at query time.

### DialogueRunner.cs (scripts/cozy/)
Plain C# state machine. Constructed with a step list, advances through steps, emits events for
the UI to render. No Godot dependency — testable.
- `Start(steps)` — begin a sequence
- `Advance()` — player pressed advance / chose an option
- `SelectChoice(index)` — player picked a choice
- Events: `LineReady(speaker, text, emotion, hasChoices)`, `ChoicesReady(options[])`,
  `StageCommand(type, params)`, `SequenceEnded`
- Processes effect steps (flag/friendship) internally via a callback interface

### DialogueBox.cs + dialogue_box.tscn (scripts/ui/, scenes/ui/)
The Stardew-style UI: portrait panel (left), speaker name label, text label with typewriter
reveal, advance indicator, choice button container. Wired to DialogueRunner events.
- Typewriter: reveals text character-by-character; input skips to full text, then next advance
  progresses the sequence.
- Choices: when `ChoicesReady` fires, show buttons; button press calls `SelectChoice`.
- Portrait: loads from `res://assets/portraits/{speakerId}_{emotion}.png` with fallback to
  `{speakerId}.png` then a default silhouette.
- Player speaker uses the player's chosen name from CharacterProfile.

### CutsceneDirector.cs (scripts/cozy/)
A Node that executes staging commands from `DialogueRunner.StageCommand`. Manages:
- Fade overlay (ColorRect with AnimationPlayer or tween)
- Actor registry: maps actor ids to scene nodes (villager sprites, the player) or spawns
  temporary cutscene actors at markers
- Camera pan: tweens the camera to a marker position, returns when done
- Move: tweens an actor to a marker, calls back when arrived
- Markers: `%CutsceneMarker_<name>` nodes placed in the scene (Marker2D)

### GameState integration
- `StartDialogue(sequenceId)` — resolve from database, play via runner, freeze world
- `StartTalkDialogue(charId)` — query talk pool, play best match (or fall back to toast)
- `DialogueStarted` / `DialogueEnded` events
- `SeenDialogues` tracking (HashSet<string>) — `once` sequences never replay
- Save: bump to v9, persist `SeenDialogueIds`

### Wiring
- `OutpostScene.TryTalkToVillager()`: replace the `Personality` toast with
  `GameState.StartTalkDialogue(charId)` — if no talk pool exists for the character, fall back to
  the existing toast behavior.
- `GameState.HeartThresholdReached`: when a `HeartUnlock.EventId` is non-null, auto-queue
  `StartDialogue(eventId)` — the cutscene plays immediately after the threshold fires.
- `CozyWorldScene`: add `DialogueBox` to modal tracking (`CloseOtherModals`, `SetModalFreeze`).

## File layout

```
data/dialogues/              # JSON dialogue content (res://data/dialogues/)
  tharr/talk.json            # (example — no content shipped with framework)
  tharr/heart_2.json
  events/outpost_founding.json

scripts/data/dialogues/      # C# data model + database
  DialogueData.cs
  DialogueDatabase.cs

scripts/cozy/                # runtime system
  DialogueRunner.cs
  CutsceneDirector.cs

scripts/ui/                  # presentation
  DialogueBox.cs

scenes/ui/
  dialogue_box.tscn
```

## Spike

`dialogue_spike.tscn` / `DialogueSpike.cs`: synthetic test dialogue with lines, a choice branch,
staging commands (fade, wait), and talk-pool query — all exercised headless. Verifies the
runner state machine, condition gating, seen tracking, choice branching, and effect application.

## Deferred
- Voice acting / audio cues on lines
- Animated portraits (sprite sheet per emotion)
- Complex staging (weather/lighting changes, spawn/despawn NPCs, combat triggers from dialogue)
- Localization (i18n keys instead of inline text)
- Dialogue editor tooling
