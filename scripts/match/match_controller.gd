class_name MatchController
extends Node

signal match_started
signal time_changed(remaining_seconds: float)
signal match_ended(result_text: String)
signal state_changed

enum MatchState { READY, ACTIVE, ENDED }

@export var balance: BalanceConfig

var player_1: PlayerState
var player_2: PlayerState
var remaining_seconds: float = 0.0
var match_state: int = MatchState.READY
var result_text := ""


func _ready() -> void:
	assert(balance != null, "MatchController requires a BalanceConfig resource.")
	player_1 = PlayerState.new(1, balance.mech_max_health, balance.starting_scrap)
	player_2 = PlayerState.new(2, balance.mech_max_health, balance.starting_scrap)
	start_match()


func _process(delta: float) -> void:
	if match_state != MatchState.ACTIVE:
		return
	var active_delta := minf(delta, remaining_seconds)
	var generated_scrap := balance.scrap_per_second * active_delta
	player_1.add_scrap(generated_scrap)
	player_2.add_scrap(generated_scrap)
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	time_changed.emit(remaining_seconds)
	if is_zero_approx(remaining_seconds):
		end_match()


func start_match() -> void:
	player_1.reset()
	player_2.reset()
	remaining_seconds = balance.match_duration_seconds
	result_text = ""
	match_state = MatchState.ACTIVE
	match_started.emit()
	time_changed.emit(remaining_seconds)
	state_changed.emit()


func restart_match() -> void:
	start_match()


func add_debug_scrap(player_number: int) -> void:
	if match_state != MatchState.ACTIVE:
		return
	var player := get_player(player_number)
	if player != null:
		player.add_scrap(balance.debug_scrap_amount)


func spend_debug_scrap(player_number: int) -> bool:
	if match_state != MatchState.ACTIVE:
		return false
	var player := get_player(player_number)
	return player != null and player.spend_scrap(balance.debug_scrap_amount)


func get_player(player_number: int) -> PlayerState:
	if player_number == 1:
		return player_1
	if player_number == 2:
		return player_2
	return null


# Presentation calls this temporary test hook; it is not a gameplay action.
func deal_debug_damage(attacking_player_number: int, amount: int = -1) -> int:
	if match_state != MatchState.ACTIVE or attacking_player_number not in [1, 2]:
		return 0
	var attacker := player_1 if attacking_player_number == 1 else player_2
	var defender := player_2 if attacking_player_number == 1 else player_1
	var requested := balance.debug_damage_amount if amount < 0 else amount
	var applied := defender.mech.apply_damage(requested)
	attacker.record_mech_damage(applied)
	state_changed.emit()
	if balance.end_match_when_mech_reaches_zero and defender.mech.current_health <= 0:
		end_match()
	return applied


func end_match() -> void:
	if match_state != MatchState.ACTIVE:
		return
	remaining_seconds = 0.0
	match_state = MatchState.ENDED
	if player_1.total_mech_damage_dealt > player_2.total_mech_damage_dealt:
		result_text = "Player 1 wins!"
	elif player_2.total_mech_damage_dealt > player_1.total_mech_damage_dealt:
		result_text = "Player 2 wins!"
	else:
		result_text = "Draw!"
	time_changed.emit(remaining_seconds)
	match_ended.emit(result_text)
	state_changed.emit()


func get_state_name() -> String:
	return ["Ready", "Match Active", "Match Ended"][match_state]
