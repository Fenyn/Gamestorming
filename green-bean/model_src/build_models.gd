extends SceneTree

## Builds the custom models in model_src/ and saves each as an editable Godot
## scene in scenes/props/.
##
## Run from the green-bean folder:
##   godot --headless --path . --script res://model_src/build_models.gd
##
## Existing scenes are NOT overwritten, so changes you make in the editor are
## safe. To regenerate one from its script (losing editor changes), pass its
## name after "--":
##   godot --headless --path . --script res://model_src/build_models.gd -- --force hand_grinder
## or "--force all".

const OUT_DIR := "res://scenes/props/"
const MODELS := {
	"hand_grinder": preload("res://model_src/hand_grinder.gd"),
	"steam_station": preload("res://model_src/steam_station.gd"),
	"milk_pitcher": preload("res://model_src/milk_pitcher.gd"),
	"hot_water_dispenser": preload("res://model_src/hot_water_dispenser.gd"),
	"gooseneck_kettle": preload("res://model_src/gooseneck_kettle.gd"),
	"shot_press": preload("res://model_src/shot_press.gd"),
	"shot_press_station": preload("res://model_src/shot_press_station.gd"),
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
		var builder: GDScript = MODELS[model_name]
		var root: Node3D = builder.build()
		get_root().add_child(root)
		var err := ModelKit.save_scene(root, path)
		print("%s -> %s (%s)" % [key, path, "ok" if err == OK else "error %d" % err])
		if err != OK:
			failed += 1
		root.queue_free()
	quit(1 if failed > 0 else 0)
