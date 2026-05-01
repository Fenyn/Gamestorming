# Green Bean — Progression & Unlock Design

Two currencies drive progression: **Money** (earned from serving drinks) and **Stars** (earned from drink quality). Money buys equipment and supplies — the physical tools of the trade. Stars represent mastery and unlock equipment upgrades, new shop layouts, and special content. Drink recipes aren't purchased — they unlock automatically when you own the required equipment.

---

## Starting Kit

The player begins with the bare minimum to serve one drink type. Everything else is earned.

| Category | Starting With |
|---|---|
| **Shop** | Espresso Stand (solo) |
| **Drinks** | Pour Over |
| **Sizes** | Small, Medium |
| **Equipment** | Hand grinder, kettle, pour-over station, cup stack, lid dispenser, register, hand-off, counter pad |
| **Syrups** | None |
| **Sauces** | None |
| **Modifiers** | None |

Day 1 is a tutorial in disguise. The player only makes pour-overs, masters the grind → bloom → main pour → draw-down flow, learns to juggle passive brew times, and gets comfortable with the carry/place/interact loop. Simple orders, forgiving customers.

---

## Drink Unlocks — Equipment-Driven

Drink recipes are **never purchased directly**. A recipe unlocks automatically the moment the player owns all the equipment it requires. The player then chooses whether to add it to their active menu between days.

This means the player thinks about equipment, not recipes. "I want to serve lattes" becomes "I need a fridge and a steam station." Buying equipment is the investment; the recipe is the payoff.

### Unlock Map

| Drink | Auto-Unlocks When You Own | New Concept |
|---|---|---|
| **Pour Over** | *starter equipment* | Coarse grind, bloom pour, passive draw-down |
| **Americano** | Aeropress + Hot Water Station | Fine grind, pressure extraction, hot water pour |
| **Macchiato** | Aeropress | Quick espresso-only drink (no water/milk step) |
| **Latte** | Aeropress + Fridge + Steam Station | Milk steaming, foam targets, pitcher workflow |
| **Cappuccino** | Aeropress + Fridge + Steam Station | Same gear as latte — unlocks alongside it. High foam (75%) |
| **Red Eye** | Pour-Over Station + Aeropress | Multi-method drink (pour-over base + espresso shot) |
| **Mocha** | Aeropress + Fridge + Steam Station + Sauce Station + Mocha Prep Station | Sauce bottles, prep phase, bottle management |

Latte and Cappuccino unlock together since they need the same gear. The player picks which to put on the menu. This is a natural "two-for-one" reward for buying the milk setup.

#### Future Drinks (not yet implemented)

| Drink | Equipment Required | New Concept | Notes |
|---|---|---|---|
| **Flat White** | Aeropress + Fridge + Steam Station | Micro-foam precision (~20% foam target) | Tight quality bar, rewards steam mastery |
| **Cortado** | Aeropress + Fridge + Steam Station | Small equal-ratio drink, speed/precision | Fixed small size only |
| **Caramel Macchiato** | Aeropress + Fridge + Steam + Sauce Station + Caramel Prep | Layered build (milk first, shot on top, drizzle) | Reversed build order |
| **Hot Chocolate** | Fridge + Steam Station + Sauce Station + Mocha Prep | No coffee — steamed milk + mocha sauce | Expands customer base |
| **Chai Latte** | Fridge + Steam Station + Chai Shelf | Chai concentrate (new supply type) | New inventory category |
| **Matcha Latte** | Fridge + Steam Station + Matcha Prep Station | Matcha whisking mini-game | New prep station |
| **Cold Brew** | Cold Brew Tower | Overnight batch prep (prep day before) | Time-shifted inventory planning |
| **Frappuccino** | Blender Station + Fridge + Ice Bin | Blending mini-game, ice, whipped cream | Multiple new stations |
| **Affogato** | Aeropress + Ice Cream Freezer | Espresso + ice cream scoop | Fun novelty drink |

### Size Unlocks

