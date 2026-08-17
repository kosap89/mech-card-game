extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const EXPECTED_BUILD_TIMES := {
	&"light_cannon": 1.0,
	&"autocannon": 1.5,
	&"pulse_gun": 1.5,
	&"rotary_gun": 2.0,
	&"twin_cannon": 2.5,
	&"heavy_cannon": 3.0,
	&"mortar": 3.0,
	&"plasma_cannon": 3.5,
	&"rail_cannon": 4.0,
	&"siege_cannon": 5.0,
}
const EPSILON := 0.001

var failures: Array[String] = []


func _init() -> void:
	_test_card_data_and_construction()
	_test_empty_slot_only_and_trash()
	_test_targeting_lifecycle_and_match_stop()
	_test_ai_construction()
	_test_ui()
	if failures.is_empty():
		print("PHASE_15_CONSTRUCTION_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_card_data_and_construction() -> void:
	var controller := _new_controller()
	controller.opponent_ai.enabled = false
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	var definitions := _definitions(controller)
	for card_id in EXPECTED_BUILD_TIMES:
		var card: CardData = definitions[card_id]
		_check(is_equal_approx(card.build_time, EXPECTED_BUILD_TIMES[card_id]), "%s has its configured Phase 15 build time" % card.display_name)
	var light: CardData = definitions[&"light_cannon"]
	controller.player_1.hand.append(light)
	var hand_count_before := controller.player_1.hand.size()
	controller.player_1.current_scrap = light.cost
	_check(controller.try_play_card(1, light, 0) == PlayerState.PlayPartResult.SUCCESS, "A weapon starts construction in an empty slot")
	var part: MechPart = controller.player_1.mech.slots[0]
	_check(part.is_constructing and is_zero_approx(part.build_elapsed) and is_equal_approx(part.get_build_remaining(), light.build_time), "New runtime weapon starts at the full build countdown")
	_check(controller.player_1.current_scrap == 0 and controller.player_1.hand.size() == hand_count_before - 1, "Scrap and exactly one hand card mutate immediately when construction begins")
	controller._process(light.build_time * 0.5)
	_check(part.is_constructing and is_equal_approx(part.get_build_remaining(), light.build_time * 0.5), "Construction countdown advances during an active match")
	_check(controller.player_1.total_mech_damage_dealt == 0 and is_zero_approx(part.activation_elapsed), "A building weapon neither attacks nor advances its activation timer")
	controller._process(light.build_time * 0.5)
	_check(not part.is_constructing and part.current_health == part.max_health and is_zero_approx(part.activation_elapsed), "Construction completes at full Health with a fresh activation timer")
	controller._process(light.activation_interval - 0.01)
	_check(controller.player_1.total_mech_damage_dealt == 0, "Completed weapon waits for its full activation interval")
	controller._process(0.01)
	_check(controller.player_1.total_mech_damage_dealt == light.damage, "Completed weapon attacks through the existing combat system")
	controller.restart_match()
	controller.player_1.hand.append(light)
	controller.player_1.current_scrap = light.cost
	controller.try_play_card(1, light, 0)
	controller._process(light.build_time + light.activation_interval)
	_check(controller.player_1.total_mech_damage_dealt == light.damage, "A combined update still fires at build time plus activation interval")
	controller.restart_match()
	_check(controller.player_1.mech.slots[0] == null, "Restart clears construction/runtime state")
	controller.free()


func _test_empty_slot_only_and_trash() -> void:
	var controller := _new_controller()
	controller.opponent_ai.enabled = false
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	controller.player_1.hand.append(light)
	controller.player_1.current_scrap = light.cost
	controller.try_play_card(1, light, 0)
	var building_part: MechPart = controller.player_1.mech.slots[0]
	controller.player_1.hand.append(heavy)
	controller.player_1.current_scrap = heavy.cost
	_check(controller.try_play_card(1, heavy, 0) == PlayerState.PlayPartResult.SLOT_OCCUPIED, "A building slot rejects another card")
	_check(controller.player_1.mech.slots[0] == building_part and heavy in controller.player_1.hand and controller.player_1.current_scrap == heavy.cost, "Building-slot rejection changes no state")
	_check(controller.try_trash_part(1, 0) == PlayerState.TrashPartResult.SUCCESS and controller.player_1.mech.slots[0] == null, "A constructing weapon can be Trashed")
	controller.player_1.current_scrap = heavy.cost
	controller.try_play_card(1, heavy, 0)
	var active_part: MechPart = controller.player_1.mech.slots[0]
	active_part.advance_construction(heavy.build_time)
	controller.player_1.hand.append(light)
	var scrap_before := controller.player_1.current_scrap
	_check(controller.try_play_card(1, light, 0) == PlayerState.PlayPartResult.SLOT_OCCUPIED, "An active occupied slot rejects another card")
	_check(controller.player_1.mech.slots[0] == active_part and light in controller.player_1.hand and controller.player_1.current_scrap == scrap_before, "Active-slot rejection is atomic")
	_check(controller.try_trash_part(1, 0) == PlayerState.TrashPartResult.SUCCESS, "An active weapon can still be Trashed")
	controller.free()


func _test_targeting_lifecycle_and_match_stop() -> void:
	var controller := _new_controller()
	controller.opponent_ai.enabled = false
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	var source := MechPart.new(light, controller.player_1, 0)
	source.advance_construction(light.build_time)
	var target := MechPart.new(heavy, controller.player_2, 0)
	controller.player_1.mech.install_part(source, 0)
	controller.player_2.mech.install_part(target, 0)
	_check(not controller.set_player_1_weapon_target_part(0, 0), "A constructing enemy weapon cannot be targeted")
	target.advance_construction(heavy.build_time)
	_check(controller.set_player_1_weapon_target_part(0, 0), "A completed enemy weapon becomes targetable")
	var stopped_build := MechPart.new(heavy, controller.player_1, 1)
	controller.player_1.mech.install_part(stopped_build, 1)
	controller.end_match()
	controller._process(heavy.build_time)
	_check(stopped_build.is_constructing and is_zero_approx(stopped_build.build_elapsed), "Construction stops when the match ends")
	controller.free()


func _test_ai_construction() -> void:
	var controller := _new_controller()
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	var light: CardData = load("res://data/cards/light_cannon.tres")
	controller.player_2.hand.clear()
	controller.player_2.hand.append(light)
	controller.player_2.current_scrap = light.cost
	controller.opponent_ai.advance(controller.balance.ai_decision_interval_seconds)
	var part: MechPart = _first_part(controller.player_2.mech)
	_check(part != null and part.is_constructing and controller.player_2.hand.is_empty(), "AI uses normal card play and creates a constructing weapon")
	controller._process(light.build_time)
	_check(not part.is_constructing and controller.player_2.total_mech_damage_dealt == 0, "AI weapon finishes construction without firing immediately")
	controller._process(light.activation_interval)
	_check(controller.player_2.total_mech_damage_dealt == light.damage, "AI weapon fires after its normal post-build interval")
	controller.free()


func _test_ui() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	var light: CardData = load("res://data/cards/light_cannon.tres")
	_check("Build:" in main_scene.p1_hand_container.get_child(0).text, "Hand cards show build time")
	controller.player_1.hand.append(light)
	controller.player_1.current_scrap = light.cost
	controller.try_play_card(1, light, 0)
	_check("BUILDING" in main_scene.p1_slot_buttons[0].text and "Build:" in main_scene.p1_slot_buttons[0].text and "Next:" not in main_scene.p1_slot_buttons[0].text, "Slot UI shows construction instead of active combat data")
	var hand_button: Button = main_scene.p1_hand_container.get_child(0)
	controller._process(0.25)
	main_scene._process(0.0)
	_check(hand_button == main_scene.p1_hand_container.get_child(0), "Construction countdown updates do not rebuild the hand")
	main_scene.p1_slot_buttons[0].pressed.emit()
	_check(main_scene.selected_weapon_slot == -1, "Constructing own weapon cannot enter target-assignment mode")
	controller.player_1.mech.slots[0].advance_construction(light.build_time)
	main_scene._process(0.0)
	_check("Next:" in main_scene.p1_slot_buttons[0].text and "BUILDING" not in main_scene.p1_slot_buttons[0].text, "Completed construction switches to active weapon presentation")
	main_scene.free()


func _new_controller() -> MatchController:
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres")
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()
	return controller


func _definitions(controller: MatchController) -> Dictionary:
	var result := {}
	for card in controller.test_deck.cards:
		result[card.id] = card
	return result


func _first_part(mech: MechState) -> MechPart:
	for part in mech.slots:
		if part != null:
			return part
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
