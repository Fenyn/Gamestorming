# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Green Bean — Barista Simulator

A first-person, low-poly 3D **barista simulator** with online multiplayer, built in Godot 4.6. Players take orders at the register, print tickets with cup codes, and assemble drinks by hand at the bar. Every task is a tactile mouse-driven mini-game. Read this whole file before making non-trivial changes.

## Development

- **Engine:** Godot 4.6 stable. Open `green-bean/project.godot` in the editor, F5 to run.
- **Language:** GDScript only. No C# / GDExtension.
- **Renderer:** Forward Plus (3D).
- **Current phase:** Phase 1a grey-box prototype. Solo espresso stand, untextured primitives, no multiplayer yet.
- Scene files (`.tscn`) may be hand-written — if Godot fails to parse on import, check `ext_resource` IDs and `parent=` paths.
- This project lives inside a monorepo (`Gamestorming/`) alongside `life-magic/` and `coinshot/`. Each is a standalone Godot project with its own `project.godot`.

---

## Vision

Build a cozy, chaotic coffee shop game in the vein of Overcooked, Plate Up!, and TCG Shop Simulator — but first-person and with authentic barista mechanics drawn from real Starbucks experience. The cup-code system (abbreviations on printed tickets) is the core differentiator. The game should feel hands-on: players physically grind beans, press aeropresses, steam milk, and pour drinks with tactile mouse and keyboard interactions. Everything is diegetic — no abstract menus, just you, the shop, and the coffee.

---

## Tech Stack

- **Godot 4.6 stable**, Forward Plus renderer (3D).
- **GDScript** throughout. No C# / GDExtension.
- **Online multiplayer** via Godot's built-in `MultiplayerAPI`, `MultiplayerSpawner`, and `MultiplayerSynchronizer`.
- **Low-poly 3D** art style. Warm coffee shop palette.
- Each player has a **first-person camera** and a visible character body (other players see you).

---

## Core Game Loop

### 1. Register Station
A customer walks up and states their order (speech bubble). The player walks to the register and uses the in-world POS screen to enter the drink:
- Select size (Short, Tall, Grande, Venti)
- Select drink type
- Select milk type
- Add modifiers

The register uses **center-of-view targeting** — the player moves their head/camera normally and the crosshair acts as the cursor, hitting buttons on the POS screen by looking at them and clicking. No mode switch, no cursor change — just point your face at the button and click. This keeps the interaction fully diegetic and consistent with normal FP controls.

The player can **queue multiple orders** before making any drinks. Ring up several customers in a row, stacking tickets at the printer, then start brewing. This is a deliberate strategic choice — batch ordering is faster at the register but builds pressure at the bar and tests customer patience.

Confirming the order sends it to the **ticket printer**. Incorrect entry = incorrect ticket = wrong drink downstream.

### 2. Ticket Printer & Cup Pickup
The ticket prints with a cup code using Starbucks-style shorthand abbreviations. The player grabs a cup from the **cup stack** (one stack per size — infinite supply in Phase 1, eventually requires restocking from cup sleeves). Picking up a cup near the printer attaches the ticket automatically.

### 3. Bar Station
The player **carries one item at a time**, held in front of their viewport Skyrim-style. They carry the cup to each station, set it down, perform the mini-game, pick it up, and move to the next station. If a step requires a second item (e.g., steaming pitcher for a latte), the player must set down the cup, pick up the pitcher, do the task, set down the pitcher, pick up the cup, then pour.

Mini-games use a **camera lock** — pressing E at a station snaps the camera to a fixed POV for that task. The station checks that all prerequisite items are in place (cup positioned, grounds loaded, etc.) before starting. The same locked camera angle is used every time that task runs, giving the player consistent muscle memory.

### 4. Hand-off
Completed drink goes on the hand-off counter. Customer picks it up.

---

## Diegetic Design Principle

