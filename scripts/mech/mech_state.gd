class_name MechState
extends RefCounted

signal health_changed(current_health: int, max_health: int)
signal slots_changed

const SLOT_COUNT := 4

var max_health: int
var current_health: int
var slots: Array = []


func _init(configured_max_health: int) -> void:
	max_health = maxi(1, configured_max_health)
	current_health = max_health
	slots.resize(SLOT_COUNT)
	slots.fill(null)


func apply_damage(amount: int) -> int:
	if amount <= 0 or current_health <= 0:
		return 0
	var applied := mini(amount, current_health)
	current_health -= applied
	health_changed.emit(current_health, max_health)
	return applied


func is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT


func is_slot_empty(slot_index: int) -> bool:
	return is_valid_slot(slot_index) and slots[slot_index] == null


func install_part(part: MechPart, slot_index: int) -> bool:
	if part == null or not is_slot_empty(slot_index):
		return false
	part.slot_index = slot_index
	slots[slot_index] = part
	part.health_changed.connect(_on_part_health_changed)
	part.destroyed.connect(_on_part_destroyed.bind(part))
	slots_changed.emit()
	return true


func damage_part(slot_index: int, amount: int) -> int:
	if not is_valid_slot(slot_index):
		return 0
	var part: MechPart = slots[slot_index]
	if part == null:
		return 0
	return part.apply_damage(amount)


func _on_part_health_changed(_current_health: int, _max_health: int) -> void:
	slots_changed.emit()


func _on_part_destroyed(part: MechPart) -> void:
	if is_valid_slot(part.slot_index) and slots[part.slot_index] == part:
		slots[part.slot_index] = null
		slots_changed.emit()


func reset() -> void:
	current_health = max_health
	slots.fill(null)
	health_changed.emit(current_health, max_health)
	slots_changed.emit()
