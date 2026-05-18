class_name CombatCalc
extends RefCounted

const COVER_DAMAGE_REDUCTION: float = 0.5
const COVER_HIT_PENALTY: float = 0.25
const HIGH_GROUND_BONUS: float = 0.25
const LOW_GROUND_PENALTY: float = 0.25
const BASE_ENEMY_HIT_CHANCE: float = 0.65
const OVERWATCH_HIT_CHANCE: float = 0.50


static func compute_damage(base_damage: int, elev_diff: int, in_cover: bool, defense_bonus: int = 0) -> int:
	var damage: float = float(base_damage)
	if elev_diff > 0:
		damage *= (1.0 + HIGH_GROUND_BONUS)
	elif elev_diff < 0:
		damage *= (1.0 - LOW_GROUND_PENALTY)
	if in_cover:
		damage *= (1.0 - COVER_DAMAGE_REDUCTION)
	return maxi(roundi(damage) - defense_bonus, 1)


static func roll_hit(base_chance: float, in_cover: bool) -> bool:
	var chance: float = base_chance
	if in_cover:
		chance -= COVER_HIT_PENALTY
	return randf() < chance


static func get_modifier_text(elev_diff: int, in_cover: bool) -> String:
	var parts: Array[String] = []
	if elev_diff > 0:
		parts.append("High Ground: +%d%%" % roundi(HIGH_GROUND_BONUS * 100))
	elif elev_diff < 0:
		parts.append("Low Ground: -%d%%" % roundi(LOW_GROUND_PENALTY * 100))
	if in_cover:
		parts.append("Cover: -%d%%" % roundi(COVER_DAMAGE_REDUCTION * 100))
	if parts.is_empty():
		return ""
	return "\n".join(parts)
