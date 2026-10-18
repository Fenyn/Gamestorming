extends SceneTree
## Headless checks for Romaji, Srs and StrokeCheck. Prints TEST RESULT: PASS or FAIL.

var _failures: int = 0


func _init() -> void:
	_romaji()
	_srs()
	_strokes()
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(name: String, got: Variant, want: Variant) -> void:
	if got != want:
		_failures += 1
		print("FAIL %s: got %s want %s" % [name, str(got), str(want)])


func _romaji() -> void:
	_check("kazan", Romaji.to_kana("kazan"), "かざn")
	_check("kazan final", Romaji.to_kana_final("kazan"), "かざん")
	_check("taberu", Romaji.to_kana("taberu"), "たべる")
	_check("nihon", Romaji.to_kana("nihon"), "にほn")
	_check("nihonn", Romaji.to_kana("nihonn"), "にほん")
	_check("n before consonant", Romaji.to_kana("kanji"), "かんじ")
	_check("n before vowel", Romaji.to_kana("kani"), "かに")
	_check("n apostrophe", Romaji.to_kana("kin'enn"), "きんえん")
	_check("n apostrophe final", Romaji.to_kana_final("kin'en"), "きんえん")
	_check("double consonant", Romaji.to_kana("gakkou"), "がっこう")
	_check("shi chi tsu", Romaji.to_kana("shichitsu"), "しちつ")
	_check("si ti tu", Romaji.to_kana("sititu"), "しちつ")
	_check("kyou", Romaji.to_kana("kyou"), "きょう")
	_check("jya", Romaji.to_kana("jyajuujo"), "じゃじゅうじょ")
	_check("fu hu", Romaji.to_kana("fuhu"), "ふふ")
	_check("wo", Romaji.to_kana("wo"), "を")
	_check("long mark", Romaji.to_kana("ko-hi-"), "こーひー")
	_check("pending k", Romaji.to_kana("k"), "k")
	_check("pending ky", Romaji.to_kana("ky"), "ky")
	_check("small tsu", Romaji.to_kana("xtsu"), "っ")
	_check("uppercase", Romaji.to_kana("OOKII"), "おおきい")
	_check("kata to hira", Romaji.katakana_to_hiragana("カザン"), "かざん")
	_check("is kana", Romaji.is_kana("かざん"), true)
	_check("is kana latin", Romaji.is_kana("かzan"), false)


func _srs() -> void:
	_check("pass 0", Srs.pass_stage(0), 1)
	_check("pass 6", Srs.pass_stage(6), 7)
	_check("pass burned", Srs.pass_stage(7), 7)
	_check("miss 1", Srs.miss_stage(1), 1)
	_check("miss 3", Srs.miss_stage(3), 1)
	_check("miss 5", Srs.miss_stage(5), 3)
	_check("due 0", Srs.due_day(0, 100), 100)
	_check("due 1", Srs.due_day(1, 100), 101)
	_check("due 3", Srs.due_day(3, 100), 107)
	_check("due 6", Srs.due_day(6, 100), 190)
	_check("due burned", Srs.due_day(7, 100) > 1000000, true)
	_check("today positive", Srs.today() > 20000, true)


func _strokes() -> void:
	var checker: StrokeCheck = StrokeCheck.new()
	var expected: PackedVector2Array = PackedVector2Array([Vector2(20, 50), Vector2(50, 52), Vector2(90, 54)])
	var good: PackedVector2Array = PackedVector2Array([Vector2(24, 46), Vector2(60, 50), Vector2(85, 56)])
	_check("good stroke", checker.check(good, expected), "")
	var backwards: PackedVector2Array = PackedVector2Array([Vector2(85, 56), Vector2(60, 50), Vector2(24, 46)])
	_check("backwards stroke", checker.check(backwards, expected), "start")
	var short: PackedVector2Array = PackedVector2Array([Vector2(22, 50), Vector2(30, 50), Vector2(80, 54)])
	_check("short still ok", checker.check(short, expected), "")
	var tiny: PackedVector2Array = PackedVector2Array([Vector2(22, 50), Vector2(24, 50)])
	_check("tiny stroke", checker.check(tiny, expected), "end")
	var far: PackedVector2Array = PackedVector2Array([Vector2(20, 100), Vector2(90, 104)])
	_check("far stroke", checker.check(far, expected), "start")
	var scaled: PackedVector2Array = StrokeCheck.to_box(PackedVector2Array([Vector2(256, 128)]), 256.0)
	_check("to box", scaled[0].is_equal_approx(Vector2(109, 54.5)), true)
	var from: PackedVector2Array = StrokeCheck.from_json([[1.5, 2.5], [3, 4]])
	_check("from json", from.size() == 2 and from[0] == Vector2(1.5, 2.5), true)
