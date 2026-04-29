class_name Level2Canals
extends LevelBase

func build() -> void:
	level_name = "The Canal District"
	spawn_point = Vector3(0, 1.2, 0)

	var C := Color(0.36, 0.34, 0.31)
	var D := Color(0.32, 0.30, 0.28)

	_place_sign(Vector3(0, 3, -3), "THE CANAL DISTRICT\n\n" +
		"No girders out here. You'll have to\n" +
		"make your own anchors.\n\n" +
		"[Q] Drop a coin. It sticks to the ground.\n" +
		"[F] Coinshot. Fires a coin where you're looking.")

	# ═══════════════════════════════════════
	# SECTION A: THE DOCKS — Coin Drop Training
	# ═══════════════════════════════════════

	# Starting dock buildings — long and low
	_place_box(Vector3(-6, 3, -5), Vector3(8, 6, 8), C)
	_place_box(Vector3(-9, 4, -3), Vector3(4, 8, 5), D)
	_place_box(Vector3(5, 3.5, -6), Vector3(6, 7, 6), D)
	_place_box(Vector3(8, 2.5, -4), Vector3(4, 5, 5), C)
	_place_girder(Vector3(0, 5, -6), Vector3(4, 0.4, 0.4), 400.0)

	_place_sign(Vector3(0, 7, -4.5), "Nothing to push off of up here.\n" +
		"Press [Q] to drop a coin at your feet.\n" +
		"Once it hits the ground, Push off it.")

	# First target — building across 30m gap, NO girder on top
	_place_box(Vector3(-4, 5, -38), Vector3(10, 10, 8), D)
	_place_box(Vector3(-7, 4.5, -35), Vector3(4, 9, 5), C)
	_place_box(Vector3(2, 4, -40), Vector3(5, 8, 5), C)
	# Nook on near wall for orientation
	_place_nook(Vector3(-4, 10.5, -34), Vector3(2, 0.25, 1.5))

	# Recovery pillar mid-gap
	_place_box(Vector3(0, 3, -22), Vector3(3, 6, 3), D)
	_place_girder(Vector3(0, 6.5, -22), Vector3(2, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION B: THE CANALS — Coinshot + Bridge Pillars
	# ═══════════════════════════════════════

	# From the rooftop, the canal stretches ahead — wide and open
	_place_girder(Vector3(-4, 10.5, -38), Vector3(4, 0.4, 0.4), 400.0)

	_place_sign(Vector3(-4, 12.5, -36.5), "Long way across.\n" +
		"Try [F] to fire a coin at those bridge pillars.\n" +
		"Then Push [Space] off it to cross.\n" +
		"Or drop [Q] and Push. Up to you.")

	# Bridge pillar 1 — 25m ahead
	_place_box(Vector3(0, 7, -62), Vector3(3, 14, 3), D)
	_place_nook(Vector3(0, 11, -60.5), Vector3(2, 0.25, 1.5))
	_place_girder(Vector3(0, 10, -62), Vector3(0.35, 0.35, 3), 250.0)

	# Bridge pillar 2 — 25m further, offset right
	_place_box(Vector3(8, 8, -86), Vector3(3, 16, 3), D)
	_place_nook(Vector3(8, 13, -84.5), Vector3(2, 0.25, 1.5))
	_place_girder(Vector3(8, 12, -86), Vector3(0.35, 0.35, 3), 250.0)

	# Long building on far bank — the landing zone
	_place_box(Vector3(3, 8, -110), Vector3(14, 16, 10), C)
	_place_box(Vector3(-3, 7, -107), Vector3(6, 14, 6), D)
	_place_box(Vector3(10, 7, -113), Vector3(5, 14, 5), D)
	_place_girder(Vector3(3, 16.5, -110), Vector3(5, 0.4, 0.4), 400.0)
	_place_girder(Vector3(3, 22, -110), Vector3(0.4, 0.4, 5), 400.0)

	# Recovery girder along canal wall
	_place_box(Vector3(-8, 3, -75), Vector3(3, 6, 3), D)
	_place_girder(Vector3(-8, 6.5, -75), Vector3(2, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION C: FALLING ANCHORS
	# ═══════════════════════════════════════

	_place_sign(Vector3(3, 18.5, -108.5), "That orange beam is rusted through.\n" +
		"Push off it before it gives way.")

	# Tall tower with falling anchor
	_place_box(Vector3(14, 12, -125), Vector3(6, 24, 6), D)
	_place_box(Vector3(16, 11, -122), Vector3(4, 22, 4), C)
	_place_falling_anchor(Vector3(14, 24.5, -125), Vector3(4, 0.4, 0.4), 300.0, 1.5)

	# Landing cluster — generous
	_place_box(Vector3(5, 14, -145), Vector3(12, 28, 10), C)
	_place_box(Vector3(9, 13, -148), Vector3(6, 26, 5), D)
	_place_box(Vector3(1, 12, -142), Vector3(5, 24, 5), D)
	_place_girder(Vector3(5, 28.5, -145), Vector3(4, 0.4, 0.4), 400.0)

	# Recovery
	_place_girder(Vector3(10, 18, -135), Vector3(2.5, 0.35, 0.35), 200.0)

	# ── Goal ──
	_place_goal(Vector3(5, 32, -145), Vector3(8, 0.5, 8))
	_place_sign(Vector3(5, 35, -145), "Getting the hang of it.\n" +
		"The keeps are up ahead.", 20)

	# ── Boundary + city backdrop ──
	_build_boundary(Vector3(3, 0, -72), 90.0)
	_build_city_backdrop(Vector3(3, 0, -72), 90.0, 160.0, 55, 16.0, 0.08)