Sizes unlock independently and apply to all drinks.

| Size | Price | Effect |
|---|---|---|
| Small | *starter* | Base amounts, base price |
| Medium | *starter* | 1.2x amounts, 1.15x price |
| Large | $60 | 1.5x amounts, 1.3x price |
| Extra Large | $120 | 1.8x amounts, 1.5x price |

Larger sizes mean more time per drink but more revenue. Unlocking XL is a strategic choice — it's high-value but ties up stations longer during rush.

---

## Money Unlocks — Modifiers

### Syrup System

The **syrup rack** is a one-time unlock that enables the whole syrup system. Individual flavors are then purchased separately.

| Unlock | Price | Notes |
|---|---|---|
| **Syrup Rack** (system unlock) | $100 | Adds one pump station slot, enables syrup orders |
| Vanilla | $40 | First flavor, most common |
| Caramel | $40 | |
| Hazelnut | $50 | |
| Toffee Nut | $50 | |
| Additional Syrup Station | $75 | Second pump slot (faster workflow) |

**Future syrups:** Peppermint (seasonal), Raspberry, Lavender, Brown Sugar, Sugar-Free Vanilla.

Each syrup unlocked increases the chance customers request it. More variety = more modifiers flying around = more complexity.

### Sauce System

Sauces require their own prep infrastructure. The first sauce unlock bundles the prep station.

| Unlock | Price | Notes |
|---|---|---|
| **Sauce Station** (system unlock) | $125 | Drizzle station + 3 empty bottles |
| **Mocha Prep Station** | *bundled with Mocha drink* | Jug + powder bag workflow |
| Mocha Sauce | *bundled with Mocha drink* | First sauce, required for Mocha recipe |
| **Caramel Prep Station** | $100 | Sleeve squeeze workflow |
| Caramel Sauce | $60 | Modifier for any drink |
| White Mocha Sauce | $75 | Modifier for any drink |
| **Bottle Rack** | $50 | 3-slot organized bottle storage |
| Extra Sauce Bottles | $30 each | Start with 3, buy more for buffer |

**Future sauces:** Dark Caramel, Pumpkin (seasonal), Pistachio.

---

## Money Unlocks — Base Equipment

Money buys the base tier of every station and tool. This is how the player expands their shop's capability — more equipment means more drinks auto-unlock and more customers can be served.

### Station Purchases

| Station | Price | What It Enables |
|---|---|---|
| **Grinder** (hand) | *starter* | Grinding beans (coarse/fine) |
| **Pour-Over Station** | *starter* | Pour-over brew method |
| **Kettle** | *starter* | Hot water for pour-over and americanos |
| **Cup Stack** | *starter* | Cup supply |
| **Lid Dispenser** | *starter* | Lids for all drinks |
| **Register** | *starter* | Taking orders |
| **Hand-Off Counter** | *starter* | Serving completed drinks |
| **Counter Pad** | *starter* | Staging area (4 slots) |
| **Aeropress** | $100 | Espresso extraction → unlocks Americano, Macchiato |
| **Hot Water Station** | $50 | Hot water for americanos → completes Americano unlock |
| **Fridge** | $75 | Milk storage |
| **Steam Station** | $125 | Milk steaming → with Fridge + Aeropress, unlocks Latte + Cappuccino |
| **Syrup Rack** | $100 | Syrup pump station, enables syrup modifiers |
| **Sauce Station** | $125 | Sauce drizzle station + 3 empty bottles |
| **Mocha Prep Station** | $150 | Mocha sauce production (jug + powder workflow) → with milk gear, unlocks Mocha |
| **Caramel Prep Station** | $100 | Caramel sauce production (sleeve squeeze) |
| **Bottle Rack** | $50 | 3-slot organized sauce bottle storage |

### Modifier Purchases (Money)

Individual syrup flavors and sauce types are bought with money after owning the relevant station.

