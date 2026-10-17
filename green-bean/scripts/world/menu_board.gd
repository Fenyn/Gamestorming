extends Node3D

## Writes the active menu onto the menu board model: drink names on the left,
## the small-size price on the right. Refreshes when a day or prep starts, since
## that is when the menu can have changed.

func _ready() -> void:
	EventBus.prep_started.connect(_refresh)
	EventBus.day_started.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var names := get_node_or_null("NameColumn") as Label3D
	var prices := get_node_or_null("PriceColumn") as Label3D
	var footer := get_node_or_null("Footer") as Label3D
	if names == null or prices == null:
		return
	var drinks: Array = UnlockManager.get_menu_drinks()
	if drinks.is_empty():
		drinks = [DrinkData.DrinkType.POUR_OVER]
	var name_lines: PackedStringArray = []
	var price_lines: PackedStringArray = []
	for d in drinks:
		var drink: DrinkData.DrinkType = d
		name_lines.append(DrinkData.get_drink_name(drink))
		price_lines.append("$%.2f" % DrinkData.get_base_price(drink, DrinkData.CupSize.SMALL))
	names.text = "\n".join(name_lines)
	prices.text = "\n".join(price_lines)
	if footer:
		footer.text = "Sizes S  M  L  XL\nLarger sizes cost more"
