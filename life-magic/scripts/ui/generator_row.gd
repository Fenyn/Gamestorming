extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var count_label: Label = %CountLabel
@onready var production_label: Label = %ProductionLabel
@onready var cost_label: Label = %CostLabel
@onready var buy_button: Button = %BuyButton

var _data: GeneratorData
var _buy_amount: int = 1

const BUY_AMOUNTS := [1, 10, 100, -1]
var _buy_index: int = 0


func setup(data: GeneratorData) -> void:
	_data = data


func _ready() -> void:
	if not _data:
		return

	name_label.text = _data.display_name
	tooltip_text = _data.description
	buy_button.pressed.connect(_on_buy_pressed)
	buy_button.gui_input.connect(_on_buy_gui_input)

	_apply_tier_style()

	EventBus.mana_changed.connect(func(_a, _d): _update_display())
	EventBus.generator_purchased.connect(func(t, _c):
		if t == _data.tier: _update_display()
	)
	EventBus.tick_fired.connect(func(_t): _on_tick())

	_update_display()


func _on_buy_pressed() -> void:
	var amount := _get_effective_buy_amount()
	if amount > 0:
		GeneratorManager.purchase_generator(_data.tier, amount)


func _on_buy_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cycle_buy_amount()


func _cycle_buy_amount() -> void:
	_buy_index = (_buy_index + 1) % BUY_AMOUNTS.size()
	_buy_amount = BUY_AMOUNTS[_buy_index]
	_update_display()


func _get_effective_buy_amount() -> int:
	if _buy_amount == -1:
		return GeneratorManager.get_max_affordable(_data.tier)
	return _buy_amount


func _apply_tier_style() -> void:
	var tier_color := ThemeBuilder.get_tier_color(_data.tier)
	add_theme_stylebox_override("panel", ThemeBuilder.create_panel_style(tier_color, 3))


func _on_tick() -> void:
	_update_display()
	if _data and GameState.get_generator_count(_data.tier) > 0:
		production_label.modulate = Color(1.5, 1.5, 1.5)
		var tween := create_tween()
		tween.tween_property(production_label, "modulate", Color.WHITE, 0.5)


func _update_display() -> void:
	if not _data:
		return

	var owned := GameState.get_generator_owned(_data.tier)
	var total := GameState.get_generator_count(_data.tier)
	if total > owned + 0.01:
		count_label.text = "%s (+%s)" % [GameFormulas.format_number(owned), GameFormulas.format_number(total - owned)]
	else:
		count_label.text = "%s" % GameFormulas.format_number(owned)

	var prod := GeneratorManager.get_production_per_beat(_data.tier)
	if _data.produces_tier == -1:
		production_label.text = "Produces %s Mana/beat" % GameFormulas.format_number(prod)
	else:
		var target := GeneratorManager.get_tier_data(_data.produces_tier)
		production_label.text = "Produces %s %s/beat" % [GameFormulas.format_number(prod), target.display_name]

	var amount := _get_effective_buy_amount()
	var amount_str := "Max" if _buy_amount == -1 else "x%d" % _buy_amount

	if amount <= 0:
		buy_button.text = "Buy %s" % amount_str
		buy_button.disabled = true
		cost_label.text = "---"
	else:
		var cost := GeneratorManager.get_bulk_cost(_data.tier, amount)
		buy_button.text = "Buy %s" % amount_str
		buy_button.disabled = GameState.mana < cost
		cost_label.text = "%s Mana" % GameFormulas.format_number(cost)