| Item | Price | Requires |
|---|---|---|
| Vanilla Syrup | $40 | Syrup Rack |
| Caramel Syrup | $40 | Syrup Rack |
| Hazelnut Syrup | $50 | Syrup Rack |
| Toffee Nut Syrup | $50 | Syrup Rack |
| Mocha Sauce | *bundled with Mocha Prep* | Mocha Prep Station |
| Caramel Sauce | $60 | Sauce Station + Caramel Prep |
| White Mocha Sauce | $75 | Sauce Station + Mocha Prep |

**Future syrups:** Peppermint (seasonal), Raspberry, Lavender, Brown Sugar, Sugar-Free Vanilla.
**Future sauces:** Dark Caramel, Pumpkin (seasonal), Pistachio.

### Additional Equipment (Money)

Utility purchases that improve workflow but don't unlock new drinks.

| Item | Price | Effect |
|---|---|---|
| **Second Counter Pad** | $75 | 4 more snap slots for staging drinks |
| **Second Syrup Station** | $75 | Two pump slots (faster with multiple syrups) |
| **Speed Rail** | $150 | Narrow shelf behind counter — holds 6 items in a line |
| **Cup Warmer** | $100 | Pre-warmed cups — slight quality bonus on all drinks |
| **Dual Cup Stack** | $60 | Two cup stacks — grab cups faster, less walking |
| **Extra Sauce Bottles** | $30 each | More bottles for buffer during rush |

### Size Unlocks (Money)

| Size | Price | Effect |
|---|---|---|
| Small | *starter* | Base amounts, base price |
| Medium | *starter* | 1.2x amounts, 1.15x price |
| Large | $60 | 1.5x amounts, 1.3x price |
| Extra Large | $120 | 1.8x amounts, 1.5x price |

---

## Star Unlocks — Equipment Upgrades

Stars represent mastery. Spending stars upgrades equipment you already own from Tier 1 (manual) through Tier 2 (semi-auto) to Tier 3 (fully automated). The design rule: **automation removes a skill challenge but adds throughput capacity**. A player with a hand grinder makes great coffee slowly; a player with an auto grinder serves more customers but the game shifts challenge elsewhere.

Stars are earned from drink quality — every drink served adds its star rating (0-5) to a lifetime total. Stars are **spent** on upgrades, not averaged. Volume and quality both matter.

### Grinder Path

| Tier | Name | Stars | Behavior |
|---|---|---|---|
| 1 | **Hand Grinder** | *starter* | Manual crank mini-game. Player sets grind level. Slow but free. |
| 2 | **Electric Grinder** | 40 | Player sets grind level + presses start. Grinds automatically (passive). |
| 3 | **Auto Grinder** | 120 | Reads ticket, auto-selects grind level, auto-grinds. Just press start. |

### Espresso Path

| Tier | Name | Stars | Behavior |
|---|---|---|---|
| 1 | **Aeropress** | *bought with $* | Full manual: grounds → water → stir → steep → press mini-game |
| 2 | **Semi-Auto Espresso** | 80 | Portafilter + tamp mini-game. Wider green zone on extraction. Faster. |
| 3 | **Full Espresso Machine** | 200 | Tamp + lock portafilter. Machine pulls shot automatically. Dual group heads. |

### Steam Path

| Tier | Name | Stars | Behavior |
|---|---|---|---|
| 1 | **Manual Wand** | *bought with $* | Full steam mini-game. Scald risk on neglect. |
| 2 | **Auto-Shutoff Wand** | 60 | Same mini-game but auto-stops at target temp. No scald risk. |
| 3 | **Auto Steamer** | 150 | Set foam level, press start, walk away. Done in ~8s. |

### Pour-Over Path

| Tier | Name | Stars | Behavior |
|---|---|---|---|
| 1 | **Manual Gooseneck** | *starter* | Full saturation pour mini-game. Manual bloom + main pour. |
| 2 | **Electric Kettle** | 30 | Auto-heats water (no kettle fill step). Pour mini-game unchanged. |
| 3 | **Batch Brewer** | 100 | Set and forget. Makes a full carafe, pour cups from tap. No mini-game. |

