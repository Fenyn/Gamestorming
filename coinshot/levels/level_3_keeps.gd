class_name Level3Keeps
extends LevelBase

func build() -> void:
	level_name = "The High Keeps"
	spawn_point = Vector3(0, 1.2, 0)

	var C := Color(0.40, 0.38, 0.35)
	var D := Color(0.34, 0.32, 0.30)
	var W := Color(0.38, 0.36, 0.33)

	_place_sign(Vector3(0, 3, -3), "THE HIGH KEEPS\n\n" +
		"The nobles put iron in their walls.\n" +
		"Works for us.")

	# ═══════════════════════════════════════
	# SECTION A: STARTING KEEP — Burn Control
	# ═══════════════════════════════════════

	# Large starting keep — stepped profile
	_place_box(Vector3(0, 4, -10), Vector3(14, 8, 12), C)
	_place_box(Vector3(0, 10, -10), Vector3(10, 4, 8), D)
	_place_girder(Vector3(0, 12.5, -10), Vector3(5, 0.4, 0.4), 400.0)
	# Flanking walls
	_place_box(Vector3(-10, 5, -10), Vector3(3, 10, 8), W)
	_place_box(Vector3(10, 5, -10), Vector3(3, 10, 8), W)

	_place_sign(Vector3(0, 14.5, -8.5), "[Scroll Up/Down] adjusts your burn rate.\n" +
		"Low burn for control. High burn for power.\n" +
		"That awning will block a full-burn launch.\n" +
		"Ease off and steer through the gap on the left.")

	# Stone awning blocking direct vertical launch
	_place_overhang(Vector3(5, 18, -20), Vector3(14, 0.5, 16))

	# Wide courtyard gap (35m) to next keep
	_place_box(Vector3(-8, 9, -45), Vector3(12, 18, 10), D)
	_place_box(Vector3(-8, 19, -45), Vector3(8, 2, 7), C)
	_place_girder(Vector3(-8, 20.5, -45), Vector3(4, 0.35, 0.35), 350.0)
	# Recovery girder under the awning
	_place_girder(Vector3(2, 16, -20), Vector3(3, 0.35, 0.35), 200.0)
	# Recovery in courtyard gap
	_place_box(Vector3(-2, 5, -28), Vector3(4, 10, 4), W)
	_place_girder(Vector3(-2, 10.5, -28), Vector3(2.5, 0.35, 0.35), 250.0)

	# ═══════════════════════════════════════
	# SECTION B: MOVING ANCHOR — Timing
	# ═══════════════════════════════════════

	_place_sign(Vector3(-8, 22.5, -43.5), "See the green beam? It moves.\n" +
		"Wait for it to get close, then Pull.")

	# Tall keep wall the moving anchor travels along
	_place_box(Vector3(8, 14, -55), Vector3(5, 28, 18), W)
	_place_box(Vector3(8, 29, -55), Vector3(4, 2, 14), D)

	# Moving anchor on a long horizontal track
	_place_moving_anchor(
		Vector3(5, 24, -48),
		Vector3(3, 0.4, 0.4), 400.0,
		Vector3(0, 0, -12), 5.0
	)

	# Landing keep across another gap
	_place_box(Vector3(-5, 12, -80), Vector3(12, 24, 10), D)
	_place_box(Vector3(-5, 25, -80), Vector3(8, 2, 7), C)
	_place_girder(Vector3(-5, 26.5, -80), Vector3(4, 0.35, 0.35), 350.0)

	# Recovery
	_place_girder(Vector3(3, 20, -68), Vector3(2.5, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION C: VERTICAL MOVING ANCHORS — The Climb
	# ═══════════════════════════════════════

	_place_sign(Vector3(-5, 28.5, -78.5), "Old lift mechanism. Still works.\n" +
		"Push off the green anchors as they rise\n" +
		"to climb the tower.")

	# Tall keep tower to climb — wide enough to maneuver around
	_place_box(Vector3(8, 22, -90), Vector3(8, 44, 8), W)
	_place_box(Vector3(8, 45, -90), Vector3(5, 2, 5), D)

	# Three staggered vertical moving anchors — spaced for momentum
	_place_moving_anchor(
		Vector3(4, 26, -90), Vector3(3, 0.4, 0.4), 350.0,
		Vector3(0, 8, 0), 3.5
	)
	_place_moving_anchor(
		Vector3(4, 34, -88), Vector3(3, 0.4, 0.4), 350.0,
		Vector3(0, 7, 0), 4.0
	)
	_place_moving_anchor(
		Vector3(4, 42, -90), Vector3(3, 0.4, 0.4), 350.0,
		Vector3(0, 6, 0), 3.0
	)
	# Recovery girder
	_place_girder(Vector3(7, 30, -90), Vector3(0.35, 0.35, 4), 250.0)

	# Summit keep — wide landing
	_place_box(Vector3(0, 22, -105), Vector3(14, 44, 10), C)
	_place_box(Vector3(0, 45, -105), Vector3(10, 2, 7), D)
	_place_box(Vector3(0, 47, -105), Vector3(6, 2, 5), C)
	_place_girder(Vector3(0, 48.5, -105), Vector3(5, 0.4, 0.4), 400.0)

	# ── Goal ──
	_place_goal(Vector3(0, 52, -105), Vector3(10, 0.5, 10))
	_place_sign(Vector3(0, 55, -105), "Good climb.\n" +
		"Next up: the slingshot.", 20)

	# ── Boundary + city backdrop ──
	_build_boundary(Vector3(0, 0, -55), 80.0)
	_build_city_backdrop(Vector3(0, 0, -55), 80.0, 150.0, 50, 30.0, 0.2)
