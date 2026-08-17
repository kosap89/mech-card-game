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
var build_elapsed: float = 0.0
var is_constructing: bool = true
# Guards the match-level combat consequence; removal by Trash/reset never sets it.
var combat_destruction_resolved: bool = false
var target_type: int = TargetType.MAIN_MECH
var target_slot_index: int = -1
# Runtime identity is retained alongside the slot so removing a target and later
# building another weapon there cannot silently redirect an existing target.
var target_part: MechPart = null


func _init(source_card: CardData, owning_player: PlayerState, target_slot_index: int) -> void:
	card_data = source_card
	owner = owning_player
	slot_index = target_slot_index
	max_health = maxi(1, card_data.max_health)
	current_health = max_health
	is_constructing = card_data.build_time > 0.0


func apply_damage(amount: int) -> int:
	if amount <= 0 or current_health <= 0 or is_constructing:
		return 0
	var applied := mini(amount, current_health)
	current_health -= applied
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		destroyed.emit()
	return applied


func mark_combat_destruction_resolved() -> bool:
	if combat_destruction_resolved or is_constructing or current_health > 0:
		return false
	combat_destruction_resolved = true
	return true


func advance_activation(delta: float) -> int:
	if is_constructing or current_health <= 0 or card_data.damage <= 0 or card_data.activation_interval <= 0.0:
		return 0
	activation_elapsed += delta
	var activation_count := 0
	while activation_elapsed >= card_data.activation_interval:
		activation_elapsed -= card_data.activation_interval
		activation_count += 1
	return activation_count


func get_activation_remaining() -> float:
	if is_constructing or card_data == null or card_data.activation_interval <= 0.0:
		return 0.0
	return clampf(card_data.activation_interval - activation_elapsed, 0.0, card_data.activation_interval)


func advance_construction(delta: float) -> bool:
	if not is_constructing:
		return false
	build_elapsed += maxf(0.0, delta)
	if build_elapsed < card_data.build_time:
		return false
	build_elapsed = card_data.build_time
	is_constructing = false
	current_health = max_health
	activation_elapsed = 0.0
	target_main_mech()
	return true


func get_build_remaining() -> float:
	if not is_constructing:
		return 0.0
	return clampf(card_data.build_time - build_elapsed, 0.0, card_data.build_time)


func target_main_mech() -> void:
	target_type = TargetType.MAIN_MECH
	target_slot_index = -1
	target_part = null


func target_enemy_part(enemy_slot_index: int, enemy_part: MechPart) -> bool:
	if is_constructing or enemy_slot_index < 0 or enemy_part == null or enemy_part.is_constructing:
		return false
	target_type = TargetType.PART
	target_slot_index = enemy_slot_index
	target_part = enemy_part
	return true