Everything the player interacts with exists in the 3D world. No full-screen overlays, no floating menus, no mode-switched cursors. The register is a screen you aim your view at and click. Tickets are physical objects you pick up. Cups float in front of you Skyrim-style as you carry them. Mini-games lock to a fixed camera angle at the station. This is a core design principle, not a nice-to-have.

---

## Task Juggling & Unattended Failures

A core part of the barista experience is **juggling multiple tasks at once**. A real barista sets shots to pull, walks away to start prepping another drink, and comes back 20 seconds later. The game leans into this — many tasks have a **passive phase** where the player can walk away, but leaving too long causes **micro failures**.

### Unattended Failure States

Tasks left unattended past their safe window degrade or fail:

| Task | Safe Window | Micro Failure | Consequence |
|---|---|---|---|
| **Aeropress shot** | Steeps for ~10s, then ready for ~8s | Shot over-extracts and becomes bitter, eventually "dies" (goes cold/stale) | Quality penalty → eventual total loss if ignored too long |
| **Milk steaming** | Reaches target temp, holds briefly | Milk scalds (burns) — visual cue: steam turns aggressive, milk discolors | Scalded milk must be dumped and restarted |
| **Pour over draw-down** | Finishes draining in ~15s, coffee stays warm briefly | Coffee goes cold/stale if left sitting too long | Quality penalty — still servable but lower score |
| **Grinder (hand)** | N/A — requires active input | No failure — just stops when you stop cranking | No penalty, just wasted time |
| **Hot water pour** | Active — hold to pour | Overflow if player doesn't stop pouring | Spill, wasted cup, restart |

### Design Intent
- The player is **rewarded for multitasking**: start the grinder, walk to the register to take an order, come back to finish grinding.
- But they're **punished for neglect**: set milk to steam and forget about it = scalded milk, wasted time.
- **Audio and visual cues** warn the player before failure: a shot timer beeping, milk hissing louder, a color shift on the liquid. These cues must be audible from across the shop so the player can react without staring at the station.
- The tension between "I should go do something else while this brews" and "but if I forget, it'll fail" is the core of the gameplay loop.
- In multiplayer, one player can call out "shots are almost done!" while the other finishes an order — communication prevents failures.

---

## Controls Philosophy

Every barista action is its own mini-game. Mouse and keyboard inputs are both fair game — whatever feels most tactile for the action.

Actions should feel **tactile and satisfying**, not abstracted. The physicality is the game.

### Player Controls
- **WASD** — movement (disabled during camera-locked mini-games)
- **Mouse look** — camera control; also acts as cursor for in-world screens (center of view = pointer)
- **Left click** — primary interaction (click POS buttons, pick up items, activate mini-game inputs)
- **E** — interact with stations (locks camera to station POV and starts mini-game if prerequisites met)
- **Esc / E again** — exit camera-locked mini-game, return to free movement
- **Space** — jump (if needed for movement)
- **Additional keys** may be used within mini-games (e.g., holding a key while pressing)

### Carried Items
- Player holds **one item at a time**, floating in front of the viewport (Skyrim-style)
- **Left click** on a surface/station = set item down at that location
- **Left click** on a placed item = pick it up
- Items: cups (4 sizes), steaming pitcher, milk carton
- Cup stacks (one per size) provide infinite cups in Phase 1; restocking from cup sleeves is a later feature

---

## Mini-Game Specifications

Each station interaction is a self-contained mini-game. Quality scores from each step compound into the final drink quality, which determines points earned.

### Grinder Mini-Game
The player must **set the grind level** before grinding. Different drinks require different grind settings:
- **Coarse** — pour over
- **Fine** — aeropress espresso

Wrong grind level = quality penalty on the final drink.

**Phase 1 — Hand Grinder:** Player physically cranks the grinder using mouse circular motions (or a keyboard input). The grind takes real time. A fill indicator shows when enough grounds are ready. **Requires active input** — no passive phase, no failure state. Grinding just pauses when the player stops.

**Upgrade — Electric Grinder:** Player sets the grind level and presses a button. Grinding happens automatically but still takes time. **Passive phase** — player is free to walk away. No failure state (grinder just stops when done).

