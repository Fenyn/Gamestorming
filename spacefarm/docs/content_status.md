# Content Status Tracker

What's decided, what's TBD, what's blocked, what's implemented. Check this before starting any work.

**Legend**: DONE = implemented and working in code. DECIDED = creative decision made, not yet in code. STUB = code skeleton exists with debug placeholders. TBD = needs creative decision. BLOCKED = waiting on another decision.

Full design details: `.claude/plans/look-at-spacefarming-and-piped-snowflake.md`

## Architecture (Code Infrastructure)

| System | Status | Notes |
|---|---|---|
| EventBus | DONE | Pure signal hub, crew_relationship_changed added |
| InputManager | DONE | Input contexts (GAMEPLAY/MENU/CUTSCENE) |
| GameState | DONE | Inventory, progression, unlocks, titan_ai_awakened |
| TimeManager | DONE (needs update) | Currently 16hr days, 14-day seasons, 10s/hr dev speed. Needs: 20hr days, 28-day seasons, 42s/hr, day-of-week system |
| Database | DONE (needs expansion) | Preloads crops/recipes/milestones. Needs: contact loading |
| CrewManager | TBD | NEW autoload — crew relationships, gifts, decay, birthday, chatter |
| SeasonManager | TBD | NEW autoload — jump/season state, predictions, canvas tints |
| SocialConfig resource | TBD | Tuning constants for heart/gift system |
| SeasonConfig resource | TBD | Season names, tints, time multipliers |

## Core Mechanics (Existing)

| System | Status | Notes |
|---|---|---|
| Crop growth (10 types) | DONE | State machine, biome gating, water schedules, quality |
| Processing chains (10 recipes) | DONE | Raw -> basic -> advanced, 3 machine types |
| Directive/milestone system | DONE | 2 directives in code (Maia-voiced), system supports more |
| Energy/fatigue | DONE | 100 max, tool costs, sleep recovery |
| Save/load | DONE | JSON persistence with crop tile snapshots |
| Room transitions | DONE | Exit zones, sealed airlock unlock system |
| Terminal UI | DONE | Shell works, needs story content |
| Comms UI | DONE | Shell exists, needs crew content |
| Hybridizer | DONE | 10 hybrid recipes, 3-day incubation |
| Cargo shipping | DONE | Pod + panel — needs text reframe to "distribute to crew" |
| Room display names | DONE | ROOM_DISPLAY_NAMES dict in station.gd |

## New Mechanics (Planned)

| System | Status | Phase | Notes |
|---|---|---|---|
| Day-of-week system | TBD | Phase 1 | 7 named days, derived from day number |
| Jump-driven seasons | DECIDED | Phase 1 | Radiance/Blaze/Dusk/Frost, 28-day seasons, star-system time variation |
| CrewMember scene | TBD | Phase 1 | StaticBody2D interactable, spawned from data |
| NPC interaction | TBD | Phase 1 | Talk = greeting/chatter, hold item = gift |
| Heart/friendship points | DECIDED | Phase 2 | 10 hearts, 250pts each, weekly gift cap, decay |
| Gift tier system | DECIDED | Phase 2 | Loved/liked/neutral/disliked/hated, per-character responses |
| Idle chatter pools | DECIDED | Phase 2 | Keyed by stranger/acquaintance/friendly/close/trusted/bonded |
| NPC schedules | DECIDED | Phase 3 | Day-of-week + hour → room_id, string keys |
| Dialogue panel | TBD | Phase 4 | Overlay for NPC conversations |
| Heart events | DECIDED | Phase 4 | At hearts 2/4/6/8/10, location+time+hearts trigger |
| Bundle restoration system | DECIDED | Phase 5 | Community Center style, repair nodes at sealed doors |
| Hermes asteroid mining | DECIDED | Phase 5 | Ship-based laser mining, half-day time cost |
| Cargo reframe | DECIDED | Phase 6 | Text changes: "distribute to crew" not "launch" |
| Crew services | DECIDED | Phase 7 | Heart-gated vendor/service per NPC role |
| Automation redesign | TBD | Phase 8 | Replace worm/bee stubs — alien symbiotes? Titan subsystems? |

## Room Progression

| Room | Crew Name | room_id | Status | Unlock |
|---|---|---|---|---|
| Hangar | Hangar | hangar | TBD (new room) | Start |
| The Commons | The Commons | hub | DONE | Start |
| Crew Quarters | Crew Quarters | living_quarters | DONE | Start |
| Cargo Hold | Cargo Hold | cargo_bay | DONE | Start |
| Grow Bay 1 | Grow Bay 1 | grow_bay | DONE (needs resize: 4 plots) | Start |
| Triage Bay | Triage Bay | medical_bay | TBD (new room) | Unlock A: tool interaction |
| The Forge | The Forge | processing_lab | DONE | Unlock B: bundle "Nutrient Restoration" |
| Grow Bay 2 | Grow Bay 2 | grow_bay_b | DONE (needs resize: 8+ plots) | Unlock B: same bundle |
| Analysis Chamber | Analysis Chamber | advanced_processing | DONE | Unlock C: bundle "Synthesis Restoration" |
| Vivarium | Vivarium | animal_bay | TBD (new room) | Unlock D: bundle "Containment Revival" |
| Splice Lab | Splice Lab | hybridization_lab | DONE | Unlock E: bundle "Conduit Restoration" |
| Grow Bay 3 | Grow Bay 3 | grow_bay_c | DONE | Unlock F: bundle "Chamber Activation" |
| Stellar Array | Stellar Array | observatory | TBD (new room) | Unlock G: bundle "Sensor Restoration" |
| Hermes Mining | — | — | TBD (Hermes upgrade) | Unlock H: crew project |
| Data Vault | Data Vault | archive | TBD (new room) | Unlock I: 15 text fragments + quest |
| Command Nexus | Command Nexus | bridge | TBD (new room) | Unlock J: Data Vault prereq + bundles |
| Drive Core | Drive Core | engine_room | TBD (new room) | Unlock K: Command Nexus prereq + bundles |
| The Sanctum | The Sanctum | alien_quarters | TBD (new room) | Unlock L: heart 8 Titan AI + all fragments |
| Seed Archive | Seed Archive | greenhouse_vault | TBD (new room) | Unlock L: same gate |

