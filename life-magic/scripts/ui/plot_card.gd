extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var bloom_label: Label = %BloomLabel
@onready var slot_grid: GridContainer = %SlotGrid
@onready var plant_button: Button = %PlantButton
@onready var plant_cost_label: Label = %PlantCostLabel
@onready var tend_container: VBoxContainer = %TendContainer
@onready var bonus_label: Label = %BonusLabel

var _data: PlotData
var _slot_panels: Array[Dictionary] = []
var _tend_controls: Dictionary = {}

const STAGE_COLORS := {
	"empty": Color(0.2, 0.2, 0.2),
	"Inscribed": Color(0.25, 0.2, 0.4),
	"Pulsing": Color(0.35, 0.25, 0.55),
	"Surging": Color(0.45, 0.3, 0.7),
	"Resonant": Color(0.5, 0.4, 0.85),
	"Ascended": Color(0.85, 0.65, 0.13),
}

const BAR_COLORS := {
	"empty": Color(0.15, 0.15, 0.15),
	"Inscribed": Color(0.3, 0.22, 0.42),
	"Pulsing": Color(0.38, 0.28, 0.55),
	"Surging": Color(0.45, 0.35, 0.68),
	"Resonant": Color(0.52, 0.42, 0.8),
	"Ascended": Color(0.95, 0.75, 0.15),
}


func setup(data: PlotData) -> void:
	_data = data


func _ready() -> void:
	if not _data:
		return

	name_label.text = _data.display_name
	plant_button.pressed.connect(_on_plant)

	_build_slots()
	_build_tend_controls()

	EventBus.plot_growth_tick.connect(_update_display)
	EventBus.plot_seed_planted.connect(func(_id, _s): _update_display())
	EventBus.plot_tend_changed.connect(func(_id): _update_display())
	EventBus.plot_full_bloom.connect(_on_full_bloom)
	EventBus.mana_changed.connect(func(_a, _d): _update_plant_button())
	EventBus.tick_fired.connect(func(_t): _update_display())

	_update_display()


func _build_slots() -> void:
	slot_grid.columns = 2 if _data.slot_count <= 6 else 3

	for i in _data.slot_count:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 52)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		margin.add_child(vbox)

		var top_row := HBoxContainer.new()
		vbox.add_child(top_row)

		var stage_label := Label.new()
		stage_label.text = "Vacant"
		stage_label.add_theme_font_size_override("font_size", 11)
		stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(stage_label)

		var pct_label := Label.new()
		pct_label.text = ""
		pct_label.add_theme_font_size_override("font_size", 10)
		pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top_row.add_child(pct_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.max_value = 1.0
		bar.step = 0.001
		bar.value = 0.0
		bar.show_percentage = false
		vbox.add_child(bar)

		slot_grid.add_child(panel)
		_slot_panels.append({
			"panel": panel,
			"stage_label": stage_label,
			"pct_label": pct_label,
			"bar": bar,
			"last_stage": "",
		})


func _build_tend_controls() -> void:
	var header := Label.new()
	header.text = "Attune (%d pts)" % _data.tend_points
	header.add_theme_font_size_override("font_size", 12)
	tend_container.add_child(header)

	for target in _data.tend_options:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var label := Label.new()
		label.text = PlotManager.get_tend_label(target)
		label.custom_minimum_size.x = 100
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)

		var minus := Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(32, 32)
		minus.pressed.connect(func(): _adjust_tend(target, -1))
		row.add_child(minus)

		var pts_label := Label.new()
		pts_label.text = "0"
		pts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pts_label.custom_minimum_size.x = 24
		pts_label.add_theme_font_size_override("font_size", 13)
		row.add_child(pts_label)

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(32, 32)
		plus.pressed.connect(func(): _adjust_tend(target, 1))
		row.add_child(plus)

		tend_container.add_child(row)
		_tend_controls[target] = {
			"label": pts_label,
			"minus": minus,
			"plus": plus,
		}


func _on_plant() -> void:
	PlotManager.plant_seed(_data.id)
	_update_display()


func _on_full_bloom(plot_id: String, _bloom_count: int) -> void:
	if plot_id != _data.id:
		return
	for sp in _slot_panels:
		var bar: ProgressBar = sp["bar"]
		bar.modulate = Color(3.0, 2.5, 1.0, 1.0)
		var tween := create_tween()
		tween.tween_property(bar, "modulate", Color.WHITE, 1.0)
	_update_display()


