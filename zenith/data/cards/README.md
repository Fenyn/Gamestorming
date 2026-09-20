# Card data

One JSON file per set, each `{"cards": [...]}`. Schema is in `../../README.md`.

`starter/starter_set.json` is the starter pool: themed titles (naming pass 2026-09-17), real mechanics. Flavor text and art briefs are still to come.

**This file is the source of truth and is edited in place.** Nothing regenerates the whole pool any more; the old whole-world generator is parked in `tools/legacy/gen_starters.py` and reverted anything edited here when it ran. New cards go in a module under `tools/decks/` and are written by `python tools/add_cards.py decks/<name>`, which touches only the ids that module defines.

Test fixtures live in `tests/fixtures/cards/` and never ship.
