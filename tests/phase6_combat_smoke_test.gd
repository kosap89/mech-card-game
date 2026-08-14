extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const EPSILON := 0.0001

var failures: Array[String] = []


func _init() -> void:
	_test_ui_minimum_size()
	var controller := _new_controller()
	var cannon: CardData = load("res://data/cards/light_cannon.tres")
	_check(cannon.max_health == 40 and cannon.damage == 10 and is_equal_approx(cannon.activation_interval, 2.0), "Light Cannon preserves the original installed-weapon behavior")
	var cannon_count := 0
	for deck_card in controller.test_deck.cards:
		if deck_card.display_name == "Light Cannon":
			cannon_count += 1
	_check(cannon_count == 2, "Phase 10 test deck contains two Light Cannons per player (found %d)" % cannon_count)

	var cannon_part := _install_test_part(controller.player_1, cannon, 0)
	_check(cannon_part.current_health == cannon_part.max_health and cannon_part.max_health == cannon.max_health, "Installed part begins at full configured Health")
	var defender_health := controller.player_2.mech.current_health
	controller._process(cannon.activation_interval - 0.1)
	_check(controller.player_2.mech.current_health == defender_health, "Cannon waits for one full activation interval")
	controller._process(0.1)
	_check(controller.player_2.mech.current_health == defender_health - cannon.damage, "Cannon damages the opposing main mech")
	_check(controller.player_1.total_mech_damage_dealt == cannon.damage, "Automatic damage updates attacker score")
	controller._process(cannon.activation_interval)
	_check(controller.player_1.total_mech_damage_dealt == cannon.damage * 2, "Cannon attacks repeatedly")

	_install_test_part(controller.player_1, cannon, 1)
	var damage_before := controller.player_1.total_mech_damage_dealt
	controller._process(cannon.activation_interval)
	_check(controller.player_1.total_mech_damage_dealt == damage_before + cannon.damage * 2, "Two Cannons activate independently")

	controller.player_2.mech.current_health = 4
	damage_before = controller.player_1.total_mech_damage_dealt
	controller._process(cannon.activation_interval)
	_check(controller.player_2.mech.current_health == 0, "Automatic damage cannot reduce mech Health below zero")
	_check(controller.player_1.total_mech_damage_dealt == damage_before + 4, "Only actual applied automatic damage is scored")

	controller.restart_match()
	cannon_part = _install_test_part(controller.player_1, cannon, 0)
	var scrap_before := controller.player_1.current_scrap
	_check(controller.damage_debug_part(1, 0, 10) == 10, "Debug part damage applies")
	_check(cannon_part.current_health == 30, "Part Health decreases")
	_check(controller.damage_debug_part(1, 0, 1000) == 30, "Part damage clamps to remaining Health")
	_check(cannon_part.current_health == 0 and controller.player_1.mech.slots[0] == null, "Part is destroyed and removed at zero Health")
	_check(absf(controller.player_1.current_scrap - scrap_before) < EPSILON, "Destroyed part grants no Scrap")
	damage_before = controller.player_1.total_mech_damage_dealt
	controller._process(cannon.activation_interval)
	_check(controller.player_1.total_mech_damage_dealt == damage_before, "Destroyed weapon stops attacking")

	controller.restart_match()
	cannon_part = _install_test_part(controller.player_1, cannon, 0)
	controller._process(cannon.activation_interval * 0.5)
	controller.end_match()
	damage_before = controller.player_1.total_mech_damage_dealt
	controller._process(cannon.activation_interval * 2.0)
	_check(controller.player_1.total_mech_damage_dealt == damage_before, "Combat stops after match end")

	controller.restart_match()
	_check(_all_slots_empty(controller.player_1.mech), "Restart removes installed weapons")
	controller._process(cannon.activation_interval)
	_check(controller.player_1.total_mech_damage_dealt == 0, "No old weapon attack fires after restart")
	controller.free()

	if failures.is_empty():
		print("PHASE_6_COMBAT_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_ui_minimum_size() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	var margin: MarginContainer = main_scene.get_child(1)
	var minimum_size := margin.get_combined_minimum_size()
	_check(minimum_size.x <= 1100.0 and minimum_size.y <= 720.0, "Phase 6 UI minimum size fits the configured viewport")
	main_scene.free()


func _new_controller() -> MatchController:
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres")
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()
	controller.opponent_ai.enabled = false
	return controller


func _install_test_part(player: PlayerState, card: CardData, slot_index: int) -> MechPart:
	var part := MechPart.new(card, player, slot_index)
	_check(player.mech.install_part(part, slot_index), "Test part installs in an empty slot")
	return part


func _all_slots_empty(mech: MechState) -> bool:
	for part in mech.slots:
		if part != null:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
