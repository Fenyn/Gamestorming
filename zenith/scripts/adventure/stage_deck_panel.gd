class_name StageDeckPanel
extends ColorRect
## A modal browser for the run's Life Deck: DeckInfo's stats up top and a RunDeckList below. Esc
## or Close dismisses it. The scrim blocks input to everything behind it.

@onready var panel: PanelContainer = $Center/Panel
@onready var close_button: Button = $Center/Panel/Column/Header/Close
@onready var info: DeckInfo = $Center/Panel/Column/Info
@onready var deck_list: RunDeckList = $Center/Panel/Column/DeckList


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	panel.add_theme_stylebox_override("panel", ZenithTheme.modal_panel())


func open(deck: DeckList, might_max: int, faces: CardFaceCache) -> void:
	info.show_deck(deck, might_max, faces)
	# The full list below replaces DeckInfo's own three-card highlight reel, which would otherwise
	# push the panel taller than the window; the stats/Aspects/composition block above stays.
	# show_deck() sets these visible again each time, so they are hidden after, not just once.
	(info.get_node("KeyHeader") as Control).visible = false
	(info.get_node("KeyCards") as Control).visible = false
	var mastery_def: CardDef = Session.library.defs.get(deck.mastery_id)
	# The Duelist is a stack of cards, so the caption lists the rungs instead of counting them.
	# Same wording as the deck detail's Aspect chips: "1 · Starved", with the line word added
	# when the stack climbs through more than one of the character's printed lines.
	var stack: PersonalityStack = deck.duelist_stack(Session.library)
	# Commas between rungs: the caption already spends its middle dots on its own fields.
	var rungs: String = ",  ".join(CardText.stack_rungs(stack))
	deck_list.set_caption("Mastery: %s   ·   %s   ·   %d cards" % [
		mastery_def.title if mastery_def != null else "None",
		rungs if rungs != "" else "Aspects %d" % deck.aspects, deck.cards.size()])
	deck_list.show_cards(deck.cards, Session.library, faces)
	visible = true
	close_button.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
