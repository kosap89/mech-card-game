class_name MechState
extends RefCounted

signal health_changed(current_health: int, max_health: int)

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


func reset() -> void:
	current_health = max_health
	slots.fill(null)
	health_changed.emit(current_health, max_health)
