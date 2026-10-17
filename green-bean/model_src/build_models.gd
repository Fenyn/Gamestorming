extends SceneTree

## Builds every custom model in model_src/ and writes it to assets/models/custom/.
##
## Run from the green-bean folder:
##   godot --headless --path . --script res://model_src/build_models.gd
## Then open the editor (or run --headless --editor --quit) to import the .glb files.

const OUT_DIR := "res://assets/models/custom/"
const MODELS := {
	"hand_grinder": preload("res://model_src/hand_grinder.gd"),
}

func _initialize() -> void:
	var failed := 0
	for model_name in MODELS:
		var builder: GDScript = MODELS[model_name]
		var root: Node3D = builder.build()
		get_root().add_child(root)
		var path := ProjectSettings.globalize_path(OUT_DIR + String(model_name) + ".glb")
		var err := ModelKit.export_glb(root, path)
		print("%s -> %s (%s)" % [model_name, path, "ok" if err == OK else "error %d" % err])
		if err != OK:
			failed += 1
		root.queue_free()
	quit(1 if failed > 0 else 0)
