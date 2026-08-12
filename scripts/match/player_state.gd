class_name PlayerState
extends RefCounted

signal damage_total_changed(total: int)

var player_number: int
var mech: MechState
var total_mech_damage_dealt: int = 0


func _init(number: int, mech_max_health: int) -> void:
	player_number = number
	mech = MechState.new(mech_max_health)


func record_mech_damage(amount: int) -> void:
	if amount > 0:
		total_mech_damage_dealt += amount
		damage_total_changed.emit(total_mech_damage_dealt)


func reset() -> void:
	total_mech_damage_dealt = 0
	mech.reset()
	damage_total_changed.emit(total_mech_damage_dealt)
