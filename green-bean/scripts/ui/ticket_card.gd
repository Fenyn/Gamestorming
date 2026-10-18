class_name TicketCard
extends VBoxContainer

## The HUD's copy of the cup ticket for the order in hand: the cup code, the
## drink, and its steps. Done steps are ticked and greyed, the next one is
## marked. With info mode on (Tab), hovering a step shows how to do it.

signal tip_changed(text: String, at_y: float)

## Pseudo-steps around the recipe's own.
const GRAB_CUP := -1
const HAND_OFF := -2

@onready var _code: Label = %Code
@onready var _drink: Label = %Drink
@onready var _steps: VBoxContainer = %Steps
@onready var _info_key: HBoxContainer = %InfoKey

var _order: OrderData = null
var _rows: Array[HBoxContainer] = []
var _data: Array[Dictionary] = []
var _info_mode := false
var _hover_row := -1

func _ready() -> void:
	visible = false
	_info_key.add_child(KeyHint.make("Tab", ""))

func show_order(order: OrderData) -> void:
	if order == _order:
		return
	_order = order
	visible = order != null
	if order == null:
		return
	_code.text = order.ticket_code
	_drink.text = DrinkData.get_drink_name(order.drink_type)
	_build_steps()

func _build_steps() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	_data.clear()
	_data.append({"name": "Grab a cup", "step": GRAB_CUP, "tip": ""})
	var recipe_steps: Array = DrinkData.get_recipe(_order.drink_type)["steps"]
	for s in recipe_steps:
		var step: DrinkData.Step = s
		var sname := DrinkData.get_step_name(step, _order.drink_type)
		if sname.is_empty():
			continue
		_data.append({"name": sname, "step": step, "tip": DrinkData.get_step_tooltip(step)})
	if _order.has_syrup():
		var syn := DrinkData.get_syrup_name(_order.requested_syrup as DrinkData.SyrupType)
		_data.append({"name": "%s syrup" % syn, "step": DrinkData.Step.ADD_SYRUP, "tip": "Set the cup under the pump and pump the count on the bottle's tag."})
	if _order.requested_sauce >= 0 and not DrinkData.has_step(_order.drink_type, DrinkData.Step.ADD_SAUCE):
		var san := DrinkData.get_sauce_name(_order.requested_sauce as DrinkData.SauceType)
		_data.append({"name": "%s sauce" % san, "step": DrinkData.Step.ADD_SAUCE, "tip": DrinkData.get_step_tooltip(DrinkData.Step.ADD_SAUCE)})
	_data.append({"name": "Lid", "step": DrinkData.Step.LID, "tip": "Hold the cup and press E at the lid caddy."})
	_data.append({"name": "Hand off", "step": HAND_OFF, "tip": "Set it on the pickup shelf."})
	for entry in _data:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiStyle.SPACE_S)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UiIcon.make(UiIcon.Kind.DOT, UiStyle.INK_SOFT, 18))
		var l := Label.new()
		l.text = str(entry["name"])
		l.theme_type_variation = UiStyle.TICKET_MUTED
		row.add_child(l)
		_steps.add_child(row)
		_rows.append(row)

## Ticks steps the cup has done (every step up to the furthest one done).
func refresh(cup: Cup) -> void:
	if _order == null:
		return
	var highest := -1
	for i in range(_data.size()):
		if _is_done(int(_data[i]["step"]), cup):
			highest = i
	for i in range(_rows.size()):
		var icon := _rows[i].get_child(0) as UiIcon
		var l := _rows[i].get_child(1) as Label
		if i <= highest:
			icon.kind = UiIcon.Kind.CHECK
			icon.color = UiStyle.OLIVE
			l.theme_type_variation = UiStyle.TICKET_MUTED
		elif i == highest + 1:
			icon.kind = UiIcon.Kind.NEXT
			icon.color = UiStyle.INK
			l.theme_type_variation = UiStyle.TICKET_TEXT
		else:
			icon.kind = UiIcon.Kind.DOT
			icon.color = UiStyle.INK_SOFT
			l.theme_type_variation = UiStyle.TICKET_MUTED
	_update_hover()

func _is_done(step: int, cup: Cup) -> bool:
	if step == GRAB_CUP:
		return cup != null
	if step == HAND_OFF or cup == null:
		return false
	match step:
		DrinkData.Step.SHOT_PRESS_BREW: return cup.has_shot
		DrinkData.Step.POUR_OVER_BREW: return cup.has_pour_over_coffee
		DrinkData.Step.HOT_WATER: return cup.has_hot_water
		DrinkData.Step.STEAM_MILK: return cup.has_steamed_milk
		DrinkData.Step.ADD_SAUCE: return cup.has_sauce
		DrinkData.Step.ADD_SYRUP: return cup.syrup_pumps > 0.0
		DrinkData.Step.LID: return cup.has_lid
	return false

func set_info_mode(on: bool) -> void:
	_info_mode = on
	_hover_row = -1
	if not on:
		tip_changed.emit("", 0.0)

func _update_hover() -> void:
	if not _info_mode:
		return
	var mouse := get_viewport().get_mouse_position()
	var found := -1
	for i in range(_rows.size()):
		if _rows[i].get_global_rect().grow(4).has_point(mouse) and not str(_data[i]["tip"]).is_empty():
			found = i
	if found == _hover_row:
		return
	_hover_row = found
	if found < 0:
		tip_changed.emit("", 0.0)
	else:
		tip_changed.emit(str(_data[found]["tip"]), _rows[found].global_position.y)
