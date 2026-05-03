class_name UnitInstance
extends RefCounted

var data: UnitData
var current_health: int = 0
var current_attack: int = 0
var lane_index: int = 0
var owner_index: int = 0
var summoning_sickness: bool = true
var has_attacked: bool = false
var bonus_attack: int = 0
var bonus_health: int = 0
var bonus_armor: int = 0
var has_reflect: bool = false
var valkyrie_used: bool = false

func get_effective_attack() -> int:
	return current_attack + bonus_attack

func get_effective_health() -> int:
	return current_health

func get_armor() -> int:
	var base: int = 0
	for kw: KeywordData in data.keywords:
		if kw.keyword == KeywordData.Keyword.ARMOR:
			base = kw.value
			break
	return base + bonus_armor

func get_siege() -> int:
	for kw: KeywordData in data.keywords:
		if kw.keyword == KeywordData.Keyword.SIEGE:
			return kw.value
	return 0

func has_keyword(keyword: KeywordData.Keyword) -> bool:
	for kw: KeywordData in data.keywords:
		if kw.keyword == keyword:
			return true
	return false

func take_damage(amount: int) -> int:
	var armor: int = get_armor()
	var actual: int = maxi(amount - armor, 0)
	current_health -= actual
	return actual

func is_dead() -> bool:
	return current_health <= 0
