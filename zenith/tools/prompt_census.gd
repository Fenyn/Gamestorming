extends SceneTree
## Counts prompts by kind over random duels between shipped decks, and how many of each kind
## had only one option, so needless stops in the flow show up. Run headless:
##   godot --headless --path zenith -s tools/prompt_census.gd

const GAMES: int = 12
const MAX_STEPS: int = 3000


func _init() -> void:
	var total: Dictionary = {}
	var single: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var decks: Array[DeckList] = []
	for n in DirAccess.get_files_at("res://data/decks"):
		if n.ends_with(".json"):
			decks.append(DeckList.load_from("res://data/decks".path_join(n)))
	for g in range(GAMES):
		var a: DeckList = decks[g % decks.size()]
		var b: DeckList = decks[(g * 3 + 1) % decks.size()]
		var ref: Referee = Referee.new()
		var pair: Array[DeckList] = [a, b]
		ref.setup(pair, lib, table, 100 + g)
		ref.start()
		var steps: int = 0
		while not ref.is_over() and steps < MAX_STEPS:
			steps += 1
			var p: Prompt = ref.engine.prompt
			var key: String = String(p.kind)
			if p.kind == &"pick_option":
				key += ":" + str(p.context.get("choice", p.context.get("op", "")))
			total[key] = int(total.get(key, 0)) + 1
			if p.options.size() == 1:
				single[key] = int(single.get(key, 0)) + 1
				if OS.get_cmdline_user_args().has("--detail"):
					print("single %s: %s  ctx=%s" % [key, p.describe(), JSON.stringify(p.context)])
			var opt: Command = p.options[rng.randi_range(0, p.options.size() - 1)]
			ref.submit(p.player, opt.to_dict())
			ref.engine.take_events()
	var keys: Array = total.keys()
	keys.sort()
	print("kind: prompts, single-option")
	for k in keys:
		print("  %-28s %6d %6d" % [k, total[k], int(single.get(k, 0))])
	quit()
