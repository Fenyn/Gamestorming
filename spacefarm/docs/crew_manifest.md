# Crew Manifest

The Hermes mission crew -- 16 specialists assembled for humanity's first contact with an alien vessel. Now stranded aboard the Titan, they must use their expertise to survive.

Each crew member serves a dual purpose: their mission role is realistic for a first-contact team, and their gameplay function fills a Stardew Valley-style vendor, service, or infrastructure slot.

## Design Parameters

- [DECIDED] 16 crew members (including the player)
- [DECIDED] Each has a mission role + a gameplay function
- [DECIDED] Player character is the Botanist
- [TBD] All names, personalities, and detailed backstories
- [TBD] Social/relationship system (friendship levels, gift preferences, heart events)
- [TBD] NPC schedules (which room each crew member occupies at which time of day)

## Crew Roster

| # | Mission Role | Gameplay Function | Stardew Equivalent | Primary Location | Name |
|---|---|---|---|---|---|
| 1 | Mission Commander | Quest giver, directive relay, authority figure | Mayor Lewis | The Commons | [TBD] |
| 2 | Pilot | Navigation data, eventual Titan flight capability | — | Hangar / Hermes | [TBD] |
| 3 | **Botanist (PLAYER)** | Farming, food production | The Farmer | Mobile | [TBD/Blank] |
| 4 | Medical Officer | Health items, fatigue recovery, stamina upgrades | Harvey | Medical Bay | [TBD] |
| 5 | Chief Engineer | Tool upgrades, ship repair, area unlocks | Clint (blacksmith) | Workshop / Maintenance | [TBD] |
| 6 | Xenobiologist | Alien specimens, collection/museum, alien crop research | Gunther (museum) | Research Lab | [TBD] |
| 7 | Linguist | Alien language translation, lore delivery, Titan AI interface | — (library) | Archive | [TBD] |
| 8 | Geologist | Mining, alien materials, soil/mineral analysis | — | Grow Chambers / Cargo | [TBD] |
| 9 | Physicist | Research tree, alien tech theory, experiment quests | Wizard | Research Lab | [TBD] |
| 10 | Comms Officer | Long-range signal events, radio transmissions | — | Hermes / Commons | [TBD] |
| 11 | Security Lead | Sealed area clearance, ship defense, exploration escort | Adventurer's Guild | Maintenance / sealed areas | [TBD] |
| 12 | Quartermaster | General store, ration distribution, supply management | Pierre | Cargo Hold | [TBD] |
| 13 | Chef / Nutritionist | Cooking recipes, meal variety, crew meal system | Gus (saloon) | Commons (mess area) | [TBD] |
| 14 | Psychologist | Morale system, relationship advice, crew dynamics | — | Crew Quarters | [TBD] |
| 15 | Computer Scientist | Alien system hacking, terminal unlocks, data recovery | — | Various terminals | [TBD] |
| 16 | EVA Specialist | Exterior ship exploration, spacewalks, external salvage | — (foraging) | Hangar / exterior | [TBD] |

## Role Details

### Mission Commander
The crew's leader. Relays directives from the Hermes AI and later coordinates with the Titan AI. Carries the weight of decisions — keeping 15 people alive and focused. Gameplay: primary quest/directive interface, similar to how the mayor functions in Stardew.

### Pilot
Flew the Hermes to the Titan. Expert in spacecraft systems and navigation. Feels the loss of Earth most acutely — piloting was their identity and now there's nowhere to fly. Gameplay: provides navigation/sensor data, eventually enables Titan movement or shuttle excursions if the story goes there.

### Chief Engineer
The crew's problem-solver. If it's broken, they fix it. If it's alien, they figure out how it works mechanically (the Linguist handles the language, the Engineer handles the hardware). Gameplay: tool upgrades, ship repair quests that gate new areas, builds/improves equipment.

### Xenobiologist
Specialist in non-Earth biology. On the original mission to study the alien builders; now studies everything the Titan has to offer. Gameplay: identifies alien specimens, runs a collection/museum of discoveries, provides insights on alien crops and growing conditions.

### Linguist
The key to understanding the Titan. Decodes alien text on ship systems, translates the Titan AI's communications, and unlocks lore. Gameplay: alien language progression mechanic — as the Linguist makes progress, new systems, rooms, and story content become accessible.

### Geologist
Mineralogist and materials scientist. Analyzes the Titan's construction, identifies useful alien materials, and assesses soil composition in the grow chambers. Gameplay: provides materials for crafting and upgrades, soil analysis for biome configuration.

### Physicist
The crew's theoretical mind. Understands the principles behind alien technology even when they can't operate it yet. Gameplay: research tree — unlocks theoretical understanding that enables practical applications by other crew members.

### Comms Officer
Manages the Hermes' communication equipment. Scans for signals from the star system, attempts long-range contact with Earth, and monitors the Titan's own communication systems. Gameplay: event trigger NPC — intercepted signals, distress calls, anomalous transmissions become story hooks and quests.

### Security Lead
Military specialist on the mission for crew safety. Handles sealed area clearance (checking for hazards before the crew enters), ship defense protocols, and exploration escort. Gameplay: gates dangerous areas, provides clearance for exploration, combat/defense if applicable.

### Quartermaster
Supply chain specialist. Manages the crew's resources — food distribution, equipment allocation, material storage. Gameplay: general store equivalent — the player trades with the Quartermaster, who distributes goods to the rest of the crew.

### Chef / Nutritionist
Food specialist who turns raw crops and processed goods into meals. Works closely with the Botanist (player). Gameplay: cooking system anchor — provides recipes, takes ingredients, produces meals with gameplay effects.

### Psychologist
Mental health specialist. Monitors crew morale and helps manage interpersonal dynamics under extreme stress. Gameplay: social system anchor — provides insight into crew relationships, may offer advice on gift preferences or relationship milestones.

### Computer Scientist
Systems and software specialist. Interfaces with both the Hermes' computers and the Titan's alien systems at the software level (while the Engineer handles hardware). Gameplay: unlocks alien terminals, recovers data, hacks sealed electronic systems.

### EVA Specialist
Trained for extravehicular activity — spacewalks and exterior operations. On the original mission to inspect the Titan's hull; now handles any work outside the pressurized areas. Gameplay: exterior exploration equivalent (replaces the "foraging" concept) — salvages materials from the Titan's damaged exterior, accesses sealed external compartments.

## ContactData Mapping

The existing `resources/contact_data.gd` resource class has fields that map to crew members:

| ContactData Field | Crew Manifest Equivalent |
|---|---|
| contact_id | Unique identifier (e.g., "commander", "engineer") |
| contact_name | Crew member's name |
| role | Mission role |
| location_claim | Primary location room_id |
| messages[] | Dialogue/message content |

Data files go in `data/contacts/*.tres` — none exist yet. Each crew member gets one .tres file.

## Social System [TBD]

Future design work needed for:
- Friendship/affection progression (Stardew heart system equivalent)
- Gift preferences per crew member
- Heart events / story beats tied to relationship levels
- NPC daily schedules (which room, what time)
- Crew morale as a collective mechanic vs individual relationships
- Whether romance is part of the system
- Group dynamics and inter-crew relationships the player can influence
