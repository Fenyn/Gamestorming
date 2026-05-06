# Skeleton Crew

FTL meets friendslop. A co-op roguelike where 2–4 players each control a crewmate aboard a single ship fleeing through hostile space. No one has the full picture. Everyone's yelling.

**Engine:** Godot 4.6 (3D, first-person)
**Genre:** Co-op Roguelike / Friendslop / Ship Sim
**Players:** 2–4 (online multiplayer, stretch: local)
**Inspirations:** FTL: Faster Than Light, Lethal Company, Pulsar: Lost Colony, Sea of Thieves, Barotrauma

---

## Elevator Pitch

FTL but you ripped the pause button out and gave each crew station to a different friend. One player is sprinting to fix a hull breach, another is trying to line up a missile shot, a third just vented the oxygen by accident. The ship doesn't care about your feelings.

---

## Core Loop

```
Star map → pick next node (crew votes / captain decides)
  → Jump to node → encounter (combat, event, shop, hazard)
    → Combat: real-time, each player physically runs their crewmate
       between ship rooms to man systems, fight fires, repel boarders
    → Resolve encounter → collect scrap
  → Spend scrap at shops on ship upgrades, system repairs, fuel
  → Rebel fleet advances → pressure to keep moving
→ Reach final sector → boss encounter → win or die trying
```

Permadeath per run. Full crew wipe = restart. Individual crewmate death = that player spectates (or haunts the ship as a ghost mechanic — stretch goal).

---

## What Each Player Actually Does

