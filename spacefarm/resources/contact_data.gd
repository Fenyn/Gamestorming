class_name ContactData
extends Resource

@export_group("Identity")
@export var contact_id: String = ""
@export var contact_name: String = ""
@export var role: String = ""
@export var greeting: String = ""

@export_group("Location")
@export var location_claim: String = ""
@export var schedule: Dictionary = {}

@export_group("Social")
@export var is_romanceable: bool = false
@export var birthday_season: String = ""
@export var birthday_day: int = 1
@export var gameplay_function: String = ""

@export_group("Gifts")
@export var loved_items: Array[String] = []
@export var liked_items: Array[String] = []
@export var disliked_items: Array[String] = []
@export var hated_items: Array[String] = []
@export var gift_responses: Dictionary = {}

@export_group("Dialogue")
@export var idle_chatter: Dictionary = {}
@export var messages: Array[Dictionary] = []
