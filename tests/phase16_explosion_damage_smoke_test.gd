extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_combat_destruction_and_single_explosion()
	_test_automatic_shot_explosion()
	_test_safe_removal_paths()
	_test_target_fallback()
	_test_lethal_explosion_stops_match()
	_test_debug_damage_and_feedback()
	if failures.is_empty():
		print("PHASE_16_EXPLOSION_DAMAGE_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_combat_destruction_and_single_explosion() -> void:
	var controller := _new_controller()
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	var part := _active_part(heavy, controller.player_2, 0)
	controller.player_2.mech.install_part(part, 0)
	var mech_health := controller.player_2.mech.current_health
	var scrap := controller.player_2.current_scrap
	_check(controller.apply_part_damage(controller.player_1, controller.player_2, 0, heavy.max_health - 1) == heavy.max_health - 1, "Nonlethal combat damage applies to an ACTIVE weapon")
	_check(controller.player_2.mech.current_health == mech_health and not part.combat_destruction_resolved, "Nonlethal part damage causes no explosion")
	_check(controller.apply_part_damage(controller.player_1, controller.player_2, 0, 1000) == 1, "Lethal part damage clamps to remaining Health")
	_check(controller.player_2.mech.slots[0] == null and part.current_health == 0, "Combat destruction removes the weapon immediately")
	_check(controller.player_2.mech.current_health == mech_health - heavy.damage, "Explosion damages the weapon owner's main mech by card damage")
	_check(controller.player_1.total_mech_damage_dealt == heavy.damage, "Actual explosion damage is attributed to the attacking player")
	_check(controller.player_2.current_scrap == scrap, "Combat destruction returns no Scrap")
	var health_after := controller.player_2.mech.current_health
	_check(controller.apply_part_damage(controller.player_1, controller.player_2, 0, 1000) == 0 and controller.player_2.mech.current_health == health_after, "An empty destroyed slot cannot explode twice")
	_check(not part.mark_combat_destruction_resolved(), "Runtime guard rejects duplicate explosion resolution")
	controller.free()


func _test_safe_removal_paths() -> void:
	var controller := _new_controller()
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var owner_health := controller.player_1.mech.current_health
	var active := _active_part(light, controller.player_1, 0)
	controller.player_1.mech.install_part(active, 0)
	var expected_return := ceili(light.cost * controller.balance.scrap_return_fraction)
	_check(controller.try_trash_part(1, 0) == PlayerState.TrashPartResult.SUCCESS, "ACTIVE weapon Trash succeeds")
	_check(controller.player_1.mech.current_health == owner_health and controller.player_1.current_scrap == expected_return, "ACTIVE weapon Trash is safe and returns Scrap")
	var building := MechPart.new(light, controller.player_1, 0)
	controller.player_1.mech.install_part(building, 0)
	var scrap_before := controller.player_1.current_scrap
	_check(controller.try_trash_part(1, 0) == PlayerState.TrashPartResult.SUCCESS, "BUILDING weapon Trash succeeds")
	_check(controller.player_1.mech.current_health == owner_health and controller.player_1.current_scrap == scrap_before + expected_return and not building.combat_destruction_resolved, "BUILDING Trash is safe and never resolves an explosion")
	controller.player_1.mech.install_part(_active_part(light, controller.player_1, 0), 0)
	controller.restart_match()
	_check(controller.player_1.mech.current_health == owner_health and controller.player_1.mech.slots[0] == null, "Restart cleanup removes weapons without explosions")
	controller.free()


func _test_automatic_shot_explosion() -> void:
	var controller := _new_controller()
	var siege: CardData = load("res://data/cards/siege_cannon.tres")
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var attacker := _active_part(siege, controller.player_1, 0)
	var target := _active_part(light, controller.player_2, 0)
	controller.player_1.mech.install_part(attacker, 0)
	controller.player_2.mech.install_part(target, 0)
	controller.set_player_1_weapon_target_part(0, 0)
	var mech_health := controller.player_2.mech.current_health
	controller._process(siege.activation_interval)
	_check(controller.player_2.mech.slots[0] == null, "An automatic targeted shot destroys the enemy weapon")
	_check(controller.player_2.mech.current_health == mech_health - light.damage, "Overkill shot causes only the destroyed weapon's damage as main-mech explosion damage")
	_check(controller.player_1.total_mech_damage_dealt == light.damage, "The destroying shot does not also directly hit the main mech")
	_check(attacker.target_type == MechPart.TargetType.MAIN_MECH, "The firing weapon falls back after its target explodes")
	controller.free()


func _test_target_fallback() -> void:
	var controller := _new_controller()
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	var mortar: CardData = load("res://data/cards/mortar.tres")
	var weapon_a := _active_part(light, controller.player_1, 0)
	var weapon_b := _active_part(light, controller.player_1, 1)
	var weapon_c := _active_part(light, controller.player_1, 2)
	var target_a := _active_part(heavy, controller.player_2, 0)
	var target_b := _active_part(mortar, controller.player_2, 1)
	controller.player_1.mech.install_part(weapon_a, 0)
	controller.player_1.mech.install_part(weapon_b, 1)
	controller.player_1.mech.install_part(weapon_c, 2)
	controller.player_2.mech.install_part(target_a, 0)
	controller.player_2.mech.install_part(target_b, 1)
	controller.set_player_1_weapon_target_part(0, 0)
	controller.set_player_1_weapon_target_part(1, 0)
	controller.set_player_1_weapon_target_part(2, 1)
	controller.apply_part_damage(controller.player_1, controller.player_2, 0, heavy.max_health)
	_check(weapon_a.target_type == MechPart.TargetType.MAIN_MECH and weapon_b.target_type == MechPart.TargetType.MAIN_MECH, "All weapons targeting the destroyed module fall back to Enemy Mech")
	_check(weapon_c.target_part == target_b and weapon_c.target_slot_index == 1, "Unrelated per-weapon targets remain unchanged")
	controller.free()


func _test_lethal_explosion_stops_match() -> void:
	var controller := _new_controller()
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var doomed := _active_part(heavy, controller.player_2, 0)
	var later_weapon := _active_part(light, controller.player_2, 1)
	later_weapon.activation_elapsed = light.activation_interval
	var building := MechPart.new(heavy, controller.player_2, 2)
	controller.player_2.mech.install_part(doomed, 0)
	controller.player_2.mech.install_part(later_weapon, 1)
	controller.player_2.mech.install_part(building, 2)
	controller.player_2.mech.current_health = heavy.damage - 1
	var player_1_health := controller.player_1.mech.current_health
	controller.apply_part_damage(controller.player_1, controller.player_2, 0, heavy.max_health)
	_check(controller.match_state == MatchController.MatchState.ENDED and controller.result_text == "Player 1 wins!", "Lethal explosion ends the match with the opposing attacker as winner")
	_check(controller.player_2.mech.current_health == 0 and controller.player_1.total_mech_damage_dealt == heavy.damage - 1, "Lethal explosion clamps Health and records actual applied mech damage")
	controller._process(heavy.build_time + light.activation_interval)
	_check(controller.player_1.mech.current_health == player_1_health and is_zero_approx(building.build_elapsed), "No later firing or construction proceeds after lethal explosion")
	controller.free()


func _test_debug_damage_and_feedback() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	var light: CardData = load("res://data/cards/light_cannon.tres")
	controller.player_1.mech.install_part(_active_part(light, controller.player_1, 0), 0)
	var owner_health := controller.player_1.mech.current_health
	_check(controller.damage_debug_part(1, 0, light.max_health) == light.max_health, "Debug part damage uses the normal combat-destruction path")
	_check(controller.player_1.mech.current_health == owner_health - light.damage and controller.player_2.total_mech_damage_dealt == light.damage, "Debug destruction damages the owner and attributes damage to the opponent")
	_check("Light Cannon destroyed!" in main_scene.feedback_label.text and "10 damage to Player 1 mech" in main_scene.feedback_label.text, "UI provides compact explosion feedback")
	main_scene.free()


func _new_controller() -> MatchController:
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres").duplicate()
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()
	controller.opponent_ai.enabled = false
	return controller


func _active_part(card: CardData, player: PlayerState, slot_index: int) -> MechPart:
	var part := MechPart.new(card, player, slot_index)
	part.advance_construction(card.build_time)
	return part


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
