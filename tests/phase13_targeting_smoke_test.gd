extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")

var failures: Array[String] = []


func _init() -> void:
	var controller := _new_controller()
	controller.opponent_ai.enabled = false
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")

	_check(controller.player_1_target_type == MatchController.TargetType.MAIN_MECH, "Player 1 defaults to the enemy main mech")
	_check(not controller.set_player_1_target_part(0), "An empty enemy slot cannot be targeted")
	var enemy_part := MechPart.new(heavy, controller.player_2, 0)
	controller.player_2.mech.install_part(enemy_part, 0)
	_check(controller.set_player_1_target_part(0), "An occupied enemy slot can be selected")
	_check(controller.player_1_target_type == MatchController.TargetType.PART and controller.player_1_target_part == enemy_part, "Selected target records the enemy slot and exact runtime part")

	var player_weapon := MechPart.new(light, controller.player_1, 0)
	controller.player_1.mech.install_part(player_weapon, 0)
	var timer_before := player_weapon.activation_elapsed
	controller.set_player_1_target_main_mech()
	controller.set_player_1_target_part(0)
	_check(is_equal_approx(player_weapon.activation_elapsed, timer_before), "Target switching does not alter weapon timers")
	var enemy_mech_health := controller.player_2.mech.current_health
	controller._process(light.activation_interval)
	_check(enemy_part.current_health == heavy.max_health - light.damage, "Player 1 installed weapon damage routes to the selected enemy part")
	_check(controller.player_2.mech.current_health == enemy_mech_health and controller.player_1.total_mech_damage_dealt == 0, "Part damage does not affect main-mech Health or its damage statistic")

	controller.damage_debug_part(2, 0, enemy_part.current_health)
	_check(controller.player_2.mech.slots[0] == null and controller.player_1_target_type == MatchController.TargetType.MAIN_MECH, "Destroying the selected part removes it and restores the main-mech target")
	player_weapon.activation_elapsed = light.activation_interval
	controller._process(0.0)
	_check(controller.player_2.mech.current_health == enemy_mech_health - light.damage, "The next installed-weapon shot falls back to the enemy main mech")

	controller.restart_match()
	controller.balance.builtin_cannon_activation_interval_seconds = 3.0
	enemy_part = MechPart.new(heavy, controller.player_2, 0)
	controller.player_2.mech.install_part(enemy_part, 0)
	controller.set_player_1_target_part(0)
	controller._process(3.0)
	_check(controller.player_2.mech.current_health == controller.player_2.mech.max_health - controller.balance.builtin_cannon_damage, "Built-in Cannon ignores the manual part target and damages the main mech")

	controller.player_2.hand.append(light)
	controller.player_2.current_scrap = light.cost
	_check(controller.try_play_card(2, light, 0) == PlayerState.PlayPartResult.REPLACED, "AI gameplay API can replace the targeted enemy slot")
	_check(controller.player_1_target_type == MatchController.TargetType.MAIN_MECH, "Replacing the targeted runtime part safely resets targeting")
	controller.restart_match()
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	var player_part := MechPart.new(heavy, controller.player_1, 0)
	controller.player_1.mech.install_part(player_part, 0)
	var ai_weapon := MechPart.new(light, controller.player_2, 0)
	controller.player_2.mech.install_part(ai_weapon, 0)
	var player_mech_health := controller.player_1.mech.current_health
	controller._process(light.activation_interval)
	_check(controller.player_1.mech.current_health == player_mech_health - light.damage and player_part.current_health == player_part.max_health, "Player 2 installed weapons continue targeting Player 1 main mech only")
	controller.set_player_1_target_part(0)
	controller.restart_match()
	_check(controller.player_1_target_type == MatchController.TargetType.MAIN_MECH and controller.player_1_target_slot_index == -1, "Restart resets Player 1 targeting")
	controller.free()

	_test_targeting_ui(light)

	if failures.is_empty():
		print("PHASE_13_TARGETING_SMOKE_TEST: PASS")
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


func _test_targeting_ui(light: CardData) -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	_check("[SELECTED TARGET]" in main_scene.p2_mech_target_button.text, "Enemy main mech visibly shows the default target")
	_check(main_scene.p2_slot_buttons.all(func(button: Button) -> bool: return button.disabled), "Empty enemy slots are not targetable")
	controller.player_2.mech.install_part(MechPart.new(light, controller.player_2, 0), 0)
	_check(not main_scene.p2_slot_buttons[0].disabled, "Occupied enemy module becomes targetable")
	var hand_button: Button = main_scene.p1_hand_container.get_child(0)
	main_scene.p2_slot_buttons[0].pressed.emit()
	_check("[SELECTED TARGET]" in main_scene.p2_slot_buttons[0].text, "Selected enemy module displays a target indicator")
	controller._process(0.25)
	main_scene._process(0.0)
	_check(hand_button == main_scene.p1_hand_container.get_child(0), "Target and countdown refreshes do not rebuild Player 1 hand controls")
	controller.end_match()
	_check(main_scene.p2_mech_target_button.disabled and main_scene.p2_slot_buttons[0].disabled, "Target selection stops after match end")
	main_scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
