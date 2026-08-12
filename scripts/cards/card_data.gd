class_name CardData
extends Resource

enum CardType { PART }

@export var id: StringName
@export var display_name: String
@export_range(0.0, 1000.0, 0.1) var cost: float = 0.0
@export var card_type: CardType = CardType.PART
