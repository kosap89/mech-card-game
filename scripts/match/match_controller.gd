class_name MatchController
extends Node

signal match_started
signal match_ended(result_text: String)
signal state_changed
signal ai_card_played(card_name: String, slot_index: int, replaced: bool, old_part_name: String)
signal player_1_target_changed(target_type: int, slot_index: int)

enum MatchState { READY, ACTIVE, ENDED }
enum TargetType { MAIN_MECH, PART }

@export var balance: BalanceConfig
@export var test_deck: CardDeckDefinition

var player_1: PlayerState
var player_2: PlayerState
var match_state: int = MatchState.READY
var result_text := ""
var opponent_ai: SimpleOpponentAI
var player_1_target_type: int = TargetType.MAIN_MECH
var player_1_target_slot_index: int = -1
var player_1_target_part: MechPart = null


func _ready() -> void:
	assert(balance != null, "MatchController requires a BalanceConfig resource.")
	assert(test_deck != null, "MatchController requires a CardDeckDefinition resource.")
	player_1 = PlayerState.new(1, balance.mech_max_health, balance.starting_scrap, test_deck, balance.draw_interval_seconds)
	player_2 = PlayerState.new(2, balance.mech_max_health, balance.starting_scrap, test_deck, balance.draw_interval_seconds)
	player_2.mech.slots_changed.connect(_validate_player_1_target)
	opponent_ai = SimpleOpponentAI.new(self, 2, balance.ai_decision_interval_seconds)
	opponent_ai.card_played.connect(_on_ai_card_played)
	start_match()


func _process(delta: float) -> void:
	if match_state != MatchState.ACTIVE:
		return
	_update_builtin_cannon(player_1, player_2, delta)
	if match_state == MatchState.ACTIVE:
		_update_builtin_cannon(player_2, player_1, delta)
	if match_state == MatchState.ACTIVE:
		_update_player_combat(player_1, player_2, delta)
	if match_state == MatchState.ACTIVE:
		_update_player_combat(player_2, player_1, delta)
	if match_state != MatchState.ACTIVE:
		return
	player_1.advance_scrap_generation(delta, balance.scrap_gain_amount, balance.scrap_gain_interval_seconds)
	player_2.advance_scrap_generation(delta, balance.scrap_gain_amount, balance.scrap_gain_interval_seconds)
	player_1.advance_card_draw(delta)
	player_2.advance_card_draw(delta)
	opponent_ai.advance(delta)


func start_match() -> void:
	_reset_player_1_target(false)
	player_1.reset(balance.starting_hand_size)
	player_2.reset(balance.starting_hand_size)
	result_text = ""
	match_state = MatchState.ACTIVE
	opponent_ai.reset()
	match_started.emit()
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


func get_builtin_cannon_remaining(player_number: int) -> float:
	var player := get_player(player_number)
	if player == null:
		return 0.0
	return player.mech.get_builtin_cannon_remaining(balance.builtin_cannon_activation_interval_seconds)


func try_play_card(player_number: int, card: CardData, slot_index: int) -> int:
	if match_state != MatchState.ACTIVE:
		return PlayerState.PlayPartResult.INVALID_CARD
	var player := get_player(player_number)
	if player == null:
		return PlayerState.PlayPartResult.INVALID_CARD
	return player.try_play_part(card, slot_index, balance.scrap_return_fraction)


func try_trash_part(player_number: int, slot_index: int) -> int:
	if match_state != MatchState.ACTIVE:
		return PlayerState.TrashPartResult.EMPTY_SLOT
	var player := get_player(player_number)
	if player == null:
		return PlayerState.TrashPartResult.INVALID_SLOT
	return player.try_trash_part(slot_index, balance.scrap_return_fraction)


func set_player_1_target_main_mech() -> bool:
	if match_state != MatchState.ACTIVE:
		return false
	_reset_player_1_target()
	return true


func set_player_1_target_part(slot_index: int) -> bool:
	if match_state != MatchState.ACTIVE or not player_2.mech.is_valid_slot(slot_index):
		return false
	var part: MechPart = player_2.mech.slots[slot_index]
	if part == null:
		return false
	player_1_target_type = TargetType.PART
	player_1_target_slot_index = slot_index
	player_1_target_part = part
	player_1_target_changed.emit(player_1_target_type, player_1_target_slot_index)
	return true


