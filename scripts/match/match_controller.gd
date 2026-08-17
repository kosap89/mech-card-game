class_name MatchController
extends Node

signal match_started
signal match_ended(result_text: String)
signal state_changed
signal ai_card_played(card_name: String, slot_index: int)
signal player_1_weapon_targets_changed
signal weapon_exploded(weapon_name: String, owner_player_number: int, explosion_damage: int)
signal mech_damaged(player_number: int, amount: int)
signal part_damaged(player_number: int, slot_index: int, amount: int)

enum MatchState { READY, ACTIVE, ENDED }

@export var balance: BalanceConfig
@export var test_deck: CardDeckDefinition
@export var load_persisted_settings: bool = false
@export var current_settings_path: String = BalanceSettingsStore.CURRENT_SETTINGS_PATH

var player_1: PlayerState
var player_2: PlayerState
var match_state: int = MatchState.READY
var result_text := ""
var opponent_ai: SimpleOpponentAI
var settings_store: BalanceSettingsStore
var settings_paused: bool = false


func _ready() -> void:
	assert(balance != null, "MatchController requires a BalanceConfig resource.")
	assert(test_deck != null, "MatchController requires a CardDeckDefinition resource.")
	settings_store = BalanceSettingsStore.new(balance, test_deck)
	if load_persisted_settings:
		settings_store.load_current(current_settings_path)
	balance = settings_store.runtime_balance
	test_deck = settings_store.runtime_deck
	player_1 = PlayerState.new(1, balance.mech_max_health, balance.starting_scrap, test_deck, balance.draw_interval_seconds)
	player_2 = PlayerState.new(2, balance.mech_max_health, balance.starting_scrap, test_deck, balance.draw_interval_seconds)
	player_2.mech.slots_changed.connect(_validate_player_1_weapon_targets)
	player_1.mech.slots_changed.connect(_validate_player_2_weapon_targets)
	opponent_ai = SimpleOpponentAI.new(self, 2, balance.ai_decision_interval_seconds)
	opponent_ai.card_played.connect(_on_ai_card_played)
	start_match()


func _process(delta: float) -> void:
	if settings_paused or match_state != MatchState.ACTIVE:
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
	player_1.reset(balance.starting_hand_size)
	player_2.reset(balance.starting_hand_size)
	result_text = ""
	match_state = MatchState.ACTIVE
	opponent_ai.reset()
	match_started.emit()
	state_changed.emit()


func restart_match() -> void:
	start_match()


func set_settings_paused(paused: bool) -> void:
	settings_paused = paused


func apply_settings_snapshot(snapshot: Dictionary) -> bool:
	settings_store.apply_snapshot(snapshot)
	var saved := settings_store.save_current(current_settings_path)
	_apply_runtime_configuration()
	restart_match()
	return saved


func _apply_runtime_configuration() -> void:
	for player in [player_1, player_2]:
		player.starting_scrap = balance.starting_scrap
		player.draw_interval_seconds = balance.draw_interval_seconds
		player.deck_definition = test_deck
		player.mech.max_health = balance.mech_max_health
	opponent_ai.decision_interval_seconds = balance.ai_decision_interval_seconds


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
	return player.try_play_part(card, slot_index)


func try_trash_part(player_number: int, slot_index: int) -> int:
	if match_state != MatchState.ACTIVE:
		return PlayerState.TrashPartResult.EMPTY_SLOT
	var player := get_player(player_number)
	if player == null:
		return PlayerState.TrashPartResult.INVALID_SLOT
	return player.try_trash_part(slot_index, balance.scrap_return_fraction)


func set_player_1_weapon_target_main_mech(weapon_slot_index: int) -> bool:
	var weapon := _get_player_1_weapon(weapon_slot_index)
	if match_state != MatchState.ACTIVE or weapon == null or weapon.is_constructing:
		return false
	weapon.target_main_mech()
	player_1_weapon_targets_changed.emit()
	return true


func set_player_1_weapon_target_part(weapon_slot_index: int, enemy_slot_index: int) -> bool:
	var weapon := _get_player_1_weapon(weapon_slot_index)
	if match_state != MatchState.ACTIVE or weapon == null or weapon.is_constructing or not player_2.mech.is_valid_slot(enemy_slot_index):
		return false
	var enemy_part: MechPart = player_2.mech.slots[enemy_slot_index]
	if not weapon.target_enemy_part(enemy_slot_index, enemy_part):
		return false
	player_1_weapon_targets_changed.emit()
	return true


func apply_mech_damage(attacker: PlayerState, defender: PlayerState, amount: int) -> int:
	if match_state != MatchState.ACTIVE or attacker == null or defender == null or attacker == defender:
		return 0
	var applied := defender.mech.apply_damage(amount)
	if applied > 0:
		mech_damaged.emit(defender.player_number, applied)
	attacker.record_mech_damage(applied)
	if defender.mech.current_health <= 0:
		end_match(attacker.player_number)
	return applied


