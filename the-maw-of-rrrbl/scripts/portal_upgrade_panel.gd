extends PanelContainer
class_name PortalUpgradePanel

signal panel_closed()

var _portal: DreamerPortal
var _spark_manager: SparkManager
var _container: VBoxContainer
var _title_label: Label
var _summary_label: Label
var _buttons: Dictionary = {}

const UPGRADE_ORDER: Array[String] = [
	"flow", "yield", "burst",
	"momentum", "mass", "bounce", "gravity",
	"scatter", "magnet", "lucky",
]

const UPGRADE_DISPLAY: Dictionary = {
	"flow":     { "name": "Flow",     "desc": "Faster orb spawning",                       "section": "PRODUCTION" },
	"yield":    { "name": "Yield",    "desc": "Orbs earn more sparks",                     "section": "PRODUCTION" },
	"burst":    { "name": "Burst",    "desc": "Spawn multiple orbs per wave",              "section": "PRODUCTION" },
	"momentum": { "name": "Momentum", "desc": "Orbs launch faster",                        "section": "PHYSICS" },
	"mass":     { "name": "Mass",     "desc": "Heavier: faster downhill, harder to turn",  "section": "PHYSICS" },
	"bounce":   { "name": "Bounce",   "desc": "Orbs ricochet off walls (needs tunnels!)",  "section": "PHYSICS" },
	"gravity":  { "name": "Gravity",  "desc": "Increased fall speed on ramps",             "section": "PHYSICS" },
	"scatter":  { "name": "Scatter",  "desc": "Random launch angle spread",                "section": "BEHAVIOR" },
	"magnet":   { "name": "Magnet",   "desc": "Orbs curve toward the Maw",                 "section": "BEHAVIOR" },
	"lucky":    { "name": "Lucky",    "desc": "Chance for golden orbs worth 5x sparks",    "section": "BEHAVIOR" },
}

const SECTION_COLORS: Dictionary = {
	"PRODUCTION": Color(0.9, 0.75, 0.4),
	"PHYSICS": Color(0.4, 0.85, 0.9),
	"BEHAVIOR": Color(0.85, 0.5, 0.9),
}

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(320, 0)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 4)
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_container)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	_container.add_child(_title_label)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_size_override("font_size", 11)
	_summary_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_container.add_child(_summary_label)

	var current_section: String = ""
	for stat: String in UPGRADE_ORDER:
		var display: Dictionary = UPGRADE_DISPLAY[stat]
		var section: String = display["section"] as String
		if section != current_section:
			current_section = section
			_add_section_header(section)

		var btn: Button = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_upgrade_pressed.bind(stat))
		_container.add_child(btn)
		_buttons[stat] = btn

		var desc: Label = Label.new()
		desc.text = display["desc"] as String
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_container.add_child(desc)

	var sep: HSeparator = HSeparator.new()
	_container.add_child(sep)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.custom_minimum_size.y = 32
	close_btn.pressed.connect(close_panel)
	_container.add_child(close_btn)

func bind_spark_manager(sm: SparkManager) -> void:
	_spark_manager = sm

func open_for_portal(portal: DreamerPortal) -> void:
	_portal = portal
	visible = true
	_refresh()

func close_panel() -> void:
	visible = false
	_portal = null
	panel_closed.emit()

func _add_section_header(section_name: String) -> void:
	var sep: HSeparator = HSeparator.new()
	_container.add_child(sep)
	var header: Label = Label.new()
	header.text = section_name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", SECTION_COLORS.get(section_name, Color.WHITE))
	_container.add_child(header)

func _on_upgrade_pressed(stat: String) -> void:
	if _portal == null or _spark_manager == null:
		return
	var cost: int = _portal.get_upgrade_cost(stat)
	if cost < 0:
		return
	if not _spark_manager.spend(cost):
		return
	_portal.apply_upgrade(stat)
	_refresh()

func _refresh() -> void:
	if _portal == null:
		return

	var config: Dictionary = _portal.get_config()
	_title_label.text = config["name"] as String

	_summary_label.text = "F%d Y%d Bu%d | Mo%d Ma%d Bo%d G%d | Sc%d Mg%d Lu%d" % [
		_portal.flow_level, _portal.yield_level, _portal.burst_level,
		_portal.momentum_level, _portal.mass_level, _portal.bounce_level,
		_portal.gravity_level,
		_portal.scatter_level, _portal.magnet_level, _portal.lucky_level,
	]

	_refresh_stat("flow", "%.1fs" % _portal.get_spawn_interval())
	_refresh_stat("yield", "x%.1f" % _portal.get_orb_multiplier())
	_refresh_stat("burst", "%d orbs" % _portal.get_burst_count())
	_refresh_stat("momentum", "%.1f force" % _portal.get_orb_impulse())
	_refresh_stat("mass", "%.1f kg" % _portal.get_orb_mass())
	_refresh_stat("bounce", "%.1f" % _portal.get_orb_bounce())
	_refresh_stat("gravity", "%.1fx" % _portal.get_orb_gravity_scale())
	_refresh_stat("scatter", "%.0f deg" % _portal.get_scatter_angle() if _portal.scatter_level > 0 else "off")
	_refresh_stat("magnet", "%.1f pull" % _portal.get_magnet_strength() if _portal.magnet_level > 0 else "off")
	_refresh_stat("lucky", "%d%%" % int(_portal.get_lucky_chance() * 100) if _portal.lucky_level > 0 else "off")

func _refresh_stat(stat: String, value_text: String) -> void:
	var btn: Button = _buttons.get(stat) as Button
	if btn == null:
		return
	var display: Dictionary = UPGRADE_DISPLAY[stat]
	var stat_name: String = display["name"] as String
	var level: int = _portal.get_stat_level(stat)
	var max_level: int = _portal.get_stat_max(stat)
	var cost: int = _portal.get_upgrade_cost(stat)

	if cost < 0:
		btn.text = "%s  Lv.%d  [MAX]  (%s)" % [stat_name, level, value_text]
		btn.disabled = true
		btn.modulate = Color(0.4, 0.7, 0.4, 0.7)
	else:
		var can_afford: bool = _spark_manager != null and _spark_manager.can_afford(cost)
		btn.text = "%s  Lv.%d/%d  [%d sparks]  (%s)" % [stat_name, level, max_level, cost, value_text]
		btn.disabled = not can_afford
		btn.modulate = Color.WHITE if can_afford else Color(0.5, 0.5, 0.5, 0.7)
