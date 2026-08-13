class_name MatchController
extends Node

signal match_started
signal time_changed(remaining_seconds: float)
signal match_ended(result_text: String)
signal state_changed
signal ai_card_played(card_name: String, slot_index: int, replaced: bool, old_part_name: String)

enum MatchState { READY, ACTIVE, ENDED }

@export var balance: BalanceConfig
@export var test_deck: CardDeckDefinition

var player_1: PlayerState
var player_2: PlayerState
var remaining_seconds: float = 0.0
var match_state: int = MatchState.READY
var result_text := ""
var opponent_ai: SimpleOpponentAI


func _ready() -> void:
	assert(balance != null, "MatchController requires a BalanceConfig resource.")
	assert(test_deck != null, "MatchController requires a CardDeckDefinition resource.")
	player_1 = PlayerState.new(1, balance.mech_max_health, balance.starting_scrap, test_deck, balance.draw_interval_seconds)
	player_2 = PlayerState.new(2, balance.mech_max_health, balance.starting_scrap, test_deck, balance.draw_interval_seconds)
	opponent_ai = SimpleOpponentAI.new(self, 2, balance.ai_decision_interval_seconds)
	opponent_ai.card_played.connect(_on_ai_card_played)
	start_match()


func _process(delta: float) -> void:
	if match_state != MatchState.ACTIVE:
		return
	var active_delta := minf(delta, remaining_seconds)
	var generated_scrap := balance.scrap_per_second * active_delta
	player_1.add_scrap(generated_scrap)
	player_2.add_scrap(generated_scrap)
	player_1.advance_card_draw(active_delta)
	player_2.advance_card_draw(active_delta)
	_update_player_combat(player_1, player_2, active_delta)
	if match_state == MatchState.ACTIVE:
		_update_player_combat(player_2, player_1, active_delta)
	if match_state == MatchState.ACTIVE:
		opponent_ai.advance(active_delta)
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	time_changed.emit(remaining_seconds)
	if is_zero_approx(remaining_seconds):
		end_match()


func start_match() -> void:
	player_1.reset(balance.starting_hand_size)
	player_2.reset(balance.starting_hand_size)
	remaining_seconds = balance.match_duration_seconds
	result_text = ""
	match_state = MatchState.ACTIVE
	opponent_ai.reset()
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


func apply_mech_damage(attacker: PlayerState, defender: PlayerState, amount: int) -> int:
	if match_state != MatchState.ACTIVE or attacker == null or defender == null or attacker == defender:
		return 0
	var applied := defender.mech.apply_damage(amount)
	attacker.record_mech_damage(applied)
	if balance.end_match_when_mech_reaches_zero and defender.mech.current_health <= 0:
		end_match()
	return applied


func _update_player_combat(attacker: PlayerState, defender: PlayerState, delta: float) -> void:
	for slot_value in attacker.mech.slots:
		var part: MechPart = slot_value
		if part == null:
			continue
		var activation_count := part.advance_activation(delta)
		for activation_index in activation_count:
			if match_state != MatchState.ACTIVE:
				return
			apply_mech_damage(attacker, defender, part.card_data.damage)


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


func _on_ai_card_played(card_name: String, slot_index: int, replaced: bool, old_part_name: String) -> void:
	ai_card_played.emit(card_name, slot_index, replaced, old_part_name)
