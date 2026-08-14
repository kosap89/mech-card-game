extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const TEST_EPSILON := 0.0001

var failures: Array[String] = []


func _init() -> void:
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres")
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()
	controller.opponent_ai.enabled = false

	_check(is_equal_approx(controller.player_1.current_scrap, controller.balance.starting_scrap), "Player 1 starts with configured Scrap")
	_check(is_equal_approx(controller.player_2.current_scrap, controller.balance.starting_scrap), "Player 2 starts with configured Scrap")

	controller._process(controller.balance.scrap_gain_interval_seconds - 0.1)
	_check(controller.player_1.current_scrap == controller.balance.starting_scrap, "Scrap waits for a full gain interval")
	controller._process(0.1)
	var expected_generated := controller.balance.starting_scrap + controller.balance.scrap_gain_amount
	_check(controller.player_1.current_scrap == expected_generated, "Player 1 generates whole Scrap")
	_check(controller.player_2.current_scrap == expected_generated, "Player 2 generates Scrap independently")

	controller.player_1.add_scrap(1)
	_check(controller.player_1.can_afford(1), "can_afford succeeds for an affordable cost")
	_check(not controller.player_1.can_afford(controller.player_1.current_scrap + 1), "can_afford rejects an unaffordable cost")
	var before_spend := controller.player_1.current_scrap
	_check(controller.player_1.spend_scrap(1), "spend_scrap succeeds with enough Scrap")
	_check(controller.player_1.current_scrap == before_spend - 1, "spend_scrap subtracts the cost")
	before_spend = controller.player_1.current_scrap
	_check(not controller.player_1.spend_scrap(before_spend + 1), "spend_scrap fails cleanly when unaffordable")
	_check(controller.player_1.current_scrap == before_spend, "failed spending leaves Scrap unchanged")
	_check(controller.player_1.current_scrap >= 0, "Scrap never becomes negative")

	controller.end_match()
	var ended_scrap := controller.player_1.current_scrap
	controller._process(1.0)
	controller.add_debug_scrap(1)
	_check(controller.player_1.current_scrap == ended_scrap, "generation and debug controls stop after match end")

	controller.restart_match()
	_check(controller.player_1.current_scrap == controller.balance.starting_scrap, "restart resets Player 1 Scrap")
	_check(controller.player_2.current_scrap == controller.balance.starting_scrap, "restart resets Player 2 Scrap")
	controller._process(1.0)
	_check(controller.player_1.current_scrap > controller.balance.starting_scrap, "restart resumes Scrap generation")

	controller.restart_match()
	controller.deal_debug_damage(1)
	_check(controller.player_2.mech.current_health == controller.balance.mech_max_health - controller.balance.debug_damage_amount, "existing damage still reduces health")
	_check(controller.player_1.total_mech_damage_dealt == controller.balance.debug_damage_amount, "existing damage tracking still works")
	controller.deal_debug_damage(1, controller.player_2.mech.current_health)
	_check(controller.result_text == "Player 1 wins!", "zero Health determines the winner")
	controller.restart_match()
	_check(controller.player_1.total_mech_damage_dealt == 0 and controller.player_2.total_mech_damage_dealt == 0, "restart resets existing damage totals")
	_check(is_zero_approx(controller.player_1.scrap_generation_elapsed), "restart resets Scrap generation timing")
	controller.free()

	if failures.is_empty():
		print("PHASE_3_SCRAP_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
