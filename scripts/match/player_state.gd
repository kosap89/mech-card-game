class_name PlayerState
extends RefCounted

signal damage_total_changed(total: int)
signal scrap_changed(current_scrap: float)

var player_number: int
var mech: MechState
var total_mech_damage_dealt: int = 0
var current_scrap: float = 0.0
var starting_scrap: float = 0.0


func _init(number: int, mech_max_health: int, configured_starting_scrap: float) -> void:
	player_number = number
	mech = MechState.new(mech_max_health)
	starting_scrap = maxf(0.0, configured_starting_scrap)
	current_scrap = starting_scrap


func record_mech_damage(amount: int) -> void:
	if amount > 0:
		total_mech_damage_dealt += amount
		damage_total_changed.emit(total_mech_damage_dealt)


func add_scrap(amount: float) -> void:
	if amount <= 0.0:
		return
	current_scrap += amount
	scrap_changed.emit(current_scrap)


func can_afford(amount: float) -> bool:
	return amount >= 0.0 and current_scrap >= amount


func spend_scrap(amount: float) -> bool:
	if amount <= 0.0 or not can_afford(amount):
		return false
	current_scrap = maxf(0.0, current_scrap - amount)
	scrap_changed.emit(current_scrap)
	return true


func reset() -> void:
	total_mech_damage_dealt = 0
	current_scrap = starting_scrap
	mech.reset()
	damage_total_changed.emit(total_mech_damage_dealt)
	scrap_changed.emit(current_scrap)
