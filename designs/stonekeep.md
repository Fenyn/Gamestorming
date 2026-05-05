# Stonekeep

A settlement incremental game. Buy workers to auto-gather resources, spend resources to expand your keep from campfire to citadel. Survive as many winter days as you can before the cold destroys everything.

**Engine:** Godot 4.6 (2.5D or top-down)
**Assets:** Kenney Retro Fantasy Kit (100 pieces, CC0)
**Genre:** Incremental / Idle + Settlement Builder
**Inspirations:** Gnorp Apologue, Age of Empires, Banished

---

## Core Loop

```
Buy workers → workers auto-gather resources from the land
Spend resources → build/upgrade the keep → unlock better workers/buildings
Spring → Summer → Fall → WINTER (survival) → keep falls → Crown Points → rebuild
```

**Primary resources:** Wood, Stone, Wheat, Ore, Gold
**Prestige resource:** Crown Points (earned based on keep tier + winter days survived)

---

## The Land (The "Rock")

Resource nodes surrounding the keep. Workers harvest from them. Nodes never deplete (this is an incremental, not survival).

| Node | Resource | Worker Type |
|------|----------|-------------|
| **Forest** | Wood | Woodcutters |
| **Quarry** | Stone | Miners |
| **Fields** | Wheat | Farmers |
| **Iron Vein** | Ore | Prospectors |
| **River** | Fish/Water | Fishers |
| **Gold Deposit** | Gold | Panners (mid-game unlock) |

---

## Worker Types (The Gnorps)

You buy workers. They auto-gather. Each type harvests a different resource.

**Gatherers:**

| Worker | Resource | Behavior |
|--------|----------|----------|
| **Woodcutter** | Wood | Chops trees, carries logs |
| **Miner** | Stone | Hammers quarry, hauls stone |
| **Farmer** | Wheat | Tends fields, harvests grain |
| **Prospector** | Ore | Digs at iron veins |
| **Fisher** | Fish | Casts lines at river |
| **Panner** | Gold | Sifts river (later unlock) |

**Converters (transform resources):**

| Worker | Input → Output | Effect |
|--------|---------------|--------|
| **Mason** | Stone → Building progress | Constructs keep upgrades |
| **Smith** | Ore → Tools | Upgrades all workers' efficiency |

**Per-type upgrades:**
- Count (more workers)
- Speed (gather faster)
- Carry capacity (more per trip)
- Tools (smith-made, boosts efficiency)

**Player choice:** Raw gatherers (income NOW) vs converters (delayed but compounding payoff). Mirrors Gnorp's gnorp-types vs infrastructure investment.

---

## The Keep (Visible Progression)

Starts as a campfire. Grows into a citadel. This IS your score and your thing-to-stare-at.

**Building tiers:**

| Tier | Structure | Unlocks |
|------|-----------|---------|
| 1 | Campfire | Starting worker |
| 2 | Hut | Second worker type |
| 3 | Cabin | Third worker, storage |
| 4 | Watchtower | See further nodes, fourth worker |
| 5 | Stockade | Basic defense, slows winter damage |
| 6 | Keep | Mason, Smith, fifth worker |
| 7 | Castle | All workers, advanced buildings |
| 8 | Fortress | Prestige-tier bonuses |
| 9 | Citadel | End-tier, massive |

Each tier is visually distinct. Watching it grow is the primary reward.

**Side buildings (unlocked at various tiers):**
- **Storehouse** — resource cap increase
- **Barracks** — defenders (slows winter attacks)
- **Workshop** — auto-upgrades worker tools
- **Market** — converts between resource types
- **Library** — permanent bonuses (persist through winter)
- **Granary** — stockpiles food for winter
- **Hearth** — cold resistance

---

## Prestige — The Seasons

Three seasons to grow. Then Winter kills everything.

**The Year:**

| Season | Days | What happens |
|--------|------|-------------|
| **Spring** | 1-3 | Land thaws. Workers emerge. Slow start. |
| **Summer** | 4-8 | Peak production. Keep grows fast. |
| **Fall** | 9-11 | Resources slow. Final push. Stockpile. Prepare. |
| **Winter** | 12+ | Cold. Wolves. Damage. Survival mode. |

**Winter is infinite and escalating:**
- Day 1-3: Light cold. Workers slow. Minor wolf attacks.
- Day 4-7: Blizzards. Workers freeze. Wolves hit harder.
- Day 8-12: Structural damage. Keep crumbles. Food runs out.
- Day 13+: Total collapse.

**How long you survive Winter = your score.**

**Crown Points based on:**
- Keep tier reached
- Winter days survived
- Total resources gathered
- Buildings completed

**What resets:** Keep (campfire), workers, resources, buildings
**What persists:** Crown Points, unlocked types, Library bonuses, knowledge

**Crown Points shop:**
- Unlock worker types
- Permanent gathering bonuses
- Start at higher keep tier
- Unlock buildings (Barracks, Granary, Hearth)
- Better winter tools (thicker walls)
- Fall-specific buildings (auto-stockpile)

---

## The Key Tension

**Growth vs defense.** Every resource spent on walls ISN'T spent on the keep.

- Calendar always visible. You SEE winter approaching.
- "It's Fall and I'm only Stockade — not enough time for Castle"
- "Do I build Barracks (survive longer) or push for one more keep tier (more Crown Points)?"

**Each year, Winter is harsher:**
- Year 1: Mild. Survive 5-8 days.
- Year 5: Harsh. Optimized player does 10-12 days.
- Year 10+: Brutal. Only fully prepped keeps last past 15.

You get better tools, but Winter gets worse. Escalating challenge.

---

## Tone — "Prepare for Winter"

Cozy settlement builder with tense inevitable destruction. The joy is in building. The drama is in winter.

**Visual:**
- Retro fantasy pixel-style (Kenney kit)
- Keep growing tier by tier
- Workers bustling, carrying, hammering
- Seasonal color shifts: green → gold → orange → white/dark
- Winter wolves at map edges, creeping closer

**Sound:**
- Spring: birdsong, gentle winds
- Summer: hammering, bustling
- Fall: wind picking up, urgency
- Winter: howling wind, wolf howls, cracking stone

**The hooks:**
- "Mid-summer, almost at Keep — if I push I'll make Castle before fall"
- "Build Barracks or push one more tier?"
- "Last year: 8 winter days. This year with Granary: maybe 12."
- "One more year → unlock Smiths → everything changes"
