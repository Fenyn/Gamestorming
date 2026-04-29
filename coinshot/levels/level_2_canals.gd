class_name Level2Canals
extends LevelBase

func build() -> void:
	level_name = "The Iron Arches"
	spawn_point = Vector3(0, 23.2, 0)

	var C := Color(0.36, 0.34, 0.31)
	var D := Color(0.32, 0.30, 0.28)
	var S := Color(0.42, 0.40, 0.45)
	var P := Color(0.48, 0.46, 0.50)

	# Starting keep — elevated
	_place_box(Vector3(0, 10, 0), Vector3(14, 20, 12), D)
	_place_box(Vector3(0, 21, 0), Vector3(10, 2, 9), C)
	_place_girder(Vector3(0, 22.5, 0), Vector3(5, 0.4, 0.4), 400.0)

	_place_sign(Vector3(0, 25, 3), "THE IRON ARCHES\n\n" +
		"Push the wall. Pull the arch as you pass.\n" +
		"Momentum does the rest.")

	# ═══════════════════════════════════════
	# SECTION A: THE FIRST ARC
	# ═══════════════════════════════════════

	# Left wall — push off to fly right
	_place_box(Vector3(-9, 14, 0), Vector3(4, 20, 10), D)
	_place_girder(Vector3(-7, 22, 0), Vector3(0.35, 0.35, 6), 500.0)

	_place_sign(Vector3(-4, 25, 2), "Push the wall. Sling the arch.")

	# Arch — right and forward of start
	_place_box(Vector3(20, 14, -14), Vector3(2.5, 28, 2.5), S)
	_place_pyramid(Vector3(20, 28.5, -14), 3.0, 4.0, P)
	_place_box(Vector3(26, 14, -14), Vector3(2.5, 28, 2.5), S)
	_place_pyramid(Vector3(26, 28.5, -14), 3.0, 4.0, P)
	_place_girder(Vector3(23, 26, -14), Vector3(6, 0.5, 0.5), 600.0)

	# Landing — forward past the arch, generous
	_place_box(Vector3(12, 8, -42), Vector3(14, 16, 12), D)
	_place_box(Vector3(12, 17, -42), Vector3(10, 2, 9), C)
	_place_girder(Vector3(12, 18.5, -42), Vector3(5, 0.4, 0.4), 400.0)
	_place_girder(Vector3(12, 16, -36), Vector3(4, 0.5, 0.5), 400.0)

	# Recovery
	_place_box(Vector3(18, 5, -25), Vector3(5, 10, 5), D)
	_place_girder(Vector3(18, 10.5, -25), Vector3(3, 0.35, 0.35), 250.0)

	# ═══════════════════════════════════════
	# SECTION B: TIGHTER ARC
	# ═══════════════════════════════════════

	_place_sign(Vector3(12, 20.5, -40), "Tighter this time.\nSmaller landing.")

	# Right wall — push off to fly left
	_place_box(Vector3(21, 14, -46), Vector3(4, 18, 10), D)
	_place_girder(Vector3(19, 20, -46), Vector3(0.35, 0.35, 6), 500.0)

	# Arch — left and forward
	_place_box(Vector3(-8, 14, -62), Vector3(2.5, 26, 2.5), S)
	_place_pyramid(Vector3(-8, 27.5, -62), 3.0, 3.5, P)
	_place_box(Vector3(-14, 14, -62), Vector3(2.5, 26, 2.5), S)
	_place_pyramid(Vector3(-14, 27.5, -62), 3.0, 3.5, P)
	_place_girder(Vector3(-11, 24, -62), Vector3(6, 0.5, 0.5), 500.0)

	# Smaller landing
	_place_box(Vector3(-6, 8, -88), Vector3(10, 16, 10), C)
	_place_box(Vector3(-6, 17, -88), Vector3(7, 2, 7), D)
	_place_girder(Vector3(-6, 18.5, -88), Vector3(4, 0.35, 0.35), 400.0)
	_place_girder(Vector3(-6, 16, -83), Vector3(4, 0.5, 0.5), 400.0)

	# Recovery
	_place_box(Vector3(-7, 5, -74), Vector3(4, 10, 4), D)
	_place_girder(Vector3(-7, 10.5, -74), Vector3(2.5, 0.35, 0.35), 250.0)

	# ═══════════════════════════════════════
	# SECTION C: THE S-CURVE
	# ═══════════════════════════════════════

	_place_sign(Vector3(-6, 20.5, -86), "Two arches. One flight.\nDon't stop between them.")

	# Left wall — push off to fly right
	_place_box(Vector3(-14, 14, -92), Vector3(4, 18, 8), D)
	_place_girder(Vector3(-12, 20, -92), Vector3(0.35, 0.35, 5), 500.0)

	# First arch — right, curves right-to-forward
	_place_box(Vector3(12, 14, -104), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(12, 26.5, -104), 2.5, 3.5, P)
	_place_box(Vector3(18, 14, -104), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(18, 26.5, -104), 2.5, 3.5, P)
	_place_girder(Vector3(15, 24, -104), Vector3(6, 0.5, 0.5), 500.0)

	# Second arch — left, curves momentum leftward
	_place_box(Vector3(-12, 14, -124), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(-12, 26.5, -124), 2.5, 3.5, P)
	_place_box(Vector3(-18, 14, -124), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(-18, 26.5, -124), 2.5, 3.5, P)
	_place_girder(Vector3(-15, 24, -124), Vector3(6, 0.5, 0.5), 500.0)

	# Landing after S-curve
	_place_box(Vector3(-8, 8, -150), Vector3(12, 16, 12), D)
	_place_box(Vector3(-8, 17, -150), Vector3(8, 2, 8), C)
	_place_girder(Vector3(-8, 18.5, -150), Vector3(5, 0.35, 0.35), 400.0)
	_place_girder(Vector3(-8, 16, -144), Vector3(4, 0.5, 0.5), 400.0)

	# Recovery between arches
	_place_box(Vector3(3, 5, -114), Vector3(4, 10, 4), D)
	_place_girder(Vector3(3, 10.5, -114), Vector3(2.5, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# SECTION D: THE CRUMBLE
	# ═══════════════════════════════════════

	_place_sign(Vector3(-8, 20.5, -148), "That orange beam won't hold.\nOne shot.")

	# Left wall — push off to fly right
	_place_box(Vector3(-16, 14, -154), Vector3(4, 14, 8), D)
	_place_girder(Vector3(-14, 20, -154), Vector3(0.35, 0.35, 5), 500.0)

	# Crumbling arch — falling anchor beam
	_place_box(Vector3(10, 16, -168), Vector3(2, 22, 2), S)
	_place_pyramid(Vector3(10, 27.5, -168), 2.5, 3.5, P)
	_place_falling_anchor(Vector3(10, 26, -168), Vector3(5, 0.5, 0.5), 400.0, 2.5)

	# Final landing — generous
	_place_box(Vector3(4, 10, -196), Vector3(14, 20, 14), D)
	_place_box(Vector3(4, 21, -196), Vector3(10, 2, 10), C)
	_place_girder(Vector3(4, 22.5, -196), Vector3(5, 0.4, 0.4), 400.0)
	_place_girder(Vector3(4, 20, -189), Vector3(4, 0.5, 0.5), 400.0)

	# Recovery
	_place_box(Vector3(6, 5, -180), Vector3(4, 10, 4), D)
	_place_girder(Vector3(6, 10.5, -180), Vector3(2.5, 0.35, 0.35), 250.0)

	# ── Goal ──
	_place_goal(Vector3(4, 26, -196), Vector3(8, 0.5, 8))
	_place_sign(Vector3(4, 29, -196), "Time to pick up speed.", 20)

	# ── Checkpoints ──
	_place_checkpoint(Vector3(0, 22, 0))
	_place_checkpoint(Vector3(12, 18, -42))
	_place_checkpoint(Vector3(-6, 18, -88))
	_place_checkpoint(Vector3(-8, 18, -150))
	_place_checkpoint(Vector3(4, 22, -196))

	# ── Boundary + backdrop ──
	_build_boundary(Vector3(0, 0, -98), 120.0)
	_build_city_backdrop(Vector3(0, 0, -98), 120.0, 180.0, 60, 22.0, 0.15)
