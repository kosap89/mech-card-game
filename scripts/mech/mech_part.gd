class_name MechPart
extends RefCounted

var card_data: CardData
var owner: PlayerState
var slot_index: int


func _init(source_card: CardData, owning_player: PlayerState, target_slot_index: int) -> void:
	card_data = source_card
	owner = owning_player
	slot_index = target_slot_index
