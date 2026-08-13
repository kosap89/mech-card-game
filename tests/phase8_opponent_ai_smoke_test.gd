extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const EPSILON := 0.0001

var failures: Array[String] = []
var ai_play_count := 0


func _init() -> void:
	var controller := _new_controller()
	var ai := controller.opponent_ai
	ai.random.seed = 808
	controller.ai_card_played.connect(_on_ai_card_played)
	var player := controller.player_2
	var human_hand_before := controller.player_1.hand.duplicate()
	var selected_card: CardData = player.hand[0]
	player.current_scrap = selected_card.cost
	var hand_before := player.hand.size()
	var scrap_before := player.current_scrap
	ai.advance(controller.balance.ai_decision_interval_seconds - 0.1)
	_check(ai_play_count == 0 and _occupied_slot_count(player.mech) == 0, "AI waits for its configured decision interval")
	ai.advance(0.1)
	_check(ai_play_count == 1, "AI performs one card play at a decision point")
	_check(player.hand.size() == hand_before - 1, "AI plays a card from its actual hand")
	_check(player.current_scrap < scrap_before, "Normal card play deducts AI Scrap")
	_check(_occupied_slot_count(player.mech) == 1, "AI installs only into its own mech")
	_check(controller.player_1.hand == human_hand_before and _occupied_slot_count(controller.player_1.mech) == 0, "AI does not modify Player 1 cards or slots")

	controller.restart_match()
	ai.random.seed = 808
	player = controller.player_2
	player.current_scrap = 0.0
	hand_before = player.hand.size()
	ai.advance(controller.balance.ai_decision_interval_seconds)
	_check(player.hand.size() == hand_before and _occupied_slot_count(player.mech) == 0, "AI does not play an unaffordable card")
	_check(player.current_scrap >= 0.0, "AI Scrap never becomes negative")

	controller.restart_match()
	ai.random.seed = 808
	player = controller.player_2
	player.current_scrap = 100.0
	while player.hand.size() < MechState.SLOT_COUNT + 1 and not player.deck.is_empty():
		player.draw_card()
	for decision_index in MechState.SLOT_COUNT:
		var plays_before := ai_play_count
		ai.advance(controller.balance.ai_decision_interval_seconds)
		_check(ai_play_count == plays_before + 1, "AI makes at most one successful play per decision cycle")
	_check(_occupied_slot_count(player.mech) == MechState.SLOT_COUNT, "AI fills all four empty slots before replacing")
	var old_parts := player.mech.slots.duplicate()
	var hand_size_before_replace := player.hand.size()
	var scrap_before_replace := player.current_scrap
	ai.advance(controller.balance.ai_decision_interval_seconds)
	_check(ai_play_count >= 5 and _occupied_slot_count(player.mech) == MechState.SLOT_COUNT, "AI uses Replace after all slots are full")
	_check(_slot_was_replaced(player.mech, old_parts), "AI Replace removes an old part and installs a fresh part")
	_check(player.hand.size() == hand_size_before_replace - 1 and player.current_scrap != scrap_before_replace, "AI Replace uses normal hand and Scrap state")

	controller.end_match()
	hand_before = player.hand.size()
	var slots_before_end := player.mech.slots.duplicate()
	ai.advance(controller.balance.ai_decision_interval_seconds * 2.0)
	_check(player.hand.size() == hand_before and player.mech.slots == slots_before_end, "AI does not act after match end")

	controller.restart_match()
	_check(is_zero_approx(ai.decision_elapsed_seconds), "Restart resets AI decision timing")
	_check(_occupied_slot_count(controller.player_2.mech) == 0, "Restart clears the AI mech")
	controller.player_2.current_scrap = 100.0
	hand_before = controller.player_2.hand.size()
	ai.advance(controller.balance.ai_decision_interval_seconds)
	_check(controller.player_2.hand.size() == hand_before - 1, "AI resumes normal decisions after restart")
	controller.free()

	_test_player_2_ui_is_read_only()

	if failures.is_empty():
		print("PHASE_8_OPPONENT_AI_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _new_controller() -> MatchController:
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres")
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()
	return controller


func _test_player_2_ui_is_read_only() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	_check(not main_scene.p1_hand_container.get_child(0).disabled, "Player 1 hand remains interactive")
	_check(main_scene.p2_hand_container.get_child(0).disabled, "Player 2 hand is not human-selectable")
	_check(main_scene.p2_slot_buttons.all(func(button: Button) -> bool: return button.disabled), "Player 2 slots are not human-selectable")
	_check(main_scene.p2_trash_buttons.all(func(button: Button) -> bool: return button.disabled), "Player 2 Trash controls are disabled")
	main_scene.free()


func _on_ai_card_played(_card_name: String, _slot_index: int, _replaced: bool, _old_part_name: String) -> void:
	ai_play_count += 1


func _occupied_slot_count(mech: MechState) -> int:
	var count := 0
	for part in mech.slots:
		if part != null:
			count += 1
	return count


func _slot_was_replaced(mech: MechState, old_parts: Array) -> bool:
	for slot_index in MechState.SLOT_COUNT:
		if mech.slots[slot_index] != old_parts[slot_index]:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
