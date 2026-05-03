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

const CARD_PATHS: Array[String] = [
	"res://resources/cards/nordic/units/huscarl.tres",
	"res://resources/cards/nordic/units/berserker.tres",
	"res://resources/cards/nordic/units/fenrirs_chosen.tres",
	"res://resources/cards/nordic/units/dwarven_sapper.tres",
	"res://resources/cards/nordic/units/einherjar.tres",
	"res://resources/cards/nordic/units/changeling.tres",
	"res://resources/cards/nordic/units/stone_troll.tres",
	"res://resources/cards/nordic/units/valkyrie.tres",
	"res://resources/cards/nordic/units/frost_giant.tres",
	"res://resources/cards/nordic/buildings/grand_lodge.tres",
	"res://resources/cards/nordic/buildings/mead_hall.tres",
	"res://resources/cards/nordic/buildings/palisade_wall.tres",
	"res://resources/cards/nordic/buildings/blacksmith.tres",
	"res://resources/cards/nordic/buildings/powder_hall.tres",
	"res://resources/cards/nordic/spells/grand_melee.tres",
	"res://resources/cards/nordic/spells/eirs_mending.tres",
	"res://resources/cards/nordic/spells/hlins_bulwark.tres",
	"res://resources/cards/nordic/spells/blood_fury.tres",
	"res://resources/cards/nordic/spells/armor_of_retribution.tres",
	"res://resources/cards/nordic/spells/lightning_storm.tres",
	"res://resources/cards/nordic/spells/barrel_of_mead.tres",
]

func _load_all_cards() -> void:
	for path: String in CARD_PATHS:
		var card: CardData = load(path) as CardData
		if card != null and card.id != "":
			_cards[card.id] = card
