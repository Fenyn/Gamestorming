extends SceneTree
## Contact sheet of placeholder art, for eyeballing a batch without launching a duel.
## godot --headless --path zenith -s tests/art_sheet.gd -- <out.png> <id> <id> ...

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ids: Array = Array(args.slice(1))
	var cell: Vector2i = Vector2i(452, 320)
	var cols: int = 4
	var rows: int = int(ceil(float(ids.size()) / cols))
	var sheet: Image = Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	for i in range(ids.size()):
		var id: String = str(ids[i])
		var tex: Texture2D = load("res://assets/card_art/%s/%s.svg" % [id.get_slice("_", 0), id])
		var img: Image = tex.get_image()
		# Letterbox rather than stretch: these canvases differ by card type and a squashed
		# thumbnail would be judged for a shape the card never shows.
		var fit: float = minf(float(cell.x) / img.get_width(), float(cell.y) / img.get_height())
		img.resize(int(img.get_width() * fit), int(img.get_height() * fit))
		img.convert(Image.FORMAT_RGBA8)
		var at: Vector2i = Vector2i(i % cols, i / cols) * cell + (cell - img.get_size()) / 2
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(args[0])
	print("sheet saved: %d" % ids.size())
	quit()
