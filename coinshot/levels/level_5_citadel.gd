class_name Level5Citadel
extends LevelBase

func build() -> void:
	level_name = "The Black Citadel"
	spawn_point = Vector3(0, 1.2, 0)

	var B := Color(0.24, 0.22, 0.20)
	var D := Color(0.28, 0.26, 0.24)
	var S := Color(0.35, 0.33, 0.38)
	var P := Color(0.40, 0.38, 0.42)

	_place_sign(Vector3(0, 3, -3), "THE BLACK CITADEL\n\n" +
		"No more signs after this one.\n" +
		"Get to the top.", 28)

	# ═══════════════════════════════════════
	# THE APPROACH — imposing dark walls
	# ═══════════════════════════════════════

	_place_box(Vector3(-8, 6, -8), Vector3(5, 12, 10), B)
	_place_box(Vector3(8, 6, -8), Vector3(5, 12, 10), B)
	_place_box(Vector3(0, 3, -10), Vector3(10, 6, 8), D)
	_place_girder(Vector3(0, 6.5, -10), Vector3(4, 0.5, 0.5), 500.0)

	# ═══════════════════════════════════════
	# SECTION 1: THE OUTER GATE — Moving Anchor
	# ═══════════════════════════════════════

	# Massive gate towers — 35m ahead
	_place_box(Vector3(-10, 12, -45), Vector3(6, 24, 12), B)
	_place_box(Vector3(-10, 25, -45), Vector3(4, 2, 10), D)
	_place_box(Vector3(10, 12, -45), Vector3(6, 24, 12), B)
	_place_box(Vector3(10, 25, -45), Vector3(4, 2, 10), D)
	# Spire caps
	_place_box(Vector3(-10, 14, -40), Vector3(2, 12, 2), S)
	_place_pyramid(Vector3(-10, 20.5, -40), 2.5, 3.5, P)
	_place_box(Vector3(10, 14, -40), Vector3(2, 12, 2), S)
	_place_pyramid(Vector3(10, 20.5, -40), 2.5, 3.5, P)

	# Moving anchor between the gate towers
	_place_moving_anchor(
		Vector3(0, 14, -45), Vector3(4, 0.4, 0.4), 400.0,
		Vector3(0, 10, 0), 4.5
	)
	_place_nook(Vector3(-6.5, 12, -42), Vector3(1.5, 0.25, 1.5))

	# Courtyard beyond the gate — wide open space
	_place_box(Vector3(0, 10, -75), Vector3(16, 20, 10), D)
	_place_box(Vector3(0, 21, -75), Vector3(12, 2, 8), B)
	_place_girder(Vector3(0, 22.5, -75), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery in the gate gap
	_place_box(Vector3(0, 4, -60), Vector3(4, 8, 4), D)
	_place_girder(Vector3(0, 8.5, -60), Vector3(2.5, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION 2: THE HIDDEN PATH — Mist Vision
	# ═══════════════════════════════════════

	# Solid wall blocking forward view
	_place_box(Vector3(0, 18, -88), Vector3(20, 12, 2), B)

	# Hidden girders behind the wall
	_place_girder(Vector3(-5, 28, -95), Vector3(0.4, 0.4, 5), 350.0)
	_place_girder(Vector3(4, 32, -105), Vector3(4, 0.4, 0.4), 350.0)

	# Building behind the wall
	_place_box(Vector3(4, 16, -108), Vector3(10, 32, 8), D)
	_place_box(Vector3(4, 33, -108), Vector3(6, 2, 6), B)
	_place_girder(Vector3(4, 34.5, -108), Vector3(4, 0.35, 0.35), 350.0)

	# ═══════════════════════════════════════
	# SECTION 3: THE CRUMBLING STAIR — Falling Anchors
	# ═══════════════════════════════════════

	# Sequence of towers with falling anchors — 25m apart
	_place_box(Vector3(-6, 26, -125), Vector3(4, 12, 4), D)
	_place_falling_anchor(Vector3(-6, 33, -125), Vector3(3, 0.4, 0.4), 300.0, 2.0)

	_place_box(Vector3(4, 30, -148), Vector3(4, 10, 4), D)
	_place_falling_anchor(Vector3(4, 36, -148), Vector3(3, 0.4, 0.4), 300.0, 2.0)

	_place_box(Vector3(-4, 34, -170), Vector3(4, 10, 4), D)
	_place_falling_anchor(Vector3(-4, 40, -170), Vector3(3, 0.4, 0.4), 300.0, 2.0)

	# Recovery
	_place_girder(Vector3(0, 30, -137), Vector3(2.5, 0.35, 0.35), 200.0)
	_place_girder(Vector3(0, 34, -160), Vector3(2.5, 0.35, 0.35), 200.0)

	# Stable platform after the crumbling stair
	_place_box(Vector3(0, 24, -190), Vector3(10, 48, 10), B)
	_place_box(Vector3(0, 49, -190), Vector3(7, 2, 7), D)
	_place_girder(Vector3(0, 50.5, -190), Vector3(4, 0.4, 0.4), 400.0)

	# ═══════════════════════════════════════
	# SECTION 4: THE SLINGSHOT GAUNTLET
	# ═══════════════════════════════════════

	# Launch wall
	_place_box(Vector3(-8, 46, -190), Vector3(3, 10, 5), D)
	_place_girder(Vector3(-7, 52, -190), Vector3(0.35, 0.35, 4), 500.0)

	# First arch — 40m to the right
	_place_box(Vector3(22, 46, -200), Vector3(2, 18, 2), S)
	_place_pyramid(Vector3(22, 55.5, -200), 2.5, 3.5, P)
	_place_box(Vector3(28, 46, -200), Vector3(2, 18, 2), S)
	_place_pyramid(Vector3(28, 55.5, -200), 2.5, 3.5, P)
	_place_girder(Vector3(25, 54, -200), Vector3(6, 0.5, 0.5), 500.0)

	# Mid-rest platform
	_place_box(Vector3(36, 28, -210), Vector3(8, 56, 8), D)
	_place_box(Vector3(36, 57, -210), Vector3(5, 2, 5), B)
	_place_girder(Vector3(36, 58.5, -210), Vector3(4, 0.35, 0.35), 350.0)

	# Recovery
	_place_girder(Vector3(25, 48, -198), Vector3(2.5, 0.35, 0.35), 200.0)

	# Second arch — moving slingshot anchor
	_place_box(Vector3(20, 54, -220), Vector3(2, 14, 2), S)
	_place_pyramid(Vector3(20, 61.5, -220), 2.5, 3.0, P)
	_place_box(Vector3(26, 54, -220), Vector3(2, 14, 2), S)
	_place_pyramid(Vector3(26, 61.5, -220), 2.5, 3.0, P)
	_place_moving_anchor(
		Vector3(23, 58, -220), Vector3(5, 0.5, 0.5), 500.0,
		Vector3(0, 5, 0), 5.0
	)

	_place_girder(Vector3(22, 54, -214), Vector3(2.5, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# THE SUMMIT — Central Tower
	# ═══════════════════════════════════════

	_place_box(Vector3(6, 34, -240), Vector3(14, 68, 14), B)
	_place_box(Vector3(6, 69, -240), Vector3(10, 3, 10), D)
	_place_box(Vector3(6, 73, -240), Vector3(6, 3, 6), S)
	_place_girder(Vector3(6, 75, -240), Vector3(6, 0.4, 0.4), 600.0)

	# Flanking spires
	_place_box(Vector3(-4, 38, -234), Vector3(2, 28, 2), S)
	_place_pyramid(Vector3(-4, 52.5, -234), 2.5, 4.5, P)
	_place_box(Vector3(16, 36, -246), Vector3(2, 26, 2), S)
	_place_pyramid(Vector3(16, 49.5, -246), 2.5, 4.0, P)
	_place_box(Vector3(0, 32, -248), Vector3(2, 22, 2), S)
	_place_pyramid(Vector3(0, 43.5, -248), 2.5, 3.5, P)

	# ── Goal ──
	_place_goal(Vector3(6, 78, -240), Vector3(10, 0.5, 10))
	_place_pyramid(Vector3(6, 84, -240), 5.0, 7.0, COL_GOAL)

	var victory := Label3D.new()
	victory.text = "THE MISTS ARE YOURS"
	victory.global_position = Vector3(6, 88, -240)
	victory.font_size = 56
	victory.modulate = Color(1, 0.85, 0.3)
	victory.outline_size = 12
	victory.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	victory.no_depth_test = true
	add_child(victory)

	# ── Boundary + city backdrop ──
	_build_boundary(Vector3(6, 0, -120), 140.0)
	_build_city_backdrop(Vector3(6, 0, -120), 140.0, 200.0, 65, 50.0, 0.35)
