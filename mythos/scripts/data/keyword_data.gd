class_name KeywordData
extends Resource

enum Keyword { RANGE, ARMOR, HASTE, ELUSIVE, SIEGE, MOBILITY, TRIUMPH, IMMUNE }

@export var keyword: Keyword = Keyword.HASTE
@export var value: int = 0
