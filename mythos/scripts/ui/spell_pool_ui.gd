class_name SpellPoolUI
extends VBoxContainer

var _spell_buttons: Array[Button] = []
var _selected_spell_id: String = ""

func _ready() -> void:
	visible = false
	_build_spell_list()
	EventBus.spell_pool_deselected.connect(_on_deselected)

func _build_spell_list() -> void:
	var header: Label = Label.new()
	header.text = "Spells"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	var spells: Array[SpellData] = CardDatabase.get_all_spells()
	for spell: SpellData in spells:
		var btn: Button = Button.new()
		btn.text = spell.display_name + " (" + str(spell.cost) + ")"
		btn.custom_minimum_size = Vector2(150, 30)
		btn.pressed.connect(_on_spell_pressed.bind(spell.id))
		add_child(btn)
		_spell_buttons.append(btn)

func _on_spell_pressed(spell_id: String) -> void:
	if _selected_spell_id == spell_id:
		_selected_spell_id = ""
		EventBus.spell_pool_deselected.emit()
	else:
		_selected_spell_id = spell_id
		EventBus.spell_pool_selected.emit(spell_id)

func _on_deselected() -> void:
	_selected_spell_id = ""
