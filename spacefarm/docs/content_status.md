# Content Status Tracker

What's built, what's stubbed, what's remaining. Check this before starting any work.

**Legend**: DONE = implemented and working. STUB = code exists with debug placeholders, needs content. TBD = needs design decision or implementation. BLOCKED = waiting on another decision.

Full design details: `.claude/plans/look-at-spacefarming-and-piped-snowflake.md`

## Architecture (Autoloads — 6 total)

| Autoload | Status | Notes |
|---|---|---|
| EventBus | DONE | Signals for time, farming, supply, progression, crew, UI. Cleaned: removed food_added, directive_failed, automation signals |
| InputManager | DONE | GAMEPLAY / MENU / CUTSCENE contexts |
| GameState | DONE | Inventory, progression, unlocks, titan_ai_awakened, supply_deposits. Automation stubs removed |
| TimeManager | DONE | 20hr days (6am-2am), 28-day seasons, 7-day weeks (Mon-Sun), season names (Radiance/Blaze/Dusk/Frost), 10s/hr dev speed (42s for release) |
| Database | DONE | Preloads crops/recipes/milestones. Dynamic loading: contacts, heart events, supply requests |
| CrewManager | DONE | Relationships (250pts/heart, 10 levels), gifts (2/week, 5 tiers, birthday 8x), talk (+20/day), decay (-2/day), chatter, schedules |

## Systems Built (Phases 1-4, 6)

| System | Status | Key Files |
|---|---|---|
| Day-of-week | DONE | time_manager.gd — DAY_NAMES, get_day_name(), get_day_of_week() |
| Jump-driven seasons | DONE (constants only) | time_manager.gd — SEASON_NAMES, get_season_name(). SeasonManager autoload not yet built (visual tints, time multipliers, jump prediction TBD) |
| CrewMember NPC | DONE | scenes/crew/crew_member.gd+.tscn — CharacterBody2D, NavigationAgent2D, 5-state machine |
| NPC state machine | DONE | crew_states/ — Idle, Wander, Talking, Relocating, Transit. Uses godot-base BaseStateMachine |
| NPC pathfinding | DONE | NavigationAgent2D per NPC, NavigationRegion2D per room (auto-generated), phase-on-stuck after 2s |
| Room-graph traversal | DONE | station.gd — BFS pathfinding across rooms, NPCs walk to exits, chain through intermediate rooms |
| NPC schedules | DONE (no content) | crew_manager.gd — day-of-week string keys + hour → room_id. Deferred moves retry each frame |
| Heart/gift system | DONE | crew_manager.gd — 5 tiers, weekly cap, birthday multiplier, decay, per-character responses |
| Idle chatter | DONE (no content) | crew_manager.gd — pool-based by heart range (stranger/acquaintance/friendly/close/trusted/bonded/devoted/soulbound) |
| Dialogue panel | DONE | scenes/ui/dialogue_panel.gd+.tscn — speaker, text, choices, sequence advancement |
| Heart events | DONE (no content) | resources/heart_event_data.gd, Database loads from data/heart_events/, station.gd checks on NPC interact |
| Supply Board | DONE (no content) | scenes/ui/supply_board.gd+.tscn — 3 sections (Provisions/Requests/Restoration), per-item deposit, rewards, module unlocks |
| Supply requests | DONE (no content) | resources/supply_request_data.gd, Database loads from data/supply_requests/ |
| Room display names | DONE | station.gd ROOM_DISPLAY_NAMES dict |
| SocialConfig | DONE | resources/social_config.gd + data/config/social_config.tres — tunable heart/gift constants |
| Nav regions per room | DONE | base_room.gd — auto-generated rectangular NavigationRegion2D |

## 15 Crew ContactData Files (STUB)

All in `data/contacts/`. Each has contact_id, contact_name, role, greeting (stub text), location_claim, gameplay_function. All content fields empty:

| contact_id | Role | Location | Service |
|---|---|---|---|
| commander | Mission Commander | hub | quest |
| pilot | Pilot | hub | — |
| medic | Medical Officer | living_quarters | clinic |
| engineer | Chief Engineer | processing_lab | upgrades |
| xenobiologist | Xenobiologist | advanced_processing | museum |
| linguist | Linguist | hub | translation |
| geologist | Geologist | cargo_bay | — |
| physicist | Physicist | advanced_processing | research |
| comms_officer | Comms Officer | hub | — |
| security | Security Lead | service_tunnel | — |
| quartermaster | Quartermaster | cargo_bay | shop |
| chef | Chef | hub | cooking |
| psychologist | Psychologist | living_quarters | — |
| hacker | Computer Scientist | hub | — |
| eva_specialist | EVA Specialist | cargo_bay | — |

