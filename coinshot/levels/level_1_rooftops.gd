class_name Level1Rooftops
extends LevelBase

func build() -> void:
	level_name = "The Ash Yard"
	spawn_point = Vector3(0, 1.2, 0)

	var C := Color(0.36, 0.34, 0.31)
	var D := Color(0.32, 0.30, 0.28)

	# ── Spawn floors (no world ground — levels own their surfaces) ──
	_place_platform(Vector3(0, -0.25, -3), Vector3(22, 0.5, 22))
	_place_platform(Vector3(20, -0.25, -79), Vector3(22, 0.5, 16))

	# ── Title ──
	_place_sign(Vector3(0, 4, -2), "THE ASH YARD", 28)

	# Controls reference — small, off to the side
	_place_sign(Vector3(-5, 2.5, -5), "[LMB] Lock  [RMB] Add anchor\n" +
		"[Space] Push  [E] Pull\n" +
		"[Tab] Mist-vision  [R] Respawn\n" +
		"[\\[] / [\\]] Switch levels", 14)

	# ═══════════════════════════════════════
	# SECTION A: LOCK AND PUSH
	# ═══════════════════════════════════════

	# Courtyard framing
	_place_box(Vector3(-8, 3.5, -4), Vector3(6, 7, 8), C)
	_place_box(Vector3(8, 3.5, -4), Vector3(6, 7, 8), C)
	_place_box(Vector3(0, 3, -12), Vector3(14, 6, 3), D)

	# Floor girder — the first anchor
	_place_girder(Vector3(0, 0.25, -6), Vector3(3, 0.5, 3), 500.0)
	_place_sign(Vector3(3, 2.5, -5), "[LMB] to lock an anchor.\n[Space] to push away from it.")
	_place_sign(Vector3(-3, 2, -8), "Blue lines lead to metal.\n[Tab] to toggle.", 14)

	# Target rooftop — push up and forward to reach it
	_place_box(Vector3(0, 6, -22), Vector3(14, 12, 10), D)
	_place_box(Vector3(-4, 7.5, -20), Vector3(4, 15, 5), C)
	_place_girder(Vector3(0, 12.5, -22), Vector3(5, 0.4, 0.4), 400.0)

	# ═══════════════════════════════════════
	# SECTION B: DIRECTIONAL PUSH
	# ═══════════════════════════════════════

	_place_sign(Vector3(2, 14.5, -20), "Push sends you away from the anchor.\n Use these anchors to launch yourself across the gap.")

	# Left wall with embedded girder — push sends player right
	_place_box(Vector3(-8, 10, -27), Vector3(4, 20, 8), D)
	_place_girder(Vector3(-6, 14, -27), Vector3(0.35, 0.35, 5), 500.0)

	# Landing platform 22m to the right
	_place_box(Vector3(22, 8, -30), Vector3(10, 16, 10), C)
	_place_box(Vector3(24, 9, -28), Vector3(4, 18, 4), D)
	_place_girder(Vector3(22, 16.5, -30), Vector3(5, 0.4, 0.4), 400.0)

	# ═══════════════════════════════════════
	# SECTION C: PULL
	# ═══════════════════════════════════════

	_place_sign(Vector3(22, 18.5, -28), "[E] pulls you toward an anchor.\nLock the iron ahead and Pull.")

	# 30m gap — must pull to cross
	_place_box(Vector3(20, 12, -64), Vector3(14, 24, 12), D)
	_place_box(Vector3(16, 11, -61), Vector3(4, 22, 5), C)
	_place_box(Vector3(24, 11, -67), Vector3(5, 22, 5), C)
	# Pull target on near face
	_place_girder(Vector3(20, 22, -58), Vector3(5, 0.5, 0.5), 500.0)
	_place_girder(Vector3(20, 24.5, -64), Vector3(4, 0.4, 0.4), 400.0)

	# Recovery midway
	_place_box(Vector3(21, 5, -46), Vector3(4, 10, 4), D)
	_place_girder(Vector3(21, 10.5, -46), Vector3(2.5, 0.35, 0.35), 250.0)

	# ═══════════════════════════════════════
	# SECTION D: MULTI-TARGET (RMB)
	# ═══════════════════════════════════════

	# Hint on the section C rooftop to drop down
	_place_sign(Vector3(20, 26.5, -66), "Drop down.")

	# Open courtyard below with three floor girders
	_place_box(Vector3(12, 6, -80), Vector3(4, 12, 10), C)
	_place_box(Vector3(28, 6, -80), Vector3(4, 12, 10), C)

	_place_sign(Vector3(20, 3, -74), "Too high for one anchor.\n[LMB] the first. [RMB] to add more.\nThen push.")

	_place_girder(Vector3(20, 0.25, -77), Vector3(2.5, 0.5, 2.5), 500.0)
	_place_girder(Vector3(17, 0.25, -81), Vector3(2.5, 0.5, 2.5), 500.0)
	_place_girder(Vector3(23, 0.25, -81), Vector3(2.5, 0.5, 2.5), 500.0)

	# Tall tower behind the girders — multi-target launch reaches the top
	_place_box(Vector3(20, 24, -92), Vector3(10, 48, 10), D)
	_place_box(Vector3(20, 49, -92), Vector3(10, 2, 10), C)
	_place_girder(Vector3(20, 50.5, -92), Vector3(5, 0.4, 0.4), 400.0)

	# ═══════════════════════════════════════
	# SECTION E: PUSH + PULL COMBO
	# ═══════════════════════════════════════

	_place_sign(Vector3(20, 52.5, -90), "Push to launch. Pull mid-flight.\nChain them together.")

	# Goal tower 30m ahead — push off current rooftop, pull its face girder
	_place_box(Vector3(14, 26, -125), Vector3(14, 52, 14), D)
	_place_box(Vector3(14, 53, -125), Vector3(10, 2, 10), C)
	# Pull target on near face
	_place_girder(Vector3(14, 48, -118), Vector3(6, 0.5, 0.5), 500.0)
	_place_girder(Vector3(14, 54.5, -125), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery
	_place_box(Vector3(18, 10, -108), Vector3(4, 20, 4), D)
	_place_girder(Vector3(18, 20.5, -108), Vector3(2.5, 0.35, 0.35), 250.0)

	# Coin hint near the goal
	_place_sign(Vector3(14, 56.5, -123), "[Q] drops a coin. [F] fires one in front of you.\nThey are metal and can serve as placeable anchors.", 14)

	# ── Goal ──
	_place_goal(Vector3(14, 58, -125), Vector3(8, 0.5, 8))
	_place_sign(Vector3(14, 61, -125), "The arches are next.", 20)

	# ── Checkpoints ──
	_place_checkpoint(Vector3(0, 0, -5))
	_place_checkpoint(Vector3(0, 12, -22))
	_place_checkpoint(Vector3(22, 16, -30))
	_place_checkpoint(Vector3(20, 24, -64))
	_place_checkpoint(Vector3(20, 0, -77))
	_place_checkpoint(Vector3(20, 50, -92))

	# ── Boundary + backdrop ──
	_build_boundary(Vector3(14, 0, -62), 85.0)
	_build_city_backdrop(Vector3(14, 0, -62), 85.0, 155.0, 55, 15.0, 0.1)
