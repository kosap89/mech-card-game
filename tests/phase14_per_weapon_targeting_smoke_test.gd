extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")

var failures: Array[String] = []


func _init() -> void:
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	var controller := _new_controller()
	controller.opponent_ai.enabled = false
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	var weapon_a := MechPart.new(light, controller.player_1, 0)
	var weapon_b := MechPart.new(light, controller.player_1, 1)
	var enemy_a := MechPart.new(heavy, controller.player_2, 0)
	var enemy_b := MechPart.new(heavy, controller.player_2, 1)
	controller.player_1.mech.install_part(weapon_a, 0)
	controller.player_1.mech.install_part(weapon_b, 1)
	controller.player_2.mech.install_part(enemy_a, 0)
	controller.player_2.mech.install_part(enemy_b, 1)
	_check(weapon_a.target_type == MechPart.TargetType.MAIN_MECH and weapon_b.target_type == MechPart.TargetType.MAIN_MECH, "New weapons independently default to the enemy main mech")
	var timer_before := weapon_a.activation_elapsed
	_check(controller.set_player_1_weapon_target_part(0, 0), "Weapon A accepts an occupied enemy-part target")
	_check(weapon_a.target_part == enemy_a and weapon_b.target_type == MechPart.TargetType.MAIN_MECH, "Assigning Weapon A does not change Weapon B")
	_check(is_equal_approx(weapon_a.activation_elapsed, timer_before), "Target assignment does not reset activation timing")
	controller._process(light.activation_interval)
	_check(enemy_a.current_health == heavy.max_health - light.damage, "Weapon A routes damage to its selected enemy part")
	_check(controller.player_2.mech.current_health == controller.player_2.mech.max_health - light.damage, "Weapon B independently routes damage to the enemy main mech")
	_check(controller.set_player_1_weapon_target_part(1, 1), "Weapon B accepts a different enemy-part target")
	_check(weapon_a.target_part == enemy_a and weapon_b.target_part == enemy_b, "Two weapons retain different persistent targets")

	controller.damage_debug_part(2, 0, enemy_a.current_health)
	_check(weapon_a.target_type == MechPart.TargetType.MAIN_MECH and weapon_b.target_part == enemy_b, "Destroying one target resets only affected weapons")
	controller.player_2.hand.append(light)
	controller.player_2.current_scrap = light.cost
	_check(controller.try_play_card(2, light, 1) == PlayerState.PlayPartResult.REPLACED, "AI gameplay path can replace a targeted slot")
	_check(weapon_b.target_type == MechPart.TargetType.MAIN_MECH, "AI Replace invalidates affected individual targets")

	controller.player_1.hand.append(heavy)
	controller.player_1.current_scrap = heavy.cost
	_check(controller.try_play_card(1, heavy, 0) == PlayerState.PlayPartResult.REPLACED, "Player 1 Replace remains available")
	var replacement: MechPart = controller.player_1.mech.slots[0]
	_check(replacement != weapon_a and replacement.target_type == MechPart.TargetType.MAIN_MECH and replacement.target_slot_index == -1, "Replacement weapon receives a fresh main-mech target")
	controller.restart_match()
	_check(controller.player_1.mech.slots.all(func(part) -> bool: return part == null), "Restart removes all runtime weapon target state")
	controller.free()

	_test_ui_interaction(light, heavy)

	if failures.is_empty():
		print("PHASE_14_PER_WEAPON_TARGETING_SMOKE_TEST: PASS")
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


func _test_ui_interaction(light: CardData, heavy: CardData) -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	var weapon_a := MechPart.new(light, controller.player_1, 0)
	var weapon_b := MechPart.new(light, controller.player_1, 1)
	var enemy_part := MechPart.new(heavy, controller.player_2, 0)
	controller.player_1.mech.install_part(weapon_a, 0)
	controller.player_1.mech.install_part(weapon_b, 1)
	controller.player_2.mech.install_part(enemy_part, 0)
	main_scene.p2_slot_buttons[0].pressed.emit()
	_check(weapon_a.target_type == MechPart.TargetType.MAIN_MECH and weapon_b.target_type == MechPart.TargetType.MAIN_MECH, "Enemy click without an own-weapon selection does not retarget weapons")
	main_scene.p1_slot_buttons[0].pressed.emit()
	_check(main_scene.selected_weapon_slot == 0 and "[SELECT TARGET]" in main_scene.p1_slot_buttons[0].text, "Clicking an occupied own module enters target-assignment mode")
	main_scene.p2_slot_buttons[0].pressed.emit()
	_check(weapon_a.target_part == enemy_part and weapon_b.target_type == MechPart.TargetType.MAIN_MECH and main_scene.selected_weapon_slot == -1, "Enemy click assigns only the selected weapon and clears temporary selection")
	_check("Target:" in main_scene.p1_slot_buttons[0].text and "Enemy Slot 1" in main_scene.p1_slot_buttons[0].text, "Own module displays its persistent target")
	main_scene.p1_slot_buttons[0].pressed.emit()
	var hand_button: Button = main_scene.p1_hand_container.get_child(0)
	hand_button.pressed.emit()
	_check(main_scene.selected_weapon_slot == -1 and main_scene.selected_cards[1] != null, "Hand selection clears target-assignment mode")
	controller.player_1.current_scrap = 100
	var old_weapon: MechPart = controller.player_1.mech.slots[0]
	main_scene.p1_slot_buttons[0].pressed.emit()
	_check(controller.player_1.mech.slots[0] != old_weapon and main_scene.selected_cards[1] == null, "Selected hand card gives Replace priority over weapon selection")
	var stable_hand_button: Button = main_scene.p1_hand_container.get_child(0)
	controller._process(0.25)
	main_scene._process(0.0)
	_check(stable_hand_button == main_scene.p1_hand_container.get_child(0), "Countdown and target labels update without rebuilding the hand")
	main_scene.p1_slot_buttons[1].pressed.emit()
	main_scene.p1_trash_buttons[1].pressed.emit()
	_check(main_scene.selected_weapon_slot == -1 and controller.player_1.mech.slots[1] == null, "Trashing the selected own weapon clears temporary target selection")
	controller.player_1.mech.install_part(MechPart.new(light, controller.player_1, 1), 1)
	main_scene.p1_slot_buttons[1].pressed.emit()
	controller.damage_debug_part(1, 1, light.max_health)
	_check(main_scene.selected_weapon_slot == -1 and controller.player_1.mech.slots[1] == null, "Destroying the selected own weapon clears temporary target selection")
	controller.player_1.mech.install_part(MechPart.new(light, controller.player_1, 1), 1)
	main_scene.p1_slot_buttons[1].pressed.emit()
	controller.end_match()
	_check(main_scene.selected_weapon_slot == -1 and main_scene.p1_slot_buttons[1].disabled and main_scene.p2_slot_buttons[0].disabled, "Match end clears temporary selection and disables targeting")
	main_scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
