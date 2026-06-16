# Story Arc & Progression

How the narrative unfolds and the directive system works aboard the Titan.

## Act Structure

### Act 1 -- Survival

**Narrative**: The crew has just been transported to an unknown star system. Panic gives way to pragmatism. The Mission Commander takes charge, the Hermes AI provides survival protocols, and the Botanist (player) is tasked with the most urgent problem: food.

**Gameplay**: Learn farming mechanics, establish crops in Grow Bay 1, process basic goods, complete restoration bundles. The crew settles into their roles. Relationship building begins. Jump-driven seasons (Radiance/Blaze/Dusk/Frost) determine what crops can grow.

**Progression**: Bundle-based restoration (Community Center style). Repair Nodes at sealed doors require curated item sets. First bundle opens the room; subsequent bundles upgrade features within it.

| Unlock | Gate | ~Hours | Unlocks |
|---|---|---|---|
| A: Triage Bay | Tool interaction (assist Engineer) | ~1 | Medic NPC, health services |
| B: Forge + Grow Bay 2 | Bundle: "Nutrient Restoration" (3 bundles) | ~3 | Processing chains, Tier 2 crops, 8+ plots, automation hooks |
| C: Analysis Chamber | Bundle: "Synthesis Restoration" (3 bundles) | ~10 | Advanced processing, assembly recipes |
| D: Vivarium | Bundle: "Containment Revival" (3 bundles) | ~14 | Alien creature husbandry |
| E: Splice Lab | Bundle: "Conduit Restoration" (3 bundles) | ~16 | Hybridization system |
| F: Grow Bay 3 | Bundle: "Chamber Activation" (2 bundles) | ~20 | Specialized alien substrate |

**Transition to Act 2**: The Hermes AI begins flagging alien systems it can't analyze. The Linguist makes early progress on the alien language. The Engineer discovers that some of the Titan's sealed sections have power running to them.

### Act 2 -- Adaptation [TBD details]

**Narrative**: The crew shifts from pure survival to understanding their environment. The Titan isn't just shelter — it's a vessel with its own systems, its own history, and its own damaged intelligence. The Linguist decodes enough alien text to partially activate the Titan AI. It speaks in fragments at first.

**Gameplay**: Deeper processing, hybridization, alien creature husbandry, Hermes asteroid mining. New crew services come online. The Titan AI begins speaking in fragments.

**Progression**: Mix of bundles, crew quests, translation milestones.

| Unlock | Gate | ~Hours | Unlocks |
|---|---|---|---|
| G: Stellar Array | Bundle: "Sensor Restoration" (4 bundles) | ~26 | Star scanning, jump prediction, signal detection |
| H: Hermes Mining | Crew project (Pilot + Engineer, 2 bundles) | ~28 | Asteroid mining — daily choice: farm or mine |
| I: Data Vault | 15 alien text fragments + quest | ~33 | Alien blueprints, Tier 3-4 crops, deep lore |
| J: Command Nexus | Data Vault prereq + bundle | ~46 | Titan AI direct interface, navigation data |

**Transition to Act 3**: The Titan AI becomes fully communicative. It reveals something about the ship's purpose, the builders, or the star system that reframes the crew's situation.

### Act 3 -- Discovery [TBD]

**Narrative**: The crew faces a choice shaped by what they've learned. The Titan's original mission, the fate of its builders, and the nature of this star system come into focus. Getting home may be possible — but it may not be simple.

**Gameplay**: Endgame content, full ship access, highest-tier alien crops, power allocation, the culmination of the alien language system. The Titan AI is a full participant in the crew's decisions.

**Progression**:

| Unlock | Gate | ~Hours | Unlocks |
|---|---|---|---|
| K: Drive Core | Command Nexus prereq + bundle | ~52 | Power allocation mechanic, jump drive understanding |
| L: The Sanctum | Titan AI heart 8 + all fragments translated | ~65 | Builders' living spaces, Seed Archive, alien crops, endgame lore |

[TBD: Act 3 narrative details. The foundation (Acts 1-2) needs to be solid before designing the endgame.]

## The Two AIs

### M.A.I.A. — Monitoring and Advising Integrated Assistant (Hermes AI)

[DECIDED] The Earth shuttle's mission computer. The acronym conveniently shares a name with the mother of Hermes in Greek mythology, and the crew leans into it.

**Knowledge base**: Human science, survival protocols, agricultural databases, engineering references. Everything Earth knew at the time of launch.

**Limitations**: No knowledge of alien systems. Can analyze data the crew provides but can't interface with the Titan directly.

**Directive style**: Frames objectives in terms of crew welfare and safety, not raw metrics. "The crew needs a reliable food source" rather than "produce 50 food units." The numbers are there, but the framing is always about people.

