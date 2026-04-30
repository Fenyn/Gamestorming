# Life Magic

```
                .o.             .o.
              .o888o.         .o888o.
            .o8888888o.     .o8888888o.
           o88888888888o. .o88888888888o
          o8888888888888888888888888888888o
          o8888888888888888888888888888888o
           o88888888888888888888888888888o
            o888888888888888888888888888o
             o8888888888888888888888888o
              o88888888888888888888888o
               o888888888888888888888o
                o8888888888888888888o
                 o88888888888888888o
                  o888888888888888o
                   o8888888888888o
                    o88888888888o
                     o888888888o
                      o8888888o
                       o88888o
                        o888o
                    .o.  o8o  .o.
                  .o888o. o .o888o.
                 o8888888o o8888888o
                  `o888o'|||`o888o'
                    `o'  |||  `o'
                         |||
                         |||
                         |||
                        /|||\
                       / ||| \
          .--.        /  |||  \        .--.
         ( :: )      /  /|||\  \      ( :: )
          `--'      /  / ||| \  \      `--'
           |       /  /  |||  \  \       |
           |      /  /   |||   \  \      |
    ^^^^^^^^^^^^^^/  /   |||    \  \^^^^^^^^^^^^^^^
    ~~~~~~~~~~~~~~'  /  /|||\  \  '~~~~~~~~~~~~~~~
    ~~~~~~~~~~~~~~~~/  / ||| \  \~~~~~~~~~~~~~~~~~
    ~~~~~~~~~~~~~~~'~~'~/|||\~'~~'~~~~~~~~~~~~~~~~
    ~~~~~~~~~~~~~~~~~~~/|||||\~~~~~~~~~~~~~~~~~~~~

            An idle game powered by your heartbeat
