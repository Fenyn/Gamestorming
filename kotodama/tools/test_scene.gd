extends Node
## Headless run of one day: invite a spirit, plant its words, pass and miss drills, save.
## Run as a scene so autoloads resolve: godot --headless --path . tools/test_scene.tscn
## Uses its own save file. Prints TEST RESULT: PASS or FAIL.

const TEST_SAVE: String = "user://test_kotodama.json"

var _failures: int = 0


func _ready() -> void:
	_run()


## Kana back to romaji for the few readings this test types. Enough for N5 numerals.
func _to_romaji(kana: String) -> String:
	var table: Dictionary = {
		"い": "i", "ち": "chi", "ひ": "hi", "と": "to", "つ": "tsu", "っ": "x", "に": "ni", "ん": "nn",
		"さ": "sa", "ぜ": "ze", "じ": "ji", "ゅ": "xyu", "う": "u", "き": "ki", "ょ": "xyo",
		"く": "ku", "は": "ha", "ご": "go", "ろ": "ro", "な": "na", "や": "ya", "か": "ka", "こ": "ko",
		"ど": "do", "お": "o", "ま": "ma", "え": "e", "あ": "a", "ね": "ne", "せ": "se", "た": "ta",
	}
	var out: String = ""
	for c in kana:
		out += table.get(c, c)
	return out


func _check(name: String, got: Variant, want: Variant) -> void:
	if got != want:
		_failures += 1
		print("FAIL %s: got %s want %s" % [name, str(got), str(want)])


func _run() -> void:
	Progress.use_path(TEST_SAVE)
	Progress.reset_state()
	await get_tree().process_frame
	var main: Main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var today: int = Srs.today()
	var yard: Yard = main.get_node("%Yard")
	var invite: InvitationPanel = main.get_node("%InvitationPanel")
	var drill: DrillPanel = main.get_node("%DrillPanel")

	_check("lights at the gate", yard.light_count(), 5)
	_check("no spirits yet", yard.spirits.size(), 0)

	# ---- invite 一
	main._on_light_clicked(0, false)
	_check("invite visible", invite.visible, true)
	_check("一 has no parts so starts at order", invite._step, InvitationPanel.Step.ORDER)
	invite._on_next()
	_check("name step", invite._step, InvitationPanel.Step.NAME)
	invite._on_next()
	_check("write step", invite._step, InvitationPanel.Step.WRITE)
	var canvas: StrokeCanvas = invite.get_node("%Canvas")
	for stroke in canvas.expected:
		canvas.submit_stroke(canvas._to_canvas(stroke))
	_check("ofuda written", canvas.active, false)
	invite._on_next()
	_check("placing meadow", yard.placing_zone, "meadow")
	main._on_place_clicked("meadow")
	_check("一 known", Progress.is_known("k:一"), true)
	_check("spirit added", yard.spirits.has("一"), true)
	_check("words step", invite._step, InvitationPanel.Step.WORDS)
	var offered: int = invite._words.size()
	_check("words offered use 一", offered >= 2 and offered <= 3, true)
	var offered_words: Array[String] = []
	for w in invite._words:
		offered_words.append(w["word"])
	print("offered: ", "、".join(offered_words))
	invite._on_romaji_submitted("wrong")
	_check("wrong reading keeps the word", invite._word_index, 0)
	for i in range(offered):
		var w: Dictionary = invite._words[i]
		var readings: Array = w["readings"]
		invite._on_romaji_submitted(_to_romaji(readings[0]))
	_check("一 planted", Progress.is_known("w:一"), true)
	_check("一つ planted", Progress.is_known("w:一つ"), true)
	_check("invite closed", invite.visible, false)
	_check("flowers added", yard.flowers.size(), offered)
	_check("tally invited", int(Progress.tally["invited"]), 1)
	_check("tally planted", int(Progress.tally["planted"]), offered)
	_check("four lights left", yard.light_count(), 4)

	# ---- call the spirit
	var spirit: Spirit = yard.spirits["一"]
	_check("spirit due today", Progress.is_due(spirit.key, today), true)
	main._on_spirit_clicked(spirit)
	_check("drill visible", drill.visible, true)
	_check("first drill is call", drill._drill, DrillPanel.Drill.CALL)
	drill._on_romaji_submitted("ichi")
	_check("call passed", drill._passed, true)
	drill._finish()
	_check("stage 1", Progress.stage_of("k:一"), 1)
	_check("due tomorrow", Progress.is_due("k:一", today), false)

	# ---- miss a flower, then pick its meaning
	var flower: Flower = yard.flowers["一"]
	main._on_flower_clicked(flower)
	drill._on_romaji_submitted("ni")
	_check("water missed", drill._passed, false)
	drill._finish()
	_check("miss floors at 1", Progress.stage_of("w:一"), 1)
	_check("missed item asks again today", Progress.is_due("w:一", today), true)
	_check("tally missed", int(Progress.tally["missed"]), 1)
	main._on_flower_clicked(flower)
	_check("second drill is what", drill._drill, DrillPanel.Drill.WHAT)
	var choices: GridContainer = drill.get_node("%Choices")
	var visible_choices: int = 0
	for child in choices.get_children():
		var button: Button = child
		if button.visible:
			visible_choices += 1
		if button.text == drill._correct_choice:
			drill._on_choice(button)
	_check("four choices", visible_choices, 4)
	_check("what passed", drill._passed, true)
	drill._finish()
	_check("flower stage 2", Progress.stage_of("w:一"), 2)

	# ---- write the spirit from memory (third drill)
	Progress.items["k:一"]["due"] = today
	Progress.items["k:一"]["drill"] = 2
	main.refresh()
	main._on_spirit_clicked(spirit)
	_check("third drill is form", drill._drill, DrillPanel.Drill.FORM)
	var drill_canvas: StrokeCanvas = drill.get_node("%Canvas")
	drill_canvas.submit_stroke(PackedVector2Array([Vector2(10, 10), Vector2(20, 200)]))
	drill_canvas.submit_stroke(PackedVector2Array([Vector2(10, 10), Vector2(20, 200)]))
	_check("two bad strokes end the drill", drill._answered, true)
	_check("form missed", drill._passed, false)
	drill._finish()
	_check("parts line shown only for kanji with parts", drill.get_node("%Parts").text, "")

	# ---- save and reload
	Progress.save_state()
	var before: int = Progress.items.size()
	Progress.load_state()
	_check("save round trip", Progress.items.size(), before)

	Progress.reset_state()
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