**Upgrade — Auto Grinder (highest tier):** Automatically selects the correct grind level for the drink on the ticket. Player just presses start.

### Aeropress Mini-Game
Two phases:

**Active — Press:** The player presses the plunger down by holding an input and controlling downward pressure/speed:
- A pressure indicator on the aeropress (in-world, diegetic) shows a "green zone" for ideal press speed
- Too fast = over-extracted, bitter (quality penalty)
- Too slow = under-extracted, weak (quality penalty)
- Smooth, steady pressure through the green zone = perfect shot
- The exact input method (mouse drag downward, hold key + mouse position, etc.) should be prototyped to find what feels best

**Passive — Steep & Ready Window:** After adding water and stirring, the coffee steeps for ~10 seconds (passive — player can walk away). Then it's ready to press for ~8 seconds. After the ready window:
- Shot begins over-extracting (quality degrades over time)
- Eventually the shot "dies" — goes cold/stale and must be discarded
- **Audio cue:** Timer beep when ready. Escalating urgent beep as it starts to over-extract. Audible from across the shop.

### Pour Over Mini-Game
Two phases:

**Active — Pour:** Mouse-controlled gooseneck kettle pour. The player controls where the water stream hits the grounds:
- Mouse position guides the pour point over the coffee bed
- A **saturation overlay** on the grounds shows dry vs. saturated areas (visual heatmap or color change)
- Goal: achieve even saturation across all the grounds
- Quality is determined by **saturation evenness** — dead spots = under-extracted areas = lower quality
- Pour rate may also matter (too fast floods the filter, too slow takes forever)

**Passive — Draw-Down:** After pouring, coffee drains through the filter (~15 seconds). Player can walk away. Coffee stays warm briefly after finishing, then begins to cool:
- **Audio cue:** Dripping sound stops when draw-down finishes. A gentle chime or visual cue signals it's ready.
- If left too long, coffee goes cold — still servable but quality penalty.

### Milk Steaming Mini-Game
**Active with failure-on-neglect.** Mouse controls the steam wand depth in the milk pitcher:
- **Mouse Y position** = wand depth (higher = shallow/surface, lower = deep/submerged)
- **Audio feedback:** Surface position produces a paper-tearing hiss (good for foaming). Too shallow = screech (bad). Too deep = no foam, just heat.
- **Visual indicators:** Foam level rising in the pitcher, milk temperature gauge or color shift
- Goal: hit target foam level and temperature without scalding
- Different drinks may want different foam levels (latte = light foam, cappuccino = heavy foam — Phase 2 concern)

**Failure — Scalding:** If the player walks away while the steam wand is on, or holds too long:
- Milk overheats and scalds — visual: milk discolors, steam turns aggressive
- **Audio cue:** Hiss turns into a harsh rumble/boil sound. Audible across the shop.
- Scalded milk must be dumped and the pitcher refilled. Time lost + milk wasted.
- The steam wand does NOT auto-shutoff — it keeps heating until the player returns.

### Water Pour Mini-Game (Americano)
**Active with overflow risk.** Pour hot water from a dispenser to a fill line on the cup:
- Hold to pour, release to stop
- Overfill = spill = wasted cup, must restart with a new one
- Simple but requires attention — can't just hold and walk away

### Stir Mini-Game (Aeropress)
**Active, brief.** Circular mouse motions to stir the aeropress slurry before pressing. A visual indicator shows mix evenness. Short and simple — just a few rotations. No failure state, just quality variation based on how evenly you stir.

---

## Prototype Drink Menu (Phase 1)

Phase 1 has no flavored syrups, no latte art, and no blended drinks. Three drinks, two brew methods:

### Pour Over — Black Coffee
A single-origin drip coffee. The simplest drink and a good tutorial order.

