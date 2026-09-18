extends SceneTree
## Load probe: N concurrent duels driven by random legal commands through Referees, as a
## dedicated server would run them. Reports memory per duel and time per command.

func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var decks: Array[DeckList] = []
	for n in DirAccess.get_files_at("res://data/decks"):
		if n.ends_with(".json") and n != "starter_set.json":
			decks.append(DeckList.load_from("res://data/decks".path_join(n)))
	var n_duels: int = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 200
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var mem0: int = OS.get_static_memory_usage()
	var refs: Array[Referee] = []
	var t0: int = Time.get_ticks_usec()
	for i in range(n_duels):
		var r: Referee = Referee.new()
		r.setup([decks[i % decks.size()], decks[(i * 3 + 1) % decks.size()]], lib, table, 1000 + i)
		r.start()
		r.take_updates()
		refs.append(r)
	var t_setup: int = Time.get_ticks_usec() - t0
	var mem_setup: int = OS.get_static_memory_usage() - mem0
	# Every duel takes 40 commands, one at a time round-robin, with wire serialisation both ways
	var commands: int = 0
	var bytes_out: int = 0
	var t_submit: int = 0
	var t_views: int = 0
	var t_pack: int = 0
	t0 = Time.get_ticks_usec()
	for step in range(40):
		for r in refs:
			if r.is_over():
				continue
			var p: PromptView = r.prompt_for(r.engine.prompt.player)
			if p == null or p.options.is_empty():
				continue
			var opt: OptionView = p.options[rng.randi_range(0, p.options.size() - 1)]
			var wire: Dictionary = opt.to_command(p.player).to_dict()
			var a: int = Time.get_ticks_usec()
			var ok: bool = r.submit(p.player, wire) == ""
			var b: int = Time.get_ticks_usec()
			t_submit += b - a
			if ok:
				commands += 1
				var ups: Array[SeatUpdate] = r.take_updates()
				var dicts: Array[Dictionary] = []
				for u in ups:
					dicts.append(u.to_dict())
				var c: int = Time.get_ticks_usec()
				t_views += c - b
				for d in dicts:
					bytes_out += var_to_bytes(d).compress(FileAccess.COMPRESSION_ZSTD).size()
				t_pack += Time.get_ticks_usec() - c
	var t_play: int = Time.get_ticks_usec() - t0
	var mem_play: int = OS.get_static_memory_usage() - mem0
	print("duels: %d" % n_duels)
	print("setup: %.1f ms total, %.2f ms per duel" % [t_setup / 1000.0, t_setup / 1000.0 / n_duels])
	print("memory after setup: %.1f MB, %.0f KB per duel" % [mem_setup / 1048576.0, mem_setup / 1024.0 / n_duels])
	print("memory after play: %.1f MB, %.0f KB per duel" % [mem_play / 1048576.0, mem_play / 1024.0 / n_duels])
	print("commands: %d in %.1f ms, %.3f ms per command incl. updates" % [commands, t_play / 1000.0, t_play / 1000.0 / maxf(1, commands)])
	print("split per command: submit %.2f ms, views %.2f ms, pack %.2f ms" % [t_submit / 1000.0 / maxf(1, commands), t_views / 1000.0 / maxf(1, commands), t_pack / 1000.0 / maxf(1, commands)])
	print("wire: %.0f bytes compressed per command (both seats)" % (bytes_out / maxf(1, commands)))
	quit()
