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

You are a wizard gardener tending a magical garden. Your garden grows automatically — but its growth is powered by your heartbeat. The game's tick speed scales with your heart rate: rest and the garden ticks slowly, exercise and it pulses with life energy.

The core loop is modeled after CIFI (Cell Idle Factory Incremental), with a cascading generator chain where higher-tier plants produce lower-tier plants, creating exponential growth. The twist: everything in the game runs on "heartbeats" (ticks), and your real heart rate controls how fast those ticks fire.

**At rest (~65 BPM):** 1.0x speed, ~8 second ticks  
**Light exercise (~100 BPM):** ~1.7x speed, ~4.7 second ticks  
**Vigorous exercise (~150 BPM):** ~2.5x speed, ~3.2 second ticks  
**At HR cap (~85% max):** 3.0x speed, ~2.7 second ticks

The game rewards healthy exercise intensity but caps benefits at a safe threshold based on the player's age, so it never incentivizes dangerous overexertion.

## Systems

### Cascading Generators
Five tiers of magical plants, each producing the tier below it every tick:

- **Mystic Shrubs** → produce Creeping Vines
- **Creeping Vines** → produce Blooming Flowers
- **Blooming Flowers** → produce Whispering Herbs
- **Whispering Herbs** → produce Enchanted Sprouts
- **Enchanted Sprouts** → produce **Life Mana** (primary currency)

Manually purchased generators drive cost scaling. Cascade-produced generators are free and don't inflate prices.

### Heart Rate Integration
Three modes for heart rate input:

- **Demo:** Built-in simulated workout cycle (rest → warmup → lifting sets → cooldown) with an animated ASCII wizard. No external setup needed — works in browser.
- **Manual:** Set BPM with scroll wheel for testing specific values.
- **Device:** WebSocket connection for real heart rate monitors (Pixel Watch via Health Connect, or any BLE HR device via bridge).

Heart rate drives the universal tick speed. BPM is displayed with fitness-tracker-style zone indicators (Resting → Light → Moderate → Vigorous → Peak) color-coded from blue through green/yellow/orange to red.

### Garden Plots
Plots are plantable garden areas where you grow seeds over time for multiplier bonuses. Each plot has:

- **Plant slots** — spend mana to plant seeds that grow through 5 stages (Seed → Sprout → Growing → Mature → Blooming) over ~50 ticks
- **Tend points** — allocate points to boost specific generators or mana production, scaled by average plant maturity
- **Full Bloom** — when all slots reach Blooming, the plot grants a permanent multiplier (survives future resets) and plants reset for another cycle

### Upgrades
Per-generator production multipliers, universal multipliers, and tick speed upgrades. Unlock as you hit lifetime mana thresholds.

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
7. **PlotManager** — garden plot growth, tend bonuses, Full Bloom
8. **SaveManager** — JSON persistence, offline progress, version migration

### Key Design Decisions
- **Tick-first architecture:** everything subscribes to `EventBus.tick_fired`. HR affects tick interval, making it the universal accelerator.
- **EventBus decoupling:** managers communicate via signals, never reference each other directly.
- **Data-driven content:** generators, upgrades, and plots are Godot Resource (.tres) files. Add content by creating new .tres files.
- **Owned vs produced generators:** manually purchased generators drive cost scaling. Cascade-produced generators are free — this prevents runaway costs.
- **Multiplier reconciliation:** UpgradeManager is the single recalculation point, querying both upgrade levels and plot tend bonuses.
- **All math centralized:** GameFormulas contains every formula as a static pure function.

## Future Plans
- **Seasonal Rebirth** (prestige system) — reset generators for permanent Season Tokens
- **Additional garden plots** — each unlocking new game systems
- **Android Health Connect plugin** — real Pixel Watch heart rate integration
- **Audio** — heartbeat sounds synced to BPM, purchase/bloom sound effects
- **Web export** — browser-playable demo

## Tech Stack
- Godot 4.6 (Mobile renderer)
- GDScript
- Python 3 (optional, for WebSocket HR simulator)