**Steps:**
1. Set grind level to **coarse** at the grinder
2. Grind beans — ACTIVE (hand grinder mini-game)
3. Place paper filter in pour-over dripper (interact)
4. Add grounds to filter (interact)
5. Pour hot water with gooseneck kettle — ACTIVE (pour over mini-game, saturation-based)
6. Draw-down — PASSIVE (~15s, can walk away, coffee cools if neglected)
7. Pour finished coffee into cup (interact)
8. Lid and hand off

**Ticket code:** `S/T/G/V` + `PO` (e.g., "G PO" = Grande Pour Over)

### Aeropress Espresso Shot
Used as the base for espresso drinks. Not a traditional espresso machine — the aeropress is the Phase 1 equivalent.

**Steps:**
1. Set grind level to **fine** at the grinder
2. Grind beans — ACTIVE (hand grinder mini-game)
3. Add grounds to aeropress chamber (interact)
4. Pour hot water into chamber — ACTIVE (water pour mini-game, fill to line)
5. Stir — ACTIVE, brief (stir mini-game, circular mouse motions)
6. Steep — PASSIVE (~10s, can walk away)
7. Ready window — ~8s to come back and press before over-extraction begins
8. Attach filter cap and flip (interact)
9. Press down — ACTIVE (aeropress mini-game, pressure control through green zone)
10. Extract shot into cup — shot begins dying if not used promptly

### Americano
Aeropress shot + hot water.

**Steps:**
1. Pull an aeropress shot (steps above — shot dies if left too long)
2. Add hot water to the cup from dispenser — ACTIVE (water pour mini-game, fill to line, overflow risk)
3. Lid and hand off

**Ticket code:** `S/T/G/V` + `A` (e.g., "T A" = Tall Americano)

### Latte
Aeropress shot + steamed milk. The most complex Phase 1 drink — multiple active and passive phases to juggle.

**Steps:**
1. Pull an aeropress shot (steps above — shot dies if left too long)
2. Grab milk from fridge (walk to fridge, interact)
3. Pour milk into steaming pitcher (interact)
4. Steam milk — ACTIVE, FAILURE RISK (milk steaming mini-game, scalds if unattended)
5. Pour steamed milk into cup (interact)
6. Lid and hand off

**Ticket code:** `S/T/G/V` + `L` (e.g., "V L" = Venti Latte)

