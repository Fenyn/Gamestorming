extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var desc_label: Label = %DescLabel
@onready var buy_button: Button = %BuyButton
@onready var cost_label: Label = %CostLabel

var _data: UpgradeData


func setup(data: UpgradeData) -> void:
	_data = data


func _ready() -> void:
	if not _data:
		return

	name_label.text = _data.display_name
	desc_label.text = _data.description
	buy_button.pressed.connect(_on_buy)

	EventBus.mana_changed.connect(func(_a, _d): _update_display())
	_update_display()


func _on_buy() -> void:
	UpgradeManager.purchase(_data.id)
	_update_display()


func _update_display() -> void:
	if not _data:
		return

	var level := UpgradeManager.get_level(_data.id)
	var maxed := UpgradeManager.is_maxed(_data.id)

	if maxed:
		level_label.text = "Lv %d (MAX)" % level
		buy_button.disabled = true
		buy_button.text = "Maxed"
		cost_label.text = ""
	else:
		level_label.text = "Lv %d" % level
		var cost := UpgradeManager.get_cost(_data.id)
		var currency := "Vitality" if _data.cost_type == "vitality" else "Mana"
		cost_label.text = "%s %s" % [GameFormulas.format_number(cost), currency]
		buy_button.text = "Upgrade"
		if _data.cost_type == "vitality":
			buy_button.disabled = GameState.vitality < cost
		else:
			buy_button.disabled = GameState.mana < cost
