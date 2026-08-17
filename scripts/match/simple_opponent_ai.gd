class_name SimpleOpponentAI
extends RefCounted

signal card_played(card_name: String, slot_index: int)

var match_controller: MatchController
var player_number: int
var decision_interval_seconds: float
var decision_elapsed_seconds: float = 0.0
var enabled: bool = true
var random := RandomNumberGenerator.new()


func _init(controller: MatchController, controlled_player_number: int, decision_interval: float) -> void:
	match_controller = controller
	player_number = controlled_player_number
	decision_interval_seconds = maxf(0.1, decision_interval)
	random.randomize()


func reset() -> void:
	decision_elapsed_seconds = 0.0


func advance(delta: float) -> void:
	if not enabled or match_controller.match_state != MatchController.MatchState.ACTIVE:
		return
	decision_elapsed_seconds += maxf(0.0, delta)
	if decision_elapsed_seconds < decision_interval_seconds:
		return
	decision_elapsed_seconds = fmod(decision_elapsed_seconds, decision_interval_seconds)
	_take_one_decision()


func _take_one_decision() -> bool:
	var player := match_controller.get_player(player_number)
	if player == null:
		return false
	for part_value in player.mech.slots:
		var part: MechPart = part_value
		if part != null and not part.is_constructing and part.needs_ai_target_assignment:
			assign_weapon_target(part)
	var playable_cards: Array[CardData] = []
	for card in player.hand:
		if not _valid_slots_for_card(player, card).is_empty():
			playable_cards.append(card)
	if playable_cards.is_empty():
		return false
	var selected_card := playable_cards[random.randi_range(0, playable_cards.size() - 1)]
	var valid_slots := _valid_slots_for_card(player, selected_card)
	var slot_index: int = valid_slots[random.randi_range(0, valid_slots.size() - 1)]
	var result := match_controller.try_play_card(player_number, selected_card, slot_index)
	if result != PlayerState.PlayPartResult.SUCCESS:
		return false
	card_played.emit(selected_card.display_name, slot_index)
	return true


func assign_weapon_target(weapon: MechPart) -> bool:
	if weapon == null or weapon.owner.player_number != player_number or weapon.is_constructing:
		return false
	var defender := match_controller.player_1
	var choices: Array[int] = [-1]
	for slot_index in MechState.SLOT_COUNT:
		var target: MechPart = defender.mech.slots[slot_index]
		if target != null and not target.is_constructing:
			choices.append(slot_index)
	var choice := choices[random.randi_range(0, choices.size() - 1)]
	if choice < 0:
		weapon.target_main_mech()
	else:
		weapon.target_enemy_part(choice, defender.mech.slots[choice])
	weapon.needs_ai_target_assignment = false
	return true


func _valid_slots_for_card(player: PlayerState, card: CardData) -> Array[int]:
	var empty_slots: Array[int] = []
	for slot_index in MechState.SLOT_COUNT:
		if player.mech.is_slot_empty(slot_index):
			empty_slots.append(slot_index)
	var valid_slots: Array[int] = []
	for slot_index in empty_slots:
		var result := player.validate_play_part(card, slot_index)
		if result == PlayerState.PlayPartResult.SUCCESS:
			valid_slots.append(slot_index)
	return valid_slots
