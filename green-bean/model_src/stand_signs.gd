extends RefCounted

## Signage for the stand, one builder per piece:
## - roof_sign(): name board standing on the roof's front edge, 1.7 x 0.38 m,
##   cream face in a dark olive frame with a coffee bean and the stand's name.
##   Origin: base centre on the roof deck. Faces +Z.
## - hanging_sign(text): 62 x 15 cm board on two chains, lettered both sides.
##   Origin: the hang point (top centre). Faces +Z.
## - menu_board(): wall-mounted chalkboard, 50 x 80 cm in a wood frame, with
##   NameColumn and PriceColumn labels that scripts/world/menu_board.gd fills.
##   Origin: back face, bottom centre. Faces +Z.
## - a_frame(): sidewalk chalkboard sign, 60 x 90 cm leaves. Origin: ground
##   centre. The front leaf faces +Z.

const MK := preload("res://model_src/model_kit.gd")

const OLIVE := Color(0.37, 0.41, 0.24)
const CREAM := Color(0.95, 0.92, 0.84)
const CHALK := Color(0.16, 0.18, 0.17)
const CHALK_TEXT := Color(0.93, 0.92, 0.88)

## build_models.gd entry point: kind is roof, hanging, menu or a_frame.
static func build(kind := "roof", text := "") -> Node3D:
	match kind:
		"hanging":
			return hanging_sign(text)
		"menu":
			return menu_board()
		"a_frame":
			return a_frame()
	return roof_sign()

static func roof_sign() -> Node3D:
	var root := Node3D.new()
	root.name = "RoofSign"
	var size := Vector3(1.7, 0.38, 0.05)
	var lift := 0.06
	var frame_color := OLIVE.darkened(0.2)
	var frame: Material = MK.mat(frame_color, 0.0, 0.6)
	for sx in [-1.0, 1.0]:
		MK.box(root, "Leg", Vector3(0.05, lift + 0.15, 0.05), Vector3(float(sx) * 0.6, (lift + 0.15) * 0.5, -0.05), frame)
	var face_y := lift + size.y * 0.5
	MK.box(root, "Board", size, Vector3(0, face_y, 0), frame)
	MK.box(root, "Face", Vector3(size.x - 0.08, size.y - 0.08, 0.004), Vector3(0, face_y, size.z * 0.5 + 0.002), MK.mat(CREAM, 0.0, 0.8))
	# Bean and name as one block, centred from the measured text width.
	var title := "GREEN BEAN"
	var title_px := 0.0016
	var title_w := _text_width(title, 120) * title_px
	var bean_w := 0.135
	var gap := 0.07
	var left := -(bean_w + gap + title_w) * 0.5
	var bean := MK.group(root, "Bean")
	bean.position = Vector3(left + bean_w * 0.5, face_y, size.z * 0.5 + 0.02)
	var brown: Material = MK.mat(Color(0.36, 0.2, 0.1), 0.0, 0.6)
	var half := MK.sphere(bean, "Half", 0.09, Vector3.ZERO, brown, 1.0, 16)
	half.scale = Vector3(0.75, 1.0, 0.3)
	half.rotation_degrees = Vector3(0, 0, -20)
	MK.box(bean, "Crease", Vector3(0.011, 0.145, 0.01), Vector3(0, 0, 0.025), MK.mat(Color(0.2, 0.1, 0.05), 0.0, 0.7), Vector3(0, 0, -20))
	_text(root, title, Vector3(left + bean_w + gap + title_w * 0.5, face_y, size.z * 0.5 + 0.006), 120, title_px, frame_color)
	return root

## Width of a single line in pixels, in the font Label3D uses by default.
static func _text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

static func hanging_sign(text: String) -> Node3D:
	var root := Node3D.new()
	root.name = "HangingSign"
	var drop := 0.2
	var board := Vector3(0.62, 0.15, 0.02)
	var chain: Material = MK.mat(Color(0.55, 0.55, 0.57), 0.8, 0.4)
	for sx in [-1.0, 1.0]:
		MK.cyl(root, "Chain", 0.003, 0.003, drop, Vector3(float(sx) * 0.25, -drop * 0.5, 0), chain, 6)
		MK.cyl(root, "Hook", 0.008, 0.008, 0.01, Vector3(float(sx) * 0.25, -0.005, 0), chain, 8)
	var y := -drop - board.y * 0.5
	MK.rounded_box(root, "Board", board, Vector3(0, y, 0), 0.01, MK.mat(OLIVE, 0.0, 0.6))
	for face in [1.0, -1.0]:
		var l := _text(root, text, Vector3(0, y, float(face) * (board.z * 0.5 + 0.002)), 72, 0.0012, CREAM)
		if face < 0.0:
			l.rotation_degrees = Vector3(0, 180, 0)
	return root

