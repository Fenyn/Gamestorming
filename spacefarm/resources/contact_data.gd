class_name ContactData
extends Resource

@export_group("Identity")
@export var contact_id: String = ""
@export var contact_name: String = ""
@export var role: String = ""
@export var location_claim: String = ""

@export_group("Messages")
@export var messages: Array[Dictionary] = []
