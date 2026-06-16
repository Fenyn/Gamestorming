# Ship Layout -- The Titan as Game World

The Titan is the entire game world. Every room is an alien space the crew discovers and repurposes. Areas unlock progressively via a bundle-based restoration system (Community Center style). Paced to match Stardew Valley (~26 hrs/year, big unlocks every 4-8 hrs).

See [terminology_map.md](terminology_map.md) for code room_id to display name mapping. Full design details in the plan file.

## The Hermes (Earth Shuttle)

The crew's human-built shuttle, docked in the Titan's Hangar.

- **Role**: Early-game home base, Maia terminal, starting supplies, mining launch point (later)
- **Contains**: M.A.I.A. terminal, seed stock, Earth tools, communication gear
- **Upgradeable**: Hermes Mining Rig (laser mining array, unlocked ~28 hrs in)
- **Feel**: Cramped, familiar, human — stark contrast with the Titan's alien spaces

## Discover and Repurpose

Every room follows this pattern:
1. Engineer opens the sealed door
2. Crew explores the alien space
3. Linguist reads alien signage (what was it FOR?)
4. Crew repurposes it for human needs
5. Alien tech provides capabilities Earth equipment can't match

Rooms have **dual identity** — a crew working name and an alien origin name (revealed as the Linguist translates).

## Room Inventory

| Crew Name | room_id | Alien Origin | Unlock | ~Hours |
|---|---|---|---|---|
| Hangar | hangar | Docking bay | Start | 0 |
| The Commons | hub | Assembly chamber | Start | 0 |
| Crew Quarters | living_quarters | Rest alcoves | Start | 0 |
| Cargo Hold | cargo_bay | Material storage | Start | 0 |
| Grow Bay 1 | grow_bay | Small cultivation alcove (damaged) | Start | 0 |
| Triage Bay | medical_bay | Bio-scanner suite | Unlock A: tool interaction | ~1 |
| The Forge | processing_lab | Material synthesis chamber | Unlock B: bundle | ~3 |
| Grow Bay 2 | grow_bay_b | Full cultivation array | Unlock B: same bundle | ~3 |
| Analysis Chamber | advanced_processing | Analytical laboratory | Unlock C: bundle | ~10 |
| Vivarium | animal_bay | Organism containment | Unlock D: bundle | ~14 |
| Splice Lab | hybridization_lab | Genetic manipulation suite | Unlock E: bundle | ~16 |
| Grow Bay 3 | grow_bay_c | Cultivation array (alien substrate) | Unlock F: bundle | ~20 |
| Stellar Array | observatory | Stellar navigation nexus | Unlock G: bundle | ~26 |
| Data Vault | archive | Knowledge repository | Unlock I: translation + quest | ~33 |
| Command Nexus | bridge | Central command interface | Unlock J: prerequisite + bundle | ~46 |
| Drive Core | engine_room | Propulsion and power | Unlock K: prerequisite + bundle | ~52 |
| The Sanctum | alien_quarters | Builders' living spaces | Unlock L: relationship gate | ~65 |
| Seed Archive | greenhouse_vault | Botanical preservation vault | Unlock L: same gate | ~65 |

Hermes Mining Rig (Unlock H, ~28 hrs) is not a room — it's a Hermes upgrade for asteroid mining.

## Grow Bay Philosophy

With jump-driven seasons, grow chambers don't need hard biome theming. Seasons (star systems) drive crop variety, not chamber types.

- **Grow Bay 1**: Small, cramped, damaged alcove. 4 plots, no alien infrastructure. Jury-rigged by the crew out of necessity. Limitations create early tension.
- **Grow Bay 2**: The real farm. 8+ plots, wider layout, intact alien irrigation/soil systems. First automation hooks — alien nodes activatable with Titan Fragments (auto-water, auto-till, auto-harvest).
- **Grow Bay 3**: Specialized alien substrate. Supports growth types standard bays can't. Some crops only grow here.

## Bundle Restoration System

Each sealed door has a **Repair Node** — an alien biological interface. The first bundle [OPENS ROOM] for basic access. Subsequent [UPGRADE] bundles enhance features within the room. See the plan file for specific bundle requirements per unlock.

## Hermes Mining Rig

Unlocked after the Stellar Array reveals nearby asteroid fields (~28 hrs in). Ship-based laser mining minigame — select an asteroid field, fly out in the Hermes, mine with a laser interface.

- **Pilot** flies, **Geologist** identifies compositions, **Engineer** upgrades the laser and hull
- Each mining trip takes half the day — can't farm AND mine same day
- Tier 1 (near-field) → Tier 2 (mid-field, hull upgrade) → Tier 3 (deep-field, Drive Core + engine upgrade)
- Replaces Stardew's mine as the resource extraction loop

## Room Connectivity

```
                [Command Nexus]
                       |
       [Data Vault]--[Stellar Array]
               |
[Hangar/Hermes]--[Commons]--[Grow Bay 1]--[Grow Bay 2]
                    |              |
              [Crew Quarters]  [Grow Bay 3]
                    |
          [Triage Bay]--[Maintenance Corridor]
                    |
              [Cargo Hold]--[The Forge]
                                |
                     [Analysis Chamber]--[Splice Lab]
                                |
                          [Vivarium]
                                |
                          [Drive Core]
                                |
                   [The Sanctum + Seed Archive]
```

Conceptual — actual placement follows the 4000px grid in station.tscn.

## Technical Notes

- Room scenes: `scenes/station/rooms/`
- Room generation: `tools/room_painter.gd` (ROOMS table is source of truth)
- Grid spacing: 4000px between rooms in station.tscn
- Tile size: 48x48 (LimeZu Modern Interiors)
- Dimension rules: Multiples of 48, even tile counts, 96px door gaps centered
- Collision: Wall tiles carry physics collision via tileset — no separate bodies
- Display names: `ROOM_DISPLAY_NAMES` dict in station.gd (needs updating for new rooms)
- Unlock system: `MODULE_DOORS` dict + `MilestoneData.unlocked_modules` — data-driven, rooms added incrementally
- See CLAUDE.md "Room Visuals & Collision" for full technical details