```

An idle/incremental game that incentivizes exercise by tying game speed to your real heart rate. Built in Godot 4.6.

## Concept

You are a wizard who specializes in life magic, working from the heart of your tower. Every spell you cast is fueled by your own heartbeat — the steadier the pulse, the more reliable the magic, and the harder you push your body, the more life energy surges through the weave. The game's tick speed scales with your heart rate: rest and the magic flows gently, exercise and it pulses with raw life force.

The core fantasy is **regeneration and growth**, drawn from two life-force sources:

- **Personal life force** — your heartbeat, channeled through Heartmotes, Pulse Glyphs, and Lifebound Familiars near the tower
- **Planetary life force** — the planet's slow pulse, tapped through ley-line Wardens and Heartfont Spires anchored to Gaia's heartbeat

Each tier feeds the one below, regrowing constantly, until raw Life Mana floods back to the wizard. Every tick is a heartbeat.

**At rest (~65 BPM):** 1.0x speed, ~8 second ticks  
**Light exercise (~100 BPM):** ~1.7x speed, ~4.7 second ticks  
**Vigorous exercise (~150 BPM):** ~2.5x speed, ~3.2 second ticks  
**At HR cap (~85% max):** 3.0x speed, ~2.7 second ticks

The game rewards healthy exercise intensity but caps benefits at a safe threshold based on the player's age, so it never incentivizes dangerous overexertion.

## Systems

### Cascading Generators
Five tiers of life-magic constructs, each calling forth the tier below it every heartbeat:

- **Heartfont Spires** → call **Verdant Wardens**
- **Verdant Wardens** → summon **Lifebound Familiars**
- **Lifebound Familiars** → inscribe **Pulse Glyphs**
- **Pulse Glyphs** → release **Heartmotes**
- **Heartmotes** → condense into **Life Mana** (primary currency)

Costs and base production are tuned for a CIFI-style curve: per-purchase cost multipliers are gentle (1.07 → 1.15 across tiers) but the gap between tiers is large, so unlocking each new construct is a meaningful milestone rather than a quick step. Higher-tier constructs produce fewer of the next tier per heartbeat (1.0 → 0.05 base production), which dampens the runaway compounding of a 5-tier cascade.

Manually purchased generators drive cost scaling. Cascade-produced generators are free and don't inflate prices.

### Heart Rate Integration
Three modes for heart rate input:

- **Demo:** Built-in simulated workout cycle (rest → warmup → lifting sets → cooldown) with an animated ASCII wizard. No external setup needed — works in browser.
- **Manual:** Set BPM with scroll wheel for testing specific values.
- **Device:** WebSocket connection for real heart rate monitors (Pixel Watch via Health Connect, or any BLE HR device via bridge).

Heart rate drives the universal tick speed. BPM is displayed with fitness-tracker-style zone indicators (Resting → Light → Moderate → Vigorous → Peak) color-coded from blue through green/yellow/orange to red.

### The Sanctum
The Sanctum is where the wizard inscribes life-bound sigils that strengthen the weave over time. Each sanctum has:

- **Sigil slots** — spend mana to inscribe a sigil that charges through 5 stages (Seed → Sprout → Growing → Mature → Blooming) over ~60 heartbeats
- **Attunement points** — allocate points to boost specific generators or mana production, scaled by average sigil charge
- **Full Bloom** — when all slots reach full charge, the sanctum grants a permanent multiplier (survives future resets) and the sigils reset for another cycle

### Upgrades — Tower Enhancements
The wizard's tower is the focus of every upgrade. Each enhancement taps a different source of life energy and channels it back into your weave to drive regeneration and growth:

- **Cardiac Conduit / Sigilwright's Forge / Beastsong Crystal** — channel the wizard's *personal* life force into Heartmotes, Pulse Glyphs, and Familiars
- **Ley-Line Tap / Gaian Heartstone** — tap the *planet's* life energy through ley lines and a heartstone in the tower's core, empowering Wardens and Spires
- **Verdant Renewal** — a tower-wide wellspring of regenerative life force that strengthens every construct
- **Quickened Pulse** — tower resonance accelerates the heartbeat itself, speeding every tick

Per-generator multipliers, a universal multiplier, and a tick-speed enhancement. Unlock as you hit lifetime mana thresholds.

### Player Profile
Enter your age to calibrate heart rate zones and caps. Resting HR is estimated from age automatically. HR cap (default 85% of max) is adjustable.

## Running

Open the project in Godot 4.6 and press Play. The game starts in Demo mode with the simulated workout running immediately.

### Debug Keys
- **M** — add 1,000 mana
- **N** — add 1,000,000 mana
- **Scroll wheel** — adjust simulated BPM (Manual mode)

### WebSocket HR Bridge
For testing with external heart rate data:

```
python tools/hr_simulator.py
```

Then switch to "Device" mode in the Profile tab. The simulator sends realistic workout HR data over `ws://localhost:9876`.

## Architecture

### Autoloads (initialization order)
1. **EventBus** — global signal hub, no logic
2. **GameState** — central state store, serialization
3. **HeartRateManager** — HR data provider (simulated/demo/websocket)
4. **TickEngine** — accumulator-based tick system, fires at HR-driven intervals
5. **GeneratorManager** — cascading generator chain
6. **UpgradeManager** — upgrade purchases + multiplier reconciliation
7. **PlotManager** — sanctum sigil growth, attunement bonuses, Full Bloom
8. **SaveManager** — JSON persistence, offline progress, version migration

### Key Design Decisions
- **Tick-first architecture:** everything subscribes to `EventBus.tick_fired`. HR affects tick interval, making it the universal accelerator.
- **EventBus decoupling:** managers communicate via signals, never reference each other directly.
- **Data-driven content:** generators, upgrades, and plots are Godot Resource (.tres) files. Add content by creating new .tres files.
- **Owned vs produced generators:** manually purchased generators drive cost scaling. Cascade-produced generators are free — this prevents runaway costs.
- **Multiplier reconciliation:** UpgradeManager is the single recalculation point, querying both upgrade levels and sanctum attunement bonuses.
- **All math centralized:** GameFormulas contains every formula as a static pure function.

## Future Plans
- **Seasonal Rebirth** (prestige system) — reset generators for permanent Season Tokens
- **Additional sanctums** — each unlocking new game systems
- **Android Health Connect plugin** — real Pixel Watch heart rate integration
- **Audio** — heartbeat sounds synced to BPM, purchase/bloom sound effects
  
## Tech Stack
- Godot 4.6 (Mobile renderer)
- GDScript
- Python 3 (optional, for WebSocket HR simulator)
