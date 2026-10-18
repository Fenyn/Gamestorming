extends SceneTree

## Saves UiStyle.build_theme() as the project theme (assets/ui/ui_theme.tres).
## An existing file is kept so editor tweaks survive; pass "-- --force" to rebuild.
##   godot --headless --path . --script res://tools/build_ui_theme.gd -- --force

func _init() -> void:
	var force := OS.get_cmdline_user_args().has("--force")
	if FileAccess.file_exists(UiStyle.THEME_PATH) and not force:
		print("%s exists, skipped (use --force to rebuild)" % UiStyle.THEME_PATH)
		quit()
		return
	var err := ResourceSaver.save(UiStyle.build_theme(), UiStyle.THEME_PATH)
	print("%s -> %s" % [UiStyle.THEME_PATH, "ok" if err == OK else error_string(err)])
	quit()
