extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_ai_target_selection_and_fallback()
	_test_ai_targeted_destruction()
	_test_damage_events_and_ui_flash()
	if failures.is_empty():
		print("PHASE_18_AI_TARGETING_DAMAGE_FLASH_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_ai_target_selection_and_fallback() -> void:
	var controller := _new_controller()
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	var human_active := _active_part(light, controller.player_1, 0)
	var human_building := MechPart.new(heavy, controller.player_1, 1)
	var ai_a := _active_part(light, controller.player_2, 0)
	var ai_b := _active_part(heavy, controller.player_2, 1)
	controller.player_1.mech.install_part(human_active, 0)
	controller.player_1.mech.install_part(human_building, 1)
	controller.player_2.mech.install_part(ai_a, 0)
	controller.player_2.mech.install_part(ai_b, 1)
	controller.opponent_ai.random.seed = 1818
	var saw_mech := false
	var saw_part := false
	for index in 20:
		var elapsed_before := ai_a.activation_elapsed
		controller.opponent_ai.assign_weapon_target(ai_a)
		saw_mech = saw_mech or ai_a.target_type == MechPart.TargetType.MAIN_MECH
		saw_part = saw_part or ai_a.target_part == human_active
		_check(ai_a.target_part != human_building, "AI never selects a BUILDING weapon")
		_check(is_equal_approx(ai_a.activation_elapsed, elapsed_before), "AI targeting does not reset activation countdown")
	_check(saw_mech and saw_part, "Uniform temporary AI selection can choose main mech or an ACTIVE weapon")

	ai_a.target_main_mech()
	ai_a.needs_ai_target_assignment = false
	ai_b.target_enemy_part(0, human_active)
	ai_b.needs_ai_target_assignment = false
	controller.opponent_ai.advance(controller.balance.ai_decision_interval_seconds)
	_check(ai_a.target_type == MechPart.TargetType.MAIN_MECH and ai_b.target_part == human_active, "Independent valid AI targets persist across decision cycles")
	controller.try_trash_part(1, 0)
	_check(ai_b.target_type == MechPart.TargetType.MAIN_MECH and ai_b.needs_ai_target_assignment, "Trashing an AI target causes immediate safe main-mech fallback")
	_check(not human_building.combat_destruction_resolved, "Safe Trash targeting flow causes no explosion")

	var newly_built := MechPart.new(light, controller.player_2, 2)
	controller.player_2.mech.install_part(newly_built, 2)
	controller._process(light.build_time)
	_check(not newly_built.is_constructing and not newly_built.needs_ai_target_assignment, "Newly completed AI weapon receives a target immediately")
	_check(newly_built.target_type == MechPart.TargetType.MAIN_MECH, "With only BUILDING enemy modules available, completed AI weapon targets main mech")
	controller.free()


func _test_ai_targeted_destruction() -> void:
	var controller := _new_controller()
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	var human_target := _active_part(light, controller.player_1, 0)
	var ai_weapon := _active_part(heavy, controller.player_2, 0)
	human_target.current_health = heavy.damage
	controller.player_1.mech.install_part(human_target, 0)
	controller.player_2.mech.install_part(ai_weapon, 0)
	ai_weapon.target_enemy_part(0, human_target)
	controller.player_1.mech.current_health = light.damage - 1
	ai_weapon.activation_elapsed = heavy.activation_interval
	controller._process(0.0)
	_check(controller.player_1.mech.slots[0] == null, "AI targeted shot destroys the Player 1 weapon")
	_check(controller.player_1.mech.current_health == 0, "Destroyed weapon explosion damages Player 1 main mech")
	_check(ai_weapon.target_type == MechPart.TargetType.MAIN_MECH and ai_weapon.needs_ai_target_assignment, "AI target falls back after destruction")
	_check(controller.match_state == MatchController.MatchState.ENDED and controller.result_text == "Player 2 wins!", "AI-caused explosion kill awards Player 2 the win")
	controller.free()


func _test_damage_events_and_ui_flash() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller.load_persisted_settings = false
	controller._ready()
	controller.opponent_ai.enabled = false
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	main_scene.match_controller = controller
	main_scene._ready()
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var p1_part := _active_part(light, controller.player_1, 0)
	var p2_part := _active_part(light, controller.player_2, 0)
	controller.player_1.mech.install_part(p1_part, 0)
	controller.player_2.mech.install_part(p2_part, 0)
	p2_part.target_main_mech()
	main_scene._process(0.0)
	_check("Target: Your Mech" in main_scene.p2_slot_buttons[0].text, "AI weapon module displays its current target")

	controller.deal_debug_damage(1, 5)
	_check(main_scene.p2_health_bar.modulate == main_scene.DAMAGE_FLASH_COLOR, "Player 2 mech debug damage flashes its Health bar")
	main_scene._process(0.15)
	controller.deal_debug_damage(1, 5)
	main_scene._process(0.1)
	_check(main_scene.p2_health_bar.modulate == main_scene.DAMAGE_FLASH_COLOR, "Repeated damage refreshes rather than overlaps the flash timer")
	main_scene._process(0.11)
	_check(main_scene.p2_health_bar.modulate == Color.WHITE, "Mech flash returns to its normal modulation")

	controller.damage_debug_part(1, 0, 5)
	controller.damage_debug_part(2, 0, 5)
	_check(main_scene.p1_slot_panels[0].modulate == main_scene.DAMAGE_FLASH_COLOR and main_scene.p2_slot_panels[0].modulate == main_scene.DAMAGE_FLASH_COLOR, "Both players' ACTIVE weapon modules flash on actual part damage")
	var building := MechPart.new(light, controller.player_1, 1)
	controller.player_1.mech.install_part(building, 1)
	_check(controller.damage_debug_part(1, 1, 5) == 0 and main_scene.p1_slot_panels[1].modulate == Color.WHITE, "BUILDING weapon takes no damage and does not flash")

	main_scene._clear_damage_flashes()
	p1_part.activation_elapsed = light.activation_interval
	controller._process(0.0)
	_check(main_scene.p2_health_bar.modulate == main_scene.DAMAGE_FLASH_COLOR, "Installed Player 1 weapon main-mech damage flashes Player 2 Health")
	main_scene._clear_damage_flashes()
	p2_part.activation_elapsed = light.activation_interval
	controller._process(0.0)
	_check(main_scene.p1_health_bar.modulate == main_scene.DAMAGE_FLASH_COLOR, "Installed AI weapon main-mech damage flashes Player 1 Health")
	main_scene._clear_damage_flashes()
	controller.balance.builtin_cannon_activation_interval_seconds = 1.0
	controller._process(1.0)
	_check(main_scene.p1_health_bar.modulate == main_scene.DAMAGE_FLASH_COLOR and main_scene.p2_health_bar.modulate == main_scene.DAMAGE_FLASH_COLOR, "Both Built-in Cannon hits use universal mech flash feedback")

	main_scene._clear_damage_flashes()
	controller.damage_debug_part(1, 0, p1_part.current_health)
	_check(main_scene.p1_health_bar.modulate == main_scene.DAMAGE_FLASH_COLOR, "Weapon explosion damage uses the same owner-mech flash")
	controller.restart_match()
	_check(main_scene.damage_flash_remaining.is_empty() and main_scene.p1_health_bar.modulate == Color.WHITE and main_scene.p2_health_bar.modulate == Color.WHITE, "Restart clears every active damage flash")
	main_scene.free()


func _new_controller() -> MatchController:
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres")
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()
	controller.opponent_ai.enabled = false
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	return controller


func _active_part(card: CardData, player: PlayerState, slot_index: int) -> MechPart:
	var part := MechPart.new(card, player, slot_index)
	part.advance_construction(card.build_time)
	return part


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
