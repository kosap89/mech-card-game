class_name SimpleOpponentAI
extends RefCounted

signal card_played(card_name: String, slot_index: int, replaced: bool, old_part_name: String)

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
	var playable_cards: Array[CardData] = []
	for card in player.hand:
		if not _valid_slots_for_card(player, card).is_empty():
			playable_cards.append(card)
	if playable_cards.is_empty():
		return false
	var selected_card := playable_cards[random.randi_range(0, playable_cards.size() - 1)]
	var valid_slots := _valid_slots_for_card(player, selected_card)
	var slot_index: int = valid_slots[random.randi_range(0, valid_slots.size() - 1)]
	var old_part: MechPart = player.mech.slots[slot_index]
	var old_part_name := "" if old_part == null else old_part.card_data.display_name
	var result := match_controller.try_play_card(player_number, selected_card, slot_index)
	if result not in [PlayerState.PlayPartResult.SUCCESS, PlayerState.PlayPartResult.REPLACED]:
		return false
	card_played.emit(selected_card.display_name, slot_index, result == PlayerState.PlayPartResult.REPLACED, old_part_name)
	return true


func _valid_slots_for_card(player: PlayerState, card: CardData) -> Array[int]:
	var empty_slots: Array[int] = []
	for slot_index in MechState.SLOT_COUNT:
		if player.mech.is_slot_empty(slot_index):
			empty_slots.append(slot_index)
	var candidate_slots: Array[int] = empty_slots
	if candidate_slots.is_empty():
		for slot_index in MechState.SLOT_COUNT:
			candidate_slots.append(slot_index)
	var valid_slots: Array[int] = []
	for slot_index in candidate_slots:
		var result := player.validate_play_part(card, slot_index, match_controller.balance.scrap_return_fraction)
		if result in [PlayerState.PlayPartResult.SUCCESS, PlayerState.PlayPartResult.REPLACED]:
			valid_slots.append(slot_index)
	return valid_slots
