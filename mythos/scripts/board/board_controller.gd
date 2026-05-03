class_name BoardController
extends Node3D

var grid_slots: Array[Array] = [[], []]
var lane_slots: Array[Array] = [[], []]
var spell_slots: Array[Array] = [[], []]

func _ready() -> void:
	_build_board()
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_deselected.connect(_on_card_deselected)
	EventBus.spell_pool_selected.connect(_on_spell_selected)
	EventBus.spell_pool_deselected.connect(_on_spell_deselected)
	EventBus.slot_clicked.connect(_on_slot_clicked)

func _build_board() -> void:
	_build_ground_plane()
	_build_city(0, 5.0)
	_build_city(1, -5.0)
	_build_lanes(0, 1.5)
	_build_lanes(1, -1.5)
	_build_spell_track(0, 9.0)
	_build_spell_track(1, -9.0)

func _build_ground_plane() -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(12, 22)
	mesh_inst.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.25)
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.position = Vector3(0, -0.01, 0)
	add_child(mesh_inst)

func _build_city(player_index: int, base_z: float) -> void:
	var container: Node3D = get_node("Player" + str(player_index + 1) + "City")
	for row: int in range(5):
		for col: int in range(5):
			var slot: Area3D = _create_grid_slot(player_index, Vector2i(col, row))
			var x: float = float(col - 2)
			var z: float = base_z + float(row - 2)
			slot.position = Vector3(x, 0, z)
			container.add_child(slot)
			grid_slots[player_index].append(slot)

func _build_lanes(player_index: int, z_pos: float) -> void:
	var container: Node3D = get_node("Player" + str(player_index + 1) + "Lanes")
	for lane: int in range(5):
		var slot: Area3D = _create_lane_slot(player_index, lane)
		var x: float = float(lane - 2)
		slot.position = Vector3(x, 0, z_pos)
		container.add_child(slot)
		lane_slots[player_index].append(slot)

func _build_spell_track(player_index: int, z_pos: float) -> void:
	var container: Node3D = get_node("Player" + str(player_index + 1) + "Spells")
	for i: int in range(5):
		var slot: Node3D = _create_spell_slot(player_index, i)
		var x: float = float(i - 2)
		slot.position = Vector3(x, 0, z_pos)
		container.add_child(slot)
		spell_slots[player_index].append(slot)

func _create_grid_slot(player_index: int, grid_pos: Vector2i) -> Area3D:
	var slot: Area3D = Area3D.new()
	slot.set_script(preload("res://scripts/board/grid_slot.gd"))
	slot.grid_pos = grid_pos
	slot.owner_player = player_index

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.85, 0.05, 0.85)
	mesh_inst.mesh = box
	slot.add_child(mesh_inst)

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.85, 0.1, 0.85)
	col_shape.shape = shape
	slot.add_child(col_shape)

	slot.input_ray_pickable = true
	return slot

func _create_lane_slot(player_index: int, lane_index: int) -> Area3D:
	var slot: Area3D = Area3D.new()
	slot.set_script(preload("res://scripts/board/lane_slot.gd"))
	slot.lane_index = lane_index
	slot.owner_player = player_index

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.85, 0.05, 1.1)
	mesh_inst.mesh = box
	slot.add_child(mesh_inst)

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.85, 0.1, 1.1)
	col_shape.shape = shape
	slot.add_child(col_shape)

	slot.input_ray_pickable = true
	return slot

func _create_spell_slot(player_index: int, position_index: int) -> Node3D:
	var slot: Node3D = Node3D.new()
	slot.set_script(preload("res://scripts/board/spell_slot.gd"))
	slot.slot_position = position_index
	slot.owner_player = player_index

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.8, 0.03, 0.8)
	mesh_inst.mesh = box
	slot.add_child(mesh_inst)

	return slot

func highlight_valid_lane_slots(player_index: int) -> void:
	var player: PlayerState = GameState.get_player(player_index)
	for slot: LaneSlot in lane_slots[player_index]:
		var has_unit: bool = player.get_lane_unit(slot.lane_index) != null
		slot.set_highlighted(not has_unit)

func highlight_valid_grid_slots(player_index: int) -> void:
	var player: PlayerState = GameState.get_player(player_index)
	for slot: GridSlot in grid_slots[player_index]:
		var occupied: bool = player.get_grid_cell(slot.grid_pos) != null
		slot.set_highlighted(not occupied)

func unhighlight_all() -> void:
	for player_slots: Array in grid_slots:
		for slot: GridSlot in player_slots:
			slot.set_highlighted(false)
	for player_slots: Array in lane_slots:
		for slot: LaneSlot in player_slots:
			slot.set_highlighted(false)

func _on_card_selected(card_index: int) -> void:
	if not TurnManager.is_interactive_phase():
		return
	var player: PlayerState = GameState.get_active_player()
	if card_index < 0 or card_index >= player.hand.size():
		return
	var card: CardData = player.hand[card_index]
	if not GameState.can_afford(GameState.current_turn_player, card.cost):
		return
	unhighlight_all()
	if card.card_type == CardData.CardType.UNIT:
		highlight_valid_lane_slots(GameState.current_turn_player)
	elif card.card_type == CardData.CardType.BUILDING:
		highlight_valid_grid_slots(GameState.current_turn_player)

func _on_card_deselected() -> void:
	unhighlight_all()

func _on_spell_selected(spell_id: String) -> void:
	if not TurnManager.is_interactive_phase():
		return
	var spell: SpellData = CardDatabase.get_card(spell_id) as SpellData
	if spell == null or not GameState.can_afford(GameState.current_turn_player, spell.cost):
		return
	highlight_valid_lane_slots(GameState.current_turn_player)

func _on_spell_deselected() -> void:
	unhighlight_all()

func _on_slot_clicked(_slot_type: String, _position: Variant) -> void:
	unhighlight_all()