### Kettle Path

| Tier | Name | Stars | Behavior |
|---|---|---|---|
| 1 | **Stovetop Kettle** | *starter* | Must bring to hot water station to fill. Holds limited water. |
| 2 | **Large Kettle** | 20 | 2x water capacity. Fewer refill trips. |
| 3 | **Plumbed Hot Water** | 75 | Infinite hot water at the station. No kettle carry needed for americanos. |

### Quality-of-Life Upgrades (Stars)

Small upgrades that reward consistent quality with better tools.

| Item | Stars | Effect |
|---|---|---|
| **Shot Timer** | 15 | Visual countdown on aeropress showing extraction state |
| **Temp Gauge** | 15 | Visual thermometer on steam wand showing exact temp |

---

## Star Unlocks — Meta Milestones

Beyond equipment upgrades, certain star thresholds unlock meta-level content. These are **milestone unlocks** — they trigger automatically when lifetime stars earned (not spent) reach the threshold. Equipment upgrades spend stars from your balance; milestones just check your total ever earned.

This distinction matters: a player who earns 200 stars total and spends 150 on equipment upgrades still hits the 200-star milestone. Stars spent on gear don't block milestone progress.

### Why Stars for Mastery

Money rewards throughput (more drinks = more cash). Stars reward quality (better drinks = more stars per serve). A player who rushes sloppy 2-star drinks earns lots of money but few stars. A player who crafts perfect 5-star drinks earns stars fast but may serve fewer customers. The optimal strategy is both — fast AND good.

The player faces a natural tension: spend stars on equipment upgrades now (immediate throughput gains) or save them for Tier 3 upgrades later? Early upgrades like an Electric Kettle (30 stars) are cheap. Tier 3 upgrades like a Full Espresso Machine (200 stars) require real accumulation.

### Meta Milestone Unlocks

| Lifetime Stars | Unlock | Description |
|---|---|---|
| 25 | **Customer Variety I** | Regulars appear — higher patience, tip better, repeat orders |
| 50 | **Morning Rush Mode** | Optional hard mode: 2x customer rate for 2 minutes, 1.5x money |
| 100 | **Coffee Bar Blueprint** | Unlocks the 2-player Coffee Bar shop layout |
| 150 | **Customer Variety II** | Commuters appear — low patience, simple orders, big tips if fast |
| 200 | **Latte Art Station** | Purchasable station: pour latte art for bonus stars + tips |
| 300 | **Cafe Blueprint** | Unlocks the 3-4 player Cafe shop layout |
| 400 | **Secret Menu** | Rare customers request off-menu drinks for bonus rewards |
| 500 | **Seasonal Rotation** | Seasonal syrups/sauces appear in the shop (pumpkin, peppermint) |
| 750 | **Master Barista Title** | Cosmetic title + golden apron + customers recognize you |
| 1000 | **Drive-Through Blueprint** | Unlocks Drive-Through shop variant (speed-focused) |

---

## Shop Progression

Each shop is a distinct layout with its own identity, unlocked via star milestones.

### Espresso Stand (Starter)
- **Players:** 1 (solo)
- **Stations:** Compact, everything within arm's reach
- **Challenge:** Speed, multitasking solo
- **Max customers:** 3 waiting at once
- **Unlock:** Free (starting shop)

### Coffee Bar (100 Stars)
- **Players:** 1-2
- **Stations:** Spread across a real counter, deliberate station distance
- **Challenge:** Territory division, communication (multiplayer), longer walks
- **Max customers:** 5 waiting at once
- **New features:** Counter seating, visible customer area, music system
- **Unlock:** 100 lifetime stars

### Cafe (300 Stars)
- **Players:** 2-4
- **Stations:** Full floor plan, back bar, front counter, potential back room
- **Challenge:** Zone management, handoffs between players, complex orders
- **Max customers:** 8 waiting at once
- **New features:** Table service, pastry display, lobby waiting area
- **Unlock:** 300 lifetime stars

