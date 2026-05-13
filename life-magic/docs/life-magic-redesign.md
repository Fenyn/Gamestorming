# Life Magic Redesign — Core Design Document

## Status: DRAFT — Lore and systems architecture locked. Specific names, numbers, and content TBD.

---

## Vision

A heartbeat-driven incremental factory game. You are a life mage pursuing immortality by constructing magical apparatus on a workbench, processing life mana into increasingly refined fluids, and installing completed augmentations into your own body.

Your real heart rate is the game's only input pump. The factory pulses with you.

---

## Core Identity (Locked)

These are non-negotiable:

- **Heart rate is the core driver.** Every heartbeat pumps life mana into the workbench. Higher HR = more pressure and throughput. This is the only input.
- **Incremental factory gameplay.** The player designs processing chains on a 2D grid — routing, splitting, mixing, storing, and refining fluids. Depth comes from throughput optimization, ratio balancing, and bottleneck solving.
- **Life mage lore.** A wizard pursuing immortality through self-augmentation. Dark but fascinated, not grimdark. Clinical curiosity, not horror.
- **Variable input is the unique mechanic.** Unlike any factory game, the input rate fluctuates 1-3x based on real physical activity. The factory must handle a throughput range, not a constant. This is the core design challenge that no other game in the genre has.
- **HR zones are strategic, never forced.** Different pressure levels favor different apparatus. Resting is productive (low-pressure processing). Active is productive (high-pressure processing). The factory's output profile *shifts* with HR rather than just scaling.
- **Health data is never stored.** Instantaneous values only, then discarded.
- **Mobile-first.** Portrait orientation, touch interaction, clean grid placement.

---

## The Workbench (Play Space)

The main game screen. A 2D grid viewed from above — the mage's magical workbench.

### Layout
- Dark surface with subtle magical grid lines
- The **Heart** is fixed at the bottom-center, pulsing with real HR
- Apparatus placed on grid cells
- Conduits (glowing tubes) connect apparatus, auto-routed orthogonally
- Grid size TBD — starts small, expandable through progression

### Interaction
- **Place:** Tap empty cell, select apparatus from inventory bar
- **Connect:** Drag from one apparatus to another, conduit auto-routes
- **Configure:** Tap apparatus to open detail panel (ratios, stats, upgrades)
- **Rearrange:** Long-press to pick up and move, conduits reroute automatically
- **Zoom:** Pinch to zoom if workbench grows beyond screen

### Pressure System
- Pressure originates at the Heart, driven by real HR
- Decreases with conduit distance (measured in hops, not diagonal)
- Each apparatus type has a pressure profile — some need high pressure to activate, some need low pressure, some work at any level
- High HR raises base pressure, activating more apparatus and increasing throughput
- Low HR lowers base pressure, favoring calm/slow-process apparatus
- Backpressure occurs when downstream apparatus can't consume fast enough — visually communicated, mechanically consequential

---

## Fluid System

### Design Principles
- Multiple fluid types processed from a single raw input (Life Mana)
- Each base fluid requires different pressure conditions to produce — creating natural HR-based variety
- Fluids can be mixed to create higher-tier products — ratio-sensitive
- Fluids can be enriched through multi-pass processing — quality vs. quantity tradeoff
- The number, names, colors, and specific recipes are TBD

### Structure (To Be Defined)

**Raw Input:**
- Life Mana — pumped by the heart, one pulse per beat

**Base Fluids (3-4 types):**
- Each produced by a different apparatus type from Raw Mana
- Each requires different pressure conditions (high / medium / low)
- Each has a distinct color for visual identification in conduits
- Conversion ratios TBD

**Mixed Fluids:**
- Produced by combining two base fluids in a mixing apparatus
- Ratio of inputs affects the output — not just "combine A+B" but "combine A+B at what proportion"
- Number of possible mixes = combinatorial based on base fluid count
- Specific mixes, names, and colors TBD

**Enriched Fluids:**
- Any fluid passed through a refinement apparatus multiple times
- Each pass increases quality but reduces volume
- Needed for late-game research and augmentations
- Enrichment tiers/mechanics TBD

**Endgame Fluids:**
- Complex multi-stage products requiring multiple base fluids, mixing, and enrichment
- Specifics TBD — should represent the peak challenge of factory design

---

## Apparatus (Factory Buildings)

