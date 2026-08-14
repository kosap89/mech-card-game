extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")

var failures: Array[String] = []


func _init() -> void:
	seed(12345)
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres")
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()
	controller.opponent_ai.enabled = false

	_check(controller.player_1.deck_definition != null and controller.player_2.deck_definition != null, "Both players receive a deck definition")
	_check(controller.player_1.hand.size() == controller.balance.starting_hand_size, "Player 1 receives the starting hand")
	_check(controller.player_2.hand.size() == controller.balance.starting_hand_size, "Player 2 receives the starting hand")
	_check(_all_cards_valid(controller.player_1.deck) and _all_cards_valid(controller.player_1.hand), "Player 1 cards are valid CardData resources")
	_check(_all_cards_valid(controller.player_2.deck) and _all_cards_valid(controller.player_2.hand), "Player 2 cards are valid CardData resources")
	_check(controller.player_1.deck.size() == controller.test_deck.cards.size() - controller.balance.starting_hand_size, "Starting draws reduce Player 1 deck count")
	controller.player_1.reset(0)
	_check(controller.player_1.deck != controller.test_deck.cards, "Deck initialization shuffles the predefined order")
	controller.player_1.reset(controller.balance.starting_hand_size)

	var p1_deck_before := controller.player_1.deck.size()
	var p1_hand_before := controller.player_1.hand.size()
	controller._process(controller.balance.draw_interval_seconds)
	_check(controller.player_1.deck.size() == p1_deck_before - 1, "Automatic draw reduces deck count")
	_check(controller.player_1.hand.size() == p1_hand_before + 1, "Automatic draw increases hand count")
	_check(controller.player_2.hand.size() == p1_hand_before + 1, "Both players draw independently")
	_check(controller.player_1.current_scrap > controller.balance.starting_scrap, "Existing Scrap generation continues")

	controller.end_match()
	p1_hand_before = controller.player_1.hand.size()
	controller._process(controller.balance.draw_interval_seconds)
	_check(controller.player_1.hand.size() == p1_hand_before, "Drawing stops when the match ends")

	var previous_hand := controller.player_1.hand.duplicate()
	controller.restart_match()
	_check(controller.player_1.hand.size() == controller.balance.starting_hand_size, "Restart deals a fresh starting hand")
	_check(controller.player_1.deck.size() == controller.test_deck.cards.size() - controller.balance.starting_hand_size, "Restart recreates the deck")
	_check(controller.player_1.draw_elapsed_seconds == 0.0, "Restart resets draw timing")
	_check(controller.player_1.hand != previous_hand, "Previous hand state is not retained")
	controller._process(controller.balance.draw_interval_seconds)
	_check(controller.player_1.hand.size() == controller.balance.starting_hand_size + 1, "Automatic drawing resumes after restart")

	while not controller.player_1.deck.is_empty():
		controller.player_1.draw_card()
	p1_hand_before = controller.player_1.hand.size()
	controller.player_1.advance_card_draw(controller.balance.draw_interval_seconds)
	_check(controller.player_1.hand.size() == p1_hand_before, "Empty deck temporarily stops drawing")

	controller.restart_match()
	controller.deal_debug_damage(1)
	_check(controller.player_2.mech.current_health == controller.balance.mech_max_health - controller.balance.debug_damage_amount, "Existing health and damage still work")
	controller.deal_debug_damage(1, controller.player_2.mech.current_health)
	_check(controller.match_state == MatchController.MatchState.ENDED, "Zero mech Health ends the match")
	_check(controller.result_text == "Player 1 wins!", "Existing winner feedback still works")
	controller.free()

	if failures.is_empty():
		print("PHASE_4_CARDS_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _all_cards_valid(cards: Array[CardData]) -> bool:
	for card in cards:
		if card == null or card.id.is_empty() or card.display_name.is_empty() or card.cost < 0:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
