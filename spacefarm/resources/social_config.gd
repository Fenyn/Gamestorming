class_name SocialConfig
extends Resource

@export_group("Hearts")
@export var points_per_heart: int = 250
@export var max_hearts_friend: int = 10
@export var max_hearts_romance: int = 14

@export_group("Daily")
@export var daily_talk_bonus: int = 20
@export var daily_decay: int = 2

@export_group("Gifts")
@export var gifts_per_week: int = 2
@export var birthday_multiplier: int = 8
@export var gift_points: Dictionary = {
	"loved": 80,
	"liked": 45,
	"neutral": 20,
	"disliked": -20,
	"hated": -40,
}

@export_group("Heart Ranges")
@export var heart_range_names: Array[String] = [
	"stranger", "stranger",
	"acquaintance", "acquaintance",
	"friendly", "friendly",
	"close", "close",
	"trusted", "trusted",
	"bonded",
]