Unlike FTL (one god-player managing everything), each player is ONE crewmate with:
- A physical position on the ship (must walk between rooms)
- A role specialty (bonus when manning their station)
- Limited information (only see rooms you're in or adjacent to, unless sensors are manned)
- Direct interaction: repair, fight, operate systems, open/close doors

**No pause. No top-down omniscience.** The chaos IS the game.

### The Ship as a 3D Space

The ship is a fully modeled 3D interior — corridors connecting rooms, ladders between decks, hatches, consoles, and **windows**. Every first-person player experiences the battle from inside the hull, but viewports throughout the ship give glimpses of the fight outside:

- **Corridor windows:** small portholes along main corridors. Running to fix a fire, you glance out and see the enemy ship banking for another pass. A missile streaks past the glass. You see your own turrets tracking and firing. These are ambient — you don't interact with them, but they connect the interior experience to the exterior battle
- **Room viewports:** larger windows in key rooms (mess hall, observation deck, medbay). During calm moments, scenic. During combat, terrifying — you watch enemy weapons charge and fire directly at you. A beam weapon cutting across the hull is visible as a blinding line sweeping past the viewport
- **Bridge windows:** the cockpit has the largest forward viewport, but the pilot's view is on their console (third-person tactical). A non-pilot standing in the bridge can look out the windows and see what's ahead — asteroids, stations, the enemy — but without instruments it's just a view
- **Impact visibility:** when the ship takes a hit on your side, the viewport flashes. A near-miss lights up the glass. A hull breach in a windowed room cracks the viewport — atmosphere venting is visible as a frost/fog effect on the glass before it seals or shatters entirely
- **Weapon glow:** when your own weapons fire from a nearby hardpoint, the viewport on that side strobes with muzzle flash. The gunner's turret rotation is visible from inside as the barrel sweeps past windows

The ship exterior is fully modeled too — turrets visibly rotate, weapon fire emits from hardpoints, hull damage shows as scorched plating and torn panels, shield impacts shimmer across the surface. The pilot sees all of this from their third-person view, and the first-person crew catches glimpses through windows. Enemy ships are equally modeled: you can see their turrets tracking you, their engines flaring, their hull breaking apart as you win the fight.

Windows serve no mechanical purpose — they're pure immersion. They make the ship feel like a real place in a real battle, not a set of disconnected minigame rooms.

**Scope note:** PvP (crew vs crew, ship vs ship) is a natural fit for this architecture and stays on the stretch list, but the core game is friends vs AI. All design decisions prioritize the co-op experience first.

---

## FTL Axes of Control (analysis)

Everything a single FTL player juggles, broken into categories. All of this happens simultaneously in real-time-with-pause. We need to split it across players so each role is deep enough to be a full-time job.

### Strategic (between jumps)
- **Navigation** — star map pathing, which node to jump to, balancing risk/reward/fleet pressure
- **Economy** — scrap allocation at shops: upgrades vs. repairs vs. fuel vs. weapons
- **Build planning** — which systems to invest in, weapon synergies, reactor upgrades

### Combat — Offensive
- **Weapon management** — charging, selecting targets, timing volleys to sync past shields
- **Weapon loadout** — swapping active weapons to counter enemy defenses
- **Special systems** — hacking (disable enemy system), mind control (turn enemy crew), drones (combat/defense/boarding)
- **Boarding** — teleporting crew to enemy ship, fighting enemy crew, targeting critical systems from inside

### Combat — Defensive
- **Shield management** — layered shields, ion damage recovery, Zoltan shield timing
- **Evasion** — engine power directly maps to dodge chance
- **Door control** — venting O2 to extinguish fires, funneling boarders into killzones, sealing off breaches
- **Cloaking** — timing cloak to dodge incoming volleys (window-based, not toggle)

### Combat — Resource Management
- **Power distribution** — THE central axis. Moving reactor bars between systems in real-time. Shields need 4 bars but weapons need 3 and engines need 2 and you only have 7...
- **Crew positioning** — who mans which station, who repairs, who fights. Opportunity cost per crewmember
- **Consumables** — missiles, drone parts (finite, spent per use, can't be recovered)

### Combat — Information
- **Sensors** — enemy ship layout, enemy crew positions, enemy system health. Lose sensors = blind
- **Threat assessment** — reading the enemy loadout, predicting which of your rooms will get hit, prioritizing repairs
- **Timing** — when to flee (FTL charge), when to cloak, when to fire, when to hack. Everything is windows

### Damage Control
- **Repair priority** — which damaged system to fix first (shields? O2? weapons?)
- **Fire management** — vent rooms to kill fires vs. send crew to stomp them
- **Breach management** — hull breaches drain O2 and require crew to patch
- **Crew health** — routing injured crew to medbay without leaving stations empty

---

## Roles (first-person multiplayer conversion)

The old section had generic RPG roles (gunner, medic, etc). This redesign is driven by the axes above — each role owns a **cluster of FTL axes** that becomes their full-time job in first person. Every role has a station (their console/room), a first-person interface, and reasons to physically leave that station (which creates the core tension).

### Role 1: Reactor Engineer (Power)

**Owns:** Power distribution, reactor management, electrical infrastructure

**Station:** The reactor room, deep in the ship. A massive switchboard with physical breaker handles for each system.

**First-person interface:**
- A wall of breaker switches and power bus bars. Each system has a breaker lever — pull it up to allocate power, slam it down to cut
- Total reactor output is limited. Allocating to weapons means stealing from shields. Everything is zero-sum
- Overcharge mode: crank a system past safe limits for a temporary boost, but the breaker glows red and risks blowing out (forces a physical repair)
- Reactor health meter — if the reactor room takes damage, total output drops. Engineer must repair their own room to keep everyone else running

**Why they leave the station:**
- Power conduits run through the ship. When a conduit is damaged (hit by weapons, fire), the connected system loses power even if the breaker is up. Engineer must physically trace and repair conduit junction boxes in the walls of other rooms
- Blown fuses in remote rooms need manual reset

**What it feels like:** You're the beating heart of the ship. Everyone needs you. The gunner is screaming for more weapon power, the pilot needs engines, shields are flickering — and you have 6 bars to split across systems that want 12. Then a conduit blows in the hallway and now you have to leave the board.

**Interplay with other roles:**
- → Gunner: power bars directly control weapon charge rate and how many weapons can fire. Gunner requests power, engineer decides priority
- → Pilot: engine power = evasion chance. Pilot can request a "surge" (temporary overclock) for a critical dodge window
- → Shields: shield layers are gated by power. Engineer can "pulse" all power to shields for a burst recharge, but everything else goes dark for 2 seconds
- → Damage Control: engineer can remotely cut power to a burning room (kills the fire but also kills the system)

---

### Role 2: Weapons Officer (Gunner)

**Owns:** Weapon charging, targeting, firing, weapon loadout, special offensive systems

**Station:** The weapons bay. A targeting console with a scope/screen showing the enemy ship.

**First-person interface:**
- A targeting screen showing the enemy ship schematic. Each room is selectable
- Weapon charge bars — weapons charge independently, each on its own timer
- Volley sync indicator — shows when multiple weapons will be ready simultaneously (critical for breaking shields: firing one at a time lets shields regen between hits)
- Manual targeting reticle: in first person, aiming is active — a targeting scope that the gunner physically aims at enemy ship rooms. Steadier aim = tighter spread. Hands shake under pressure (low O2, ship taking hits, fires nearby)
- Missile/special ammo: physical torpedo tubes that need manual loading. Gunner must step away from the console to shove a missile into the tube, then get back to aim and fire

**Why they leave the station:**
- Missile reloading (physical torpedo tubes in an adjacent room)
- Weapon jams — a damaged weapon needs a physical unjam (hit it with a wrench)
- If weapons bay is on fire, they either fix it or lose the console

**What it feels like:** You're the teeth. Everyone else keeps the ship alive — you end the fight. But your weapons are only as good as the power the engineer gives you and the target data the sensors officer feeds you. Without sensor locks, you're firing blind into a silhouette.

**Interplay with other roles:**
- ← Reactor Engineer: your weapons only charge if you have power bars. You're constantly negotiating for more
- ← Sensors Officer: with sensors active, you get target lock pips (aim assist), weak point highlights (bonus damage rooms), and system health readouts (know when to switch targets). Without sensors, your targeting screen is a basic silhouette — no room labels, no health bars, no lock assist. You CAN still fire, but you're guessing
- → Pilot: you can call out "shields down, hit them NOW" moments for the pilot to stop evading and hold steady (better shot accuracy when ship isn't juking)
- ← Damage Control: if your weapons are jammed and you can't leave the scope (mid-volley), you need DC to come unjam for you

---

### Role 3: Pilot (Helm)

**Owns:** Evasion, FTL charge, navigation, star map, flight

**Station:** The cockpit, at the front of the ship. A flight console with a viewport showing space.

**First-person interface:**
- Forward viewport: you SEE incoming projectiles, asteroids, and the enemy ship. Not abstracted — first person
- Evasion is active: when enemy weapons fire, you see the projectiles coming. Evasion is a timed input — dodge left/right/up/down. Engine power determines how responsive the ship is (low power = sluggish, easy to hit). High skill + high power = nearly untouchable
- FTL drive charge: a gauge that fills over the course of the fight. When full, pilot can initiate jump to escape. Charging is faster with engine power. Pilot decides when to flee
- Star map: between encounters, the pilot sees the sector map and proposes the next jump. Crew votes, pilot breaks ties
- Speed management in hazards: asteroid fields require active flying to dodge rocks. Nebula = low visibility

**Why they leave the station:**
- Unmanned cockpit = no active evasion, only passive dodge chance (much lower). Pilot almost NEVER wants to leave
- But if the cockpit takes damage, they might need to physically repair the flight console before they can steer again
- Emergency: if everyone else is down and there's a fire or boarder, pilot must choose — leave the stick and the ship becomes a sitting duck, or stay and hope someone else handles it

**What it feels like:** You're the first one to see danger and the last one to leave your seat. You have the best view of the battle but the least ability to help with anything inside the ship. Your evasion skill is the difference between a clean fight and a catastrophe. You're also the one who decides when to run.

**Interplay with other roles:**
- ← Reactor Engineer: engine power = dodge responsiveness. You live and die by how many bars the engineer gives you. You can request a power surge for a critical dodge window
- ← Sensors Officer: with sensors, you get incoming fire trajectory predictions (aim-assist for dodging). Without sensors, you're dodging on reaction alone
- → Gunner: you can "hold steady" on request (stop evading) to give the gunner a stable firing platform, but you're eating every shot while you do it. Trust exercise
- → Everyone: you decide when to jump away. If FTL is charged, you can pull the crew out of a losing fight — but anyone not on the ship gets left behind (if boarding is in play)

---

### Role 4: Damage Control Officer (DCO)

**Owns:** Repairs, fires, breaches, doors, O2, boarder combat, medbay, crew survival

**Station:** Damage Control room — a central monitoring post with a ship cross-section display and door control panel.

**First-person interface:**
- Ship status board: a wall-mounted cross-section of the ship showing room states — color-coded for fire (red), breach (blue), damaged system (yellow), boarders (purple), low O2 (grey)
- Door control panel: a grid of toggle switches for every door on the ship. Can vent rooms to space (kills fire, kills boarders, but also kills O2 and any crew in there). Can seal sections to contain hazards
- Remote O2 control: can redistribute O2 between sections
- Repair kit: DCO carries a physical repair tool. Repairing is a held interaction in first person — stand at the damaged system, hold interact, watch a progress bar. Faster than other roles at repairs but still takes time

**Why they leave the station:**
- They leave ALL THE TIME. DCO is the runner. Their station gives them information and door control, but all physical repairs happen in person
- Sprint to the engine room to patch a breach, then to weapons bay to unjam a gun, then to the medbay to drag an injured crewmate in
- Boarder combat: DCO is the best fighter (bonus melee damage). When boarders teleport in, DCO is first responder

**What it feels like:** Organized chaos. You're the firefighter (literally). You spend most of the fight sprinting through corridors, patching holes, fighting aliens, and desperately triaging what to fix first. You have the best awareness of what's wrong (your status board) but you can only fix one thing at a time. Every second counts. You're always behind.

**Interplay with other roles:**
- ← Reactor Engineer: engineer can cut power to a burning room (helps you by killing the fire, but also disables that system). You coordinate: "cut power to shields, I'll patch it, then restore"
- → Gunner: you unjam their weapons, put out fires in weapons bay, keep their room intact
- → Pilot: you keep the engines running. If engines take damage, pilot loses evasion until you fix it
- ← Sensors Officer: sensors shows you exactly what's wrong and where. Without sensors, your status board goes dark — you're running room to room checking manually
- → Everyone: door control is a weapon. You can vent a room to kill boarders, but you need to warn the crew first ("VENTING AFT CORRIDOR, GET OUT"). Miscommunication kills crewmates

---

### Role 5: Sensors / Tactical Officer (stretch — 5th player)

**Owns:** Sensors, scanning, enemy intel, hacking, electronic warfare, comms

**Station:** The CIC (Combat Information Center). A wraparound console with multiple screens.

**First-person interface:**
- Main screen: full enemy ship schematic with room labels, system health bars, crew positions (if sensors powered)
- Scanning mode: actively focus scan on a specific enemy room to reveal detailed info (exact HP, charge status of enemy weapons, crew stats). Can only deep-scan one room at a time
- Hacking interface: select an enemy system to hack. Sends a drone that latches on and disrupts (locks doors to that room, drains the system). One hack per fight, choose wisely
- Comms console: manages the ping/marker system, crew locator HUD, and shipwide voice relay
- Threat warning system: incoming missile/projectile alerts that get pushed to the pilot's HUD

**Why they leave the station:**
- Comms antenna takes external damage — requires EVA-adjacent repair (going to the comms room to physically realign)
- Sensors array in a separate room from CIC may need physical repair
- If the ship is undermanned, sensors officer is the most "optional" station — they'll get pulled to help with fires or boarders, losing intel for the whole crew

**What it feels like:** You're mission control. You see everything — but you can't DO anything directly. Your value is entirely in the information you push to your teammates. A good sensors officer makes the gunner lethal and the pilot untouchable. A missing sensors officer makes everyone fumble in the dark.

**Interplay with other roles:**
- → Gunner: target locks, weak points, "their shields are down NOW — fire", weapon charge timing on enemy (know when to brace). This is the tightest synergy in the game
- → Pilot: incoming fire warnings, trajectory data, "missile incoming port side in 3 seconds"
- → DCO: "boarders teleporting to engine room", "fire in aft corridor", full ship awareness when DCO's board is damaged
- → Reactor Engineer: "they're targeting our reactor — brace" / "their weapons are charging, shift power to shields"
- ← Reactor Engineer: sensors need power to function. If power is cut, the entire crew goes blind

---

## Role Scaling (player count)

| Players | Roles | Notes |
|---------|-------|-------|
| 2 | Pilot + Gungineer (Gunner + Engineer hybrid) | Minimal viable crew. One flies, one shoots and manages power. Maximum chaos |
| 3 | Pilot + Gunner + Engineer/DCO | Engineer doubles as damage control. Still frantic |
| 4 (sweet spot) | Pilot + Gunner + Reactor Engineer + DCO | All core axes covered. Sensors is automated (basic mode). Full synergy web |
| 5 | All five roles | Full crew. Sensors/Tactical adds the intel layer. Most coordinated, highest skill ceiling |

Hybrid roles for smaller crews merge stations physically — the Gungineer's room has both the power board and the weapons console side by side, so one player can spin between them.

---

## The Interplay Web (summary)

```
                    ┌──────────┐
          power ───→│  GUNNER  │←─── target data
            │       └────┬─────┘         │
            │            │ "hold steady" │
            │            ▼               │
     ┌──────┴───┐   ┌─────────┐   ┌─────┴──────┐
     │ ENGINEER │   │  PILOT  │   │  SENSORS   │
     └──────┬───┘   └────┬────┘   └─────┬──────┘
            │            │              │
      cut power   evasion needs    threat warnings
      to burning     power        boarder alerts
        rooms          │              │
            │       ┌──┴──────────┐   │
            └──────→│     DCO     │←──┘
                    │ (the runner)│
                    └─────────────┘
```

Every arrow is a dependency. Every dependency is a conversation. Every conversation can be interrupted by the ship exploding.

---

## Active / Passive Engagement & Station Minigames

Every interaction in the game — manning a system, repairing damage, fighting boarders — has a **minigame** that simulates physically doing the thing. The minigame IS the game. You're never just watching a progress bar.

### Design Principle: Attention as Currency

Each player can only actively play one minigame at a time. Systems you're not actively interacting with drop to **passive mode** (autopilot — reduced effectiveness, no skill expression). The moment-to-moment skill of Skeleton Crew is choosing WHICH minigame to play right now, because everything is on fire and you can only do one thing.

A role's depth comes from having 2–3 minigames competing for their attention, plus emergency minigames that pull them away from their station.

---

### Pilot Minigames

**The pilot's unique perspective: third-person ship view.**
The pilot is the ONLY player who sees the battle from outside. Their console pulls up a third-person camera centered on the ship, showing the surrounding 3D space — enemy ships, incoming fire, asteroids, debris. Everyone else is trapped in first-person inside the hull. The pilot is the crew's eyes on the macro battle.

**Ship Rotation & Positioning (primary — continuous)**
The ship has physical weapon hardpoints at fixed locations: dorsal turrets, port/starboard batteries, a forward-fixed torpedo tube, a ventral beam array. Each hardpoint has a limited **firing arc** — it can only shoot in the direction it faces.

The pilot's core job is **rotating and positioning the ship** so the gunner's active weapons can bear on the enemy:
- Gunner calls "I need port guns on target" → pilot rolls the ship to bring the port battery facing the enemy
- Torpedo tube is forward-fixed → pilot must point the ship's nose at the target for torpedo shots
- Beam array is ventral → pilot pitches the ship to expose the belly to the enemy for a beam sweep

This is a constant negotiation. The optimal rotation for the torpedo tube (nose-on) might expose the ship's weakest hull section. The ideal angle for the port battery might put the shield emitters (dorsal) facing away from incoming fire. The pilot is balancing **offensive facing** (help the gunner) vs **defensive facing** (minimize damage to critical areas, present the thickest armor toward the enemy).

Repositioning also matters: closing distance for short-range weapons, keeping distance for torpedoes, orbiting to stay out of enemy fixed-weapon arcs. The pilot reads the 3D space and makes moment-to-moment spatial decisions.

**Evasion (reactive — during incoming fire)**
When enemy fire is incoming, the pilot sees it in the third-person view as tracer trails, missile exhaust plumes, and beam charging glows converging on the ship. Evasion is **thruster input** — lateral/vertical dodges that shift the ship's position.

- Engine power determines thruster responsiveness. High power = snappy lateral thrust. Low power = sluggish, the ship drifts where it was going
- Dodging disrupts the current ship rotation. A hard dodge to starboard might roll the ship off the angle the gunner needs. The pilot has to recover the facing after dodging — or the gunner loses their shot window
- Multiple incoming vectors force hard choices: dodge the missile (big damage) but eat the laser (small damage), or hold position and take both but keep the guns on target
- **Everyone inside feels every dodge.** The ship lurches, consoles shake, crew stumble. The pilot sees it as a smooth camera move. The crew experiences it as chaos. This asymmetry is intentional — the pilot never feels how violent their inputs are

**Hold Steady (active choice — costs evasion)**
Gunner calls for a stable platform. Pilot locks the thrusters and holds the current rotation — the ship drifts on its vector, perfectly stable. The gunner's turret tracking becomes trivially easy. But the pilot watches incoming fire close on the ship with no ability to dodge. They see, from outside, the missiles slam into their friends' rooms. Trust exercise.

**FTL Charge (secondary — at helm console)**
A charging gauge with a stabilization minigame. The FTL drive has a needle that wanders — pilot must keep it in the green zone by tapping corrections (like balancing a level). Steady hands = faster charge. Neglect it and the charge stalls or regresses. The tension: you're splitting attention between dodging and charging, and you can't do both well.

**Star Map Navigation (between fights — passive phase)**
Route planning on the sector map. No minigame — this is the strategic/discussion phase. Pilot proposes, crew votes.

| Activity | Mode | Effectiveness |
|----------|------|---------------|
| Evasion dodging | Active | High dodge rate, skill-dependent |
| Evasion unmanned | Passive | Low flat dodge %, no player input |
| Hold Steady | Active (sacrifice) | 0% dodge, gunner accuracy bonus |
| FTL Charge | Active | Fast charge, competes with evasion attention |
| FTL Charge unattended | Passive | Very slow charge |

---

### Gunner Minigames

**Energy Weapons — Turret Aiming (passive-leaning)**
When the gunner mans a turret, their first-person camera snaps to the turret's viewpoint — they're looking out through the barrel housing into space. Mouse/stick input rotates the turret, and **the camera rotates with it**. The gunner's entire visual experience becomes the turret's perspective.

Turret rotation speed is a stat — cheap early turrets track slowly (the gunner drags the mouse and the camera lags behind, sluggish and heavy), upgraded turrets are snappy and responsive. This means turret upgrades don't just increase DPS on a spreadsheet — they literally change how the game feels to aim. A slow turret against a fast-strafing enemy is a genuine skill challenge: leading the target, predicting movement, fighting the rotation cap.

The turret has a limited firing arc (determined by which hardpoint it's mounted on). As the gunner rotates toward the arc limit, the view starts to clip the ship's own hull — structural beams and plating creep into frame as a visual warning. At the hard limit, the turret stops and the enemy slides out of view. The gunner needs the pilot to rotate the ship to bring the target back into arc, or physically leave the turret and run to a different hardpoint on the other side of the ship.

Energy weapons auto-fire when charged, but bolts travel through 3D space with real travel time and ballistic arcs (heavier projectiles drop over distance). The gunner must **lead the target** — aim where the enemy will be when the shot arrives, not where it is now. At close range this is trivial. At distance against a maneuvering enemy, it's genuine marksmanship.

Without upgrades, leading is pure intuition — the gunner reads the enemy's movement and guesses. The **predictive pip** is a purchasable upgrade (sensors-linked) that projects a lead indicator onto the turret view: a small reticle showing where to aim so the shot intercepts the target's current trajectory. The pip accounts for projectile travel time, ballistic arc, and relative velocity. Aim at the pip, hit the target.

But the pip isn't omniscient — it predicts based on the enemy's CURRENT vector. If the enemy changes course after the shot is fired, the pip was wrong and the shot misses. Against predictable enemies (straight-line cruisers, stationary stations) the pip makes the gunner near-perfect. Against erratic fighters that juke constantly, the pip flickers and jumps and is only a rough guide. Skill still matters.

**Pip tiers (upgrade path):**
- **No pip:** raw aim, lead by instinct. High skill floor
- **Basic pip:** lead indicator for the primary turret, no arc compensation. Helps with slow movers
- **Ballistic pip:** full arc + travel time + relative motion calculation. Accurate against steady targets
- **Predictive pip:** factors in enemy acceleration patterns (requires active sensor scan on the target). Near-perfect against anything sensors can read

The pip is also the primary synergy hook for sensors → gunner: without sensors power, the pip degrades or disappears entirely. The sensors officer's scan quality directly determines pip accuracy.

Pilot dodges still lurch the turret view and momentarily invalidate the pip (the pip recalculates after the dodge settles). Steadier ship = steadier pip = easier shots.

**Torpedoes — Load & Lock (high-active)**
Torpedoes hit hard but require a multi-step physical minigame:
1. **Load:** Leave the turret, walk to the torpedo bay. Interact with the rack: a sliding-puzzle to slot the torpedo into the forward tube (3–4 quick inputs, like matching alignment pins)
2. **Arm:** Back at the console, arm the warhead — a timing press (hit the button when the arming indicator is in the green zone, or the torpedo is a dud)
3. **Lock:** The torpedo tube is forward-fixed — the PILOT must point the ship's nose at the target. Gunner sees through the torpedo cam and calls corrections: "nose up, little more, HOLD — locked." Lock quality depends on how steady the pilot holds the facing
4. **Fire**

Torpedoes create the tightest pilot-gunner coordination in the game. The gunner can't aim them — only the pilot can, by flying the whole ship. But the pilot can't see the lock indicator — only the gunner can. They have to talk each other through it.

**Beam Weapons — Trace Cut (skill-active)**
Beam array is ventral-mounted. The pilot pitches the ship to expose the belly toward the enemy, then the gunner gets a brief window (2–3 seconds) to **sweep the beam** across the enemy ship by aiming through the ventral scope. The beam cuts along whatever path the gunner traces. A skilled trace can rake across multiple sections of the enemy hull. A sloppy trace hits one spot and wastes the window.

The pilot's stability matters enormously — if the pilot is dodging during a beam sweep, the gunner's trace jumps wildly. Beam shots almost always require a "hold steady" call.

Pairs with sensors synergy: with scan data, structural weak points glow on the enemy hull through the scope. Without sensors, you're eyeballing where to cut.

**Volley Timing (meta-minigame)**
Not a separate minigame but an awareness layer: shields regenerate between hits. If the gunner fires weapons one at a time, each shot hits a full shield. Timing all weapons to fire in a **burst volley** (wait for all charge bars to fill, then fire together) overwhelms shields. A UI element shows all weapon charge states and a "volley window" — the sweet spot where everything is ready. Disciplined gunners wait. Panicked gunners spam.

| Activity | Mode | Effectiveness |
|----------|------|---------------|
| Energy tracking | Low-active | Moderate damage, aim-dependent |
| Energy unattended | Passive | Low damage, random spread |
| Torpedo load+lock | High-active | Huge burst damage, leaves other weapons passive |
| Beam trace | Skill-active | Multi-room damage, skill-dependent path |
| Volley timing | Awareness | Multiplied damage when synced |

---

### Reactor Engineer Minigames

**Power Balancing (primary — at reactor console)**
The power board isn't static breakers — it's a live **load-balancing minigame**. Each system draws power as a waveform on the board. Weapons spike when they fire. Shields spike when recharging after a hit. Engines spike during dodge maneuvers.

The reactor has a maximum output (a red line). Total system draw is a combined waveform. If the combined draw exceeds the reactor cap, something **browns out** (random system flickers off for 1–2 seconds — could be shields right when a missile hits).

The engineer's job: watch the demand curves and **pre-emptively adjust breaker levels** before spikes happen. Gunner says "firing torpedoes in 3" — engineer boosts weapon power and dips shields to make room for the spike. Pilot dodges hard — engine demand surges — engineer was already ready because they heard the pilot call it out.

This is a **prediction and communication minigame**. The engineer who listens to their crew and anticipates demand is far better than one who reacts.

**Overclock (risk/reward — at reactor console)**
Any system can be overclocked: push the breaker past the safe zone into the red. The system performs at 150% (weapons charge faster, shields recharge instantly, engines give bonus dodge frames). BUT: a **heat gauge** rises while overclocked. The engineer plays a **pressure hold** — keep the breaker in the red zone while watching the heat needle. Pull back before it redlines and the system returns to normal. Hold too long and the breaker **blows** — system goes offline entirely, engineer must physically repair the fuse (leave the board, go to the blown fuse box, do a repair minigame).

The tension: overclock can win a fight, but a blown breaker can lose one.

**Conduit Repair (away from station)**
When conduits take damage, the engineer traces the problem to a junction box in the ship. The repair minigame: a **wire reconnection puzzle** — a small grid of disconnected power lines that need to be rotated/swapped to complete the circuit. Quick puzzle (10–15 seconds), but every second away from the power board is a second nobody's managing load balance.

| Activity | Mode | Effectiveness |
|----------|------|---------------|
| Load balancing | Active | Smooth power delivery, no brownouts |
| Breakers set and left | Passive | Frequent brownouts during demand spikes |
| Overclock | High-risk active | 150% system output, risk of blowout |
| Conduit repair | Away-from-station | Puzzle minigame, restores power to cut-off systems |

---

### DCO (Damage Control) Minigames

DCO is unique: they have the MOST minigames but they're all **away-from-station**. DCO's station (the damage board + door panel) is an information/command hub, but the real work is physical. DCO is the role with the most varied moment-to-moment gameplay.

**Fire Extinguishing — Spray & Sweep**
First-person extinguisher aim. Fire has a **source point** in the room (a sparking conduit, a burning console). Spraying the flames at random suppresses them temporarily, but they reignite. The minigame: find and spray the source point directly for a sustained burst to kill the fire permanently. In a smoke-filled room with low visibility, finding the source is the challenge. Larger fires have multiple sources.

**Hull Breach Patching — Weld Trace**
A crack in the hull is venting atmosphere. The minigame: a **weld-tracing game** — follow the breach line with your welding tool, keeping a steady pace. Too fast = weak seal (repressurizes slowly). Too slow = you're breathing vacuum for longer. The breach pulls loose objects toward it and applies a camera drift, making the trace harder. A satisfying "hiss-to-silence" audio payoff when you complete the seal.

**System Repair — Circuit Splice**
Damaged systems show a broken circuit board. The minigame: a quick **pattern-matching puzzle** — a set of broken connections where you pick the right replacement component from 3–4 options and slot it in. Wrong component = sparks, try again. Right component = system back online. More complex systems (weapons, shields) have harder puzzles with more connections.

**Boarder Combat — Melee Timing**
When hostile aliens board, DCO engages them in first-person melee. The minigame: a **timing-based combat loop**. Boarders telegraph attacks with visual/audio cues. Block at the right moment → counterattack window → strike. Miss the block → take damage. Multiple boarders means reading overlapping patterns. Any crew can fight boarders, but DCO has a larger block window and hits harder.

**Door Control — Strategic (no minigame)**
Door control at the damage board is strategic, not dexterous: toggle doors open/closed on a ship schematic. No minigame — the skill is in the DECISION (which rooms to vent, when to seal, how to funnel boarders). This is DCO's "passive" activity: standing at the board, managing doors, reading the ship status, while other crew handle things. The moment something goes wrong, DCO drops the board and sprints.

**Triage Priority (meta-game)**
Not a minigame but DCO's core skill expression: the ship has 3 fires, 2 breaches, and a boarder simultaneously. You can only fix one at a time. What order? Wrong priority = cascade failure. This is what makes DCO feel different from the other roles — they're not mastering one minigame, they're context-switching between many under extreme time pressure.

| Activity | Mode | Effectiveness |
|----------|------|---------------|
| Door control | Station (strategic) | Immediate, decision-based |
| Fire extinguishing | Away (spray & sweep) | Must find source, 5–10 sec |
| Breach patching | Away (weld trace) | Precision trace, 8–12 sec |
| System repair | Away (circuit splice) | Pattern match, 5–8 sec |
| Boarder combat | Away (melee timing) | Reaction-based, variable duration |

---

### Sensors / Tactical Minigames

**Scanning — Frequency Tuning**
The main sensor display shows the enemy ship as a silhouette. To reveal room details, the sensors officer **tunes a scanning frequency** — a dial/slider minigame where you match a wandering signal frequency. Lock on and hold = data streams in (room labels, system health, crew positions). The signal drifts, so active tracking is required. Deeper data (weapon charge timers, exact HP values) requires holding the lock longer. Getting bumped (ship takes a hit, room shakes) knocks the frequency off and you have to re-tune.

Can only deep-scan one room at a time — choosing WHICH room to scan is the strategic layer. Scan their weapons to warn the pilot? Scan their shields to help the gunner time volleys?

**Target Painting — Lock Assist**
A complementary minigame to scanning: when the sensors officer has a room scanned, they can **paint the target** — a sustained lock that feeds aim-assist data to the gunner's scope. The minigame: keep a bracketing reticle centered on the target room as the enemy ship moves/rotates. While painted, the gunner's tracking minigame gets a tighter reticle and weak point markers appear. If sensors drops the paint (distracted, damaged, leaves station), the gunner's HUD snaps back to raw mode mid-fight.

This is the tightest two-player synergy in the game: sensors paints, gunner fires, and both are playing their respective tracking minigames simultaneously on the same target.

**Hacking — Node Breach**
One use per fight (maybe more with upgrades). A **network infiltration puzzle**: a grid of nodes with firewalls. The sensors officer must connect a path from their entry point to the target system node by rotating/connecting pipe-style tiles, while a timer counts down (enemy countermeasures). Complete the path = target system gets disabled for 10–15 seconds. Fail = hack is wasted. Harder systems (weapons, shields) have more firewalls.

During the hack puzzle, the sensors officer can't scan or paint — they're fully committed. The crew goes blind while the hacker hacks.

**Comms Management — Signal Clarity (when damaged)**
When comms take damage, the sensors officer gets a **signal repair minigame**: an audio waveform display where they adjust filters to clean up the voice signal. Better tuning = clearer voice chat for the crew. Neglected = muffled garbage. This is a low-priority maintenance minigame that competes with scanning and painting for attention.

| Activity | Mode | Effectiveness |
|----------|------|---------------|
| Frequency scanning | Active | Reveals enemy data, requires sustained tuning |
| Target painting | Active | Feeds aim-assist to gunner, tightest synergy |
| Hacking | Full-commit active | Disables enemy system, sensors goes dark during |
| Comms tuning | Low-active maintenance | Keeps voice chat clear when damaged |
| All sensors unmanned | Passive | Basic silhouette only, no data, no paint, no hack |

---

### Universal Minigames (any crew can do these)

These minigames aren't role-specific — anyone can perform them, but they pull players away from their station.

| Minigame | Trigger | How it works |
|----------|---------|-------------|
| **Fire stomping** | Fire in a room, no extinguisher | Rapid input mashing to stomp out flames. Much slower than DCO's extinguisher. Desperation option |
| **Emergency repair** | Damaged system, no DCO available | Simplified circuit splice — fewer options, slower. Any crew can attempt it but takes 2x as long as DCO |
| **Melee combat** | Boarders in your room | Same timing-based combat as DCO, but smaller block window and less damage. You CAN fight, but you'll get hurt |
| **Manual door** | Doors system offline | Walk to a door, hold interact to manually crank it open/closed. Slow and physical vs DCO's instant remote toggle |
| **O2 valve** | O2 system damaged | Manual valve turn in the O2 room — a rotation input to maintain air flow. Keeps crew alive but someone has to babysit it |

---

### The Attention Economy (how it all fits together)

```
CALM PHASE (between jumps):
  Everyone at station → passive mode is fine → plan, chat, shop, upgrade
  Minigames: none active. Strategic decisions only.

EARLY COMBAT:
  Everyone at station, playing their primary minigame
  Pilot: dodging singles       ░░▓▓░░░░░░  (low pressure)
  Gunner: tracking + charging  ░░▓▓░░░░░░
  Engineer: steady load        ░░▓░░░░░░░
  DCO: watching board          ░░░░░░░░░░  (idle, waiting)
  Sensors: scanning            ░░▓▓░░░░░░

MID COMBAT (things go wrong):
  Pilot: chained dodges + FTL  ░░▓▓▓▓▓▓░░  (splitting attention)
  Gunner: torpedo load trip    ▓▓▓▓▓▓░░░░  (away from scope)
  Engineer: overclock + spike  ░░▓▓▓▓▓▓▓░  (riding the redline)
  DCO: fire + breach           ▓▓▓▓▓▓▓▓░░  (sprinting)
  Sensors: paint + scan swap   ░░▓▓▓▓▓░░░  (juggling targets)

LATE COMBAT (everything is on fire):
  Pilot: dodge spam + FTL hold ▓▓▓▓▓▓▓▓▓▓  (maxed out)
  Gunner: volley timing crunch ▓▓▓▓▓▓▓▓░░  (one shot to end it)
  Engineer: blown breaker!!    ▓▓▓▓▓▓▓▓▓▓  (away repairing fuse)
  DCO: 3 fires + boarder      ▓▓▓▓▓▓▓▓▓▓  (triage nightmare)
  Sensors: hacking (all-in)    ▓▓▓▓▓▓▓▓▓▓  (crew is blind)
  EVERYONE: doing someone else's minigame badly because their
            station is on fire and they need to stomp it out
```

The friendslop magic: in late combat, everyone is failing at multiple things simultaneously, yelling about it, and somehow pulling through (or not). Nobody has enough hands. The minigames ensure that "helping" means physically going somewhere and doing a thing — not clicking a button.

---

## Shared Ship Simulation (cross-role physical coupling)

The ship is one physical object. Every action any player takes propagates through the hull to everyone else. This is what makes it feel like you're all on the same vessel rather than playing five separate minigames in parallel.

### Movement & Inertia

**Pilot dodge → everyone feels it.**
When the pilot taps a dodge, the entire ship lurches. Every other player's viewport jolts in the corresponding direction:
- **Gunner:** targeting reticle jerks off-target. A dodge mid-aim can ruin a carefully held torpedo lock. Gunner learns to anticipate dodges, or yells "HOLD STEADY" before a critical shot
- **Engineer:** power board breakers physically rattle. An overclock riding the redline might get jostled past the blowout threshold. A dodge at the wrong moment blows a fuse
- **DCO:** weld trace jerks sideways — a steady weld becomes a jagged line. Repair puzzle components shift in their slots. Mid-repair dodge = fumble and restart
- **Sensors:** scanning frequency jumps off-lock. Target paint bracket slides off the room. Deep scan progress resets partially
- **Walking crew:** anyone in a corridor staggers. Heavy dodge while sprinting = stumble and fall (brief recovery animation). Running toward a fire and the pilot dodges — you eat floor

**FTL jump → massive lurch.** Everything unsecured slides. Crew not braced (holding interact on any console or wall handle) stumble hard. The smart crew braces when the pilot calls "JUMPING." The chaotic crew faceplants.

### Weapons Fire Feedback

**Your own weapons firing shakes the ship too — just differently.**

- **Torpedo launch:** deep THUNK reverberates through the hull. Brief directional vibration from the weapons bay side. Gunner feels it as satisfying recoil. Pilot feels it as a slight drift (torpedo exhaust pushes the ship). Engineer sees a power spike on the weapons bus
- **Beam weapon sustained fire:** constant low hum and vibration across the ship. Lights in nearby rooms dim slightly (power draw). The beam's direction creates a subtle rotational torque — pilot's drift indicator pulls toward the beam side
- **Energy weapon volley:** rapid staccato jolts. Quick and light but frequent. A full volley sounds and feels like a jackhammer through the deck plating

### Damage Propagation

**Hits aren't just numbers — they're physical events that cascade.**

- **Missile impact on shields:** dull thud, moderate ship-wide shake, shield shimmer visible through portholes. Everyone feels it but nothing breaks
- **Missile impact on hull (shields down):** SLAM. Heavy shake, lights flicker, sparks shower from the nearest conduit. The hit room takes direct damage, but adjacent rooms get secondary effects:
  - Adjacent system consoles flicker (brief input lockout — 0.5 sec of "the screen just went static")
  - Loose objects (tools, components) slide across the floor toward the impact point
  - Crew in adjacent rooms stumble
- **Critical hull hit (low HP):** structural groan sound. The ship's ambient hum changes pitch. Lighting shifts to emergency red in the hit section. Permanent slight tilt to the floor in damaged areas (subtle but disorienting over time)

### Environmental Systems as Felt Experience

**O2 isn't a number — it's breathing.**
- High O2: normal. No effect
- Low O2 in your room: screen edges start to vignette. Audio gets muffled (your ears are ringing). Movement slows. Minigame precision drops (reticles drift more, puzzle pieces are harder to select). You FEEL the suffocation through gameplay degradation, not a health bar
- No O2: screen goes grey at the edges, heavy breathing audio, movement is a stumble-walk. You can still act but everything is worse. 15 seconds until blackout

**Fire isn't a status icon — it's in your face.**
- Fire in your room: heat shimmer on screen, smoke particles reduce visibility, ambient temperature audio (crackling, roaring). Minigame UIs physically distort from heat haze. The fire extinguisher minigame is hard BECAUSE the fire is obscuring your vision
- Fire in adjacent room: smoke seeps under the door. You smell it before you see it (audio cue: distant crackling). If the door opens, smoke floods in

**Hull breach isn't a status — it's wind.**
- Breach in your room: sustained directional pull toward the breach. Camera drifts. Loose objects fly toward the hole. Audio is a roaring wind that drowns out voice chat (even external Discord can't compete with the game's audio design drowning out context). The weld-trace minigame is hard because the camera won't stay still
- Breach in adjacent room (door open): lighter pull, wind sound, temperature drop (visible breath condensation on screen)

### Power as Light and Sound

**The engineer's power decisions are visible and audible everywhere.**

- Full power: rooms are brightly lit, consoles hum steadily, systems respond snappily
- Low power: lights dim to emergency amber, consoles flicker, system response has a slight input lag (50–100ms added). Not enough to feel unfair but enough to feel WRONG
- System powered down: room goes dark. Console screens die. Emergency floor strips provide minimal navigation light. A powered-down room feels abandoned and dangerous
- Overclock: lights in the overclocked system's room pulse brighter than normal. A high-pitched electrical whine builds. Everyone near that room hears it — "the engineer is pushing weapons hot." If it blows, the lights pop and the room goes dark with a bang
- Brownout: a random system flickers for 1–2 seconds. Its room's lights stutter. Anyone using that system's minigame gets a brief screen static burst. The pilot mid-dodge feels the engines hiccup. The gunner mid-lock sees the scope flicker. The engineer just made an enemy

### Cross-Role Cascade Examples

These aren't scripted events — they emerge naturally from the simulation coupling:

**"The Torpedo Fumble"**
Gunner is loading a torpedo (sliding the alignment pins). Pilot dodges a missile → ship lurches → torpedo slides off the rack → gunner has to re-grab and re-align. Gunner: "STOP DODGING." Pilot: "STOP ASKING ME TO DIE."

**"The Dark Repair"**
DCO is in the engine room doing a circuit splice. Engineer cuts power to engines to prevent a brownout cascade. Engine room goes dark mid-puzzle. DCO can barely see the circuit board. DCO: "WHO KILLED MY LIGHTS." Engineer: "SHIELDS NEEDED THE POWER." DCO finishes the repair by feel. Engineer restores power. Engines come back brighter than before (fresh repair bonus).

**"The Suffocation Lock"**
Hull breach in O2 room → O2 drains → engineer's room (adjacent) starts losing air → engineer's precision on the power board degrades from O2 deprivation → brownouts start happening → pilot loses engine power mid-dodge → ship takes a hit → MORE damage → DCO is trying to patch the O2 breach but the camera keeps drifting from decompression AND jolting from impacts. One repair fixes the cascade, but getting there alive is the challenge.

**"The Friendly Fire Hold"**
Sensors paints a target, gunner has perfect lock, gunner calls "HOLD STEADY." Pilot stops dodging. Beam weapon fires — sustained vibration and rotational torque drift the ship. Gunner is tracing a perfect 4-room cut across the enemy. Meanwhile, the ship is eating every incoming shot because the pilot isn't dodging. Impacts shake the beam trace off course. Gunner gets 3 rooms instead of 4. Pilot resumes dodging. Everyone alive. Barely.

### Implementation Note (Godot)

All of this runs through a single **ShipPhysicsState** that every player's local client reads:
- Ship acceleration vector (from pilot inputs + weapon recoil + breach decompression)
- Per-room environment state (O2 level, temperature, light level, smoke density)
- Vibration/shake events (queued with source position, intensity, duration, falloff by distance from source room)

Each client applies the shared state to their local camera, UI, and minigame parameters. The server owns the state; clients render the consequences. No desyncs because everyone reads the same physics — they just experience it from different rooms.

---

## Fog of War & Communication

The key friendslop ingredient: **restricted information + degrading comms**.

### Vision
- Each player only sees their room + adjacent rooms (unless sensors are manned)
- Fire, breaches, and boarders in distant rooms show as WARNING icons, not details
- Sensors room reveals everything — but someone has to stand there instead of doing something useful

### Voice Comms (the Comms system)

Voice chat is a **ship system**, not a free Discord overlay.

| Comms State | Effect |
|-------------|--------|
| **Fully powered** | Shipwide voice — everyone hears everyone clearly, plus a ping/marker system on the ship map |
| **Damaged** | Proximity voice only — you hear crewmates in your room and adjacent rooms. Distant voices are muffled/garbled. No pings |
| **Destroyed** | Proximity voice only, heavily muffled even at close range. You're basically pantomiming |
| **Manned** | Comms officer gets a text-ping system even when damaged (can send short canned alerts: "FIRE", "BOARDERS", "HELP", room name) |

**Why this works:** In calm moments, the crew coordinates easily — shipwide voice is free. When combat heats up and the enemy knocks out comms, coordination collapses at the exact moment you need it most. The player in the burning engine room is screaming but nobody can hear them. Someone has to choose: do I fix comms, or do I fix shields?

**Nebula hazard:** Comms are always degraded in nebula sectors. The whole sector becomes a communication nightmare.

**Design intent:** Players will naturally use Discord/external voice. That's fine — the in-game comms layer adds *friction and fog*, not a total blackout. Even if players talk on Discord, they lose the ping system, the auto-markers, and the "who's where" HUD that comms provides. The game is harder without comms, not impossible. External voice becomes a crutch that works but doesn't fully replace the system.

---

## Star Map & Encounters

Sector map is FTL-style: branching nodes, rebel fleet advancing from behind.

**Node types:**
- **Combat** — enemy ship fight (real-time)
- **Event** — text encounter with choices (crew votes, majority wins, captain breaks ties)
- **Shop** — spend scrap on upgrades, repairs, fuel, weapons
- **Hazard** — asteroid field, nebula (sensors disabled), ion storm (systems flicker)
- **Distress** — risk/reward side encounters

**Between sectors:** difficulty ramps, new enemy types, environmental hazards.

---

## Combat Flow (3D spatial)

1. **Contact:** Enemy ship drops out of FTL or emerges from behind an asteroid. The pilot sees it appear in their third-person view. First-person crew near windows catch a glimpse — a shape in the void, engines glowing. Alert klaxon fires
2. **Stations:** Crew sprints to their posts. The pilot is already reading the enemy's approach vector and rotating the ship to present the best weapon arcs. The engineer is spinning up power allocation
3. **Engagement range:** The two ships close in 3D space. The pilot maneuvers for positioning — trying to keep the enemy in the gunner's best firing arc while presenting the ship's strongest armor/shielding toward incoming fire. The enemy AI does the same
4. **Exchange of fire:** Turrets track independently, the gunner aims through their turret cam, bolts and missiles cross the gap in real 3D with travel time and arcs. The pilot dodges — the ship lurches — the gunner's view swings. Shield impacts flash across both ships' hulls, visible from inside through windows
5. **Damage cascade:** Enemy hits punch through shields into specific hull sections. The room shakes, systems break, fires start, atmosphere vents. DCO is sprinting. Through a corridor window, a crewmate sees a chunk of their own hull plating tumbling away into space
6. **Escalation:** Boarders dock against the hull — a CLANG reverberates through the ship, then cutting sounds from a specific direction. The breach alarm tells you WHICH room they're cutting into. DCO and any available crew converge
7. **Resolution:** Destroy the enemy ship (it visibly breaks apart — the pilot watches the explosion, the crew sees the flash through windows) or charge FTL and jump away (the pilot initiates, the ship lurches into the jump, stars streak past every viewport)

**No pause. No slow-mo.** 60–90 second fights that feel like 5 minutes. The pilot sees the battle. The crew feels it.

---

## Resources

| Resource | Source | Use |
|----------|--------|-----|
| Scrap | Combat wins, events | Buy upgrades, fuel, repairs at shops |
| Fuel | Shops, events | 1 per jump — run out and you're stranded |
| Missiles | Shops, events | Consumed per missile weapon shot |
| Hull HP | — | Ship dies at 0. Repaired at shops |

---

## Impact & Juice

The ship should feel like a physical place that's falling apart around you.

### Screen Shake & Vibration
- **Enemy hits:** Camera shake scaled to damage severity. Light weapons = quick jolt. Missiles = heavy sustained rumble
- **Controller haptics:** Rumble on impacts, with intensity matching damage. Constant low vibration when hull is critical
- **Nearby explosions:** Stronger shake when damage hits a room you're in or adjacent to. Distant hits are a dull thud
- **Hull breach:** Sustained directional shake pulling toward the breach (decompression feel)
- **FTL jump:** Build-up vibration → slam → silence

### Environmental Feedback
- **Lights flicker** when power is unstable or systems take damage
- **Sparks and particle debris** in damaged rooms
- **Screen tilt/sway** in asteroid fields
- **Audio ducking** — sounds muffle when O2 is low in your room (you're suffocating)
- **Heartbeat overlay** at low crew HP

The goal: every hit the ship takes should make the whole crew flinch at the same time. Shared physical dread is peak friendslop.

---

## Multiplayer Architecture (Godot)

- **Networking:** Godot's built-in multiplayer (ENet or WebRTC for browser builds)
- **Authority:** Server-authoritative ship state (HP, systems, resources). Client-authoritative movement (player position in ship)
- **Sync:** Ship systems, combat state, enemy AI → server. Player position, input → client
- **Lobby:** Host creates run, friends join via code. Drop-in mid-run as replacement crew (stretch)

---

## MVP Scope (Prototype)

1. One ship with 4 rooms (weapons, shields, engines, medbay)
2. 2 players, online multiplayer
3. One combat encounter (enemy shoots, players man stations)
4. Basic fog of war (see your room + adjacent)
5. Win/lose condition (destroy enemy or die)

**Not in MVP:** Star map, shops, events, roles, full system list, progression.

---

## Stretch Goals

- Ghost mechanic (dead players can interact with ship as poltergeist — flickering lights, nudging doors)
- Traitor mode (one crew is secretly sabotaging the ship)
- Ship customization between runs (persistent unlock track)
- Cross-ship PvP (two crews, two ships, fight each other while managing their own chaos)
- Browser build via WebRTC for zero-friction friend onboarding
