class_name Level4Spires
extends LevelBase

func build() -> void:
	level_name = "The Crucible"
	spawn_point = Vector3(0, 1.2, 0)

	var C := Color(0.36, 0.34, 0.31)
	var D := Color(0.32, 0.30, 0.28)
	var M := Color(0.50, 0.50, 0.55)

	_place_sign(Vector3(0, 3.5, -3), "THE CRUCIBLE\n\n" +
		"Lock multiple targets.\nFeel the difference.")

	# ═══════════════════════════════════════
	# SECTION A: MULTI-TARGET LAUNCH
	# ═══════════════════════════════════════

	# Three floor girders in a triangle — lock all, push for 3x force
	_place_girder(Vector3(0, 0.25, -6), Vector3(2.5, 0.5, 2.5), 500.0)
	_place_girder(Vector3(-3.5, 0.25, -10), Vector3(2.5, 0.5, 2.5), 500.0)
	_place_girder(Vector3(3.5, 0.25, -10), Vector3(2.5, 0.5, 2.5), 500.0)

	_place_sign(Vector3(0, 2.5, -4), "Three anchors. Lock them all.\nPush.")

	_place_box(Vector3(-8, 4, -8), Vector3(5, 8, 8), C)
	_place_box(Vector3(8, 4, -8), Vector3(5, 8, 8), C)

	# Target platform ~22m up
	_place_box(Vector3(0, 10, -18), Vector3(12, 20, 12), D)
	_place_box(Vector3(0, 21, -18), Vector3(8, 2, 8), C)
	_place_girder(Vector3(0, 22.5, -18), Vector3(5, 0.4, 0.4), 400.0)

	_place_sign(Vector3(0, 24.5, -16), "One anchor moves you.\nThree anchors launch you.")

	# ═══════════════════════════════════════
	# SECTION B: THE HOVER CHANNEL
	# ═══════════════════════════════════════

	_place_sign(Vector3(0, 24.5, -20), "Push the iron below you to hover.\n[Scroll] to adjust height.\nDon't fall.")

	# Start and end platforms at y=22 (top of section A building)
	# Below: support pillars with girders at varying heights in the void
	# The player hovers across by pushing off the girders below

	# Support pillar 1 — tall, close, forgiving
	_place_box(Vector3(0, 7, -32), Vector3(3, 14, 3), M)
	_place_girder(Vector3(0, 14.5, -32), Vector3(3, 0.4, 3), 400.0)

	# Support pillar 2 — shorter, needs more burn
	_place_box(Vector3(-3, 4.5, -42), Vector3(3, 9, 3), M)
	_place_girder(Vector3(-3, 9.5, -42), Vector3(3, 0.4, 3), 400.0)

	# Support pillar 3 — medium
	_place_box(Vector3(3, 6, -52), Vector3(3, 12, 3), M)
	_place_girder(Vector3(3, 12.5, -52), Vector3(3, 0.4, 3), 400.0)

	# Support pillar 4 — short, hardest section
	_place_box(Vector3(0, 3.5, -62), Vector3(3, 7, 3), M)
	_place_girder(Vector3(0, 7.5, -62), Vector3(3, 0.4, 3), 400.0)

	# Support pillar 5 ��� tall again, relief
	_place_box(Vector3(-2, 6.5, -72), Vector3(3, 13, 3), M)
	_place_girder(Vector3(-2, 13.5, -72), Vector3(3, 0.4, 3), 400.0)

	# End platform
	_place_box(Vector3(0, 10, -85), Vector3(12, 20, 12), D)
	_place_box(Vector3(0, 21, -85), Vector3(8, 2, 8), C)
	_place_girder(Vector3(0, 22.5, -85), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery — low pillar the player can push off if they fall
	_place_box(Vector3(-7, 2.5, -52), Vector3(3, 5, 3), D)
	_place_girder(Vector3(-7, 5.5, -52), Vector3(2.5, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION C: MOVING ANCHOR DANCE
	# ═══════════════════════════════════════

	_place_sign(Vector3(0, 24.5, -83), "Moving metal. Track it.\nPull when it swings close.")

	# Three moving anchors in sequence, different patterns
	# Moving anchor 1 — horizontal sweep
	_place_moving_anchor(
		Vector3(14, 22, -102),
		Vector3(3, 0.4, 0.4), 400.0,
		Vector3(-24, 0, 0), 4.0
	)

	# Moving anchor 2 — horizontal sweep opposite direction
	_place_moving_anchor(
		Vector3(-10, 24, -120),
		Vector3(3, 0.4, 0.4), 400.0,
		Vector3(22, 0, 0), 4.5
	)

	# Moving anchor 3 — diagonal sweep with vertical component
	_place_moving_anchor(
		Vector3(12, 22, -138),
		Vector3(3, 0.4, 0.4), 400.0,
		Vector3(-18, 6, 0), 5.0
	)

	# Final landing
	_place_box(Vector3(0, 12, -158), Vector3(14, 24, 14), D)
	_place_box(Vector3(0, 25, -158), Vector3(10, 2, 10), C)
	_place_girder(Vector3(0, 26.5, -158), Vector3(5, 0.4, 0.4), 400.0)
	_place_girder(Vector3(0, 24, -151), Vector3(4, 0.5, 0.5), 400.0)

	# Recovery
	_place_box(Vector3(0, 6, -120), Vector3(4, 12, 4), D)
	_place_girder(Vector3(0, 12.5, -120), Vector3(2.5, 0.35, 0.35), 200.0)

	# ── Goal ──
	_place_goal(Vector3(0, 30, -158), Vector3(8, 0.5, 8))
	_place_sign(Vector3(0, 33, -158), "One more.", 20)

	# ── Boundary + backdrop ──
	_build_boundary(Vector3(0, 0, -80), 100.0)
	_build_city_backdrop(Vector3(0, 0, -80), 100.0, 170.0, 55, 30.0, 0.2)
