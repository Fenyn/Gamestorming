# Worldseed — Asset Mapping

Browse assets in the asset_browser scene, then fill in the model name(s) for each game element.
Use the label names shown in-game (e.g. `Building_03`, `Props_Agro_07`, `Nature_Rock_04`).
Multiple options separated by ` / ` if undecided. Mark your pick with `*`.

---

## Core Stations

| Game Element | Purpose | Model(s) |
|---|---|---|
| **Habitat Hub** | Pressurized dome, spawn point, safe zone, interior walkable | | Module_01 starting, upgrade into Module_02
| **Terraforming Hub** | Tall central structure, 3 color-coded delivery chutes | | Building_14, no chutes but we can add simple rectangles to simulate those
| **Seed Dispenser** | Terminal that cycles plant types and dispenses seeds | | this will be come combination of props to figure out later
| **Water Reservoir** | Tank with fill nozzle, player fills canister here | | building_17 (small) or _14 (large)
| **Bee Hive** | Hexagonal pod, bee docking perches, assignment UI | | building_16_01
| **Solar Panel** | Power generator, buildable (Device_11_SolarPanel?) | | Building_20
| **Plot Tile (frame)** | Outdoor grow bed border/frame for tilled soil | | Props_agro_04 through _06
| **Wind Turbine** | Post-atmosphere power source, buildable | | Building_16_01 with _02 stacked on top and then _03 on top of 2 with _03 rotating
| **Geothermal Vent** | Post-soil power source, buildable | | Building_17

## Carriable Items

| Item | Purpose | Model(s) |
|---|---|---|
| **Seed Pod (Aerolume)** | Carriable seed, cyan/green tint | | props_box_09 and we change the white light tint based on contents
| **Seed Pod (Loamspine)** | Carriable seed, amber/brown tint | | props_box_09 and we change the white light tint based on contents
| **Seed Pod (Tidefern)** | Carriable seed, blue tint | | props_box_09 and we change the white light tint based on contents
| **Water Canister** | Carriable, holds water, visual fill level | | props_box_09 and we change the white light tint based on contents and/or the fill level of the lights
| **Harvest Crate (Aerolume)** | Carriable delivery crate, cyan | | props_box_08 and we change the white light tint based on contents
| **Harvest Crate (Loamspine)** | Carriable delivery crate, amber | | props_box_08 and we change the white light tint based on contents
| **Harvest Crate (Tidefern)** | Carriable delivery crate, blue | | props_box_08 and we change the white light tint based on contents

## Growing Plants (outdoor, per growth stage)

| Plant | Seedling | Mid-growth | Bloomed/Harvest | Model(s) |
|---|---|---|---|---|
| **Aerolume** | | | | | nature_plants_09 for all stages, scale size based on growth. hide bloom part of mesh if possible
| **Loamspine** | | | | |  nature_plants_08 for all stages, scale size based on growth. hide bloom part of mesh if possible
| **Tidefern** | | | | |  nature_plants_07 for all stages, scale size based on growth. hide bloom part of mesh if possible

## Hub Interior

| Element | Purpose | Model(s) |
|---|---|---|
| **Furniture** | Tables, chairs, livability | | lots of options in Props_Furniture_#, need to break it apart further later when it matters
| **Storage racks** | Near hive/workbench | | props_rack_01, _02
| **Lab equipment** | Flavor / research vibe | | lots in props_laboratory_
| **Indoor plants** | Decoration, tutorial starter? | | props_plant_01 through _05
| **Screens / devices** | Displays, control panels | | props_device as well as building_decor_09-11

## World Dressing (static, always present)

| Element | Purpose | Model(s) |
|---|---|---|
| **Terrain rocks (small)** | Scatter near base | | nature_rocks_1 through 5
| **Terrain rocks (large)** | Landmark / barriers | | nature_rocks 6 through 10
| **Mountains** | Distant horizon backdrop | | nature_mountains
| **Crystals** | Alien mineral deposits | | nature_crystal
| **Landed shuttle** | Flavor prop near habitat | | vehicles_05
| **Ground decor** | Alien surface detail | | lots of options in nature_mushroom and trees and grass

## World Progression (appear at milestones)

| Element | When | Model(s) |
|---|---|---|
| **Grass tufts** | Soil 33%+ (MultiMesh scatter) | | these are all clearly labeled in the titles, easy maps
| **Mushrooms** | Soil 33%+ (alien flora) | |
| **Small plants** | Soil 66%+ | |
| **Large plants / bushes** | Soil 100% | |
| **Trees (small)** | Hydro 66%+ | |
| **Trees (large)** | Hydro 100% / post-win | |
| **Animals (ambient)** | Post-win sandbox | |

## Vehicles

| Element | Purpose | Model(s) |
|---|---|---|
| **Landed shuttle** | Flavor near habitat | | Vehicle05
| **Rover / transport** | Flavor or future mechanic | | Vehicles03 ground-based drone, vehicles04 flight-based drone, vehicles02 player sized rover, vehicles01 RV sized mobile player home

---

## Notes

Write any observations about scale, style, or ideas here:
lots of these are labeled easily in their names. also some wildlife options here. does the pack have any animations or anything?

- 
- 
- 
