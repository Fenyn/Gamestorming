extends SceneTree

## Saves each model_src builder as an editable scene in scenes/props/. Existing
## scenes are skipped so editor changes survive; "-- --force <name>" or
## "-- --force all" rebuilds (and loses editor changes).
##   godot --headless --path . --script res://model_src/build_models.gd

const OUT_DIR := "res://scenes/props/"
const MODELS := {
	"hand_grinder": preload("res://model_src/hand_grinder.gd"),
	"steam_station": preload("res://model_src/steam_station.gd"),
	"milk_pitcher": preload("res://model_src/milk_pitcher.gd"),
	"hot_water_dispenser": preload("res://model_src/hot_water_dispenser.gd"),
	"gooseneck_kettle": preload("res://model_src/gooseneck_kettle.gd"),
	"shot_press": preload("res://model_src/shot_press.gd"),
	"shot_press_station": preload("res://model_src/shot_press_station.gd"),
	"cone_dripper": preload("res://model_src/cone_dripper.gd"),
	"pour_over_stand": preload("res://model_src/pour_over_stand.gd"),
	"paper_cup_small": [preload("res://model_src/paper_cup.gd"), "small"],
	"paper_cup_medium": [preload("res://model_src/paper_cup.gd"), "medium"],
	"paper_cup_large": [preload("res://model_src/paper_cup.gd"), "large"],
	"paper_cup_extra_large": [preload("res://model_src/paper_cup.gd"), "extra_large"],
	"cup_dispenser": preload("res://model_src/cup_dispenser.gd"),
	"lid_caddy": preload("res://model_src/lid_caddy.gd"),
	"pos_terminal": preload("res://model_src/pos_terminal.gd"),
	"cash_drawer": preload("res://model_src/cash_drawer.gd"),
	"bar_mat": preload("res://model_src/bar_mat.gd"),
	"cash_pieces": preload("res://model_src/cash_pieces.gd"),
	"change_mat": preload("res://model_src/change_mat.gd"),
	"pickup_shelf": preload("res://model_src/pickup_shelf.gd"),
}

func _initialize() -> void:
	var forced: Array[String] = []
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--force" and i + 1 < args.size():
			forced.append(args[i + 1])
	var failed := 0
	for model_name in MODELS:
		var key := String(model_name)
		var path := OUT_DIR + key + ".tscn"
		if FileAccess.file_exists(path) and not (forced.has(key) or forced.has("all")):
			print("%s: %s exists, skipped (use --force %s to rebuild)" % [key, path, key])
			continue
		# An entry is a builder script, or [builder, args...] for one script that
		# makes several scenes.
		var entry: Variant = MODELS[model_name]
		var root: Node3D
		if entry is Array:
			var builder: GDScript = entry[0]
			root = builder.callv("build", entry.slice(1))
		else:
			root = (entry as GDScript).build()
		get_root().add_child(root)
		var err := ModelKit.save_scene(root, path)
		print("%s -> %s (%s)" % [key, path, "ok" if err == OK else "error %d" % err])
		if err != OK:
			failed += 1
		root.queue_free()
	quit(1 if failed > 0 else 0)
