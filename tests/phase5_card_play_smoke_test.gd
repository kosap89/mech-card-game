extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const EPSILON := 0.0001

var failures: Array[String] = []


func _init() -> void:
	seed(54321)
	_test_ui_interaction_path()
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres")
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()

	var player := controller.player_1
	var first_card: CardData = player.hand[0]
	var initial_hand_size := player.hand.size()
	player.add_scrap(10.0)
	var scrap_before := player.current_scrap
	var result := controller.try_play_card(1, first_card, 0)
	_check(result == PlayerState.PlayPartResult.SUCCESS, "Affordable part installs successfully")
	_check(absf(player.current_scrap - (scrap_before - first_card.cost)) < EPSILON, "Successful installation deducts the exact Scrap cost")
	_check(player.hand.size() == initial_hand_size - 1 and player.hand.find(first_card) < 0, "Successful installation removes exactly the selected card")
	var installed_part: MechPart = player.mech.slots[0]
	_check(installed_part != null and installed_part.card_data == first_card, "Installed part retains its CardData reference")
	_check(installed_part.owner == player and installed_part.slot_index == 0, "Installed part retains owner and slot")

	controller.restart_match()
	player = controller.player_1
	var unaffordable_card: CardData = player.hand[0]
	initial_hand_size = player.hand.size()
	scrap_before = player.current_scrap
	result = controller.try_play_card(1, unaffordable_card, 1)
	_check(result == PlayerState.PlayPartResult.NOT_ENOUGH_SCRAP, "Unaffordable installation fails")
	_check(absf(player.current_scrap - scrap_before) < EPSILON, "Failed affordability check does not spend Scrap")
	_check(player.hand.size() == initial_hand_size and player.hand.find(unaffordable_card) >= 0, "Unaffordable card remains in hand")
	_check(player.mech.slots[1] == null, "Unaffordable installation leaves the slot empty")

	player.add_scrap(10.0)
	var occupied_card: CardData = player.hand[0]
	_check(controller.try_play_card(1, occupied_card, 2) == PlayerState.PlayPartResult.SUCCESS, "Test setup installs into an empty slot")
	var existing_part: MechPart = player.mech.slots[2]
	var replacement_card: CardData = player.hand[0]
	initial_hand_size = player.hand.size()
	scrap_before = player.current_scrap
	result = controller.try_play_card(1, replacement_card, 2)
	_check(result == PlayerState.PlayPartResult.REPLACED, "Occupied slot uses Phase 7 Replace")
	_check(player.mech.slots[2] != existing_part and player.mech.slots[2].card_data == replacement_card, "Replace installs a fresh part")
	_check(player.hand.size() == initial_hand_size - 1 and player.hand.find(replacement_card) < 0, "Replace removes the selected card")
	_check(player.current_scrap <= scrap_before + existing_part.card_data.cost * controller.balance.scrap_return_fraction, "Replace applies return and new cost")

	var player_1_card: CardData = player.hand[0]
	var player_2_hand_size := controller.player_2.hand.size()
	result = controller.try_play_card(2, player_1_card, 0)
	_check(result == PlayerState.PlayPartResult.INVALID_CARD, "A Player 1 card cannot be installed for Player 2")
	_check(controller.player_2.hand.size() == player_2_hand_size and controller.player_2.mech.slots[0] == null, "Ownership failure changes no Player 2 state")

	controller.end_match()
	var ended_card: CardData = player.hand[0]
	initial_hand_size = player.hand.size()
	scrap_before = player.current_scrap
	result = controller.try_play_card(1, ended_card, 3)
	_check(result == PlayerState.PlayPartResult.INVALID_CARD, "Cards cannot be installed after match end")
	_check(player.hand.size() == initial_hand_size and absf(player.current_scrap - scrap_before) < EPSILON and player.mech.slots[3] == null, "Match-end rejection changes no card, Scrap, or slot state")

	controller.restart_match()
	_check(controller.player_1.hand.size() == controller.balance.starting_hand_size, "Restart deals a fresh starting hand")
	_check(controller.player_1.current_scrap == controller.balance.starting_scrap, "Restart resets Scrap")
	_check(_all_slots_empty(controller.player_1.mech) and _all_slots_empty(controller.player_2.mech), "Restart empties all mech slots")
	controller.player_1.add_scrap(10.0)
	_check(controller.try_play_card(1, controller.player_1.hand[0], 0) == PlayerState.PlayPartResult.SUCCESS, "Card play is enabled again after restart")

	controller.restart_match()
	controller._process(controller.balance.draw_interval_seconds)
	_check(controller.player_1.hand.size() == controller.balance.starting_hand_size + 1, "Existing automatic draw still works")
	_check(controller.player_1.current_scrap > controller.balance.starting_scrap, "Existing Scrap generation still works")
	controller.deal_debug_damage(1)
	_check(controller.player_2.mech.current_health == controller.balance.mech_max_health - controller.balance.debug_damage_amount, "Existing health and damage still work")
	controller._process(controller.balance.match_duration_seconds)
	_check(controller.match_state == MatchController.MatchState.ENDED and controller.result_text == "Player 1 wins!", "Existing timer and winner calculation still work")
	controller.free()

	if failures.is_empty():
		print("PHASE_5_CARD_PLAY_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_ui_interaction_path() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	main_scene.match_controller = controller
	main_scene._ready()
	var original_button: Button = main_scene.p1_hand_container.get_child(0)
	var selected_card: CardData = controller.player_1.hand[0]
	controller.player_1.add_scrap(10.0)
	_check(is_instance_valid(original_button) and original_button.get_parent() == main_scene.p1_hand_container, "Scrap updates do not rebuild hand controls during a click")
	original_button.pressed.emit()
	_check(main_scene.selected_cards[1] == selected_card, "Hand Button signal stores the selected CardData reference")
	_check("Selected card: %s" % selected_card.display_name in main_scene.p1_selected_label.text, "Selected-card feedback updates")
	main_scene.p1_slot_buttons[0].pressed.emit()
	_check(controller.player_1.mech.slots[0] != null, "Slot Button signal completes card installation")
	_check(main_scene.selected_cards[1] == null, "Successful UI installation clears selection")
	main_scene.free()


func _all_slots_empty(mech: MechState) -> bool:
	for part in mech.slots:
		if part != null:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