### Design Principles
- Each apparatus transforms, stores, or routes fluid
- They are magical organs/devices — fleshy, arcane, alive-feeling, not industrial
- Each has distinct visual identity and animation reflecting its function
- Pressure requirements create placement tension (can't put everything near the heart)
- Unlock order provides natural progression from simple chains to complex networks

### Categories (Specific Apparatus TBD)

**Processors:**
- Transform one fluid type into another
- Each has a pressure profile (high/medium/low requirement)
- Each has a conversion ratio (input:output)
- Some only activate above/below a pressure threshold

**Mixers:**
- Accept two (or more) fluid inputs
- Output depends on input types and ratios
- Ratio sensitivity creates the balancing puzzle

**Refinement:**
- Multi-pass processing — fluid loops through for enrichment
- Quality vs. volume tradeoff
- Loop management (backpressure risk from recirculation)

**Storage:**
- Buffer fluid to smooth out variable HR throughput
- Absorb surges during high HR, release during low HR
- Visible fill level
- Finite capacity

**Flow Control:**
- Splitters — divide flow at player-set ratios
- Valves — player-controlled routing direction
- Pressure modifiers — boost or reduce pressure downstream
- Overflow protection — dump excess before backpressure cascades

**Filtering/Separation:**
- Reverse a mix — separate combined fluids back into components
- Expensive/lossy but allows correction and recycling

### Unlock Progression
- Player starts with the Heart and 2-3 basic apparatus
- Research unlocks new apparatus types progressively
- Each unlock expands what the factory can produce
- Specific unlock order TBD — should follow the principle that each new apparatus enables a new production chain or solves a new problem

---

## Research Tree (Progression Driver)

### Design Principles
- Research is the primary sink for produced fluids
- Each research node requires sustained fluid delivery — not an instant purchase, but continuous consumption until complete
- Research unlocks: new apparatus, new recipes, new augmentation slots, workbench expansions
- Tree branches should correspond to different fluid types / production strategies
- Later tiers require more complex fluids, driving factory expansion

### Structure (TBD)
- Number of branches TBD
- Number of nodes per branch TBD
- Specific unlock rewards TBD
- Should be designed so that each tier demands a meaningfully more complex factory than the last

---

## Augmentations (Permanent Upgrades / Install System)

### Concept
Augmentations are the bridge between the workbench (gameplay) and the body (narrative/progression). When research reaches certain milestones, a completed augmentation appears — a finished magical device ready to install.

### Install Flow
- Completed augmentation appears at the workbench edge (or in an inventory)
- Player taps to install
- An install screen or character view shows the mage
- Augmentation applies a permanent effect
- The mage's visual appearance changes to reflect the modification

### Effect Types (Examples — Specific Augmentations TBD)
- Modify heart output (more base pressure, second output path)
- Improve conduit properties (less pressure loss, more throughput)
- Modify apparatus performance (better ratios, lower activation thresholds)
- Expand workbench (more grid space)
- Unlock new apparatus categories
- Change fundamental rules (e.g., second pressure source, inverse-pressure processing)

### Character Progression Visual
- A mage portrait/silhouette visible on screen (small, not the game board)
- Each installed augmentation visibly changes the mage's appearance
- Over time the mage becomes increasingly inhuman — more magical, less mortal
- This is a visual progress tracker and narrative reward

---

## Prestige — Death and Rebirth

### Concept
The mortal body has a limit on how many augmentations it can sustain. When capacity is reached, the body breaks down. The mage dies — but consciousness persists in crystallized essence. Rebirth in a new body, carrying forward knowledge and permanent currencies.

### What Resets
- Workbench layout
- Fluid stocks
- Research progress (partially — TBD how much carries over)
- Apparatus unlocks (partially)

### What Persists
- Prestige currency (earned from lifetime production/complexity/augmentations)
- Augmentation knowledge (can rebuild faster)
- Discovered recipes
- Workbench blueprints (saved layouts that can be re-stamped)

### Prestige Currency Spends (TBD)
- Stronger starting heart
- Starting apparatus unlocks
- New apparatus types only available post-prestige
- Augmentation capacity increase (delay next death)
- Passive bonuses

### Prestige Layers
Each layer of prestige (after N deaths) should introduce a genuinely new mechanic, not just bigger numbers.

**Potential new mechanics to introduce via prestige layers (pick and refine):**
- Synergy bonds between long-running adjacent apparatus
- Timed commissions/orders from other mages
- A second workbench layer operating on inverse pressure (strongest at rest)
- Apparatus evolution based on usage patterns
- Second heart with different properties
- Fluid memory (processing order affects output properties)

Specific layer count, thresholds, and mechanics TBD.

---

## Heart Rate Integration

### Input Sources
- **Demo mode** — tap to raise HR, decays over time (for testing/demo)
- **Simulated** — manual BPM adjustment (debug)
- **WebSocket** — external HR device
- **Wear OS** — HeartLink plugin, real HR + step data

### HR → Pressure Mapping
- Resting HR (~60-75 BPM) produces base pressure level
- Pressure scales with HR up to a cap (age-based max HR safety)
- The specific curve (linear, logarithmic, stepped) is TBD
- Should feel responsive but not twitchy — smoothing applied

### HR Zone Effects on Factory
- Not a mode switch — a continuous pressure gradient
- Low pressure: certain apparatus produce well, others don't activate
- High pressure: different apparatus activate, low-pressure ones may be disrupted or overwhelmed
- A well-designed factory produces *different valuable outputs* at different HR levels
- No HR zone is punished — every zone is productive in its own way

### Vitality (Step/Activity Tracking)
- Earned through sustained activity (steps via Wear OS, or beat accumulation)
- Used as a special currency for specific purchases or unlocks
- Specifics TBD — should integrate without being required (HR alone is sufficient to play)

---

## VFX Principles

The visuals are not decoration — they communicate game state. A player should be able to read their factory's status from the visuals alone.

### Heartbeat Pulse
- Every real heartbeat sends a visible light pulse from the Heart outward through all connected conduits
- Pulse frequency = player's HR. Slow at rest, rapid during exercise.
- This is the game's signature visual — the factory breathing with you

### Fluid Flow
- Fluid visibly moves through conduits — direction, speed, and color all readable
- Flow speed reflects actual throughput
- Empty or starved conduits go dim and still
- Different fluid types have distinct colors

### Pressure Visualization
- High-pressure conduits glow brighter and appear wider
- Low-pressure conduits are dim and thin
- Pressure gradient visible across the whole workbench at a glance

### Apparatus State
- Each apparatus has idle/active/stressed animations
- Active: glowing, bubbling, processing visuals specific to its type
- Inactive (pressure too low/high): dim, still
- Stressed (backpressure): warning visuals — pulsing red, bulging

### Backpressure and Overflow
- Backed-up conduits visually throb or change color
- Overflow produces visible dripping/leaking at connection points
- Communicates problems before the player needs to check numbers

### Mixing
- Two colored fluid streams visibly swirl and blend at mixing apparatus
- Output color derived from input colors and ratios
- The workbench becomes a palette of the player's production choices

### Ambient
- Overall workbench glow reflects total factory activity
- Busy factory during exercise: bright, vibrant, alive
- Resting factory: dim, calm, meditative
- Emotional tone shifts with the player's body

---

## Mobile UX Considerations

- Portrait orientation (target resolution TBD — current project is 420x800)
- Touch-first interaction — no hover states, no right-click
- Grid cells large enough for comfortable tapping
- Auto-routing conduits — player decides connections, game handles pathing
- Detail panels as overlays/bottom sheets, not separate screens
- Apparatus inventory as a scrollable bottom bar
- Minimal text on the workbench — information conveyed through visuals
- Research tree and augmentation install as separate screens/tabs accessible from the workbench

---

## Session Flow (What a Play Session Feels Like)

### At rest (desk, couch)
- Factory runs at low pressure
- Low-pressure apparatus doing their best work
- Calm ambient glow, slow pulses
- Good time to rearrange the workbench, review research, install augmentations

### During exercise
- Pressure rises, factory progressively activates
- High-pressure apparatus come online
- Throughput increases, production accelerates
- Backpressure management becomes relevant — did you design for this throughput?
- The factory visually comes alive — bright, pulsing, flowing

### Post-exercise
- Pressure drops, factory winds down from top
- Stored fluid in reservoirs feeds the network during transition
- Low-pressure apparatus resume
- Player reviews what was produced, makes decisions about next steps

### Key principle
Every session — whether a 5-minute rest check or a 45-minute workout — should feel productive and visually satisfying. The factory is always doing *something*. The character is always progressing toward *something*.

---

## Open Questions

- [ ] Specific fluid types — how many base fluids? What are they called? What colors?
- [ ] Specific apparatus — full list with names, functions, pressure profiles, ratios
- [ ] Research tree structure — how many branches? What does each branch unlock?
- [ ] Augmentation list — what are they, what do they do, what order?
- [ ] Prestige layer specifics — how many layers? What mechanic does each introduce?
- [ ] Workbench grid size — starting size, max size, how expansion works
- [ ] Pressure curve — what math maps HR to pressure?
- [ ] Conversion ratios — what numbers make the factory puzzle feel good?
- [ ] Commisssions/orders system — is this in scope? How does it work?
- [ ] Endgame — what is the final state? Is there a definitive ending?
- [ ] Character portrait — where on screen? How detailed? How does it change?
- [ ] Sound design — heartbeat audio synced to HR? Apparatus sounds? Ambient?
- [ ] Tutorial flow — how does the player learn placement, routing, pressure?
- [ ] Offline progress — how does the factory run when the app is closed?
- [ ] Save system — what state needs to be serialized?
- [ ] Scope of prototype — what is the minimum build to validate the core loop?
