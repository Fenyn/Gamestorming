extends PanelContainer

@onready var tier_tag: Label = %TierTag
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var effect_label: Label = %EffectLabel
@onready var desc_label: Label = %DescLabel
@onready var buy_button: Button = %BuyButton
@onready var cost_label: Label = %CostLabel

var _data: UpgradeData

enum State { LOCKED, AVAILABLE, MASTERED }


func setup(data: UpgradeData) -> void:
	_data = data


func _ready() -> void:
	if not _data:
		return

	name_label.text = _data.display_name
	buy_button.pressed.connect(_on_buy)

	_setup_tier_tag()

	EventBus.mana_changed.connect(func(_a: float, _d: float) -> void: _update_display())
	_update_display()


func _on_buy() -> void:
	UpgradeManager.purchase(_data.id)
	_update_display()


func _get_state() -> State:
	if not UpgradeManager.is_unlocked(_data.id):
		return State.LOCKED
	if UpgradeManager.is_maxed(_data.id):
		return State.MASTERED
	return State.AVAILABLE


func _setup_tier_tag() -> void:
	if _data.effect_type == "generator_mult":
		if _data.effect_target == "all":
			tier_tag.text = "All Spells"
			tier_tag.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
		else:
			var tier: int = int(_data.effect_target)
			var gen_data: GeneratorData = GeneratorManager.get_tier_data(tier)
			if gen_data:
				tier_tag.text = gen_data.display_name
			else:
				tier_tag.text = "Tier %d" % tier
			tier_tag.add_theme_color_override("font_color", ThemeBuilder.get_tier_color(tier))
	else:
		tier_tag.visible = false


func _update_display() -> void:
	if not _data:
		return

	var state: State = _get_state()
	var level: int = UpgradeManager.get_level(_data.id)

	match state:
		State.LOCKED:
			_display_locked()
		State.AVAILABLE:
			_display_available(level)
		State.MASTERED:
			_display_mastered(level)

	_apply_panel_style(state)


func _display_locked() -> void:
	name_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_DISABLED)
	level_label.text = ""
	effect_label.visible = false

	if _data.unlock_total_mana > 0.0:
		desc_label.text = "Unlocks at %s total mana" % GameFormulas.format_number(_data.unlock_total_mana)
	else:
		desc_label.text = "Unlocked by a milestone"
	desc_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_DISABLED)

	buy_button.text = "Locked"
	buy_button.disabled = true
	cost_label.text = ""


func _display_available(level: int) -> void:
	name_label.remove_theme_color_override("font_color")
	level_label.text = "Lv %d/%d" % [level, _data.max_level]

	effect_label.visible = true
	effect_label.text = _format_effect(level, false)
	effect_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)

	desc_label.text = _data.description
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6, 1))

	var cost: float = UpgradeManager.get_cost(_data.id)
	if _data.cost_type == "vitality":
		cost_label.text = "%s Vitality" % GameFormulas.format_number(cost)
		cost_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
		buy_button.disabled = GameState.vitality < cost
	else:
		cost_label.text = "%s Mana" % GameFormulas.format_number(cost)
		cost_label.remove_theme_color_override("font_color")
		buy_button.disabled = GameState.mana < cost

	buy_button.text = "Perform"


func _display_mastered(level: int) -> void:
	name_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
	level_label.text = "Lv %d (Mastered)" % level

	effect_label.visible = true
	effect_label.text = _format_effect(level, true)
	effect_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)

	desc_label.text = _data.description
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6, 1))

	buy_button.text = "Mastered"
	buy_button.disabled = true
	cost_label.text = ""


func _apply_panel_style(state: State) -> void:
	match state:
		State.LOCKED:
			add_theme_stylebox_override("panel",
				ThemeBuilder.create_panel_style(ThemeBuilder.TEXT_DISABLED, 0))
		State.AVAILABLE:
			var border_color: Color = ThemeBuilder.BORDER
			if _data.effect_type == "generator_mult" and _data.effect_target != "all":
				border_color = ThemeBuilder.get_tier_color(int(_data.effect_target))
			elif _data.effect_type == "generator_mult":
				border_color = ThemeBuilder.TEXT_GREEN
			add_theme_stylebox_override("panel",
				ThemeBuilder.create_panel_style(border_color, 3))
		State.MASTERED:
			add_theme_stylebox_override("panel",
				ThemeBuilder.create_panel_style(ThemeBuilder.TEXT_GREEN.darkened(0.4), 3))


func _format_effect(level: int, mastered: bool) -> String:
	var epl: float = _data.effect_per_level

	match _data.effect_type:
		"generator_mult":
			var current: float = 1.0 + epl * level
			if mastered:
				return "x%.2f" % current
			var next: float = 1.0 + epl * (level + 1)
			return "x%.2f -> x%.2f" % [current, next]

		"cascade_echo":
			var current_pct: int = int(epl * level * 100.0)
			if mastered:
				return "%d%% chance" % current_pct
			var next_pct: int = int(epl * (level + 1) * 100.0)
			return "%d%% -> %d%% chance" % [current_pct, next_pct]

		"bloom_burst":
			var current_sec: int = int(epl * level)
			if mastered:
				return "%ds burst" % current_sec
			var next_sec: int = int(epl * (level + 1))
			return "%ds -> %ds burst" % [current_sec, next_sec]

		"harmonic":
			if level == 0:
				var next_interval: int = 20
				if mastered:
					return "every %d beats" % next_interval
				return "every %d beats" % next_interval
			var current_interval: int = maxi(20 - (level - 1) * 3, 5)
			if mastered:
				return "every %d beats" % current_interval
			var next_interval: int = maxi(20 - level * 3, 5)
			return "every %d -> %d beats" % [current_interval, next_interval]

		"offline_beats":
			var current_min: int = int(epl * level / 60.0)
			if mastered:
				return "%dm offline" % current_min
			var next_min: int = int(epl * (level + 1) / 60.0)
			return "%dm -> %dm offline" % [current_min, next_min]

	return ""
