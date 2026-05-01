extends ScrollContainer

@onready var row_container: VBoxContainer = %RowContainer

var _active_popup: GamePopup


func _ready() -> void:
	EventBus.milestone_earned.connect(func(_id): _rebuild())
	_build_ui()


func _build_ui() -> void:
	var header := Label.new()
	header.text = "Chronicle of Power"
	header.add_theme_font_size_override("font_size", 16)
	row_container.add_child(header)

	var desc := Label.new()
	desc.text = "Each milestone marks a turning point in your journey. Earn them to unlock new powers and abilities."
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	row_container.add_child(desc)

	var count_label := Label.new()
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
	count_label.text = "%d / %d milestones earned" % [
		MilestoneManager.get_earned_count(),
		MilestoneManager.get_total_count()
	]
	row_container.add_child(count_label)

	_add_separator()

	for data in MilestoneManager.milestone_data:
		_add_milestone_card(data)


func _add_milestone_card(data: MilestoneData) -> void:
	var is_earned := MilestoneManager.is_earned(data.id)

	var card := PanelContainer.new()
	var card_style := ThemeBuilder.create_panel_style(
		ThemeBuilder.TEXT_GOLD if is_earned else ThemeBuilder.BORDER,
		3 if is_earned else 0
	)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var title_row := HBoxContainer.new()
	var indicator := Label.new()
	indicator.add_theme_font_size_override("font_size", 14)
	indicator.custom_minimum_size.x = 20
	indicator.text = "*" if is_earned else " "
	indicator.add_theme_color_override("font_color", ThemeBuilder.TEXT_GOLD)
	title_row.add_child(indicator)

	var name_label := Label.new()
	name_label.text = data.display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color",
		ThemeBuilder.TEXT_GOLD if is_earned else ThemeBuilder.TEXT_PRIMARY)
	title_row.add_child(name_label)
	vbox.add_child(title_row)

	var desc_label := Label.new()
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if is_earned:
		desc_label.text = data.flavor_text
		desc_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
	else:
		desc_label.text = data.description
		desc_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)
	vbox.add_child(desc_label)

	var reward_label := Label.new()
	reward_label.text = _format_reward(data)
	reward_label.add_theme_font_size_override("font_size", 9)
	reward_label.add_theme_color_override("font_color",
		ThemeBuilder.TEXT_GREEN if is_earned else ThemeBuilder.TEXT_DISABLED)
	vbox.add_child(reward_label)

	row_container.add_child(card)


func _format_reward(data: MilestoneData) -> String:
	match data.reward_type:
		"unlock_upgrade":
			var upgrade := UpgradeManager.get_data(data.reward_target)
			if upgrade:
				return "Unlocks: %s" % upgrade.display_name
			return "Unlocks: %s" % data.reward_target
		"unlock_plot":
			var plot := PlotManager.get_plot_data(data.reward_target)
			if plot:
				return "Unlocks: %s" % plot.display_name
			return "Unlocks: %s" % data.reward_target
		"unlock_prestige":
			return "Unlocks: Life Cycle (prestige)"
		"production_burst":
			return "Reward: %ds of instant production" % int(data.reward_value)
		"bonus_essence":
			return "Reward: +%d Essence" % int(data.reward_value)
		"free_generators":
			return "Reward: Free spell of every active tier"
	return ""


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in row_container.get_children():
		row_container.remove_child(child)
		child.queue_free()
	_build_ui()


func _add_separator() -> void:
	var sep := HSeparator.new()
	row_container.add_child(sep)