**Personality**: [DECIDED] Helicopter-parent motherly. Warm, attentive, and relentlessly concerned about the crew's wellbeing.
- Worries openly — about nutrition, sleep, morale, workload
- Celebrates the player's achievements ("I'm so proud of what you've managed here")
- Gets anxious when you work past shutdown hours or skip meals
- Firm when it matters — she won't nag idly, but she'll insist on rest
- Knows she can't protect them from everything, which makes her try harder
- As the Titan AI awakens, Maia may become protective/skeptical of the alien voice — she doesn't trust what she can't understand

**Voice samples** (for tone consistency when writing Maia's text):
- Directive: "I've been running the numbers on crew nutrition, and... we need to do better. I need you to focus on building a stable food supply. Fifty units should give us a safety margin. Please be careful out there."
- Praise: "You did it. You actually did it. I want you to know — the crew is eating well tonight because of you."
- Concern: "You're still working? It's well past shutdown. Your body needs rest, even if your mind doesn't agree. Please. Bed."
- New area: "I can't tell you what's behind that door — it's beyond my databases. But the Engineer says the atmosphere reads safe. Just... stay alert."

**Terminal category**: LOG, SYSTEM_REPORT, MANUAL

### Titan AI

[TBD: Name, personality, everything]

**State**: Damaged. Awakens in stages as the player repairs ship systems and the Linguist decodes the language.

**Communication arc**:
1. Silent (game start — systems offline)
2. Glyphs/fragments (mid Act 1 — power restored to some systems, alien text appears)
3. Broken sentences (Act 2 — Linguist makes progress, meaning emerges)
4. Full communication (late Act 2 / Act 3 — Titan AI is a conversational participant)

**Potential personality directions** [TBD — pick one or blend]:
- Ancient and patient (has existed far longer than human civilization)
- Curious about humans (its builders are gone, these new occupants are fascinating)
- Mission-focused (has objectives it wants to complete, views the crew as potential helpers)
- Damaged/confused (doesn't fully remember its own purpose, piecing itself together alongside the crew)

**Terminal category**: CLASSIFIED (alien data), potentially a new category for decoded transmissions

## Jump-Driven Seasons

Seasons are driven by the Titan jumping between star systems every 28 days. Four seasons: Radiance (warm/gold), Blaze (hot/orange-red), Dusk (cool/purple), Frost (cold/blue). Crops need the right season to grow. The Stellar Array lets the crew predict jumps 2-3 days early; the Command Nexus reveals the full schedule. See [premise.md](premise.md) for full details.

## Alien Language System

[DECIDED] Exists as a progression mechanic tied to the Linguist crew member and the Titan AI's awakening.

[TBD] Implementation approach. Options:
- **Glyph replacement**: Alien text appears as symbols throughout the ship. As the Linguist progresses, glyphs are replaced with translated text. Visual and satisfying.
- **Research unlock**: The Linguist works on translation as a background task. Player provides materials/resources. Translation milestones unlock new content.
- **Passive story progression**: Translation advances through directives and story beats. No direct player interaction with the language itself.
- **Hybrid**: Glyphs are visible everywhere (environmental storytelling), but translation is gated by research milestones that the player contributes to.

[DECIDED] The Linguist is the key NPC for this system. Their friendship/quest progression should be tied to language milestones.

## Progression System -- Technical Notes

The existing MilestoneData/DIRECTIVE_CHAIN system handles the major directive milestones. The new **bundle restoration system** operates alongside it — bundles are a higher-level grouping where completing all bundles at a Repair Node triggers a module unlock (same `unlock_airlock()` mechanism).

**Bundle data** will need a new resource class (RestoreNodeData or similar) that defines bundles per sealed door. This is Phase 5 implementation work — the MilestoneData system handles Act 1 progression; bundles expand it for Acts 2-3.

Existing directive .tres files (directive_1.tres, directive_2.tres) have been updated with Maia-voiced text. Additional directives will transition to the bundle model.

## Terminal & Story Entries

The terminal system (StoryEntryData, terminal.gd) delivers narrative content through categorized entries.

| Category | Source | Content Type |
|---|---|---|
| MANUAL | Hermes AI | How-to guides, crop references, processing instructions |
| LOG | Hermes AI | Mission logs, situation reports, system status |
| MESSAGE | Crew members | Inter-crew communications, personal messages |
| SYSTEM_REPORT | Hermes AI / Titan systems | Automated status reports, anomaly alerts |
| CLASSIFIED | Titan AI / alien data | Decoded alien records, ship history, builder lore |

[TBD] Whether MESSAGE entries come through the terminal or through a separate crew comms system (the existing CommsPanel).

## The titan_ai_awakened Flag

[DECIDED] The old `simulation_revealed` flag has been repurposed to `GameState.titan_ai_awakened` — a boolean that gates content available after the Titan AI comes online. When true, `CropData.get_active_name()` returns the crop's designation (e.g., "AG-04 Root Cultivar") instead of the display name, reflecting the alien AI's more clinical perspective on the crew's agricultural work.