### Drive-Through (1000 Stars)
- **Players:** 1-3
- **Stations:** Linear layout, speed-optimized but no room for error
- **Challenge:** Pure speed, customers leave fast, no browsing
- **Max customers:** Car queue of 6
- **New features:** Headset ordering, window handoff, timer pressure
- **Unlock:** 1000 lifetime stars

---

## Daily Economy Flow

```
Morning Prep (free time)
  └─ Prep sauces, arrange stations, plan for the day
       │
Day Opens (customers arrive)
  └─ Serve drinks → Earn Money + Stars
       │                    │
       │              Stars add to:
       │              ├─ Spendable balance (for equipment upgrades)
       │              └─ Lifetime total (for meta milestones)
       │
Day Ends
  └─ End-of-Day Summary
       ├─ Revenue earned
       ├─ Tips earned
       ├─ Supplies spent
       ├─ Profit (revenue + tips - expenses)
       ├─ Stars earned today
       ├─ Average star rating
       ├─ Day grade (S/A/B/C/D/F)
       └─ Milestone progress check (new shop unlocked? new customer type?)
       │
Between Days (shop screen)
  ├─ Buy equipment with Money → new drinks auto-unlock
  ├─ Upgrade equipment with Stars → better tools, more automation
  ├─ Buy modifiers with Money → syrups, sauces
  ├─ Set active menu → choose which drinks to serve tomorrow
  └─ Order supplies → consumables for tomorrow
```

---

## Menu Management

Between days, the player chooses which drinks to **put on the menu** for tomorrow. Only drinks on the active menu can be ordered by customers.

Why limit? Because every drink on the menu means:
- Customers might order it → you need supplies and skill
- More modifier combinations → more complexity during rush
- More stations in use → more multitasking

A player might own 10 drink recipes but only put 5 on the menu for a given day. Strategic menu building:
- **Beginner day:** Pour Over + Americano (simple, fewer stations)
- **Milk day:** Latte + Cappuccino + Mocha (all use steamer, batch steam)
- **Full menu:** Everything unlocked, maximum tips but maximum chaos

Customers can only order what's on the menu. The register only shows active menu items.

---

## Suggested Unlock Pacing

A rough guide for how a new player's first ~10 days might flow. Drink unlocks happen automatically as equipment is purchased — the "New Purchase" column shows what the player buys, and the "Unlocked" column shows what they get for free as a result.

| Day | Purchase (Money) | Auto-Unlocked Drinks | Stars Spent | Focus |
|---|---|---|---|---|
| 1 | — | Pour Over (starter) | — | Learn pour-over, serve Small/Medium |
| 2 | Aeropress ($100) + Hot Water ($50) | Americano, Macchiato | — | Espresso workflow, two new drinks at once |
| 3 | Large size ($60) | — | — | Bigger drinks, more revenue per serve |
| 4 | — | — | Shot Timer (15) | Aeropress gets easier, practice quality |
| 5 | Fridge ($75) + Steam ($125) | Latte, Cappuccino | — | Milk steaming, two more drinks at once |
| 6 | Syrup Rack ($100) + Vanilla ($40) | — | — | First modifier, pump mini-game |
| 7 | Caramel Syrup ($40) | — | Electric Kettle (30) | Second flavor, kettle upgrade frees time |
| 8 | Extra Large ($120) | — | — | Highest-value drinks |
| 9 | — | — | Electric Grinder (40) | Passive grinding, huge multitask gain |
| 10 | Sauce Station ($125) + Mocha Prep ($150) | Mocha | — | Sauce system, bottle management, prep phase |
| 11+ | Caramel Prep, more syrups, bottles... | More drinks as gear accumulates | Higher-tier upgrades | Player-driven priority |

By day 5 the player has 5 drinks and a real coffee shop going. The equipment-driven unlock means they get satisfying two-for-one moments (buy milk gear → latte AND cappuccino unlock). By day 9-10 they're choosing between spending stars on convenience upgrades or saving for bigger tier jumps.

