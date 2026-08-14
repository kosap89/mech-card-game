extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")

var failures: Array[String] = []


func _init() -> void:
	var controller := _new_controller()
	controller.opponent_ai.enabled = false
	var interval := controller.balance.builtin_cannon_activation_interval_seconds
	var damage := controller.balance.builtin_cannon_damage
	_check(damage == 10 and is_equal_approx(interval, 3.0), "Built-in Cannon uses configured Phase 9 values")

	controller._process(interval - 0.1)
	_check(controller.player_1.total_mech_damage_dealt == 0 and controller.player_2.total_mech_damage_dealt == 0, "Built-in Cannons wait for a full interval")
	controller._process(0.1)
	_check(controller.player_1.total_mech_damage_dealt == damage, "Player 1 Built-in Cannon fires after its interval")
	_check(controller.player_2.total_mech_damage_dealt == damage, "Player 2 Built-in Cannon fires on its own timer")

	controller.restart_match()
	controller.player_1.mech.builtin_cannon_elapsed = interval - 0.1
	controller._process(0.1)
	_check(controller.player_1.total_mech_damage_dealt == damage and controller.player_2.total_mech_damage_dealt == 0, "Built-in Cannon timers are independent per mech")
	controller.restart_match()
	_check(is_zero_approx(controller.player_1.mech.builtin_cannon_elapsed) and is_zero_approx(controller.player_2.mech.builtin_cannon_elapsed), "Restart resets both Built-in Cannon timers")

	controller._process(180.0)
	_check(controller.match_state == MatchController.MatchState.ACTIVE, "The removed 180-second countdown no longer ends the match")

	controller.restart_match()
	controller.player_2.mech.current_health = damage
	controller.player_2.current_scrap = 100
	controller.opponent_ai.enabled = true
	var ai_hand_before_lethal := controller.player_2.hand.size()
	controller._process(interval)
	_check(controller.match_state == MatchController.MatchState.ENDED, "A main mech reaching zero ends the match immediately")
	_check(controller.result_text == "Player 1 wins!", "The attacker receives the correct winner result")
	_check(controller.player_1.mech.current_health == controller.player_1.mech.max_health, "No later same-frame attack occurs after lethal damage")
	_check(controller.player_2.hand.size() == ai_hand_before_lethal, "AI does not act later in a frame where combat ends the match")
	var ended_scrap := controller.player_2.current_scrap
	var ended_hand_size := controller.player_2.hand.size()
	var ended_damage := controller.player_1.total_mech_damage_dealt
	controller._process(interval * 2.0)
	controller.opponent_ai.advance(controller.balance.ai_decision_interval_seconds)
	_check(controller.player_2.current_scrap == ended_scrap and controller.player_2.hand.size() == ended_hand_size, "Scrap, draw, and AI stop after match end")
	_check(controller.player_1.total_mech_damage_dealt == ended_damage, "Combat stops after match end")
	controller.opponent_ai.enabled = false

	controller.restart_match()
	controller.player_1.mech.current_health = damage
	controller._process(interval)
	_check(controller.match_state == MatchController.MatchState.ENDED and controller.result_text == "Player 2 wins!", "Player 2 wins when Player 1 reaches zero Health")

	controller.restart_match()
	controller._process(controller.balance.scrap_gain_interval_seconds - 0.1)
	_check(controller.player_1.current_scrap == controller.balance.starting_scrap, "Passive Scrap waits for its full interval")
	controller._process(0.1)
	_check(typeof(controller.player_1.current_scrap) == TYPE_INT, "Scrap runtime state is integer-based")
	_check(controller.player_1.current_scrap == controller.balance.starting_scrap + controller.balance.scrap_gain_amount, "Passive generation adds a whole Scrap amount")

	controller.restart_match()
	var heavy_cannon: CardData = load("res://data/cards/heavy_cannon.tres")
	var old_part := MechPart.new(heavy_cannon, controller.player_1, 0)
	controller.player_1.mech.install_part(old_part, 0)
	_check(controller.try_trash_part(1, 0) == PlayerState.TrashPartResult.SUCCESS, "Trash still succeeds")
	_check(controller.player_1.current_scrap == 2, "Cost 3 Trash return rounds ceil(3 * 0.5) to 2 Scrap")

	controller.restart_match()
	old_part = MechPart.new(heavy_cannon, controller.player_1, 0)
	controller.player_1.mech.install_part(old_part, 0)
	controller.player_1.hand.append(heavy_cannon)
	controller.player_1.current_scrap = 1
	_check(controller.try_play_card(1, heavy_cannon, 0) == PlayerState.PlayPartResult.REPLACED, "Replace can afford a card using rounded returned Scrap")
	_check(controller.player_1.current_scrap == 0 and controller.player_1.mech.slots[0] != old_part, "Replace applies integer return atomically and installs a fresh part")

	controller.restart_match()
	var basic_cannon: CardData = load("res://data/cards/basic_cannon.tres")
	controller.player_1.mech.install_part(MechPart.new(basic_cannon, controller.player_1, 0), 0)
	controller._process(basic_cannon.activation_interval)
	_check(controller.player_1.total_mech_damage_dealt == basic_cannon.damage, "Installed Basic Cannon combat still works independently")
	controller.damage_debug_part(1, 0, basic_cannon.max_health)
	_check(controller.player_1.mech.slots[0] == null, "Installed part destruction still works")
	controller.free()

	_test_phase9_ui()

	if failures.is_empty():
		print("PHASE_9_CORE_COMBAT_RULES_SMOKE_TEST: PASS")
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


func _test_phase9_ui() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	var labels := _collect_label_text(main_scene)
	_check(labels.count("Built-in Cannon: 10 DMG / 3s") == 2, "UI shows Built-in Cannon information for both mechs")
	_check("3:00" not in labels, "UI no longer shows the old match countdown")
	_check(main_scene.p1_scrap.text == "SCRAP: 0" and main_scene.p2_scrap.text == "SCRAP: 0", "UI formats Scrap as whole numbers")
	main_scene.free()


func _collect_label_text(node: Node) -> Array[String]:
	var texts: Array[String] = []
	if node is Label:
		texts.append((node as Label).text)
	for child in node.get_children():
		texts.append_array(_collect_label_text(child))
	return texts


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