func apply_part_damage(attacker: PlayerState, defender: PlayerState, slot_index: int, amount: int) -> int:
	if match_state != MatchState.ACTIVE or attacker == null or defender == null or attacker == defender:
		return 0
	if not defender.mech.is_valid_slot(slot_index):
		return 0
	var part: MechPart = defender.mech.slots[slot_index]
	if part == null or part.is_constructing:
		return 0
	var applied := defender.mech.damage_part(slot_index, amount)
	if applied > 0:
		part_damaged.emit(defender.player_number, slot_index, applied)
	if applied <= 0 or part.current_health > 0 or not part.mark_combat_destruction_resolved():
		return applied
	# Phase 16 temporary rule: an ACTIVE weapon explodes for its attack damage.
	var explosion_damage := maxi(0, part.card_data.damage)
	apply_mech_damage(attacker, defender, explosion_damage)
	weapon_exploded.emit(part.card_data.display_name, defender.player_number, explosion_damage)
	return applied


func _update_builtin_cannon(attacker: PlayerState, defender: PlayerState, delta: float) -> void:
	var activation_count := attacker.mech.advance_builtin_cannon(delta, balance.builtin_cannon_activation_interval_seconds)
	for activation_index in activation_count:
		if match_state != MatchState.ACTIVE:
			return
		apply_mech_damage(attacker, defender, balance.builtin_cannon_damage)


func _update_player_combat(attacker: PlayerState, defender: PlayerState, delta: float) -> void:
	for slot_value in attacker.mech.slots:
		if match_state != MatchState.ACTIVE:
			return
		var part: MechPart = slot_value
		if part == null:
			continue
		var activation_delta := delta
		if part.is_constructing:
			var construction_remaining := part.get_build_remaining()
			if not part.advance_construction(delta):
				continue
			if attacker == player_2:
				part.needs_ai_target_assignment = true
				opponent_ai.assign_weapon_target(part)
			# Only real time after completion can advance the fresh activation timer.
			activation_delta = maxf(0.0, delta - construction_remaining)
		var activation_count := part.advance_activation(activation_delta)
		for activation_index in activation_count:
			if match_state != MatchState.ACTIVE:
				return
			_apply_installed_weapon_damage(attacker, defender, part, part.card_data.damage)


func _apply_installed_weapon_damage(attacker: PlayerState, defender: PlayerState, weapon: MechPart, amount: int) -> int:
	_validate_weapon_target(weapon, defender)
	if weapon.target_type == MechPart.TargetType.PART:
		return apply_part_damage(attacker, defender, weapon.target_slot_index, amount)
	return apply_mech_damage(attacker, defender, amount)


func _validate_player_1_weapon_targets() -> void:
	var changed := false
	for slot_value in player_1.mech.slots:
		var weapon: MechPart = slot_value
		if weapon != null and not _is_player_1_weapon_target_valid(weapon):
			weapon.target_main_mech()
			changed = true
	if changed:
		player_1_weapon_targets_changed.emit()


func _validate_player_2_weapon_targets() -> void:
	for slot_value in player_2.mech.slots:
		var weapon: MechPart = slot_value
		if weapon != null and not _is_weapon_target_valid(weapon, player_1):
			weapon.target_main_mech()
			weapon.needs_ai_target_assignment = true


func _validate_player_1_weapon_target(weapon: MechPart) -> void:
	if _is_weapon_target_valid(weapon, player_2):
		return
	weapon.target_main_mech()
	player_1_weapon_targets_changed.emit()


func _is_player_1_weapon_target_valid(weapon: MechPart) -> bool:
	return _is_weapon_target_valid(weapon, player_2)


func _validate_weapon_target(weapon: MechPart, defender: PlayerState) -> void:
	if _is_weapon_target_valid(weapon, defender):
		return
	weapon.target_main_mech()
	if weapon.owner == player_2:
		weapon.needs_ai_target_assignment = true
	else:
		player_1_weapon_targets_changed.emit()


func _is_weapon_target_valid(weapon: MechPart, defender: PlayerState) -> bool:
	if weapon == null or weapon.target_type == MechPart.TargetType.MAIN_MECH:
		return true
	return defender.mech.is_valid_slot(weapon.target_slot_index) and defender.mech.slots[weapon.target_slot_index] == weapon.target_part and not weapon.target_part.is_constructing


func _get_player_1_weapon(slot_index: int) -> MechPart:
	if player_1 == null or not player_1.mech.is_valid_slot(slot_index):
		return null
	return player_1.mech.slots[slot_index]


func damage_debug_part(player_number: int, slot_index: int, amount: int = -1) -> int:
	if match_state != MatchState.ACTIVE:
		return 0
	var player := get_player(player_number)
	if player == null:
		return 0
	var attacker := player_2 if player_number == 1 else player_1
	var requested := balance.debug_part_damage_amount if amount < 0 else amount
	return apply_part_damage(attacker, player, slot_index, requested)


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


func _on_ai_card_played(card_name: String, slot_index: int) -> void:
	ai_card_played.emit(card_name, slot_index)
