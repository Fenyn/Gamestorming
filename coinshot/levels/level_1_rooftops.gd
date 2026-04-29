class_name Level1Rooftops
extends LevelBase

func build() -> void:
	level_name = "The Ash Yard"
	spawn_point = Vector3(0, 1.2, 0)

	var C := Color(0.36, 0.34, 0.31)
	var D := Color(0.32, 0.30, 0.28)

	# ── Spawn floor ──
	_place_platform(Vector3(0, -0.25, -3), Vector3(22, 0.5, 22))

	# ── Title ──
	_place_sign(Vector3(0, 4, -2), "THE ASH YARD", 28)

	_place_sign(Vector3(-5, 2.5, -5), "[LMB] Lock  [Space] Push  [E] Pull\n" +
		"[Tab] Mist-vision  [R] Respawn\n" +
		"[\\[] / [\\]] Switch levels", 14)

	# ═══════════════════════════════════════
	# SECTION A: LOCK AND PUSH
	# ═══════════════════════════════════════

	_place_box(Vector3(-8, 3.5, -4), Vector3(6, 7, 8), C)
	_place_box(Vector3(8, 3.5, -4), Vector3(6, 7, 8), C)
	_place_box(Vector3(0, 3, -12), Vector3(14, 6, 3), D)

	_place_girder(Vector3(0, 0.25, -6), Vector3(3, 0.5, 3), 500.0)
	_place_sign(Vector3(3, 2.5, -5), "[LMB] to lock an anchor.\n[Space] to push away from it.")
	_place_sign(Vector3(-3, 2, -8), "Blue lines lead to metal.\n[Tab] to toggle.", 14)

	_place_box(Vector3(0, 6, -22), Vector3(14, 12, 10), D)
	_place_box(Vector3(-4, 7.5, -20), Vector3(4, 15, 5), C)
	_place_girder(Vector3(0, 12.5, -22), Vector3(5, 0.4, 0.4), 400.0)

	# ═══════════════════════════════════════
	# SECTION B: DIRECTIONAL PUSH
	# ═══════════════════════════════════════

	_place_sign(Vector3(2, 14.5, -20), "Push sends you away from the anchor.\nUse the wall to launch across the gap.")

	_place_box(Vector3(-8, 10, -27), Vector3(4, 20, 8), D)
	_place_girder(Vector3(-6, 14, -27), Vector3(0.35, 0.35, 5), 500.0)

	_place_box(Vector3(22, 8, -30), Vector3(10, 16, 10), C)
	_place_box(Vector3(24, 9, -28), Vector3(4, 18, 4), D)
	_place_girder(Vector3(22, 16.5, -30), Vector3(5, 0.4, 0.4), 400.0)

	# ═══════════════════════════════════════
	# SECTION C: PULL
	# ═══════════════════════════════════════

	_place_sign(Vector3(22, 18.5, -28), "[E] pulls you toward an anchor.\nLock the iron ahead and pull.")

	_place_box(Vector3(20, 12, -64), Vector3(14, 24, 12), D)
	_place_box(Vector3(16, 11, -61), Vector3(4, 22, 5), C)
	_place_box(Vector3(24, 11, -67), Vector3(5, 22, 5), C)
	_place_girder(Vector3(20, 22, -58), Vector3(5, 0.5, 0.5), 500.0)
	_place_girder(Vector3(20, 24.5, -64), Vector3(4, 0.4, 0.4), 400.0)

	_place_box(Vector3(21, 5, -46), Vector3(4, 10, 4), D)
	_place_girder(Vector3(21, 10.5, -46), Vector3(2.5, 0.35, 0.35), 250.0)

	# ═══════════════════════════════════════
	# SECTION D: PUSH + PULL COMBO
	# ═══════════════════════════════════════

	_place_sign(Vector3(20, 26.5, -62), "Push to launch. Pull mid-flight.\nChain them together.")

	_place_box(Vector3(14, 18, -98), Vector3(14, 36, 14), D)
	_place_box(Vector3(14, 37, -98), Vector3(10, 2, 10), C)
	_place_girder(Vector3(14, 32, -91), Vector3(6, 0.5, 0.5), 500.0)
	_place_girder(Vector3(14, 38.5, -98), Vector3(5, 0.4, 0.4), 400.0)

	_place_box(Vector3(18, 8, -80), Vector3(4, 16, 4), D)
	_place_girder(Vector3(18, 16.5, -80), Vector3(2.5, 0.35, 0.35), 250.0)

	# ── Goal ──
	_place_goal(Vector3(14, 42, -98), Vector3(8, 0.5, 8))
	_place_sign(Vector3(14, 45, -98), "The arches are next.", 20)

	# ── Checkpoints ──
	_place_checkpoint(Vector3(0, 0, -5))
	_place_checkpoint(Vector3(0, 12, -22))
	_place_checkpoint(Vector3(22, 16, -30))
	_place_checkpoint(Vector3(20, 24, -64))

	# ── Boundary + backdrop ──
	_build_boundary(Vector3(12, 0, -50), 80.0)
	_build_city_backdrop(Vector3(12, 0, -50), 80.0, 150.0, 55, 15.0, 0.1)
