class_name Level1Rooftops
extends LevelBase

func build() -> void:
	level_name = "The Ash Warrens"
	spawn_point = Vector3(0, 1.2, 0)

	var C := Color(0.36, 0.34, 0.31)
	var D := Color(0.32, 0.30, 0.28)

	_place_sign(Vector3(0, 3.5, -3), "THE ASH WARRENS\n\n" +
		"You can feel the metal all around you.\n" +
		"Time to see what you can do with it.\n\n" +
		"[LMB] Lock targets  [Space] Push / Jump  [E] Pull\n" +
		"[Q] Drop coin  [F] Coinshot  [Scroll] Burn intensity\n" +
		"[Tab] Mist-vision  [R] Respawn  [\\[] / [\\]] Switch levels")

	# ═══════════════════════════════════════
	# SECTION A: THE COURTYARD — First Push
	# ═══════════════════════════════════════

	# Left slum block framing the courtyard
	_place_box(Vector3(-9, 3.5, -2), Vector3(8, 7, 10), C)
	_place_box(Vector3(-12, 5, 1), Vector3(5, 10, 7), D)
	_place_box(Vector3(-7, 2.5, 3), Vector3(5, 5, 6), C)

	# Right slum block
	_place_box(Vector3(9, 3, -3), Vector3(7, 6, 9), D)
	_place_box(Vector3(12, 4.5, 0), Vector3(5, 9, 6), C)

	# Ground girder — the first thing to push off
	_place_girder(Vector3(0, 0.25, -8), Vector3(3, 0.5, 3), 500.0)
	_place_sign(Vector3(0, 2.5, -5.5), "There's metal beneath you.\n" +
		"Hold [Space] to Push against it.\n" +
		"Your weight does the rest.")

	# Wide street running forward — buildings frame the path
	_place_box(Vector3(-10, 4, -18), Vector3(6, 8, 8), D)
	_place_box(Vector3(-8, 3, -14), Vector3(4, 6, 5), C)
	_place_box(Vector3(10, 5, -16), Vector3(7, 10, 6), C)
	_place_box(Vector3(8, 3.5, -20), Vector3(5, 7, 5), D)

	# ── Target rooftops 25m ahead ──
	_place_box(Vector3(-4, 5, -35), Vector3(12, 10, 10), C)
	_place_box(Vector3(-7, 7, -38), Vector3(6, 14, 7), D)
	_place_box(Vector3(3, 4.5, -33), Vector3(5, 9, 6), C)
	_place_box(Vector3(6, 6, -37), Vector3(8, 12, 8), D)
	_place_girder(Vector3(-4, 10.5, -35), Vector3(6, 0.4, 0.4), 400.0)

	# Recovery girder halfway
	_place_box(Vector3(0, 2, -22), Vector3(3, 4, 3), D)
	_place_girder(Vector3(0, 4.5, -22), Vector3(2.5, 0.35, 0.35), 250.0)

	# ═══════════════════════════════════════
	# SECTION B: THE ROOFTOPS — Pull Training
	# ═══════════════════════════════════════

	_place_sign(Vector3(-4, 12.5, -33), "See that girder up ahead?\n" +
		"Hold [E] to Pull yourself toward it.\n" +
		"Try jumping first, then Pull.")

	# Wide open gap (35m of flight) — tall cluster ahead with pull girder
	_place_box(Vector3(-3, 10, -70), Vector3(14, 20, 12), D)
	_place_box(Vector3(-8, 9, -66), Vector3(6, 18, 7), C)
	_place_box(Vector3(5, 8, -73), Vector3(7, 16, 8), C)
	_place_box(Vector3(-5, 12, -64), Vector3(5, 24, 6), D)
	# Pull girder on near face — player reaches ~18m during flight
	_place_girder(Vector3(-3, 22, -64), Vector3(6, 0.5, 0.5), 500.0)
	# Landing girder on rooftop
	_place_girder(Vector3(-3, 20.5, -70), Vector3(5, 0.4, 0.4), 400.0)

	# Mass comparison anchors
	_place_girder(Vector3(5, 17, -70), Vector3(2, 2, 2), 800.0)
	_place_girder(Vector3(-8, 18, -66), Vector3(0.2, 0.2, 4), 50.0)

	# Recovery mid-gap
	_place_box(Vector3(2, 4, -52), Vector3(4, 8, 4), D)
	_place_girder(Vector3(2, 8.5, -52), Vector3(2.5, 0.35, 0.35), 250.0)

	# ═══════════════════════════════════════
	# SECTION C: MIST VISION
	# ═══════════════════════════════════════

	_place_sign(Vector3(-3, 22.5, -68), "There's metal behind that wall.\n" +
		"Press [Tab] to toggle mist-vision.\n" +
		"Blue lines show you where the metal is,\n" +
		"even through solid stone.")

	# Solid wall blocking forward view
	_place_box(Vector3(-3, 16, -82), Vector3(22, 24, 2), D)
	_place_box(Vector3(-12, 14, -82), Vector3(8, 20, 2), C)

	# Hidden girders behind the wall — only visible with mist vision
	_place_girder(Vector3(-4, 26, -88), Vector3(0.4, 0.4, 4), 350.0)
	_place_girder(Vector3(4, 30, -95), Vector3(4, 0.4, 0.4), 350.0)

	# Building cluster behind the wall
	_place_box(Vector3(4, 14, -98), Vector3(12, 28, 10), D)
	_place_box(Vector3(-3, 12, -95), Vector3(8, 24, 7), C)
	_place_box(Vector3(9, 13, -102), Vector3(6, 26, 6), C)
	_place_girder(Vector3(4, 28.5, -98), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery girder on near face of wall
	_place_girder(Vector3(5, 18, -81), Vector3(3, 0.35, 0.35), 300.0)

	# ── Goal ──
	_place_goal(Vector3(4, 32, -98), Vector3(8, 0.5, 8))
	_place_sign(Vector3(4, 35, -98), "Not bad.\n" +
		"The canals are next.", 20)

	# ── Boundary + city backdrop ──
	_build_boundary(Vector3(0, 0, -50), 75.0)
	_build_city_backdrop(Vector3(0, 0, -50), 75.0, 140.0, 65, 14.0, 0.08)
