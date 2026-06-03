extends StaticBody3D

@export var upgrade_id: String = ""

@export_group("Visuals")
@export var broken_mesh: MeshInstance3D = null
@export var repaired_mesh: MeshInstance3D = null


func _ready() -> void:
	_update_visuals()
	EventBus.upgrade_completed.connect(_on_upgrade_completed)


func interact(_player: Node3D) -> void:
	if GameState.is_upgrade_complete(upgrade_id):
		return

	if not HomesteadManager.can_build(upgrade_id):
		var upgrade: Dictionary = HomesteadManager.get_upgrade(upgrade_id)
		var prereqs: Array = upgrade.get("prerequisites", []) as Array
		var missing: Array[String] = []
		for prereq: String in prereqs:
			if not GameState.is_upgrade_complete(prereq):
				var p: Dictionary = HomesteadManager.get_upgrade(prereq)
				missing.append(p.get("display_name", prereq) as String)
		return

	if HomesteadManager.has_resources(upgrade_id):
		HomesteadManager.build_upgrade(upgrade_id)
	else:
		_show_requirements()


func receive_item(item: Node3D) -> bool:
	if GameState.is_upgrade_complete(upgrade_id):
		return false
	if not item.is_in_group("carriable"):
		return false

	var mat_id: String = item.get("item_id") as String
	if mat_id.is_empty():
		return false

	var upgrade: Dictionary = HomesteadManager.get_upgrade(upgrade_id)
	var mat_costs: Dictionary = upgrade.get("material_costs", {}) as Dictionary

	if not mat_costs.has(mat_id):
		return false

	GameState.add_material(mat_id)
	item.queue_free()
	EventBus.material_deposited.emit(upgrade_id, mat_id)

	if HomesteadManager.has_resources(upgrade_id):
		HomesteadManager.build_upgrade(upgrade_id)

	return true


func _show_requirements() -> void:
	var upgrade: Dictionary = HomesteadManager.get_upgrade(upgrade_id)
	var cost: float = upgrade.get("money_cost", 0.0) as float
	var mats: Dictionary = upgrade.get("material_costs", {}) as Dictionary
	var desc: String = upgrade.get("description", "") as String
	# HUD will read this via EventBus
	EventBus.upgrade_inspected.emit(upgrade_id)


func _update_visuals() -> void:
	var complete: bool = GameState.is_upgrade_complete(upgrade_id)
	if broken_mesh:
		broken_mesh.visible = not complete
	if repaired_mesh:
		repaired_mesh.visible = complete


func _on_upgrade_completed(completed_id: String) -> void:
	if completed_id == upgrade_id:
		_update_visuals()
