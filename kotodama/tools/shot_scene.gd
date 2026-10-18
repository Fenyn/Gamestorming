extends Node
## Windowed run that saves screenshots of the yard and the panels to tools/shots/.
## Run: godot --path . tools/shot_scene.tscn   (not headless, it needs a window)
## Uses its own save file seeded with the first kanji and words.

const TEST_SAVE: String = "user://shot_kotodama.json"
const OUT_DIR: String = "res://tools/shots"
const SEED_KANJI: int = 14
const SEED_WORDS: int = 30


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	Progress.use_path(TEST_SAVE)
	Progress.reset_state()
	var today: int = Srs.today()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var fresh: Main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(fresh)
	await _frames(3)
	await _shot("fresh")
	fresh.queue_free()
	await _frames(1)
	var kanji: Array[Dictionary] = Progress.next_kanji(SEED_KANJI)
	var stage: int = 0
	for k in kanji:
		Progress.learn(Progress.kanji_key(k["ch"]), today)
		Progress.items[Progress.kanji_key(k["ch"])]["stage"] = stage % 8
		stage += 1
	var words: Array[Dictionary] = Progress.plantable_words(SEED_WORDS)
	for w in words:
		Progress.learn(Progress.word_key(w["word"]), today)
		Progress.items[Progress.word_key(w["word"])]["stage"] = stage % 7
		stage += 1
	for key in Progress.items:
		Progress.items[key]["due"] = today - (1 if stage % 3 == 0 else 0)
		stage += 1
	Progress.tally = {"called": 0, "watered": 0, "invited": 0, "planted": 0, "missed": 0}
	var main: Main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(3)
	var yard: Yard = main.get_node("%Yard")
	var camera: Camera2D = main.get_node("%Camera")
	camera.position = yard.zone_rect("meadow").get_center()
	await _frames(3)
	await _shot("yard")
	camera.position = yard.gate_position() + Vector2(-100, -80)
	await _frames(3)
	await _shot("gate")
	camera.position = yard.zone_rect("meadow").get_center()

	var drill: DrillPanel = main.get_node("%DrillPanel")
	drill.start(Progress.kanji_key(kanji[3]["ch"]), DrillPanel.Drill.CALL)
	drill.get_node("%Romaji").text = "hito"
	drill._on_romaji_changed("hito")
	await _frames(2)
	await _shot("drill_call")
	drill._on_romaji_submitted("hito")
	await _frames(2)
	await _shot("drill_result")
	drill._finish()

	drill.start(Progress.word_key(words[2]["word"]), DrillPanel.Drill.WHAT)
	await _frames(2)
	await _shot("drill_what")
	drill.hide()

	drill.start(Progress.kanji_key(kanji[5]["ch"]), DrillPanel.Drill.FORM)
	await _frames(2)
	await _shot("drill_form")
	drill.hide()

	var invite: InvitationPanel = main.get_node("%InvitationPanel")
	invite.start_kanji(Data.kanji_by_ch["明"], [], today)
	await _frames(2)
	await _shot("invite_parts")
	var rack: GridContainer = invite.get_node("%Rack")
	var first_tile: Button = rack.get_child(0)
	first_tile.button_pressed = true
	invite._on_next()
	await _frames(2)
	await _shot("invite_parts_checked")
	var next: Array[Dictionary] = Progress.next_kanji(1)
	invite.start_kanji(next[0], main.words_for(next[0]), today)
	invite._step = InvitationPanel.Step.ORDER
	invite._show_step()
	await _frames(20)
	await _shot("invite_order")
	invite._step = InvitationPanel.Step.NAME
	invite._show_step()
	await _frames(2)
	await _shot("invite_name")
	invite._step = InvitationPanel.Step.WORDS
	invite._show_step()
	await _frames(2)
	await _shot("invite_words")
	invite.hide()

	main.get_node("%DuskPanel").show_tally({"called": 7, "watered": 12, "invited": 5, "planted": 9})
	await _frames(2)
	await _shot("dusk")

	Progress.reset_state()
	print("SHOTS DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(OUT_DIR + "/" + name + ".png")
