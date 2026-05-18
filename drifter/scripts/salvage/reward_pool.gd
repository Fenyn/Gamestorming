class_name RewardPool

enum RewardType { MODULE, IMPLANT, SCRAP, CELL }

const SALVAGE_MODULES: Array[String] = [
	"res://resources/modules/orbital_strike.tres",
	"res://resources/modules/siphon_field.tres",
	"res://resources/modules/cascade.tres",
	"res://resources/modules/emp_burst.tres",
	"res://resources/modules/arc_sweep.tres",
	"res://resources/modules/barrier.tres",
]

const SALVAGE_IMPLANTS: Array[String] = [
	"res://resources/implants/power_surge.tres",
	"res://resources/implants/auto_loader.tres",
	"res://resources/implants/resonance_field.tres",
]

const SALVAGE_CELLS: Array[String] = [
	"res://resources/cells/high_roller.tres",
	"res://resources/cells/even_cell.tres",
	"res://resources/cells/odd_cell.tres",
	"res://resources/cells/heavy_d8.tres",
	"res://resources/cells/loaded_cell.tres",
	"res://resources/cells/wild_cell.tres",
]

const SCRAP_ENCOUNTER: int = 8
const SCRAP_ELITE: int = 20
const SCRAP_APEX: int = 40


static func generate_choices(node_type: MapNodeData.NodeType) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []

	match node_type:
		MapNodeData.NodeType.ENCOUNTER:
			choices = _roll_encounter_rewards()
		MapNodeData.NodeType.ELITE:
			choices = _roll_elite_rewards()
		MapNodeData.NodeType.APEX:
			choices = _roll_apex_rewards()

	return choices


static func _roll_encounter_rewards() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var module: ModuleData = _pick_random_module()
	if module:
		results.append({"type": RewardType.MODULE, "data": module, "label": module.display_name, "description": module.description})
	var cell: CellData = _pick_random_cell()
	if cell:
		results.append({"type": RewardType.CELL, "data": cell, "label": cell.display_name, "description": cell.description})
	results.append({"type": RewardType.SCRAP, "data": null, "label": "Scrap", "description": "+" + str(SCRAP_ENCOUNTER) + " scrap", "value": SCRAP_ENCOUNTER})
	return results


static func _roll_elite_rewards() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var module: ModuleData = _pick_random_module()
	if module:
		results.append({"type": RewardType.MODULE, "data": module, "label": module.display_name, "description": module.description})
	var implant: ImplantData = _pick_random_implant()
	if implant:
		results.append({"type": RewardType.IMPLANT, "data": implant, "label": implant.display_name, "description": implant.description})
	var cell: CellData = _pick_random_cell()
	if cell:
		results.append({"type": RewardType.CELL, "data": cell, "label": cell.display_name, "description": cell.description})
	return results


static func _roll_apex_rewards() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var module: ModuleData = _pick_random_module()
	if module:
		results.append({"type": RewardType.MODULE, "data": module, "label": module.display_name, "description": module.description})
	var implant: ImplantData = _pick_random_implant()
	if implant:
		results.append({"type": RewardType.IMPLANT, "data": implant, "label": implant.display_name, "description": implant.description})
	results.append({"type": RewardType.SCRAP, "data": null, "label": "Big Haul", "description": "+" + str(SCRAP_APEX) + " scrap", "value": SCRAP_APEX})
	return results


static func _pick_random_module() -> ModuleData:
	var owned_ids: Array[String] = []
	for m: ModuleData in RunState.modules:
		owned_ids.append(m.id)

	var available: Array[String] = []
	for path: String in SALVAGE_MODULES:
		var res: ModuleData = load(path) as ModuleData
		if res and res.id not in owned_ids:
			available.append(path)

	if available.is_empty():
		available = SALVAGE_MODULES.duplicate()

	var path: String = available[randi() % available.size()]
	return load(path) as ModuleData


static func _pick_random_cell() -> CellData:
	var path: String = SALVAGE_CELLS[randi() % SALVAGE_CELLS.size()]
	return load(path) as CellData


static func _pick_random_implant() -> ImplantData:
	var owned_ids: Array[String] = []
	for imp: ImplantData in RunState.implants:
		owned_ids.append(imp.id)

	var available: Array[String] = []
	for path: String in SALVAGE_IMPLANTS:
		var res: ImplantData = load(path) as ImplantData
		if res and res.id not in owned_ids:
			available.append(path)

	if available.is_empty():
		return null

	var path: String = available[randi() % available.size()]
	return load(path) as ImplantData
