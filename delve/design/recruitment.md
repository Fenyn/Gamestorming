# Recruitment and the roster cycle

The current agreement is in [core_concept.md](core_concept.md). The full Bulwark cast mapping, supported prototype classes and remaining narrative work are in [roster_adaptation.md](roster_adaptation.md).

## Formation and control

A normal expedition starts with exactly four distinct unlocked characters. Choose one fixed leader and three companions. The player controls the leader's combat turns and reactions; companions use AI. The leader receives personal objective credit and provides the intended dialogue viewpoint. Routes, dialogue choices, equipment, leveling decisions and rest activities remain player decisions. Character-specific dialogue and leader-biased encounter selection remain content work.

The starter roster is Aldric, Elara, Tharr and Fenwick. All four slots are available before the first normal run. Any solo introduction is a separate tutorial. If the leader falls, companions keep fighting; a surviving party recovers the leader under the regular recovery rules. Control does not jump to a companion.

## Wayfarer replacement

A Wayfarer is already fighting the floor's creatures when the party arrives. They join the encounter as a fifth AI ally. After a won fight, a surviving guest offers a replacement choice. Inspect their current character sheet, send one of the three companions home, or decline. The leader cannot be replaced.

The replacement is one operation. It preserves the guest instance, wounds and spent resources, joins at current party level and keeps exactly four party members. The guest participates as a full companion in later leveling, equipment and recovery. Joining does not grant permanent availability.

A declined, dead or dismissed character cannot appear again during the same run with rebuilt resources. Sending someone home does not extract the expedition's carried loot. Permanent unlocks and shared recruitment progress remain intact.

Each floor targets one or two individual Wayfarer nodes at seed-varied positions, including the final floor. They replace spare Skirmish/Happenstance nodes after required Lairs and Campsites are placed. A complete route can skip all Wayfarers; cramped maps may offer fewer to preserve that choice. There are no fixed meeting rows, missing-slot guarantees, or campsite backstops.

## Draw pool

`RecruitPool` draws meetable catalog entries outside the starting party in catalog order. Meeting eligibility is independent of permanent unlocks. Currently Raven and Thistle are the first locked candidates, using supported prototype builds. The full roster needs additional class builds and authored recruitment content before it enters the playable table.

Potential later draw rules:

- Weight encounters toward the leader's personal quests and relevant recruitment hooks.
- Reduce recently seen candidates to spread attention across the growing roster.
- Offer an outpost way to seek a particular character when their story permits it.
- Weight optional replacements toward useful role alternatives without overriding the player's formation.

These weighting rules are not implemented. The current draw remains deterministic and inspectable.

## From meeting to permanent recruitment

1. Meet a character. Their recruitment arc begins even if the player declines the temporary replacement.
2. Complete their authored requirements across runs. Some stories eventually need reputation, items or additional events.
3. When eligible, choose an explicit overnight stay at the outpost. This binds the character and makes them available for future formations.

Raven's first playable arc asks for three party victories and a floor boss victory after meeting her. Thistle's asks for two party victories and a floor boss victory. The guest's initial meeting fight does not count as a party-member victory. These combat milestones provide a playable first slice of trust and exploration; the full friendship stories remain to be authored.

`RecruitmentCatalog` declares steps and thresholds. `CampaignProgress` records shared recruitment/outpost progress and separate leader journals. `LeaderObjectiveCatalog` gives the current leader an initial focus credited by existing meeting and victory hooks. Starting a different run, switching leaders or losing a run never clears earned progress. `CampaignProgressStore` saves stable identifiers and counts. Live combat state and the current-run duplicate-event journal are not persisted because run resume is not implemented.

## Later meeting flavors

The current flavor is the battle already in progress. Other flavors must lead to the same optional companion replacement and separate permanent recruitment contract:

- Happenstance: meet through an event, assistance, trade or conversation.
- Duel: a hostile character yields instead of dying, then offers temporary help. Requires a yield outcome.
- Campsite arrival: a quiet story encounter with an optional replacement.
- Captive or escort battle: add authored encounter objectives before offering the replacement.

None of these replaces an occupied slot automatically. A later optional outpost unlock may enable manual companion combat control without changing the fixed leader or their progression focus.
