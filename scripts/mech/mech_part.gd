class_name MechPart
extends RefCounted

signal health_changed(current_health: int, max_health: int)
signal destroyed

enum TargetType { MAIN_MECH, PART }

var card_data: CardData
var owner: PlayerState
var slot_index: int
var max_health: int
var current_health: int
var activation_elapsed: float = 0.0
var target_type: int = TargetType.MAIN_MECH
var target_slot_index: int = -1
# Runtime identity is retained alongside the slot so replacing a part in-place
# cannot silently redirect an existing weapon target to the replacement.
var target_part: MechPart = null


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


func get_activation_remaining() -> float:
	if card_data == null or card_data.activation_interval <= 0.0:
		return 0.0
	return clampf(card_data.activation_interval - activation_elapsed, 0.0, card_data.activation_interval)


func target_main_mech() -> void:
	target_type = TargetType.MAIN_MECH
	target_slot_index = -1
	target_part = null


func target_enemy_part(enemy_slot_index: int, enemy_part: MechPart) -> bool:
	if enemy_slot_index < 0 or enemy_part == null:
		return false
	target_type = TargetType.PART
	target_slot_index = enemy_slot_index
	target_part = enemy_part
	return true