## Narrative Content

| Content | Status | Notes |
|---|---|---|
| Core premise | DECIDED | See premise.md |
| Ship names | DECIDED | Hermes (shuttle), Titan (alien ship) |
| M.A.I.A. name + personality | DECIDED | Monitoring and Advising Integrated Assistant, helicopter-parent motherly |
| Directive 1-2 text | DONE | Maia-voiced, in directive_1.tres and directive_2.tres |
| Directives 3-5 text | TBD | Bundle-based, requirements designed but text not written |
| Season names | DECIDED | Radiance, Blaze, Dusk, Frost |
| Room display names | DECIDED | See terminology_map.md + plan file |
| Crew member names | TBD | Using role-based IDs (commander, engineer, etc.) |
| Crew personalities | TBD | Brief sketches needed per member |
| Crew gift preferences | TBD | Loved/liked/disliked/hated arrays per member |
| Crew idle chatter | TBD | Pool-based, keyed by heart range |
| Crew gift responses | TBD | Per-character per-tier overrides |
| Crew schedules | TBD | Day-of-week + hour → room_id |
| Heart events (75 total) | TBD | 5 per crew member at hearts 2/4/6/8/10 |
| Story entries (.tres) | TBD | None exist yet |
| Titan AI name + personality | TBD | Late-game priority |
| Alien text fragment content | TBD | Collectibles, Linguist translates |
| Crop season assignments | TBD | Which crops grow in which season |
| Automation concept | TBD | Alien symbiotes? Titan subsystems? Crew tasks? |
| Bundle item requirements | DECIDED (A-H) | Specific items per bundle in plan file. I-L TBD pending mining items |
| Animal/creature designs | TBD | Vivarium inhabitants |
| Mining output items | TBD | Ores, minerals, alien alloys |

## Implementation Phases

| Phase | Scope | Status |
|---|---|---|
| Phase 1 | Day-of-week + crew foundation | NEXT — building this session |
| Phase 2 | Heart system + gift mechanics | Designed, not built |
| Phase 3 | NPC schedules | Designed, not built |
| Phase 4 | Dialogue panel + heart events | Designed, not built |
| Phase 5 | Ship zones + new rooms + mining | Designed, not built |
| Phase 6 | Cargo reframe | Designed, not built |
| Phase 7 | Crew services | Designed, not built |
| Phase 8 | Automation redesign | Concept TBD |

## Decisions Needed (Priority Order)

### Done
1. ~~Hermes AI name/personality~~ — M.A.I.A., helicopter-parent motherly
2. ~~simulation_revealed flag~~ — repurposed to titan_ai_awakened
3. ~~Season system~~ — jump-driven, 4 named seasons
4. ~~Unlock system~~ — bundle-based restoration, modular (first bundle opens, rest upgrade)
5. ~~Pacing~~ — Stardew-matched, 42s/hr, 28-day seasons
6. ~~Room progression~~ — 12 unlocks across ~65 hours
7. ~~Mining concept~~ — Hermes-based asteroid laser mining

### Remaining
1. **Crew member names** — 15 names needed, using role placeholders for now
2. **Titan AI concept** — name, personality, communication style
3. **Automation theme** — alien symbiotes, Titan subsystems, or crew tasks
4. **Alien language mechanic** — glyphs, research tree, or passive unlock
5. **Animal/creature designs** — what lives in the Vivarium
6. **Mining minigame UX** — interactive piloting, point-and-click, or timer-based
7. **Cooking system design** — how Chef recipes work alongside processing

## Document Status

| Document | Status | Last Updated |
|---|---|---|
| premise.md | Needs update (jump seasons, bundle system) | 2026-06-15 |
| terminology_map.md | Needs update (new room names) | 2026-06-15 |
| ship_layout.md | Needs rewrite (bundles, new rooms, pacing) | 2026-06-15 |
| crew_manifest.md | Complete (roster level) | 2026-06-15 |
| progression.md | Needs update (bundle system, seasons) | 2026-06-15 |
| content_status.md | **Updated** | 2026-06-16 |
| CLAUDE.md | Needs update (pacing, seasons, new autoloads) | 2026-06-15 |
| Plan file | **Comprehensive** — full design source of truth | 2026-06-16 |
