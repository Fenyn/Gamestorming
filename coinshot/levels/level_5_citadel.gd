class_name Level5Citadel
extends LevelBase

func build() -> void:
	level_name = "The Black Spire"
	spawn_point = Vector3(0, 1.2, 0)

	var B := Color(0.24, 0.22, 0.20)
	var D := Color(0.28, 0.26, 0.24)
	var S := Color(0.35, 0.33, 0.38)
	var P := Color(0.40, 0.38, 0.42)

	# ── Spawn floor ──
	_place_platform(Vector3(0, -0.25, -5), Vector3(24, 0.5, 22))

	_place_sign(Vector3(0, 3.5, -3), "THE BLACK SPIRE\n\n" +
		"Get to the top.", 28)

	# ═══════════════════════════════════════
	# ZONE 1: THE BASE — Push + Slingshot Entry
	# ═══════════════════════════════════════

	# Starting courtyard — dark, imposing walls
	_place_box(Vector3(-10, 5, -5), Vector3(6, 10, 10), B)
	_place_box(Vector3(10, 5, -5), Vector3(6, 10, 10), B)

	# Floor girder — push up to first ledge
	_place_girder(Vector3(0, 0.25, -6), Vector3(3, 0.5, 3), 500.0)

	# First ledge at y=12
	_place_box(Vector3(0, 6, -18), Vector3(12, 12, 10), D)
	_place_girder(Vector3(0, 12.5, -18), Vector3(5, 0.4, 0.4), 400.0)

	# Slingshot entry — wall push + arch to reach y=22 ledge
	_place_box(Vector3(-9, 8, -22), Vector3(4, 18, 8), D)
	_place_girder(Vector3(-7, 14, -22), Vector3(0.35, 0.35, 5), 500.0)

	# Arch for the entry sling
	_place_box(Vector3(16, 12, -30), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(16, 24.5, -30), 2.5, 3.5, P)
	_place_box(Vector3(22, 12, -30), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(22, 24.5, -30), 2.5, 3.5, P)
	_place_girder(Vector3(19, 22, -30), Vector3(6, 0.5, 0.5), 500.0)

	# Landing ledge at y=22
	_place_box(Vector3(10, 10, -50), Vector3(12, 20, 10), D)
	_place_box(Vector3(10, 21, -50), Vector3(8, 2, 7), B)
	_place_girder(Vector3(10, 22.5, -50), Vector3(5, 0.4, 0.4), 400.0)
	_place_girder(Vector3(10, 20, -45), Vector3(4, 0.5, 0.5), 400.0)

	# Recovery
	_place_box(Vector3(12, 4, -36), Vector3(4, 8, 4), D)
	_place_girder(Vector3(12, 8.5, -36), Vector3(2.5, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# ZONE 2: THE CLIMB — Staggered Push Platforms
	# ═══════════════════════════════════════

	# Three ascending platforms — push off each floor girder to hop upward
	_place_box(Vector3(4, 16, -64), Vector3(8, 32, 8), B)
	_place_girder(Vector3(4, 32.5, -64), Vector3(3, 0.5, 3), 400.0)

	_place_box(Vector3(-4, 20, -78), Vector3(8, 40, 8), D)
	_place_girder(Vector3(-4, 40.5, -78), Vector3(3, 0.5, 3), 400.0)

	_place_box(Vector3(6, 24, -92), Vector3(8, 48, 8), B)
	_place_girder(Vector3(6, 48.5, -92), Vector3(3, 0.5, 3), 400.0)

	# Recovery girders on tower faces
	_place_girder(Vector3(0, 26, -70), Vector3(2, 0.35, 0.35), 200.0)
	_place_girder(Vector3(2, 36, -84), Vector3(2, 0.35, 0.35), 200.0)

	# ═══════════════════════════════════════
	# ZONE 3: THE CRUMBLE — Falling Anchor Staircase
	# ═══════════════════════════════════════

	# Three falling anchors — use each before it drops, rapid sequence
	_place_box(Vector3(-4, 34, -104), Vector3(4, 18, 4), D)
	_place_falling_anchor(Vector3(-4, 54, -104), Vector3(3, 0.4, 0.4), 300.0, 2.0)

	_place_box(Vector3(6, 38, -118), Vector3(4, 16, 4), D)
	_place_falling_anchor(Vector3(6, 60, -118), Vector3(3, 0.4, 0.4), 300.0, 2.0)

	_place_box(Vector3(-2, 42, -132), Vector3(4, 14, 4), D)
	_place_falling_anchor(Vector3(-2, 66, -132), Vector3(3, 0.4, 0.4), 300.0, 2.0)

	# Recovery between falling anchors
	_place_girder(Vector3(2, 46, -110), Vector3(2, 0.35, 0.35), 200.0)
	_place_girder(Vector3(0, 54, -124), Vector3(2, 0.35, 0.35), 200.0)

	# Stable platform after the crumble
	_place_box(Vector3(0, 34, -150), Vector3(12, 68, 12), B)
	_place_box(Vector3(0, 69, -150), Vector3(8, 2, 8), D)
	_place_girder(Vector3(0, 70.5, -150), Vector3(5, 0.4, 0.4), 400.0)

	# ═══════════════════════════════════════
	# ZONE 4: THE SUMMIT — Final Slingshot
	# ═══════════════════════════════════════

	# Launch wall
	_place_box(Vector3(-8, 64, -152), Vector3(4, 12, 6), D)
	_place_girder(Vector3(-7, 70, -152), Vector3(0.35, 0.35, 4), 500.0)

	# Summit arch
	_place_box(Vector3(16, 60, -164), Vector3(2, 20, 2), S)
	_place_pyramid(Vector3(16, 70.5, -164), 2.5, 3.5, P)
	_place_box(Vector3(22, 60, -164), Vector3(2, 20, 2), S)
	_place_pyramid(Vector3(22, 70.5, -164), 2.5, 3.5, P)
	_place_girder(Vector3(19, 68, -164), Vector3(6, 0.5, 0.5), 500.0)

	# Summit tower
	_place_box(Vector3(10, 38, -186), Vector3(14, 76, 14), B)
	_place_box(Vector3(10, 77, -186), Vector3(10, 2, 10), D)
	_place_box(Vector3(10, 80, -186), Vector3(6, 3, 6), S)
	_place_girder(Vector3(10, 82, -186), Vector3(6, 0.4, 0.4), 600.0)
	_place_girder(Vector3(10, 74, -179), Vector3(4, 0.5, 0.5), 400.0)

	# Flanking spires
	_place_box(Vector3(0, 46, -180), Vector3(2, 26, 2), S)
	_place_pyramid(Vector3(0, 59.5, -180), 2.5, 4.0, P)
	_place_box(Vector3(20, 44, -192), Vector3(2, 24, 2), S)
	_place_pyramid(Vector3(20, 56.5, -192), 2.5, 3.5, P)
	_place_box(Vector3(4, 42, -194), Vector3(2, 22, 2), S)
	_place_pyramid(Vector3(4, 53.5, -194), 2.5, 3.0, P)

	# Recovery on tower face
	_place_girder(Vector3(10, 70, -179), Vector3(3, 0.35, 0.35), 300.0)

	# ── Goal ──
	_place_goal(Vector3(10, 86, -186), Vector3(10, 0.5, 10))
	_place_pyramid(Vector3(10, 92, -186), 5.0, 7.0, COL_GOAL)

	var victory := Label3D.new()
	victory.text = "THE MISTS ARE YOURS"
	victory.global_position = Vector3(10, 96, -186)
	victory.font_size = 56
	victory.modulate = Color(1, 0.85, 0.3)
	victory.outline_size = 12
	victory.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	victory.no_depth_test = true
	add_child(victory)

	# ── Checkpoints ──
	_place_checkpoint(Vector3(0, 0, -5))
	_place_checkpoint(Vector3(0, 12, -18))
	_place_checkpoint(Vector3(10, 22, -50))
	_place_checkpoint(Vector3(4, 32, -64))
	_place_checkpoint(Vector3(-4, 40, -78))
	_place_checkpoint(Vector3(6, 48, -92))
	_place_checkpoint(Vector3(0, 70, -150))

	# ── Boundary + backdrop ──
	_build_boundary(Vector3(5, 0, -93), 115.0)
	_build_city_backdrop(Vector3(5, 0, -93), 115.0, 185.0, 65, 50.0, 0.3)
