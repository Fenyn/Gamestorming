# End of the Line

A logistics incremental game with sentient trains. Buy builders to expand your rail network and trains to deliver goods. Trains develop personalities across a 3-day time loop.

**Engine:** Godot 4.6 (3D)
**Assets:** Kenney Train Kit (100 pieces, CC0)
**Genre:** Incremental / Idle + Logistics
**Inspirations:** Gnorp Apologue, Berry Bury Berry, Mini Metro

---

## Core Loop

```
Buy builders → builders auto-expand network toward new nodes
Buy trains → trains auto-deliver goods between connected nodes → Gold
Gold → more builders, more trains, upgrades
3 in-game days pass → RESET (prestige) → Tickets → permanent unlocks → new loop
```

**Primary resource:** Gold (earned per delivery)
**Prestige resource:** Tickets (earned at loop reset)

---

## Two-Layer Gnorp System

### Layer 1: Builders (Infrastructure Gnorps)

Builders autonomously expand the rail network. You buy them, they decide where to build. No player micro-control.

| Builder | Method | Trade-off |
|---------|--------|-----------|
| **Track Layer** | Straight toward nearest node | Fast, inefficient routes |
| **Pathfinder** | Finds optimal route | Slower, efficient connections |
| **Bridge Crew** | Crosses water/gaps | Unlocks isolated nodes |
| **Tunnel Borer** | Through mountains | Shortcuts, slow construction |
| **Upgrader** | Improves existing track | Faster trains on upgraded segments |

**Upgrades:** Speed, count, quality of laid track.

**Player choice:** Rush expansion (Track Layers) vs efficient routes (Pathfinders) vs upgrade existing income (Upgraders).

Builders are utilitarian. No personalities. The infrastructure gnorps.

### Layer 2: Trains (Delivery Gnorps)

Trains auto-deliver goods on whatever network exists. They choose their own routes. You buy types, they figure out the rest.

| Train Type | Speed | Capacity | Behavior |
|-----------|-------|----------|----------|
| **Handcar** | Slow | Tiny | Free starter. Short routes. |
| **Steam Loco** | Medium | Medium | Balanced, any route. |
| **Freight** | Slow | Huge | Prefers bulk (mine→factory). |
| **Express** | Fast | Small | Prefers long, high-value routes. |
| **Tanker** | Medium | Large | Liquid cargo specialist. |
| **Mail Runner** | Very Fast | Tiny | Short routes, many trips/min. |
| **Diesel** | Fast | Large | Mid-game workhorse. |
| **Electric** | Fastest | Medium | Only upgraded track. |

**Upgrades:** Speed, capacity, efficiency, fleet size (all per-type).

Trains have PERSONALITY. They develop. This is where the game's soul lives.

---

## The Network (The "Rock")

Starts as a small pre-set network. Map shows many unconnected nodes visible from the start. Creates desire: "I need builders to reach THAT port."

| Node Type | Role |
|-----------|------|
| **Mine** | Produces ore, coal, gems |
| **Farm** | Produces food, grain |
| **Factory** | Converts raw materials → goods |
| **Town** | Consumes food + goods, pays Gold |
| **Port** | Exports anything at premium |
| **Depot** | Rests/maintains trains |

---

## Sentient Trains — "They Remember"

Trains develop personality because they remember fragments of previous loops.

**Within a loop:** Trains are just trains. Run routes, deliver goods.
**Between loops:** Some trains persist as veterans. They retain traits.

**Traits (accumulated across loops):**

| Trait | How it forms | Effect |
|-------|-------------|--------|
| **Mountaineer** | Hill routes | +speed on mountains |
| **Foodie** | Food deliveries | +efficiency on food, -on ore |
| **Speedster** | Express type last loop | +speed always |
| **Homebody** | Same route 3+ loops | Massive bonus on THAT route |
| **Social** | Bonded with another train | +bonus near that train |
| **Lone Wolf** | Solo routes | +bonus when alone |
| **Old Hand** | 5+ loops survived | Buffs nearby trains |

**Bonds:** Trains that share routes across loops develop bonds. Sync timing, speed bonuses. Only exists if BOTH return.

**Moods (subtle, never labeled):**
- Veteran on preferred route: slightly faster, cheerful steam
- Veteran on wrong route: slightly slower, hesitant
- New train: no variation — just a machine

**The quiet weird:** The game never says trains are alive. You just notice Train B always arrives early on THAT route. Late game: trains make tiny track improvements on their own.

---

## Prestige — The 3-Day Time Loop

You have 3 in-game days. Then everything resets. The timer is always visible.

**Pacing:** 3 days = ~10-15 real-time minutes per loop (TBD, tunable).

**The tension:**
- Clock always ticking
- "Day 2 evening — haven't reached the port, invest in builders NOW?"
- Creates urgency without invisible meters

**What resets:** Network, trains, Gold
**What persists:** Tickets, unlocked types, permanent bonuses, veteran trains

**Ticket shop:**
- New train/builder types
- Starting bonuses (Gold, pre-built track)
- Speed upgrades (do MORE in 3 days)
- More map nodes
- Veteran slots

**Loop progression:**
- Loop 1-3: Scrambling, barely get going before reset
- Loop 4-8: Comfortable, build efficient networks in 3 days
- Loop 10+: Mastery, optimizing every hour

---

## Veteran System (Loop Persistence)

At loop end, the train with most experience survives. Keeps all traits.

**Mechanic:**
- Start with 1 veteran slot (upgradeable)
- Most-experienced train persists across reset
- Next loop: it's already at the depot, Day 1 morning. Waiting. It knows.
- Over many loops: build roster of experienced, named, personality-rich trains

**Emotional hook:** You have favorites. Old Smokey, 12 loops deep, knows every route.

---

## Tone — "Time Loop Logistics"

Cozy, warm, a tinge of mystery. Groundhog Day meets model trains.

**Visual:** Kenney's toylike 3D. Overhead/isometric. Day/night cycle. Veterans visually weathered.
**Sound:** Each veteran develops a unique whistle. Day 1 morning station bell. Day 3 clock ticking.

**Light narrative (unfolds over loops):**
- Loop 1: "Welcome. You have 3 days."
- Loop 5: "Train 7 seems to know this route already."
- Loop 10: Environmental details persist across resets.
- Loop 20+: Hints at WHY. Never fully explained.

**The hooks:**
- "One more loop — almost connected the whole map"
- "Smokey needs two more loops for Old Hand trait"
- "If I unlock Express, I can reach the Port by Day 2"
