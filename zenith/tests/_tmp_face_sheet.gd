extends Node
## Temporary: renders personality layout variants side by side for a review. Delete after use.

const OUT: String = "C:/Users/Midge/AppData/Local/Temp/claude/G--Godot-Gamestorming/afe240ea-2351-4d2d-af64-089935c2d89c/scratchpad/variants/"
const W: int = 512
const H: int = 716
const PEWTER: Color = Color("8a847c")
const CREAM: Color = Color(0.88, 0.84, 0.75)
const INK: Color = Color(0.10, 0.08, 0.06)
const DARK: Color = Color("3b3226")
const MINT: Color = Color("8fe0b8")
## id, school for the backdrop, stack height, spent
const CARDS: Array = [
	["personality_24", "root", 5, false],
	["personality_34", "pyre", 5, false],
	["personality_15", "steel", 3, true],
	["personality_62", "shade", 4, false],
	["personality_42", "shade", 1, false],
]
const VARIANTS: Array = ["current", "full_art", "short_art", "close_up"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = true
	vp.disable_3d = true
	add_child(vp)
	var face: CardFace = (load("res://scenes/duel/card_face.tscn") as PackedScene).instantiate() as CardFace
	vp.add_child(face)
	var holder: Control = Control.new()
	holder.size = Vector2(W, H)
	vp.add_child(holder)
	await get_tree().process_frame
	var rows: Array[Image] = []
	for c in CARDS:
		var def: CardDef = Session.library.defs.get(str(c[0]))
		var back: Color = Palette.SCHOOL_COLORS[str(c[1])].darkened(CardFace.BACKDROP_DARKEN)
		var imgs: Array[Image] = []
		for v in VARIANTS:
			for ch in holder.get_children():
				ch.free()
			if v == "current":
				face.visible = true
				face.show_def(def, 0, -1, null, back)
			else:
				face.visible = false
				_build(holder, str(v), def, back, int(c[2]), bool(c[3]))
			await get_tree().process_frame
			await get_tree().process_frame
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image()
			img.save_png(OUT + "%s_%s.png" % [c[0], v])
			imgs.append(img)
		rows.append(_row(imgs))
	for i in range(rows.size()):
		rows[i].save_png(OUT + "row_%s.png" % CARDS[i][0])
	print("done")
	get_tree().quit()


func _row(imgs: Array[Image]) -> Image:
	var gap: int = 24
	var out: Image = Image.create(W * imgs.size() + gap * (imgs.size() + 1), H + gap * 2, false, Image.FORMAT_RGBA8)
	out.fill(Color("443533"))
	for i in range(imgs.size()):
		var im: Image = imgs[i]
		im.convert(Image.FORMAT_RGBA8)
		out.blend_rect(im, Rect2i(0, 0, W, H), Vector2i(gap + i * (W + gap), gap))
	return out


func _build(root: Control, variant: String, def: CardDef, back: Color, stack: int, spent: bool) -> void:
	var frame: Panel = _panel(root, Rect2(0, 0, W, H), PEWTER, 8)
	var rule_tex: Texture2D = load("res://assets/ui/card_rules/double.png")
	var rule: Panel = Panel.new()
	var rb: StyleBoxTexture = StyleBoxTexture.new()
	rb.texture = rule_tex
	rb.set_texture_margin_all(32)
	rb.draw_center = false
	rb.modulate_color = PEWTER.lightened(0.45)
	rule.add_theme_stylebox_override("panel", rb)
	rule.position = Vector2.ZERO
	rule.size = Vector2(W, H)
	root.add_child(rule)
	_panel(root, Rect2(18, 16, W - 36, H - 32), CREAM, 10)
	var x0: float = 30.0
	var y0: float = 26.0
	var cw: float = 452.0
	var _f: Panel = frame
	# Head: Aspect box with stack pips, name, title.
	var box: Panel = _panel(root, Rect2(x0, y0, 64, 64), DARK, 12)
	_label(box, str(def.aspect), 32, Color.WHITE, Rect2(0, 2, 64, 40), HORIZONTAL_ALIGNMENT_CENTER)
	var pip_w: float = 8.0
	var total: float = stack * pip_w + (stack - 1) * 3.0
	for i in range(stack):
		var on: bool = i < def.aspect
		_panel(box, Rect2((64 - total) / 2.0 + i * (pip_w + 3.0), 46, pip_w, 8), Color.WHITE if on else Color(1, 1, 1, 0.25), 2)
	var name_size: int = 32 if def.title.length() <= 20 else 16
	_label(root, def.title, name_size, INK, Rect2(x0 + 76, y0 + 2, cw - 76, 36))
	var sub: String = def.aspect_title if def.aspect_title != "" else def.variant
	_label(root, sub.to_upper(), 16, Color(INK, 0.7), Rect2(x0 + 76, y0 + 40, cw - 76, 20))
	# Art.
	var art_top: float = y0 + 64 + 8
	var art_h: float = 434.0 if variant == "full_art" else 330.0
	var art: Panel = _panel(root, Rect2(x0, art_top, cw, art_h), back, 8)
	art.clip_contents = true
	var tex: Texture2D = CardFace.art_texture(def)
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		var scale: float = 3.0 if variant == "close_up" else 2.0
		var sz: Vector2 = tex.get_size() * scale
		tr.size = sz
		tr.position = Vector2((cw - sz.x) / 2.0, -75.0 if variant == "close_up" else 0.0)
		art.add_child(tr)
	# Badges.
	var td: Dictionary = def.aspect_data(def.aspect)
	var pw: Dictionary = td.get("power", {})
	var badge: Dictionary = {}
	if pw.has("attack"):
		var tmp: CardDef = CardDef.new()
		tmp.attack = pw["attack"]
		badge = CardText.attack_badge(tmp)
	var surge: int = int(td.get("surge", def.raw.get("surge", 0)))
	if variant == "close_up":
		# Badges in the head, right side.
		var bx: float = x0 + cw
		var s: Panel = _surge(root, surge, Rect2(bx - 64, y0, 64, 64))
		var _s: Panel = s
		_label(root, sub.to_upper(), 16, Color(INK, 0.7), Rect2(x0 + 76, y0 + 40, cw - 76 - 72, 20))
		if not badge.is_empty():
			_attack(root, badge, Rect2(x0 + 8, art_top + art_h - 72, 96, 64))
	else:
		var side: float = (cw - 302.0) / 2.0
		_surge(root, surge, Rect2(x0 + (side - 64) / 2.0, art_top + art_h - 72, 64, 64))
		if not badge.is_empty():
			_attack(root, badge, Rect2(x0 + cw - side + (side - 64) / 2.0 - 0, art_top + art_h - 72, 64, 64), true)
	# Text box.
	var ty: float = art_top + art_h + 8
	var th: float = y0 + 664 - ty
	if spent:
		_panel(root, Rect2(x0 - 4, ty - 2, cw + 8, th + 4), Color("b8ad97"), 6)
	var type_parts: PackedStringArray = PackedStringArray()
	if def.bloodline != "":
		type_parts.append(CardText.bloodline_name(def.bloodline))
	if def.alignment_only != "":
		type_parts.append(def.alignment_only.capitalize() + " only")
	for t in def.raw.get("tags", []):
		type_parts.append(CardText.keyword_name(str(t)))
	var line_y: float = ty
	if not type_parts.is_empty():
		_label(root, " · ".join(type_parts).to_upper(), 16, Color(INK, 0.6), Rect2(x0, ty, cw, 20))
		line_y += 24
	if spent:
		var chip: Panel = _panel(root, Rect2(x0 + cw - 76, ty, 76, 22), Color("6b6259"), 4)
		_label(chip, "SPENT", 16, Color.WHITE, Rect2(0, 0, 76, 22), HORIZONTAL_ALIGNMENT_CENTER)
	var text: KeywordLabel = KeywordLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = false
	text.fit_content = false
	text.position = Vector2(x0, line_y)
	text.size = Vector2(cw, y0 + 664 - line_y)
	var fs: int = 16 if variant == "full_art" else 24
	var plain: String = "\n".join(CardText.aspect_text(def))
	var font: Font = text.get_theme_font("normal_font")
	if fs == 24 and font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, cw - 6, 24, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y > text.size.y - 4:
		fs = 16
	text.add_theme_font_size_override("normal_font_size", fs)
	text.add_theme_font_size_override("bold_font_size", fs)
	text.add_theme_color_override("default_color", INK)
	root.add_child(text)
	text.set_plain(plain)


func _surge(root: Control, surge: int, r: Rect2) -> Panel:
	var p: Panel = _panel(root, r, DARK, 12)
	_label(p, str(surge), 32, MINT, Rect2(0, 4, r.size.x, 36), HORIZONTAL_ALIGNMENT_CENTER)
	_label(p, "SURGE", 16, Color(1, 1, 1, 0.8), Rect2(0, 40, r.size.x, 20), HORIZONTAL_ALIGNMENT_CENTER)
	return p


func _attack(root: Control, badge: Dictionary, r: Rect2, narrow: bool = false) -> void:
	var kind: String = str(badge["kind"]).replace("Focused ", "F.")
	var ink: Color = Palette.type_ink(CardDef.Type.ART if kind.ends_with("Art") else CardDef.Type.STRIKE)
	if narrow:
		r.size.x = 72
		r.position.x -= 4
	var p: Panel = _panel(root, r, ink, 12)
	_label(p, kind.to_upper(), 16, Color(1, 1, 1, 0.85), Rect2(0, 4, r.size.x, 20), HORIZONTAL_ALIGNMENT_CENTER)
	_label(p, str(badge["num"]), 32, Color.WHITE, Rect2(0, 22, r.size.x, 36), HORIZONTAL_ALIGNMENT_CENTER)


func _panel(parent: Control, r: Rect2, color: Color, radius: int) -> Panel:
	var p: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
	p.position = r.position
	p.size = r.size
	parent.add_child(p)
	return p


func _label(parent: Control, text: String, size: int, color: Color, r: Rect2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.clip_text = true
	l.position = r.position
	l.size = r.size
	parent.add_child(l)
	return l