static func menu_board() -> Node3D:
	var root := Node3D.new()
	root.name = "MenuBoard"
	var size := Vector2(0.5, 0.8)
	var frame: Material = MK.mat(MK.WOOD_DARK, 0.0, 0.7)
	MK.box(root, "Slate", Vector3(size.x, size.y, 0.015), Vector3(0, size.y * 0.5, 0.0075), MK.mat(CHALK, 0.0, 0.95))
	for sy in [0.0, 1.0]:
		MK.box(root, "FrameH", Vector3(size.x + 0.05, 0.03, 0.03), Vector3(0, sy * size.y, 0.015), frame)
	for sx in [-1.0, 1.0]:
		MK.box(root, "FrameV", Vector3(0.03, size.y + 0.05, 0.03), Vector3(float(sx) * size.x * 0.5, size.y * 0.5, 0.015), frame)
	_text(root, "MENU", Vector3(0, size.y - 0.08, 0.017), 72, 0.0013, CHALK_TEXT)
	MK.box(root, "Rule", Vector3(size.x - 0.12, 0.003, 0.001), Vector3(0, size.y - 0.13, 0.016), MK.mat(CHALK_TEXT.darkened(0.2), 0.0, 0.9))
	var names := _text(root, "", Vector3(-size.x * 0.5 + 0.04, size.y - 0.16, 0.017), 40, 0.0011, CHALK_TEXT)
	names.name = "NameColumn"
	names.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	names.line_spacing = 14
	var prices := _text(root, "", Vector3(size.x * 0.5 - 0.04, size.y - 0.16, 0.017), 40, 0.0011, CHALK_TEXT)
	prices.name = "PriceColumn"
	prices.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prices.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	prices.line_spacing = 14
	var foot := _text(root, "", Vector3(0, 0.06, 0.017), 32, 0.0011, CHALK_TEXT.darkened(0.15))
	foot.name = "Footer"
	return root

static func a_frame() -> Node3D:
	var root := Node3D.new()
	root.name = "AFrameSign"
	var h := 0.9
	var w := 0.6
	var splay := 14.0
	var frame: Material = MK.mat(MK.WOOD, 0.0, 0.7)
	# Each leaf hangs from the hinge at the top and splays out at the bottom.
	for face in [1.0, -1.0]:
		var leaf := MK.group(root, "Leaf")
		leaf.position = Vector3(0, h, 0)
		leaf.rotation_degrees = Vector3(-splay, 0 if face > 0.0 else 180, 0)
		var mid := Vector3(0, -h * 0.5, 0)
		MK.box(leaf, "Slate", Vector3(w - 0.06, h - 0.08, 0.012), mid + Vector3(0, 0.02, 0.02), MK.mat(CHALK, 0.0, 0.95))
		for sx in [-1.0, 1.0]:
			MK.box(leaf, "Rail", Vector3(0.03, h, 0.025), mid + Vector3(float(sx) * (w * 0.5 - 0.015), 0, 0.02), frame)
		MK.box(leaf, "Top", Vector3(w, 0.04, 0.025), Vector3(0, -0.02, 0.02), frame)
		_text(leaf, "COFFEE", Vector3(0, -h * 0.28, 0.027), 96, 0.0013, CHALK_TEXT)
		_text(leaf, "pour over\nlattes\namericanos", Vector3(0, -h * 0.55, 0.027), 52, 0.0011, Color(0.95, 0.85, 0.55))
		_text(leaf, "this way  >", Vector3(0, -h * 0.8, 0.027), 48, 0.0011, CHALK_TEXT)
	MK.box(root, "Hinge", Vector3(w, 0.02, 0.03), Vector3(0, h + 0.005, 0), MK.mat(Color(0.5, 0.5, 0.52), 0.7, 0.4))
	return root

static func _text(parent: Node3D, text: String, pos: Vector3, size: int, pixel: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.name = MK.unique_name(parent, "Text")
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.outline_size = 0
	l.modulate = color
	l.position = pos
	parent.add_child(l)
	return l