func _adjust_tend(target: String, delta: int) -> void:
	var state: Dictionary = GameState.plots.get(_data.id, {})
	var alloc: Dictionary = state.get("tend_allocation", {}).duplicate()
	var current: int = int(alloc.get(target, 0))
	var new_val := maxi(0, current + delta)

	var total_used := 0
	for key in alloc:
		if key != target:
			total_used += int(alloc[key])

	if new_val + total_used > _data.tend_points:
		return

	if new_val == 0:
		alloc.erase(target)
	else:
		alloc[target] = new_val

	PlotManager.reallocate_tend(_data.id, alloc)
	_update_display()


func _update_display() -> void:
	if not _data:
		return

	var state: Dictionary = GameState.plots.get(_data.id, {})
	if state.is_empty():
		return

	var bloom_count: int = state.get("bloom_count", 0)
	if bloom_count > 0:
		bloom_label.text = "Full Resonance x%d" % bloom_count
	else:
		bloom_label.text = ""

	var slots: Array = state.get("slots", [])
	var blooming_count := 0
	var planted_count := 0

	for i in slots.size():
		if i >= _slot_panels.size():
			break
		var slot: Dictionary = slots[i]
		var sp: Dictionary = _slot_panels[i]
		var stage_label: Label = sp["stage_label"]
		var pct_label: Label = sp["pct_label"]
		var bar: ProgressBar = sp["bar"]

		if not slot["planted"]:
			stage_label.text = "Vacant"
			stage_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			pct_label.text = ""
			bar.value = 0.0
		else:
			planted_count += 1
			var growth: float = slot["growth"]
			var stage := PlotManager.get_plant_stage(growth)
			var pct := int(growth * 100.0)

			stage_label.text = stage
			stage_label.add_theme_color_override("font_color", STAGE_COLORS.get(stage, Color.WHITE))
			pct_label.text = "%d%%" % pct
			pct_label.add_theme_color_override("font_color", STAGE_COLORS.get(stage, Color.WHITE))
			bar.value = growth

			if stage != sp["last_stage"] and sp["last_stage"] != "":
				bar.modulate = Color(2.0, 2.0, 2.0, 1.0)
				var tween := create_tween()
				tween.tween_property(bar, "modulate", Color.WHITE, 0.5)
			sp["last_stage"] = stage

			if growth >= 1.0:
				blooming_count += 1

	_update_plant_button()
	_update_tend_display()
	_update_bonus_display()


func _update_plant_button() -> void:
	if not _data:
		return
	if not PlotManager.has_empty_slot(_data.id):
		plant_button.text = "All Inscribed"
		plant_button.disabled = true
		plant_cost_label.text = ""
	else:
		var cost := PlotManager.get_plant_cost(_data.id)
		plant_button.text = "Inscribe Sigil"
		plant_button.disabled = GameState.mana < cost
		plant_cost_label.text = "%s Mana" % GameFormulas.format_number(cost)


func _update_tend_display() -> void:
	var state: Dictionary = GameState.plots.get(_data.id, {})
	var alloc: Dictionary = state.get("tend_allocation", {})
	var total_used := 0
	for key in alloc:
		total_used += int(alloc[key])

	for target in _tend_controls:
		var ctrl: Dictionary = _tend_controls[target]
		var pts: int = int(alloc.get(target, 0))
		ctrl["label"].text = str(pts)
		ctrl["minus"].disabled = pts <= 0
		ctrl["plus"].disabled = total_used >= _data.tend_points


func _update_bonus_display() -> void:
	var parts: PackedStringArray = []
	var state: Dictionary = GameState.plots.get(_data.id, {})
	var alloc: Dictionary = state.get("tend_allocation", {})
	var avg := PlotManager.get_average_maturity(state)

	for target in alloc:
		var pts: int = int(alloc[target])
		if pts <= 0:
			continue
		var bonus_pct := _data.tend_power_base * avg * pts * 100.0
		if bonus_pct > 0.01:
			parts.append("%s +%.0f%%" % [PlotManager.get_tend_label(target), bonus_pct])

	var bloom_count: int = state.get("bloom_count", 0)
	if bloom_count > 0 and _data.full_bloom_bonus.has("all_generators"):
		var bloom_mult := pow(float(_data.full_bloom_bonus["all_generators"]), bloom_count)
		parts.append("Resonance: %.2fx all" % bloom_mult)

	bonus_label.text = ", ".join(parts) if parts.size() > 0 else "Allocate attunement points for bonuses"
