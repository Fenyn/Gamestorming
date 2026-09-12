# Grounded creature prototype

The user chose to allow occupied footprints across elevation changes, drawing the creature from the lower ground. This is Delve's presentation convention, not a PF2e quotation.

- Body elevation: lowest tile-center surface in its footprint. One-tile creatures keep their existing slope-center placement.
- Body position: center of the low supporting tiles; if that average lies inside a raised island, use the nearest low tile center. The offset stays inside the footprint and does not depend on camera facing.
- Logical grid anchor, occupancy, reach and target selection stay unchanged.
- Marker: separate surface quad for each occupied tile, triangulated like the terrain. A shader draws a narrow outline and faint fill. No vertical connecting faces and no floating disk.
- Active turns pulse marker brightness. Body lunges cannot displace it. Movement hides the marker while the body travels, then places it on the destination terrain; reconciliation also refreshes it.
- Body, name, HP bar and impact effects share the same drawn origin. Normal terrain occlusion remains; these captures predate the hidden-body silhouette, now documented in `../silhouette/README.md`.

Open `res://scenes/dev/enemy_sprite_preview.tscn` and press F6. The grizzly in the full roster straddles the raised ruins. `grizzly_bear_idle.png` shows the grounded body beside the ledge with the footprint continuing across the upper surface.

Capture with `enemy_grounding_shot_spike.tscn`; set `DELVE_SHOT_DIRECTORY` to this folder. All twelve species have individual captures here.

Validation: build passed with zero Delve warnings/errors. Footprint checks 55/55, targeting 27/27, encounter reset 19/19, combat presentation 45/45. Rendered capture suite 45/45; visually inspected bear on stepped ground, monitor and beetle. The full rebuild reports 28 existing warnings in the referenced Pf2e.Core project.
