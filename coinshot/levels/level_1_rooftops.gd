class_name Level1Rooftops
extends LevelBase

func build() -> void:
	level_name = "The Ash Yard"
	spawn_point = Vector3(0, 1.2, 0)

	var C := Color(0.36, 0.34, 0.31)
	var D := Color(0.32, 0.30, 0.28)

	_place_sign(Vector3(0, 3.5, -3), "THE ASH YARD\n\n" +
		"[LMB] Lock  [Space] Push  [E] Pull\n" +
		"[Q] Drop coin  [F] Coinshot  [Scroll] Burn\n" +
		"[Tab] Mist-vision  [R] Respawn  [\\[] / [\\]] Levels")

	# ═══════════════════════════════════════
	# SECTION A: FIRST PUSH
	# ═══════════════���═══════════════════════

	_place_box(Vector3(-8, 3.5, -4), Vector3(6, 7, 8), C)
	_place_box(Vector3(8, 3.5, -4), Vector3(6, 7, 8), C)

	_place_girder(Vector3(0, 0.25, -6), Vector3(3, 0.5, 3), 500.0)
	_place_sign(Vector3(0, 2.5, -4), "Iron in the ground.\nLock it. Push.")

	_place_box(Vector3(0, 6, -20), Vector3(12, 12, 8), D)
	_place_box(Vector3(-4, 7.5, -18), Vector3(4, 15, 5), C)
	_place_girder(Vector3(0, 12.5, -20), Vector3(5, 0.4, 0.4), 400.0)

	# ═══════════════════════════════════════
	# SECTION B: WALL PUSH
	# ���══════════════════════════════════════

	_place_sign(Vector3(2, 14.5, -18), "Walls work too.")

	_place_box(Vector3(-8, 10, -25), Vector3(4, 20, 8), D)
	_place_girder(Vector3(-6, 14, -25), Vector3(0.35, 0.35, 5), 500.0)

	_place_box(Vector3(22, 8, -28), Vector3(10, 16, 8), C)
	_place_box(Vector3(24, 9, -26), Vector3(4, 18, 4), D)
	_place_girder(Vector3(22, 16.5, -28), Vector3(4, 0.4, 0.4), 400.0)

	# ═══════════���════════════════════════���══
	# SECTION C: THE PULL
	# ══��════════════════════════════════════

	_place_sign(Vector3(22, 18.5, -26), "Lock the iron ahead. Pull.")

	_place_box(Vector3(20, 12, -62), Vector3(12, 24, 10), D)
	_place_box(Vector3(16, 11, -59), Vector3(4, 22, 5), C)
	_place_box(Vector3(24, 11, -65), Vector3(5, 22, 5), C)
	_place_girder(Vector3(20, 22, -57), Vector3(5, 0.5, 0.5), 500.0)
	_place_girder(Vector3(20, 24.5, -62), Vector3(4, 0.4, 0.4), 400.0)

	_place_box(Vector3(21, 5, -44), Vector3(4, 10, 4), D)
	_place_girder(Vector3(21, 10.5, -44), Vector3(2.5, 0.35, 0.35), 250.0)

	# ════════���═════════════════════════��════
	# SECTION D: PUSH + PULL COMBO
	# ══��══════════��═════════════════════════

	_place_sign(Vector3(20, 26.5, -60), "Push to launch. Pull mid-flight.\nReach the top.")

	_place_box(Vector3(14, 18, -95), Vector3(12, 36, 12), D)
	_place_box(Vector3(14, 37, -95), Vector3(8, 2, 8), C)
	_place_girder(Vector3(14, 32, -89), Vector3(5, 0.5, 0.5), 500.0)
	_place_girder(Vector3(14, 38.5, -95), Vector3(4, 0.4, 0.4), 400.0)

	_place_box(Vector3(18, 8, -78), Vector3(4, 16, 4), D)
	_place_girder(Vector3(18, 16.5, -78), Vector3(2.5, 0.35, 0.35), 250.0)

	# ── Goal ──
	_place_goal(Vector3(14, 42, -95), Vector3(8, 0.5, 8))
	_place_sign(Vector3(14, 45, -95), "The arches are next.", 20)

	# ── Boundary + backdrop ──
	_build_boundary(Vector3(10, 0, -48), 80.0)
	_build_city_backdrop(Vector3(10, 0, -48), 80.0, 150.0, 55, 15.0, 0.1)
