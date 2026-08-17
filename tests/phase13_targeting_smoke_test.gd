extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")

var failures: Array[String] = []


func _init() -> void:
	var controller := _new_controller()
	controller.opponent_ai.enabled = false
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	var weapon := MechPart.new(light, controller.player_1, 0)
	weapon.advance_construction(light.build_time)
	controller.player_1.mech.install_part(weapon, 0)
	_check(weapon.target_type == MechPart.TargetType.MAIN_MECH, "Installed Player 1 weapons default to the enemy main mech")
	_check(not controller.set_player_1_weapon_target_part(0, 0), "An empty enemy slot cannot be targeted")
	var enemy_part := MechPart.new(heavy, controller.player_2, 0)
	enemy_part.advance_construction(heavy.build_time)
	controller.player_2.mech.install_part(enemy_part, 0)
	_check(controller.set_player_1_weapon_target_part(0, 0), "An occupied enemy slot can be targeted")
	var enemy_mech_health := controller.player_2.mech.current_health
	controller._process(light.activation_interval)
	_check(enemy_part.current_health == heavy.max_health - light.damage, "Targeted installed-weapon fire damages the enemy part")
	_check(controller.player_2.mech.current_health == enemy_mech_health and controller.player_1.total_mech_damage_dealt == 0, "Part damage does not change main-mech Health or its damage statistic")
	controller.damage_debug_part(2, 0, enemy_part.current_health)
	_check(weapon.target_type == MechPart.TargetType.MAIN_MECH, "Destroyed targets fall back to the enemy main mech")
	weapon.activation_elapsed = light.activation_interval
	controller._process(0.0)
	_check(controller.player_2.mech.current_health == enemy_mech_health - light.damage, "The next shot after fallback damages the enemy main mech")
	controller.free()

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


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
