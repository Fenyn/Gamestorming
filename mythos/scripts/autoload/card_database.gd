extends Node

var _cards: Dictionary = {}

func _ready() -> void:
	_load_all_cards()

func get_card(id: String) -> CardData:
	return _cards.get(id)

func get_all_units() -> Array[UnitData]:
	var result: Array[UnitData] = []
	for card: CardData in _cards.values():
		if card is UnitData:
			result.append(card as UnitData)
	return result

func get_all_buildings() -> Array[BuildingData]:
	var result: Array[BuildingData] = []
	for card: CardData in _cards.values():
		if card is BuildingData:
			result.append(card as BuildingData)
	return result

func get_all_spells() -> Array[SpellData]:
	var result: Array[SpellData] = []
	for card: CardData in _cards.values():
		if card is SpellData:
			result.append(card as SpellData)
	return result

func create_nordic_starter_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	_add_copies(deck, "huscarl", 3)
	_add_copies(deck, "berserker", 2)
	_add_copies(deck, "fenrirs_chosen", 2)
	_add_copies(deck, "dwarven_sapper", 2)
	_add_copies(deck, "einherjar", 2)
	_add_copies(deck, "changeling", 1)
	_add_copies(deck, "stone_troll", 2)
	_add_copies(deck, "valkyrie", 1)
	_add_copies(deck, "frost_giant", 1)
	_add_copies(deck, "mead_hall", 3)
	_add_copies(deck, "palisade_wall", 2)
	_add_copies(deck, "blacksmith", 2)
	_add_copies(deck, "powder_hall", 1)
	return deck

func _add_copies(deck: Array[CardData], card_id: String, count: int) -> void:
	var card: CardData = get_card(card_id)
	if card == null:
		push_warning("Card not found: " + card_id)
		return
	for i: int in range(count):
		deck.append(card.duplicate())

func _load_all_cards() -> void:
	_load_directory("res://resources/cards/nordic/units/")
	_load_directory("res://resources/cards/nordic/buildings/")
	_load_directory("res://resources/cards/nordic/spells/")

func _load_directory(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path: String = path + file_name
			var card: CardData = load(full_path) as CardData
			if card != null and card.id != "":
				_cards[card.id] = card
		file_name = dir.get_next()
