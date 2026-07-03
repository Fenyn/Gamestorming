# Combat Proto — Project Guidance for Claude Code

3D melee combat prototype fusing For Honor's directional stance system with Sekiro's posture/deflection mechanics. Pure mechanics testing — no theme, no art, greybox only.

---

## Tech Stack

- **Godot 4.6**, GDScript only, Forward Plus renderer, Jolt physics
- **godot_base addon** symlinked at `addons/godot_base/` — provides BaseStateMachine, BaseState, SfxPool, InputContext, InputConfig, ScreenFade, SceneChanger, TickEmitter

---

## GDScript Rules

- Always explicit type annotations — never `:=` with untyped sources
- Autoload scripts must NOT use `class_name`
- All other scripts use `class_name`
- Objects placed in `.tscn` files — dynamic children use `packed_scene.instantiate()`
- `@onready var x: Type = %UniqueName` for internal node references
- Private members prefixed with `_`

---

## Combat Design

### Three Resources
- **HP**: depletes from clean hits. Lower HP = slower posture recovery. 0 = death.
- **Posture**: fills up from blocks/hits. Full = posture break → deathblow (~65% max HP damage).
- **Stamina**: drains from ALL actions. Empty = EXHAUSTED (slower, can't dodge/jump, shove knockdown).

### Stance — Inverted Triangle
Three directions: **Top**, **Bottom-Left**, **Bottom-Right**. Current stance = attack direction AND guard direction.

### Offense
- **Light** (500ms): fast, low damage, directional, interruptible
- **Heavy** (867ms): slow, high damage, directional, feintable, interruptible
- **Charge**: hold heavy to charge. Full charge = UNBLOCKABLE + HYPER ARMOR
- **Shove** (500ms): vs block = massive posture damage, vs neutral = stagger
- **Lunge** (perilous, orange): can't block, CAN deflect, counter with Mikiri (forward-dodge)
- **Sweep** (perilous, yellow): can't block/deflect, counter with jump
- **Grab** (perilous, red): can't block/deflect, counter with side-dodge

### Defense
- **Block** (hold guard + direction): 0 HP, posture damage, stamina cost
- **Deflect** (tap guard + direction + 200ms window): posture to ATTACKER, both neutral
- **Dodge** (i-frames): avoids all, no posture reward
- **Jump**: airborne, sweep counter
- **Counter-shove**: nullifies shove

### Key Architecture
- **FighterInput abstraction**: Fighter reads from FighterInput, not Input directly. HumanInput for players, AIInput for AI. Same fighter code, different input source.
- **CombatResolver**: standalone hit resolution using AttackData flags (is_blockable, is_deflectable, is_perilous). New attack/defense types = flag changes, not code rewrites.
- **FighterProfile**: Resource wrapping stats + attacks. Different characters = different profiles, same fighter scene.
- **State machine**: godot_base BaseStateMachine with combat states as child nodes.

---

## Project Layout

```
scenes/fighter/           Fighter CharacterBody3D + combat states
scenes/fighter/states/    One .gd per combat state
scenes/enemy/             AI controller + training dummy
scenes/arena/             Training room
scenes/camera/            Over-the-shoulder lock-on camera
scenes/ui/                HUD, stance widget
scripts/autoload/         EventBus, GameState, InputManager
scripts/data/             Resource classes, input abstraction, combat resolver
resources/attacks/        AttackData .tres instances
resources/fighters/       FighterProfile .tres instances
```

---

## Tuning Constants

All timing values in seconds. Physics at 60fps = 16.67ms per frame.

| Action | Startup | Active | Recovery | Stamina |
|--------|---------|--------|----------|---------|
| Light | 0.2 | 0.1 | 0.2 | 10 |
| Heavy | 0.4 | 0.133 | 0.333 | 15 |
| Charge (full) | 1.0 charge | 0.133 | 0.4 | 25 |
| Shove | 0.3 | 0.067 | 0.133 | 15 |
| Lunge | 0.6 | 0.067 | 0.133 | 20 |
| Sweep | 0.6 | 0.1 | 0.1 | 20 |
| Grab | 0.5 | 0.1 | 0.1 | 15 |
| Dodge | 0.05 pre-iframe | 0.2 i-frames | 0.35 | 15 |
| Jump | 0.1 pre-iframe | 0.2 airborne | 0.3 | 10 |
| Deflect window | — | 0.2 | — | 0 |
| Hitstun | — | 0.25 | — | — |