func apply_mech_damage(attacker: PlayerState, defender: PlayerState, amount: int) -> int:
	if match_state != MatchState.ACTIVE or attacker == null or defender == null or attacker == defender:
		return 0
	var applied := defender.mech.apply_damage(amount)
	attacker.record_mech_damage(applied)
	if defender.mech.current_health <= 0:
		end_match(attacker.player_number)
	return applied


func _update_builtin_cannon(attacker: PlayerState, defender: PlayerState, delta: float) -> void:
	var activation_count := attacker.mech.advance_builtin_cannon(delta, balance.builtin_cannon_activation_interval_seconds)
	for activation_index in activation_count:
		if match_state != MatchState.ACTIVE:
			return
		apply_mech_damage(attacker, defender, balance.builtin_cannon_damage)


func _update_player_combat(attacker: PlayerState, defender: PlayerState, delta: float) -> void:
	for slot_value in attacker.mech.slots:
		var part: MechPart = slot_value
		if part == null:
			continue
		var activation_count := part.advance_activation(delta)
		for activation_index in activation_count:
			if match_state != MatchState.ACTIVE:
				return
			if attacker == player_1:
				_apply_player_1_installed_weapon_damage(part.card_data.damage)
			else:
				apply_mech_damage(attacker, defender, part.card_data.damage)


func _apply_player_1_installed_weapon_damage(amount: int) -> int:
	_validate_player_1_target()
	if player_1_target_type == TargetType.PART:
		return player_2.mech.damage_part(player_1_target_slot_index, amount)
	return apply_mech_damage(player_1, player_2, amount)


func _validate_player_1_target() -> void:
	if player_1_target_type != TargetType.PART:
		return
	var valid := player_2.mech.is_valid_slot(player_1_target_slot_index)
	valid = valid and player_2.mech.slots[player_1_target_slot_index] == player_1_target_part
	if not valid:
		_reset_player_1_target()


func _reset_player_1_target(emit_change: bool = true) -> void:
	var changed := player_1_target_type != TargetType.MAIN_MECH or player_1_target_slot_index != -1 or player_1_target_part != null
	player_1_target_type = TargetType.MAIN_MECH
	player_1_target_slot_index = -1
	player_1_target_part = null
	if emit_change and changed:
		player_1_target_changed.emit(player_1_target_type, player_1_target_slot_index)


func damage_debug_part(player_number: int, slot_index: int, amount: int = -1) -> int:
	if match_state != MatchState.ACTIVE:
		return 0
	var player := get_player(player_number)
	if player == null:
		return 0
	var requested := balance.debug_part_damage_amount if amount < 0 else amount
	return player.mech.damage_part(slot_index, requested)


# Presentation calls this temporary test hook; it is not a gameplay action.
func deal_debug_damage(attacking_player_number: int, amount: int = -1) -> int:
	if match_state != MatchState.ACTIVE or attacking_player_number not in [1, 2]:
		return 0
	var attacker := player_1 if attacking_player_number == 1 else player_2
	var defender := player_2 if attacking_player_number == 1 else player_1
	var requested := balance.debug_damage_amount if amount < 0 else amount
	var applied := apply_mech_damage(attacker, defender, requested)
	state_changed.emit()
	return applied


func end_match(winning_player_number: int = 0) -> void:
	if match_state != MatchState.ACTIVE:
		return
	match_state = MatchState.ENDED
	if winning_player_number == 1:
		result_text = "Player 1 wins!"
	elif winning_player_number == 2:
		result_text = "Player 2 wins!"
	else:
		result_text = "Match ended."
	match_ended.emit(result_text)
	state_changed.emit()


func get_state_name() -> String:
	return ["Ready", "Match Active", "Match Ended"][match_state]


func _on_ai_card_played(card_name: String, slot_index: int, replaced: bool, old_part_name: String) -> void:
	ai_card_played.emit(card_name, slot_index, replaced, old_part_name)
