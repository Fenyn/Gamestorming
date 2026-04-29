class_name Level4Spires
extends LevelBase

func build() -> void:
	level_name = "The Iron Spires"
	spawn_point = Vector3(0, 1.2, 0)

	var S := Color(0.42, 0.40, 0.45)
	var D := Color(0.34, 0.32, 0.30)
	var P := Color(0.48, 0.46, 0.50)

	_place_sign(Vector3(0, 3, -3), "THE IRON SPIRES\n\n" +
		"Tall metal. No stairs.\n" +
		"You'll have to fly.")

	# ═══════════════════════════════════════
	# SECTION A: SLINGSHOT TUTORIAL
	# ═══════════════════════════════════════

	# Starting base — wide keep with decorative spires
	_place_box(Vector3(0, 3, -8), Vector3(12, 6, 10), D)
	_place_box(Vector3(-8, 6, -6), Vector3(2, 12, 2), S)
	_place_pyramid(Vector3(-8, 12.5, -6), 2.5, 3.5, P)
	_place_box(Vector3(8, 5, -10), Vector3(2, 10, 2), S)
	_place_pyramid(Vector3(8, 10.5, -10), 2.5, 3.0, P)
	_place_girder(Vector3(0, 6.5, -8), Vector3(4, 0.4, 0.4), 400.0)

	_place_sign(Vector3(0, 8.5, -6), "THE SLINGSHOT\n\n" +
		"Push off the left wall to fly toward the arch.\n" +
		"Then Pull [E] the arch anchor as you pass it.\n\n" +
		"High burn to build speed.\n" +
		"Low burn to swing wide.\n" +
		"Let go when you're aimed at the landing.")

	# Launch wall on the left — push off this to fly right
	_place_box(Vector3(-8, 5, -14), Vector3(3, 14, 6), D)
	_place_girder(Vector3(-7, 10, -14), Vector3(0.35, 0.35, 4), 500.0)

	# The arch — two spires 45m to the right with a beam between
	_place_box(Vector3(18, 10, -25), Vector3(2.5, 20, 2.5), S)
	_place_pyramid(Vector3(18, 20.5, -25), 3.0, 4.0, P)
	_place_box(Vector3(26, 10, -25), Vector3(2.5, 20, 2.5), S)
	_place_pyramid(Vector3(26, 20.5, -25), 3.0, 4.0, P)
	_place_box(Vector3(22, 21, -25), Vector3(10, 1.5, 3), D)
	_place_girder(Vector3(22, 18, -25), Vector3(7, 0.5, 0.5), 600.0)

	# Landing — generous platform 30m past the arch
	_place_box(Vector3(34, 12, -35), Vector3(12, 24, 10), D)
	_place_box(Vector3(34, 25, -35), Vector3(8, 2, 7), S)
	_place_box(Vector3(38, 10, -32), Vector3(2, 18, 2), S)
	_place_pyramid(Vector3(38, 19.5, -32), 2.5, 3.5, P)
	_place_girder(Vector3(34, 26.5, -35), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery below the arch
	_place_box(Vector3(22, 5, -20), Vector3(5, 10, 5), D)
	_place_girder(Vector3(22, 10.5, -20), Vector3(3, 0.35, 0.35), 250.0)

	# ═══════════════════════════════════════
	# SECTION B: TIGHTER SLINGSHOT
	# ═══════════════════════════════════════

	_place_sign(Vector3(34, 28.5, -33.5), "Same thing, tighter gap.\n" +
		"Smaller landing this time.")

	# Second arch — taller, tighter, 50m to the left
	_place_box(Vector3(10, 24, -50), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(10, 36.5, -50), 2.5, 3.5, P)
	_place_box(Vector3(16, 24, -50), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(16, 36.5, -50), 2.5, 3.5, P)
	_place_girder(Vector3(13, 34, -50), Vector3(6, 0.5, 0.5), 500.0)

	# Smaller landing platform
	_place_box(Vector3(-2, 18, -60), Vector3(8, 36, 8), D)
	_place_box(Vector3(-2, 37, -60), Vector3(5, 2, 5), S)
	_place_girder(Vector3(-2, 38.5, -60), Vector3(4, 0.35, 0.35), 400.0)

	# Recovery
	_place_girder(Vector3(13, 28, -48), Vector3(0.35, 0.35, 4), 250.0)

	# ═══════════════════════════════════════
	# SECTION C: SLINGSHOT + FALLING ANCHOR
	# ═══════════════════════════════════════

	_place_sign(Vector3(-2, 40.5, -58.5), "That orange anchor is about to break.\n" +
		"One slingshot. Don't miss.")

	# Launch wall
	_place_box(Vector3(-8, 36, -60), Vector3(3, 10, 4), D)
	_place_girder(Vector3(-7, 42, -60), Vector3(0.35, 0.35, 3), 400.0)

	# Crumbling arch with falling anchor — 40m right
	_place_box(Vector3(22, 34, -72), Vector3(2, 18, 2), S)
	_place_pyramid(Vector3(22, 43.5, -72), 2.5, 3.0, P)
	_place_falling_anchor(Vector3(22, 42, -72), Vector3(5, 0.5, 0.5), 400.0, 2.5)

	# Final spire cluster with generous landing
	_place_box(Vector3(36, 26, -82), Vector3(10, 52, 10), D)
	_place_box(Vector3(36, 53, -82), Vector3(7, 2, 7), S)
	_place_box(Vector3(40, 22, -78), Vector3(2, 16, 2), S)
	_place_pyramid(Vector3(40, 30.5, -78), 2.5, 3.5, P)
	_place_box(Vector3(32, 20, -86), Vector3(2, 14, 2), S)
	_place_pyramid(Vector3(32, 27.5, -86), 2.5, 3.0, P)
	_place_girder(Vector3(36, 54.5, -82), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery
	_place_girder(Vector3(22, 36, -74), Vector3(2.5, 0.35, 0.35), 250.0)

	# ── Goal ──
	_place_goal(Vector3(36, 58, -82), Vector3(9, 0.5, 9))
	_place_pyramid(Vector3(36, 62, -82), 4.0, 6.0, COL_GOAL)
	_place_sign(Vector3(36, 62, -82), "One more to go.", 20)

	# ── Boundary + city backdrop ──
	_build_boundary(Vector3(16, 0, -45), 65.0)
	_build_city_backdrop(Vector3(16, 0, -45), 65.0, 130.0, 50, 40.0, 0.35)
