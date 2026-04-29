class_name Level2Canals
extends LevelBase

func build() -> void:
	level_name = "The Iron Arches"
	spawn_point = Vector3(0, 23.2, 0)

	var C := Color(0.36, 0.34, 0.31)
	var D := Color(0.32, 0.30, 0.28)
	var S := Color(0.42, 0.40, 0.45)
	var P := Color(0.48, 0.46, 0.50)

	# Starting keep
	_place_box(Vector3(0, 10, 0), Vector3(14, 20, 12), D)
	_place_box(Vector3(0, 21, 0), Vector3(10, 2, 9), C)
	_place_girder(Vector3(0, 22.5, 0), Vector3(5, 0.4, 0.4), 400.0)

	_place_sign(Vector3(0, 25.5, 3), "THE IRON ARCHES", 28)

	# ═══════════════════════════════════════
	# SECTION A: FIRST TETHER SWING
	# ═══════════════════════════════════════

	_place_sign(Vector3(0, 25, -2), "Lock the iron above you.\nHold [LMB] and walk off the edge.\nThe tether holds. Gravity swings you.")

	# Tall arch with overhead girder
	_place_box(Vector3(-4, 20, -15), Vector3(2, 30, 2), S)
	_place_pyramid(Vector3(-4, 35.5, -15), 2.5, 3.5, P)
	_place_box(Vector3(4, 20, -15), Vector3(2, 30, 2), S)
	_place_pyramid(Vector3(4, 35.5, -15), 2.5, 3.5, P)
	_place_girder(Vector3(0, 38, -15), Vector3(8, 0.5, 0.5), 600.0)

	# Landing — 25m ahead, reachable by swing arc
	_place_box(Vector3(0, 10, -38), Vector3(14, 20, 12), D)
	_place_box(Vector3(0, 21, -38), Vector3(10, 2, 9), C)
	_place_girder(Vector3(0, 22.5, -38), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery below the arch
	_place_box(Vector3(0, 5, -20), Vector3(5, 10, 5), D)
	_place_girder(Vector3(0, 10.5, -20), Vector3(3, 0.35, 0.35), 250.0)

	# ═══════════════════════════════════════
	# SECTION B: SWING CHAIN
	# ═══════════════════════════════════════

	_place_sign(Vector3(0, 25, -36), "Release at the peak.\nLock the next arch. Keep swinging.")

	# Three arches in sequence — swing, release, retether
	# Arch 2
	_place_box(Vector3(-3, 20, -55), Vector3(2, 30, 2), S)
	_place_pyramid(Vector3(-3, 35.5, -55), 2.5, 3.0, P)
	_place_box(Vector3(3, 20, -55), Vector3(2, 30, 2), S)
	_place_pyramid(Vector3(3, 35.5, -55), 2.5, 3.0, P)
	_place_girder(Vector3(0, 36, -55), Vector3(6, 0.5, 0.5), 500.0)

	# Arch 3
	_place_box(Vector3(-3, 20, -75), Vector3(2, 30, 2), S)
	_place_pyramid(Vector3(-3, 35.5, -75), 2.5, 3.0, P)
	_place_box(Vector3(3, 20, -75), Vector3(2, 30, 2), S)
	_place_pyramid(Vector3(3, 35.5, -75), 2.5, 3.0, P)
	_place_girder(Vector3(0, 36, -75), Vector3(6, 0.5, 0.5), 500.0)

	# Arch 4
	_place_box(Vector3(-3, 20, -95), Vector3(2, 30, 2), S)
	_place_pyramid(Vector3(-3, 35.5, -95), 2.5, 3.0, P)
	_place_box(Vector3(3, 20, -95), Vector3(2, 30, 2), S)
	_place_pyramid(Vector3(3, 35.5, -95), 2.5, 3.0, P)
	_place_girder(Vector3(0, 36, -95), Vector3(6, 0.5, 0.5), 500.0)

	# Landing after chain
	_place_box(Vector3(0, 10, -115), Vector3(14, 20, 12), D)
	_place_box(Vector3(0, 21, -115), Vector3(10, 2, 9), C)
	_place_girder(Vector3(0, 22.5, -115), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery
	_place_box(Vector3(-6, 5, -72), Vector3(4, 10, 4), D)
	_place_girder(Vector3(-6, 10.5, -72), Vector3(2.5, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION C: ROPE CONTROL
	# ═══════════════════════════════════════

	_place_sign(Vector3(0, 25, -113), "[E] shortens the tether. [Space] extends it.\nShorten mid-swing to climb higher.")

	# High arch — the landing is ABOVE the start, so the player must
	# pull (shorten rope) during the swing to gain altitude
	_place_box(Vector3(-4, 24, -132), Vector3(2, 34, 2), S)
	_place_pyramid(Vector3(-4, 41.5, -132), 2.5, 3.5, P)
	_place_box(Vector3(4, 24, -132), Vector3(2, 34, 2), S)
	_place_pyramid(Vector3(4, 41.5, -132), 2.5, 3.5, P)
	_place_girder(Vector3(0, 42, -132), Vector3(8, 0.5, 0.5), 600.0)

	# Landing — HIGHER than the start, requires shortening the rope
	_place_box(Vector3(0, 14, -155), Vector3(12, 28, 10), D)
	_place_box(Vector3(0, 29, -155), Vector3(8, 2, 7), C)
	_place_girder(Vector3(0, 30.5, -155), Vector3(5, 0.4, 0.4), 400.0)

	# Recovery
	_place_box(Vector3(-6, 6, -140), Vector3(4, 12, 4), D)
	_place_girder(Vector3(-6, 12.5, -140), Vector3(2.5, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION D: THE CRUMBLE — Timed Swing
	# ═══════════════════════════════════════

	_place_sign(Vector3(0, 32.5, -153), "That orange beam won't hold long.\nSwing fast.")

	# Push wall for initial momentum
	_place_box(Vector3(-10, 24, -158), Vector3(4, 16, 8), D)
	_place_girder(Vector3(-8, 30, -158), Vector3(0.35, 0.35, 5), 500.0)

	# Falling arch — crumbles 2.5s after force is applied
	_place_box(Vector3(14, 26, -172), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(14, 38.5, -172), 2.5, 3.5, P)
	_place_falling_anchor(Vector3(14, 38, -172), Vector3(5, 0.5, 0.5), 400.0, 2.5)

	# Final landing
	_place_box(Vector3(8, 12, -198), Vector3(14, 24, 14), D)
	_place_box(Vector3(8, 25, -198), Vector3(10, 2, 10), C)
	_place_girder(Vector3(8, 26.5, -198), Vector3(5, 0.4, 0.4), 400.0)
	_place_girder(Vector3(8, 24, -191), Vector3(4, 0.5, 0.5), 400.0)

	# Recovery
	_place_box(Vector3(8, 6, -184), Vector3(4, 12, 4), D)
	_place_girder(Vector3(8, 12.5, -184), Vector3(2.5, 0.35, 0.35), 250.0)

	# ── Goal ──
	_place_goal(Vector3(8, 30, -198), Vector3(8, 0.5, 8))
	_place_sign(Vector3(8, 33, -198), "Time to pick up speed.", 20)

	# ── Checkpoints ──
	_place_checkpoint(Vector3(0, 22, 0))
	_place_checkpoint(Vector3(0, 22, -38))
	_place_checkpoint(Vector3(0, 22, -115))
	_place_checkpoint(Vector3(0, 30, -155))
	_place_checkpoint(Vector3(8, 26, -198))

	# ── Boundary + backdrop ──
	_build_boundary(Vector3(4, 0, -100), 120.0)
	_build_city_backdrop(Vector3(4, 0, -100), 120.0, 180.0, 60, 22.0, 0.15)
