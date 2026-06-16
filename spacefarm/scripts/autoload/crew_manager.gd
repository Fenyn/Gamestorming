extends Node

var _config: SocialConfig = preload("res://data/config/social_config.tres")

var crew_relationships: Dictionary = {}
var gifts_given_this_week: Dictionary = {}
var talked_today: Dictionary = {}


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)


func _on_day_started(_day: int) -> void:
	_apply_decay()
	_reset_talked()
	_check_weekly_reset()
	_check_birthdays()


func _apply_decay() -> void:
	for crew_id: String in _get_all_crew_ids():
		if talked_today.get(crew_id, false):
			continue
		var current: int = crew_relationships.get(crew_id, 0)
		if current <= 0:
			continue
		var max_pts: int = _config.max_hearts_friend * _config.points_per_heart
		if current >= max_pts:
			continue
		crew_relationships[crew_id] = maxi(0, current - _config.daily_decay)


func _reset_talked() -> void:
	talked_today = {}


func _check_weekly_reset() -> void:
	if TimeManager.get_day_of_week() == 0:
		gifts_given_this_week = {}


func _check_birthdays() -> void:
	var season_name: String = TimeManager.get_season_name().to_lower()
	var day: int = GameState.day
	for contact: ContactData in Database.get_all_contacts():
		if contact.birthday_season == season_name and contact.birthday_day == day:
			EventBus.notification_requested.emit(
				"Maia: It's %s's birthday today. Maybe bring them something?" % contact.contact_name
			)


# --- Friendship ---

func add_friendship(crew_id: String, points: int) -> void:
	var current: int = crew_relationships.get(crew_id, 0)
	var contact: ContactData = Database.get_contact(crew_id)
	var max_hearts: int = _config.max_hearts_friend
	if contact and contact.is_romanceable:
		max_hearts = _config.max_hearts_romance
	var max_pts: int = max_hearts * _config.points_per_heart
	crew_relationships[crew_id] = clampi(current + points, 0, max_pts)
	EventBus.crew_relationship_changed.emit(crew_id, get_heart_level(crew_id))


func get_heart_level(crew_id: String) -> int:
	return crew_relationships.get(crew_id, 0) / _config.points_per_heart


func get_heart_range(crew_id: String) -> String:
	var level: int = get_heart_level(crew_id)
	var idx: int = mini(level, _config.heart_range_names.size() - 1)
	return _config.heart_range_names[idx]


# --- Gifts ---

func can_give_gift(crew_id: String) -> bool:
	return gifts_given_this_week.get(crew_id, 0) < _config.gifts_per_week


func classify_gift(crew_id: String, item_id: String) -> String:
	var contact: ContactData = Database.get_contact(crew_id)
	if contact == null:
		return "neutral"
	if item_id in contact.loved_items:
		return "loved"
	if item_id in contact.liked_items:
		return "liked"
	if item_id in contact.disliked_items:
		return "disliked"
	if item_id in contact.hated_items:
		return "hated"
	return "neutral"


func give_gift(crew_id: String, item_id: String) -> String:
	var tier: String = classify_gift(crew_id, item_id)
	var points: int = _config.gift_points.get(tier, 0)
	if _is_birthday(crew_id):
		points *= _config.birthday_multiplier
	add_friendship(crew_id, points)
	gifts_given_this_week[crew_id] = gifts_given_this_week.get(crew_id, 0) + 1
	GameState.remove_item(item_id, 1)
	return get_gift_response(crew_id, tier)


func _is_birthday(crew_id: String) -> bool:
	var contact: ContactData = Database.get_contact(crew_id)
	if contact == null:
		return false
	var season_name: String = TimeManager.get_season_name().to_lower()
	return contact.birthday_season == season_name and contact.birthday_day == GameState.day


func get_gift_response(crew_id: String, tier: String) -> String:
	var contact: ContactData = Database.get_contact(crew_id)
	if contact and contact.gift_responses.has(tier):
		return contact.gift_responses[tier]
	return "[DEBUG] Gift response: %s tier — override in %s.tres" % [tier.to_upper(), crew_id]


# --- Talk ---

func talk_to(crew_id: String) -> String:
	if not talked_today.get(crew_id, false):
		talked_today[crew_id] = true
		add_friendship(crew_id, _config.daily_talk_bonus)
	return get_idle_chatter(crew_id)


func get_idle_chatter(crew_id: String) -> String:
	var contact: ContactData = Database.get_contact(crew_id)
	if contact == null:
		return "[DEBUG] Unknown crew member: %s" % crew_id
	var range_key: String = get_heart_range(crew_id)
	var pool: Array = contact.idle_chatter.get(range_key, [])
	if pool.size() > 0:
		return pool[randi() % pool.size()]
	if contact.greeting != "":
		return contact.greeting
	return "[DEBUG] No idle chatter for %s at heart range '%s' — add lines in %s.tres" % [
		contact.contact_name, range_key, crew_id
	]


# --- Persistence ---

func to_dict() -> Dictionary:
	return {
		"crew_relationships": crew_relationships.duplicate(),
		"gifts_given_this_week": gifts_given_this_week.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	crew_relationships = data.get("crew_relationships", {})
	gifts_given_this_week = data.get("gifts_given_this_week", {})


func _get_all_crew_ids() -> Array:
	return Database.get_contact_ids()


# --- Schedules ---

func get_scheduled_room(crew_id: String, hour: int) -> String:
	var contact: ContactData = Database.get_contact(crew_id)
	if contact == null:
		return ""
	var schedule: Dictionary = contact.schedule
	if schedule.is_empty():
		return contact.location_claim
	var day_key: String = TimeManager.get_day_name().to_lower()
	var day_schedule: Dictionary = schedule.get(day_key, schedule.get("default", {}))
	if day_schedule.is_empty():
		return contact.location_claim
	var target_room: String = contact.location_claim
	for sched_hour: int in day_schedule:
		if hour >= sched_hour:
			target_room = day_schedule[sched_hour]
	return target_room
