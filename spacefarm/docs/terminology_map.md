# Terminology Map

How old terms map to new terms, and what changes in code vs display text.

## How to Use This Document

- **Display text** (display_name, ai_message, description, lore_hint, UI labels): use NEW terms
- **Code identifiers** (variable names, room_ids, file paths, signal names): keep OLD terms until a coordinated rename pass
- **New code or data**: use new terms for both code and display
- When in doubt, check this document before naming anything

## Core Concept Mapping

| Old Term | New Term | Scope |
|---|---|---|
| Station AG-7 | The Titan | Display only |
| station (code) | station (unchanged) | Code stays |
| Space station | Alien ship / vessel | Display only |
| The AI | M.A.I.A. — Monitoring and Advising Integrated Assistant (Hermes AI) | Display only |
| — | Titan AI (alien ship, awakens later) | New concept |
| Grow Ring A | Grow Chamber Alpha | Display only |
| Grow Ring B | Grow Chamber Beta | Display only |
| Grow Ring C | Grow Chamber Gamma | Display only |
| Grow Ring D | Grow Chamber Delta | Display only |
| grow_bay / grow_bay_b/c/d | (unchanged) | Code stays |
| Hub | The Commons | Display only |
| Living Quarters | Crew Quarters | Display only |
| Cargo Bay | Cargo Hold | Display only |
| Processing Lab | The Forge | Display only |
| Advanced Processing | Analysis Chamber | Display only |
| Hybridization Lab | Splice Lab | Display only |
| Service Tunnel | Maintenance Corridor | Display only |
| — (new room) | Triage Bay | medical_bay |
| — (new room) | Vivarium | animal_bay |
| — (new room) | Stellar Array | observatory |
| — (new room) | Data Vault | archive |
| — (new room) | Command Nexus | bridge |
| — (new room) | Drive Core | engine_room |
| — (new room) | The Sanctum | alien_quarters |
| — (new room) | Seed Archive | greenhouse_vault |
| — (new room) | Hangar | hangar |
| Grow Ring A | Grow Bay 1 | Display only |
| Grow Ring B | Grow Bay 2 | Display only |
| Grow Ring C | Grow Bay 3 | Display only |
| Grow Ring D | (removed — 3 grow bays, not 4) | — |
| Von Neumann probe | (removed entirely) | — |
| Probe materials | [TBD: endgame crafting goal] | — |
| Contacts (AI-simulated NPCs) | Crew (real people) | Both |
| Simulation revealed | (removed — no simulation twist) | — |
| Nano-worms | [TBD: alien equivalent] | TBD |
| Nano-bees | [TBD: alien equivalent] | TBD |
| Spacewalk / EVA | Ship exploration / sealed sections | Display only |

## Crop Designations

The AG-XX and HY-XX designation system (e.g., "AG-04 Root Cultivar", "HY-05 Mineral Rhizome") **stays**. In the new lore, these are Earth-assigned catalog numbers from the Hermes mission kit — standardized botanical identifiers the crew brought with them. The CropData.designation field remains valid.

## Code Identifier Stability

These identifiers exist in code and are **NOT** changing in this documentation pass:

**class_names**: Station, BaseRoom, StationTerminal, StationInteractable, CargoPod, ExitZone, GrowBay, CropTile, BaseMachine, Hybridizer, CropData, RecipeData, MilestoneData, ToolData, ContactData, StoryEntryData

**Autoloads**: EventBus, InputManager, GameState, TimeManager, Database, CrewManager

**File paths**: All paths under `scenes/station/`, `data/`, `resources/`, `scripts/autoload/`

**Signal names**: All signals in `scripts/autoload/event_bus.gd` (hour_changed, day_started, crop_planted, milestone_unlocked, etc.)

A future coordinated rename pass can use this document as its checklist.

## Data File Changes

| Data File | What Changes | When |
|---|---|---|
| data/milestones/*.tres | ai_message, display_name, lore_hint text | When Hermes AI voice is decided |
| data/crops/*.tres | description text (designation stays) | Tone pass |
| data/recipes/*.tres | display_name, description text if needed | Tone pass |
| data/tools/*.tres | display_name, description text if needed | Tone pass |
| data/story_entries/*.tres | All new content (none exist yet) | Content creation pass |
| data/contacts/*.tres | 15 crew .tres files created with stub content | Content pass for names/personalities |
| data/config/social_config.tres | Heart/gift tuning constants | Created |
