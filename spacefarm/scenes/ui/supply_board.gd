class_name SupplyBoard
extends PanelContainer

var _active_requests: Array[SupplyRequestData] = []

@onready var _title: Label = %Title
@onready var _provisions_section: VBoxContainer = %ProvisionsSection
@onready var _requests_section: VBoxContainer = %RequestsSection
@onready var _restoration_section: VBoxContainer = %RestorationSection
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	visible = false


func on_opened() -> void:
	_load_requests()
	_rebuild_ui()


func on_closed() -> void:
	pass


func _load_requests() -> void:
	_active_requests = Database.get_all_supply_requests()
	if GameState.supply_deposits.is_empty():
		for req: SupplyRequestData in _active_requests:
			if not GameState.supply_deposits.has(req.request_id):
				GameState.supply_deposits[req.request_id] = {}


func _rebuild_ui() -> void:
	_clear_section(_provisions_section)
	_clear_section(_requests_section)
	_clear_section(_restoration_section)

	var provisions_count: int = 0
	var requests_count: int = 0
	var restoration_count: int = 0

	for req: SupplyRequestData in _active_requests:
		if _is_completed(req) and not req.is_recurring:
			continue
		var entry: VBoxContainer = _create_request_entry(req)
		match req.category:
			SupplyRequestData.Category.PROVISIONS:
				_provisions_section.add_child(entry)
				provisions_count += 1
			SupplyRequestData.Category.REQUEST:
				_requests_section.add_child(entry)
				requests_count += 1
			SupplyRequestData.Category.RESTORATION:
				_restoration_section.add_child(entry)
				restoration_count += 1

	if provisions_count == 0:
		_add_empty_label(_provisions_section, "No provisions needed")
	if requests_count == 0:
		_add_empty_label(_requests_section, "No crew requests")
	if restoration_count == 0:
		_add_empty_label(_restoration_section, "No restoration tasks")

	_update_status()


func _create_request_entry(req: SupplyRequestData) -> VBoxContainer:
	var container: VBoxContainer = VBoxContainer.new()

	var header: Label = Label.new()
	var requester_name: String = ""
	if req.requester != "":
		var contact: ContactData = Database.get_contact(req.requester)
		if contact:
			requester_name = contact.contact_name + ": "
	header.text = "%s%s" % [requester_name, req.display_name]
	header.add_theme_font_size_override("font_size", 12)
	header.modulate = Color(0.9, 0.8, 0.5, 1)
	container.add_child(header)

	if req.description != "":
		var desc: Label = Label.new()
		desc.text = req.description
		desc.add_theme_font_size_override("font_size", 10)
		desc.modulate = Color(0.6, 0.6, 0.7, 1)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		container.add_child(desc)

	var deposited: Dictionary = GameState.supply_deposits.get(req.request_id, {})
	for item_id: String in req.items_required:
		var needed: int = req.items_required[item_id]
		var have: int = deposited.get(item_id, 0)
		var fulfilled: bool = have >= needed
		var btn: Button = Button.new()
		btn.text = "%s  %d / %d %s" % [
			_display_name(item_id), have, needed,
			"[DONE]" if fulfilled else "[deposit]"
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = fulfilled or not GameState.has_item(item_id)
		if not fulfilled:
			btn.pressed.connect(_on_deposit.bind(req.request_id, item_id))
		container.add_child(btn)

	if _is_completed(req):
		var done_label: Label = Label.new()
		done_label.text = "[COMPLETE — collect reward]"
		done_label.modulate = Color(0.3, 0.9, 0.3, 1)
		done_label.add_theme_font_size_override("font_size", 11)
		var collect_btn: Button = Button.new()
		collect_btn.text = "Collect Reward"
		collect_btn.pressed.connect(_on_collect_reward.bind(req))
		container.add_child(done_label)
		container.add_child(collect_btn)

	var sep: HSeparator = HSeparator.new()
	container.add_child(sep)
	return container


func _on_deposit(request_id: String, item_id: String) -> void:
	if not GameState.has_item(item_id):
		return
	GameState.remove_item(item_id, 1)
	if not GameState.supply_deposits.has(request_id):
		GameState.supply_deposits[request_id] = {}
	GameState.supply_deposits[request_id][item_id] = GameState.supply_deposits[request_id].get(item_id, 0) + 1

	var req: SupplyRequestData = _find_request(request_id)
	if req:
		var needed: int = req.items_required.get(item_id, 0)
		var have: int = GameState.supply_deposits[request_id].get(item_id, 0)
		GameState.items_shipped[item_id] = GameState.items_shipped.get(item_id, 0) + 1
		var crop: CropData = Database.get_crop(item_id)
		if crop:
			GameState.food_shipped_total += crop.food_units
	_rebuild_ui()


func _on_collect_reward(req: SupplyRequestData) -> void:
	for item_id: String in req.reward_items:
		GameState.add_item(item_id, req.reward_items[item_id])
	if req.reward_friendship > 0 and req.reward_friendship_target != "":
		CrewManager.add_friendship(req.reward_friendship_target, req.reward_friendship)
	if req.unlocks_module != "":
		EventBus.module_unlocked.emit(req.unlocks_module)
	if req.is_recurring:
		GameState.supply_deposits[req.request_id] = {}
	else:
		GameState.unlocked_story_entries.append(req.request_id)
	EventBus.notification_requested.emit("Request complete: %s" % req.display_name)
	EventBus.cargo_shipped.emit(GameState.supply_deposits.get(req.request_id, {}))
	_rebuild_ui()


func _is_completed(req: SupplyRequestData) -> bool:
	if req.request_id in GameState.unlocked_story_entries:
		return true
	var deposited: Dictionary = GameState.supply_deposits.get(req.request_id, {})
	for item_id: String in req.items_required:
		if deposited.get(item_id, 0) < req.items_required[item_id]:
			return false
	return true


func _find_request(request_id: String) -> SupplyRequestData:
	for req: SupplyRequestData in _active_requests:
		if req.request_id == request_id:
			return req
	return null


func _update_status() -> void:
	var total: int = _active_requests.size()
	var done: int = 0
	for req: SupplyRequestData in _active_requests:
		if _is_completed(req):
			done += 1
	_status_label.text = "%d / %d requests fulfilled" % [done, total]


func _display_name(item_id: String) -> String:
	var crop: CropData = Database.get_crop(item_id)
	if crop:
		return crop.get_active_name()
	return item_id.replace("_", " ").capitalize()


func _clear_section(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _add_empty_label(container: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(0.4, 0.4, 0.5, 1)
	container.add_child(label)