## Content Needing Authoring (systems built, zero content)

| Content | Format | Location | Scope |
|---|---|---|---|
| Crew names | contact_name field in .tres | data/contacts/*.tres | 15 names |
| Crew personalities | Not yet structured | — | 15 personality sketches |
| Idle chatter | idle_chatter dict in .tres | data/contacts/*.tres | 6+ lines per heart range per crew (90+ lines min) |
| Gift preferences | loved/liked/disliked/hated arrays | data/contacts/*.tres | 4 arrays per crew |
| Gift responses | gift_responses dict in .tres | data/contacts/*.tres | 5 tiers × 15 crew = 75 lines |
| NPC schedules | schedule dict in .tres | data/contacts/*.tres | Day + hour → room per crew |
| Heart events | HeartEventData .tres files | data/heart_events/ | Up to 75 (5 per crew at hearts 2/4/6/8/10) |
| Supply requests | SupplyRequestData .tres files | data/supply_requests/ | Provisions + crew requests + restoration bundles |
| Story terminal entries | StoryEntryData .tres files | data/story_entries/ | None exist |
| Crop season assignments | seasons array on CropData | data/crops/*.tres | Which crops grow in which season |
| Directive 3-5 text | MilestoneData .tres files | data/milestones/ | Bundle-based, requirements designed in plan |

## Remaining Implementation Phases

| Phase | Scope | Status | Notes |
|---|---|---|---|
| **5: Ship Zones** | New room scenes, bundle .tres files, Titan Fragment tracking | NOT BUILT | Rooms need tilemap painting via room_painter. Largest remaining phase. |
| **5b: Hermes Mining** | Laser mining minigame, asteroid data, Hermes upgrade flow | NOT BUILT | Separate from Phase 5. Needs UX design decision. |
| **7: Crew Services** | Per-NPC service panels (Shop, Upgrades, Cooking, Clinic, Research, Collection) | NOT BUILT | Build 1-2 at a time, each self-contained. |
| **8: Automation** | Replace removed worm/bee stubs with new concept | NOT BUILT | BLOCKED on creative decision: alien symbiotes vs Titan subsystems vs crew tasks |
| **SeasonManager autoload** | Visual tints per season, time multipliers, jump transitions, prediction data | NOT BUILT | Constants exist in TimeManager, but the manager itself doesn't exist yet |

## Removed This Session

- ShippingPanel (replaced by SupplyBoard)
- CargoPod cargo storage methods (kept as interaction-only trigger for SupplyBoard)
- food_added signal + emit
- directive_failed signal
- All automation signals (automation_activated, worm_task_completed, bee_delivery_completed)
- All automation vars from GameState (worm_count, bee_count, worm_assignments, bee_routes)
- simulation_revealed → repurposed to titan_ai_awakened (earlier in session)

## Open Design Decisions

| # | Decision | Impact | Notes |
|---|---|---|---|
| 1 | Crew member names | Unlocks NPC content authoring | Using role placeholders now |
| 2 | Titan AI concept | Unlocks Act 2+ story, late-game content | Name, personality, communication style |
| 3 | Automation theme | Unlocks Phase 8 implementation | Alien symbiotes? Titan subsystems? Crew tasks? |
| 4 | Alien language mechanic | Unlocks Linguist NPC, environmental storytelling | Glyph replacement? Research tree? Passive? |
| 5 | Vivarium creatures | Unlocks animal husbandry content | What lives there, what they produce |
| 6 | Mining minigame UX | Unlocks Phase 5b build | Interactive piloting? Point-and-click? Timer? |
| 7 | Cooking system design | Unlocks Chef NPC service panel | How recipes work alongside existing processing |

## Document Status

| Document | Status | Last Updated |
|---|---|---|
| premise.md | **Updated** — jump seasons, biological alien tech, dual AI | 2026-06-16 |
| terminology_map.md | **Updated** — all new room names, CrewManager in autoloads | 2026-06-16 |
| ship_layout.md | **Updated** — discover/repurpose, bundles, mining, grow bay philosophy | 2026-06-16 |
| crew_manifest.md | Complete (roster level, no names) | 2026-06-15 |
| progression.md | **Updated** — bundle-based unlocks, jump seasons, Act structure | 2026-06-16 |
| content_status.md | **Current** | 2026-06-16 |
| CLAUDE.md | **Updated** — 6 autoloads, pacing constants, naming discipline | 2026-06-16 |
| Plan file | **Comprehensive** — full design source of truth | 2026-06-16 |
