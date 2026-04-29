class_name Level3Keeps
extends LevelBase

func build() -> void:
	level_name = "The Steel Run"
	spawn_point = Vector3(0, 23.2, 0)

	var C := Color(0.36, 0.34, 0.31)
	var D := Color(0.32, 0.30, 0.28)
	var W := Color(0.38, 0.36, 0.33)

	# Starting keep — elevated
	_place_box(Vector3(0, 10, 0), Vector3(12, 20, 10), D)
	_place_box(Vector3(0, 21, 0), Vector3(8, 2, 7), C)
	_place_girder(Vector3(0, 22.5, 0), Vector3(5, 0.4, 0.4), 400.0)

	_place_sign(Vector3(0, 25, 3), "THE STEEL RUN\n\n" +
		"Pull, release, pull the next.\nDon't slow down.")

	# Back wall for initial push launch
	_place_box(Vector3(0, 18, 7), Vector3(10, 10, 3), D)
	_place_girder(Vector3(0, 22, 7), Vector3(6, 0.5, 0.5), 500.0)

	# ═══════════════════════════════════════
	# SECTION A: THE LINE — Straight Pull Chain
	# ═══════════════════════════════════════

	_place_sign(Vector3(0, 25, -2), "Pull toward the iron.\nRelease before you stall. Chain the next.")

	var line_z := [-20.0, -38.0, -56.0, -74.0, -92.0]
	var line_y := [20.0, 19.0, 18.0, 17.0, 16.0]
	for i in range(line_z.size()):
		_place_box(Vector3(0, line_y[i] - 5, line_z[i]), Vector3(3, 4, 3), W)
		_place_girder(Vector3(0, line_y[i], line_z[i]), Vector3(3, 0.4, 0.4), 400.0)

	# Landing after chain
	_place_box(Vector3(0, 8, -114), Vector3(14, 16, 12), D)
	_place_box(Vector3(0, 17, -114), Vector3(10, 2, 9), C)
	_place_girder(Vector3(0, 18.5, -114), Vector3(5, 0.4, 0.4), 400.0)
	_place_girder(Vector3(0, 16, -108), Vector3(4, 0.5, 0.5), 400.0)

	# Recovery
	_place_box(Vector3(-7, 4, -56), Vector3(3, 8, 3), D)
	_place_girder(Vector3(-7, 8.5, -56), Vector3(2, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION B: THE SLALOM — Zigzag Pull Chain
	# ═══════════════════════════════════════

	_place_sign(Vector3(0, 20.5, -112), "Now with curves.\nPull yourself through the zigzag.")

	var slalom_x := [16.0, -16.0, 18.0, -14.0, 16.0]
	var slalom_y := [18.0, 16.0, 20.0, 18.0, 22.0]
	var slalom_z := [-134.0, -154.0, -174.0, -194.0, -214.0]
	for i in range(slalom_x.size()):
		_place_box(Vector3(slalom_x[i], slalom_y[i] - 6, slalom_z[i]), Vector3(4, 5, 4), W)
		_place_girder(Vector3(slalom_x[i], slalom_y[i], slalom_z[i]), Vector3(3, 0.4, 0.4), 400.0)

	# Landing
	_place_box(Vector3(0, 10, -238), Vector3(14, 20, 12), D)
	_place_box(Vector3(0, 21, -238), Vector3(10, 2, 9), C)
	_place_girder(Vector3(0, 22.5, -238), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery
	_place_box(Vector3(0, 5, -174), Vector3(4, 10, 4), D)
	_place_girder(Vector3(0, 10.5, -174), Vector3(2.5, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION C: THE REDIRECT — Speed into Vertical
	# ═══════════════════════════════════════

	_place_sign(Vector3(0, 24.5, -236), "Build speed. Redirect upward.\nAll the way to the top.")

	# Speed-building pull anchors leading toward the tower
	_place_girder(Vector3(0, 20, -255), Vector3(3, 0.4, 0.4), 400.0)
	_place_girder(Vector3(0, 18, -272), Vector3(3, 0.4, 0.4), 400.0)

	# The tower — redirect horizontal speed into vertical climb
	_place_box(Vector3(0, 20, -295), Vector3(14, 40, 14), D)
	_place_box(Vector3(0, 41, -295), Vector3(10, 2, 10), C)
	# Mid-height pull anchor on near face (approach redirect)
	_place_girder(Vector3(0, 34, -288), Vector3(6, 0.5, 0.5), 500.0)
	# High pull anchor
	_place_girder(Vector3(0, 42, -288), Vector3(6, 0.5, 0.5), 500.0)
	_place_girder(Vector3(0, 43.5, -295), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery
	_place_box(Vector3(-6, 6, -272), Vector3(3, 12, 3), D)
	_place_girder(Vector3(-6, 12.5, -272), Vector3(2.5, 0.35, 0.35), 200.0)

	# ── Goal ──
	_place_goal(Vector3(0, 47, -295), Vector3(8, 0.5, 8))
	_place_sign(Vector3(0, 50, -295), "Fast enough.\nNow hold still.", 20)

	# ── Boundary + backdrop ──
	_build_boundary(Vector3(0, 0, -148), 170.0)
	_build_city_backdrop(Vector3(0, 0, -148), 170.0, 230.0, 60, 25.0, 0.15)
