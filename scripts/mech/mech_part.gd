class_name MechPart
extends RefCounted

signal health_changed(current_health: int, max_health: int)
signal destroyed

var card_data: CardData
var owner: PlayerState
var slot_index: int
var max_health: int
var current_health: int
var activation_elapsed: float = 0.0


func _init(source_card: CardData, owning_player: PlayerState, target_slot_index: int) -> void:
	card_data = source_card
	owner = owning_player
	slot_index = target_slot_index
	max_health = maxi(1, card_data.max_health)
	current_health = max_health


func apply_damage(amount: int) -> int:
	if amount <= 0 or current_health <= 0:
		return 0
	var applied := mini(amount, current_health)
	current_health -= applied
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		destroyed.emit()
	return applied


func advance_activation(delta: float) -> int:
	if current_health <= 0 or card_data.damage <= 0 or card_data.activation_interval <= 0.0:
		return 0
	activation_elapsed += delta
	var activation_count := 0
	while activation_elapsed >= card_data.activation_interval:
		activation_elapsed -= card_data.activation_interval
		activation_count += 1
	return activation_count
