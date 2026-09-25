extends Node
## Temporary: renders personality faces from the real CardFace for a review. Delete after use.

const OUT: String = "C:/Users/Midge/AppData/Local/Temp/claude/G--Godot-Gamestorming/afe240ea-2351-4d2d-af64-089935c2d89c/scratchpad/built/"
const CARDS: Array = [
	["personality_15", "steel", 5],
	["personality_62", "shade", 3],
	["personality_42", "shade", 0],
	["personality_24", "root", 7],
	["personality_34", "pyre", 10],
	["personality_06", "tide", 4],
	["personality_54", "storm", -1],
	["personality_26", "", -1],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	CardFace.strike_table = Session.strike_table
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(512, 716)
	vp.transparent_bg = true
	vp.disable_3d = true
	add_child(vp)
	var face: CardFace = (load("res://scenes/duel/card_face.tscn") as PackedScene).instantiate() as CardFace
	vp.add_child(face)
	await get_tree().process_frame
	var imgs: Array[Image] = []
	for c in CARDS:
		var def: CardDef = Session.library.defs.get(str(c[0]))
		var back: Color = CardFace.NO_BACKDROP
		if str(c[1]) != "":
			back = Palette.SCHOOL_COLORS[str(c[1])].darkened(CardFace.BACKDROP_DARKEN)
		face.show_def(def, 0, int(c[2]), null, back)
		await get_tree().process_frame
		await get_tree().process_frame
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(OUT + str(c[0]) + ".png")
		imgs.append(img)
	var cols: int = 4
	var sheet: Image = Image.create(512 * cols + 24 * (cols + 1), (716 + 24) * 2 + 24, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("443533"))
	for i in range(imgs.size()):
		sheet.blend_rect(imgs[i], Rect2i(0, 0, 512, 716), Vector2i(24 + (i % cols) * 536, 24 + (i / cols) * 740))
	sheet.save_png(OUT + "sheet.png")
	print("done")
	get_tree().quit()