### Optimal Juggling Example
A skilled player making a latte and a pour over simultaneously:
1. Set grinder to fine, start grinding for the aeropress shot
2. While grinding: set up pour-over filter (interact during cranking pauses? or a second player does this)
3. Finish grinding, add grounds to aeropress, pour water, stir, start steep (PASSIVE ~10s)
4. Walk to grinder, switch to coarse, grind for pour over
5. Aeropress beeps — walk back, press the shot
6. Walk to pour-over, add grounds, start pouring (ACTIVE)
7. Finish pour, draw-down starts (PASSIVE ~15s)
8. Walk to steam station, start steaming milk for the latte (ACTIVE — don't walk away!)
9. Finish steaming, pour into latte cup, lid, hand off
10. Pour-over finishes — pour into cup, lid, hand off

---

## Progression & Upgrades

Equipment upgrades are purchased with **money earned from serving drinks**. Upgrades automate previously manual tasks. The design principle: as old tasks automate, new menu items introduce new manual tasks, so the skill ceiling keeps moving.

### Grinder Upgrade Path (Phase 1 includes tier 1)
| Tier | Equipment | Interaction |
|---|---|---|
| 1 | **Hand grinder** | Player sets grind level manually. Cranks by hand (mouse/key mini-game). Takes real time. |
| 2 | **Electric grinder** | Player sets grind level manually. Presses button to start. Grinds automatically — player free to multitask. |
| 3 | **Auto grinder** | Reads ticket and auto-selects grind level. Player just presses start. |

### General Upgrade Tiers (Post-Prototype)
- **Tier 1:** Better equipment (faster, wider timing windows on mini-games)
- **Tier 2:** Semi-automated (button press replaces mini-game — auto-steamer, etc.)
- **Tier 3:** Fully automated (machine does it, player just places the cup)
- **Traditional espresso machine** replaces aeropress as a major upgrade — portafilter, tamping, group head, shot timing

---

## Shop Sizes & Difficulty Scaling

Three shop types that scale with player count. The shop itself changes identity — not just layout, but vibe and setting. **Station distance is a deliberate balancing lever** — more players means more bodies to cover ground, but stations are farther apart so movement and coordination become friction points.

| Shop | Players | Setting | Description |
|---|---|---|---|
| **Espresso Stand** | 1 (solo) | Roadside walk-up window | Tiny footprint — everything within arm's reach. One of each station. Cozy, efficient, intimate. Customers walk up to a window. Solo player can pivot between stations in a step or two. |
| **Coffee Bar** | 2 (duo) | Small storefront | Counter seating, a bit more room. Stations deliberately spread so one player can't cover everything — the fridge might be at one end, the register at the other. Two players divide territory. |
| **Cafe** | 3-4 (group) | Full cafe with lobby | Full floor plan. Register is at the front counter, grinder and aeropress on the back bar, fridge in a back corner, steam wand at the end of the bar. A single player running a latte end-to-end crosses the entire shop. Players must claim zones and hand off cups. |

### Layout as Balance

Station placement is the primary difficulty lever across shop sizes:
- **Espresso Stand:** Grinder, aeropress, steam wand, pour-over, and register are all within a few steps. Fridge is under the counter. The challenge is speed, not movement.
- **Coffee Bar:** Register and bar are separated. Fridge is behind the bar but not adjacent to the steam wand. Players need to walk, which creates natural task handoff points ("I'll steam, you press").
- **Cafe:** Stations are spread across a large space. The fridge might be in a back room. A player walking milk from the fridge to the steam station is out of position for 5+ seconds. Leaving milk steaming to go grab a ticket off the printer is a real risk — will you make it back before it scalds?

Extra bodies help cover the distance, but also create **physical congestion** — two players trying to use the same aeropress station or bumping into each other in a narrow bar area. The shop layouts should have intentional bottleneck points where players have to coordinate who goes where.

Difficulty also scales via:
- **Customer volume:** More customers per minute in larger shops
- **Order complexity:** Larger shops may see more complex orders earlier in the day
- **Queue pressure:** More customers waiting = more pressure on throughput
- **Ambiance expectations:** The cafe has more to maintain (tidiness, restocking) in later phases

---

## Day Structure & Scoring

Each play session is a **timed day** (like Overcooked levels). The day has a fixed duration with a customer schedule that ramps up.

### Day Timing
- Default day length: **3 minutes** (180 seconds). Easily adjustable via a constant — this is a testing default.
- Customer spawn rate ramps over the day (slow start, peak in the middle, taper at end).
- A visible in-world clock or timer shows remaining time.
- When time runs out, no new customers spawn. Players can finish drinks already in progress.

### Scoring & Money
Points are abstracted as **money** — each drink earns cash based on quality and speed. Money is the single progression currency: it funds equipment upgrades, menu unlocks, and shop improvements.

- Every order has a **base price** determined by drink type and size.
- The actual payout is modified by quality and speed:
  - **Drink accuracy** (correct drink, correct size) — must be correct to earn anything
  - **Step quality** (mini-game scores compound — grind, press, pour, steam quality) — scales payout from partial to full price
  - **Speed bonus** (faster delivery = small tip on top of base price)
  - **Wrong drink** handed off = no pay, wasted ingredients
  - **Expired order** (customer leaves) = no pay, lost opportunity
- The day has a **total possible earnings** (sum of all orders at perfect quality + max tips).
- At end of day, **earned / total possible** determines a **letter grade**:

| Grade | Threshold |
|---|---|
| S | 95%+ |
| A | 85%+ |
| B | 70%+ |
| C | 55%+ |
| D | 40%+ |
| F | Below 40% |

- The letter grade is for bragging rights and progression gating (e.g., unlock the cafe after earning B or higher on the coffee bar).
- **Money earned** is kept regardless of grade and accumulates across days to spend on upgrades.

---

## Customer Patience

Each customer has **two separate patience meters** that tick down independently:

### 1. Order Patience (waiting in line / at register)
Starts when the customer arrives and ticks down while they wait to have their order taken. If it empties, the customer leaves without ordering — lost revenue opportunity.

### 2. Pickup Patience (waiting for drink)
Starts when the order is confirmed at the register and ticks down while the customer waits at the pickup counter. If it empties, the customer leaves without their drink — no pay, wasted ingredients and effort.

### Strategic Implications
- **Batch ordering is a gamble:** Ringing up 3 customers quickly is efficient at the register, but now all 3 pickup timers are ticking while you make drinks. The last customer's patience may run out.
- **Prioritization matters:** If two drinks are in progress, finish the one whose customer is more impatient first.
- **Difficulty scaling:** Larger shops can have more impatient customers, or shorter patience windows.
- Phase 2 adds **customer archetypes** with different patience levels (regulars are chill, morning commuters are impatient).

### Phase 1 Implementation
- Simple visible bar above the customer's head (in-world, diegetic — not HUD).
- All customers have the same patience values for now.
- Patience values should be easy to tune via constants.

---

## Multiplayer Architecture

- **Peer-to-peer** hosting using Godot's `MultiplayerAPI` with ENet.
- One player hosts, others join via IP or lobby code.
- Each player owns their character via `set_multiplayer_authority()`.
- `MultiplayerSpawner` handles player instantiation on join.
- `MultiplayerSynchronizer` replicates position, rotation, and held-item state.
- Mini-game interactions are authority-owned by the interacting player — no need to sync mouse input, only the outcome (e.g., "shot pulled, quality = 0.85").
- Game state (day timer, score, customer queue) is server-authoritative (host is server).

---

## Planned Project Layout

```
project.godot
CLAUDE.md
icon.svg

scenes/
  main.tscn                 Root scene — lobby/menu entry point
  game.tscn                 Active game session (loads a shop scene)
  player/
    player.tscn              CharacterBody3D + Camera3D + interaction system
    player_body.tscn         Visible body mesh (seen by other players)
  shops/
    espresso_stand.tscn      Solo — roadside walk-up window
    coffee_bar.tscn          Duo — small storefront with counter seating
    cafe.tscn                Group (3-4) — full cafe with lobby
  stations/
    register.tscn            POS counter with in-world screen + ticket printer
    pour_over_station.tscn   Pour-over dripper + gooseneck kettle
    aeropress_station.tscn   Aeropress setup
    steam_station.tscn       Milk steaming wand + pitcher
    grinder.tscn             Coffee grinder
    hot_water.tscn           Hot water dispenser (for americanos)
    hand_off.tscn            Customer pickup counter
  items/
    cup.tscn                 Carriable cup with ticket slot
    ticket.tscn              Physical printed ticket
    pitcher.tscn             Milk steaming pitcher
  ui/
    lobby_menu.tscn          Host/join menu
    end_of_day.tscn          Score screen (letter grade + XP)
    register_screen.tscn     POS screen content (SubViewport for in-world display)

scripts/
  autoload/
    game_manager.gd          Game state, day timer, scoring, grade calculation
    network_manager.gd       P2P hosting, lobby, ENet connections
    event_bus.gd             Signal bus for decoupled events
    drink_database.gd        Drink recipes and ticket code definitions
  player/
    player.gd                FPS controller, mouse look
    interaction.gd           Raycast-based interact system (E to use)
    hand.gd                  Held item management (cup, pitcher, etc.)
  stations/
    register.gd              POS order entry logic, in-world screen via SubViewport
    ticket_printer.gd        Generates physical ticket from order data
    grinder.gd               Grinder station — grind level selection + hand-crank or auto
    pour_over.gd             Pour-over station — saturation-based pour
    aeropress.gd             Aeropress station — pressure control
    steam_wand.gd            Steam station — wand depth control
    hot_water.gd             Hot water dispenser — fill-to-line pour
    hand_off.gd              Drink delivery + quality scoring
  mini_games/
    base_mini_game.gd        Shared interface for all mini-games
    pour_mini_game.gd        Mouse-guided pouring (gooseneck saturation + simple fill)
    press_mini_game.gd       Active pressure control (aeropress plunger)
    grind_mini_game.gd       Hand-crank grinding (circular mouse/key input) + grind level
    stir_mini_game.gd        Circular mouse stirring (aeropress slurry)
    steam_mini_game.gd       Wand depth control (mouse Y) + audio/visual feedback
  data/
    drink_data.gd            Resource class for drink definitions
    order_data.gd            Resource class for customer orders
    shop_data.gd             Resource class for shop layout configs
    day_schedule.gd          Customer spawn schedule per shop size
  customers/
    customer.gd              Customer AI — walk up, order, wait, pick up, leave
    customer_spawner.gd      Spawns customers per day_schedule

resources/
  drinks/                    .tres files for each drink recipe
  materials/                 Shared materials
  models/                    Low-poly meshes
  shop_configs/              .tres files for shop size configs (customer rate, point totals, etc.)
```

---

## Ticket / Cup Code System

Tickets use Starbucks-style shorthand. Phase 1 codes:

| Field | Codes |
|---|---|
| **Size** | S (short), T (tall), G (grande), V (venti) |
| **Drink** | PO (pour over), A (americano), L (latte) |
| **Milk** | WM (whole milk) — default for Phase 1, omitted on ticket if default |

Example tickets:
- `G PO` — Grande Pour Over
- `T A` — Tall Americano
- `V L WM` — Venti Latte, Whole Milk

### Cup Size Mechanics

Size has a **small but real mechanical impact**. Larger cups require more of everything:

| Size | Grind Amount | Pour Duration | Milk Volume | Point Value |
|---|---|---|---|---|
| **Short** | Base | Base | Base | Base |
| **Tall** | 1.2x | 1.2x | 1.2x | 1.15x |
| **Grande** | 1.5x | 1.5x | 1.5x | 1.3x |
| **Venti** | 1.8x | 1.8x | 1.8x | 1.5x |

- **Grind amount:** More cranks on the hand grinder, longer auto-grind time
- **Pour duration:** Fill line is higher — more water, more milk, slightly longer pour mini-games
- **Overflow risk:** Bigger cup is more forgiving (larger margin before spill), but takes longer to fill
- **Price:** Larger drinks cost more, so the player earns more per drink — compensating for the extra time

Size affects the *duration* of tasks, not the *difficulty* of mini-games. A Venti pour-over still has the same saturation challenge — you just pour longer. The tradeoff is time vs. money: a Venti latte earns more but ties up stations longer.

### Phase 2 Additions (not yet implemented)
- Milk alternatives: NF (nonfat), 2% (two percent), OM (oat), AM (almond)
- Syrups: V (vanilla), C (caramel), H (hazelnut), SF prefix (sugar-free)
- Extras: WC (whipped cream), XH (extra hot)
- Shots: number prefix for extra shots
- New drink types: CM (caramel macchiato), M (mocha), F (frappuccino), CB (cold brew)

---

## Longer-Term Features (Post-Phase 2)

- **Shop tidiness:** Trash accumulates, condiment bar needs restocking, counters get messy. Neglect = lower star rating.
- **Cleaning mini-games:** Wipe counters (back-and-forth strokes), mop spills (circular strokes), take out trash.
- **Restocking:** Carry supplies from back room to stations (milk, beans, cups, lids, sleeves).
- **Staff management:** Hire AI baristas, assign them to stations.
- **Traditional espresso machine:** Replaces aeropress as an upgrade — portafilter, tamping, group head, shot timing.
- **Shop cosmetics:** Decor, menu boards, seating, cup designs, apron colors.
- **Daily challenges:** Morning rush, happy hour, secret menu orders.
- **Customer archetypes:** Regulars (patient), commuters (impatient), complex orderers.
- **Latte art:** Dexterity-based mini-game for tips bonus.

---

## Phasing

### Phase 1a — Grey-Box Prototype (current target)
All geometry is grey-boxed (untextured primitives). Solo espresso stand only. Proving out the core mechanics.
- First-person player controller with mouse look
- Espresso stand grey-box layout (all stations within arm's reach)
- Item carry system (one item, Skyrim-style viewport float)
- Camera-lock mini-game system with prerequisite checks
- In-world register with center-of-view targeting (no cursor mode switch)
- Ticket printer + cup stacks (infinite supply, one per size)
- Mini-game mechanical proofs of concept: grind (hand crank), pour over (saturation), aeropress (pressure), milk steam (wand depth), water pour (fill line), stir
- Unattended failure states: shot dying, milk scalding, coffee cooling
- Basic customer AI: walk up, speech bubble, dual patience meters, pick up, leave
- Timed day (3 min default)
- End-of-day score screen with letter grade + money earned

### Phase 1b — Full Prototype
- Coffee bar and cafe shop layouts
- Online P2P multiplayer: host/join via ENet, 2-4 players, synced positions and item state
- Customer spawner with difficulty scaling per shop size
- Art pass on espresso stand (low-poly models replace grey boxes)
- Audio pass: mini-game feedback sounds, ambient coffee shop, customer cues

### Phase 2 — Menu Expansion
- Flavored syrups and syrup pump mini-game
- Milk alternatives (oat, almond, nonfat, 2%)
- New drink types (mocha, caramel macchiato)
- More cup code fields on tickets
- Equipment upgrade system (tier 1-3 automation)
- Latte art mini-game
- More customer variety and patience mechanics

### Phase 3 — Shop Management
- Tidiness system (trash accumulation, messy counters)
- Cleaning mini-games (wipe, mop, take out trash)
- Restocking from back room (milk, beans, cups, lids)
- Shop cosmetics and visual progression
- Staff hiring (AI baristas)

---

## What's Built vs. What's Deferred

**Done:**
- Project setup and documentation
- FPS player controller with mouse look, WASD movement, jump
- Interaction system (RayCast3D, E to interact, center-of-view targeting)
- Item carry system (one item, Skyrim-style float, click to pick up/place)
- Grey-box espresso stand (procedurally built, all stations positioned)
- Mini-game framework (BaseMiniGame with camera lock, quality scoring)
- Grinder mini-game (hand crank, grind level selection, fill indicator)
- Aeropress mini-game (passive steep/ready window, active pressure press, over-extraction/death)
- Pour-over mini-game (saturation-based gooseneck pour, passive draw-down, coffee cooling)
- Milk steaming mini-game (wand depth, foam/temp tracking, scald failure)
- Water pour mini-game (fill-to-line, overflow risk)
- Stir mini-game (circular mouse input, rotation counting)
- Register with in-world POS screen (SubViewport, size/drink selection, ticket printing)
- Cup stacks (per-size, infinite supply, auto-attaches pending order ticket)
- Hand-off counter (validates drink completion, scores quality, awards money)
- Drink data system (DrinkData constants, OrderData quality tracking)
- Station scripts: grinder, aeropress, pour-over, steam, hot water, register, cup stack, hand-off
- Customer AI (walk to register, speech bubble, dual patience meters, walk to pickup, leave)
- Customer spawner (time-ramped schedule, day-progress intensity curve)
- Day timer (3 min default, HUD display) + money tracking + letter grade calculation
- HUD (timer, money earned, interaction prompts, crosshair)

**Needs Testing:**
- Open in Godot 4.6 and run — hand-written .tscn and procedural scene may need fixes on first import
- Mini-game feel tuning (all timing constants are best-guess)
- Station interaction flow end-to-end (register -> grind -> brew -> hand off)

**Deferred:**
- End-of-day score screen UI
- Phase 1b (multiplayer, additional shops, art/audio)
- Phase 2 (menu expansion, upgrades)
- Phase 3 (shop management)

---

## Running

1. Install Godot 4.6.
2. Open `project.godot` from this directory.
3. F5 to play.