---

## Economy Philosophy

### Money (Expansion)
- **Early stations are affordable** ($50-125) to maintain momentum — buy one or two things per day
- **Modifiers are cheap add-ons** ($40-75) for variety without big investment
- **Utility gear fills gaps** ($50-150) once the core stations are owned
- Daily earnings at the espresso stand: ~$80-150 profit on a good day
- The player can't buy everything at once, forcing prioritization of which drinks to unlock first

### Stars (Mastery)
- **Low-tier upgrades are cheap** (15-40 stars) — achievable in 1-2 good days
- **Mid-tier upgrades are meaningful** (60-120 stars) — a few days of solid quality
- **High-tier upgrades are aspirational** (150-200 stars) — requires consistent excellence
- A perfect 5-star drink earns 5 stars. A sloppy 2-star drink earns 2. The player always earns *something*, but quality dramatically accelerates progress
- Spending stars on Tier 2 gear early vs. saving for Tier 3 later is a real strategic choice
- Meta milestones (shops, customer types) are based on lifetime earned, so upgrading equipment never blocks shop progression

---

## What This Means for Code

### Unlock State (new system needed)
- `unlock_manager.gd` autoload: tracks owned equipment, owned modifiers, lifetime stars earned, stars balance (spendable), active menu, owned sizes
- `get_unlocked_drinks() -> Array[DrinkType]` — derives available drinks from owned equipment
- `is_drink_unlocked(drink_type) -> bool` — checks equipment prerequisites
- `is_on_menu(drink_type) -> bool` — checks active menu selection
- `spend_stars(amount) -> bool` — deducts from balance, lifetime total unchanged
- Persistent save/load between sessions (JSON or Godot Resource)

### Drink Prerequisite Map (new data)
- `drink_data.gd` gets a `PREREQUISITES` dict mapping each DrinkType to a list of required equipment IDs
- `unlock_manager` checks this map to derive which drinks are available
- Adding a new drink = add recipe + add prerequisite entry. No separate unlock step needed.

### Register Integration
- Register queries `unlock_manager.get_menu_drinks()` for active-menu drinks
- Register queries `unlock_manager` for owned sizes, syrups, sauces
- Button count adapts dynamically — no hardcoded drink/modifier lists

### Customer Spawner Integration
- Customers only order from active menu via `unlock_manager.get_menu_drinks()`
- Modifier chance scales with number of owned modifiers
- Customer variety (regulars, commuters) gated by lifetime star milestones

### Shop Scene Integration
- Shop scene reads owned equipment list, only instantiates purchased stations
- Equipment tier tracked per station — tier upgrade swaps the station scene/script in place
- Starter equipment always present; purchased equipment added to predefined slots

### Between-Days Screen (new)
- **Equipment Shop tab:** buy base stations with money, see which drinks they'd unlock
- **Upgrades tab:** spend stars on equipment tier upgrades, QoL items
- **Menu tab:** toggle which unlocked drinks are active for tomorrow
- **Supply tab:** order consumables for tomorrow
- **Progress tab:** lifetime stars, milestone progress, next milestone preview
- **Day summary:** revenue, tips, expenses, profit, stars earned, grade

---

## Open Questions

1. **Carry money across sessions or per-run?** Roguelike (lose money on bad day) vs. persistent accumulation? Persistent feels better for a cozy game.
2. **Can you downgrade equipment?** Probably not — upgrades are permanent.
3. **Seasonal content?** Pumpkin spice in fall, peppermint in winter — time-limited unlocks that rotate.
4. **Prestige/reset system?** After unlocking everything, reset with cosmetic rewards? Matches the life-magic prestige system design.
5. **Staff hiring?** AI baristas you can assign to stations — very late game, essentially auto-playing segments. Expensive, acts as a victory lap.
6. **Competitive mode?** Two players, separate stands, shared customer pool. Stars determine winner. Uses the same unlock system but in a session context.
