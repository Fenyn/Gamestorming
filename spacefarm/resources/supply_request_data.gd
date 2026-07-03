class_name SupplyRequestData
extends Resource

enum Category { PROVISIONS, REQUEST, RESTORATION }

@export_group("Identity")
@export var request_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: Category = Category.REQUEST
@export var requester: String = ""

@export_group("Requirements")
@export var items_required: Dictionary = {}

@export_group("Rewards")
@export var reward_items: Dictionary = {}
@export var reward_friendship: int = 0
@export var reward_friendship_target: String = ""

@export_group("Behavior")
@export var is_recurring: bool = false
@export var unlocks_module: String = ""
