# Card data

One JSON file per set, each `{"cards": [...]}`. Schema is in `../../docs/dev_reference.md` (Card JSON).

`starter/starter_set.json` is the starter pool: themed titles (naming pass 2026-09-17), real mechanics. Flavor text and art briefs are still to come.

**This file is the source of truth and is edited in place.** Nothing regenerates the whole pool any more; the old whole-world generator is parked in `tools/legacy/gen_starters.py` and reverted anything edited here when it ran.

Edit a card here by hand. To add one, write a spec with the helpers in `tools/cardlib.py` and run `python tools/add_card.py <spec>`: it adds ids that are not present, leaves everything else alone, and **refuses to rewrite a card that already exists** unless you name it with `--replace <id>`, so a hand edit here cannot be walked over. `--retire <ids>` removes cards, and refuses while a deck still runs one.

Test fixtures live in `tests/fixtures/cards/` and never ship.
