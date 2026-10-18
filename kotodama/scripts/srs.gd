class_name Srs
extends RefCounted
## The review ladder. Stages 0 to 6 schedule, stage 7 is burned.

const LADDER_DAYS: Array[int] = [0, 1, 3, 7, 14, 30, 90]
const BURNED: int = 7
const GURU: int = 3
const MASTER: int = 5
const DAY_ROLL_HOUR: int = 4
const MISS_DROP: int = 2
const MISS_FLOOR: int = 1


static func pass_stage(stage: int) -> int:
	return mini(stage + 1, BURNED)


static func miss_stage(stage: int) -> int:
	return maxi(MISS_FLOOR, stage - MISS_DROP)


## Day index the item is due on after reaching [param stage] today. Burned never comes due.
static func due_day(stage: int, today_index: int) -> int:
	if stage >= BURNED:
		return 0x7FFFFFFF
	return today_index + LADDER_DAYS[stage]


## Days since the Unix epoch, with the day rolling at [constant DAY_ROLL_HOUR] local time.
static func today() -> int:
	var unix: float = Time.get_unix_time_from_system()
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	var local: float = unix + bias_minutes * 60.0 - DAY_ROLL_HOUR * 3600.0
	return int(floor(local / 86400.0))
