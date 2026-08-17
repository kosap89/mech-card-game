extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const EPSILON := 0.001

var failures: Array[String] = []


func _init() -> void:
	var light: CardData = load("res://data/cards/light_cannon.tres")
	var heavy: CardData = load("res://data/cards/heavy_cannon.tres")
	var test_player := PlayerState.new(1, 1000, 0, load("res://data/cards/test_deck.tres"), 3.0)
	var light_part := MechPart.new(light, test_player, 0)
	light_part.advance_construction(light.build_time)
	_check(absf(light_part.get_activation_remaining() - light.activation_interval) < EPSILON, "New installed weapon starts at its full activation interval")
	light_part.advance_activation(0.5)
	_check(absf(light_part.get_activation_remaining() - 1.5) < EPSILON, "Installed weapon countdown decreases from runtime elapsed state")
	_check(light_part.advance_activation(1.5) == 1 and absf(light_part.get_activation_remaining() - light.activation_interval) < EPSILON, "Firing naturally resets the displayed remaining time")

	var heavy_part := MechPart.new(heavy, test_player, 1)
	heavy_part.advance_construction(heavy.build_time)
	light_part.advance_activation(0.25)
	heavy_part.advance_activation(1.0)
	_check(absf(light_part.get_activation_remaining() - 1.75) < EPSILON and absf(heavy_part.get_activation_remaining() - 3.0) < EPSILON, "Multiple weapons maintain independent countdown state")

	var controller := _new_controller()
	controller.opponent_ai.enabled = false
	var builtin_interval := controller.balance.builtin_cannon_activation_interval_seconds
	_check(absf(controller.get_builtin_cannon_remaining(1) - builtin_interval) < EPSILON and absf(controller.get_builtin_cannon_remaining(2) - builtin_interval) < EPSILON, "Both Built-in Cannons begin at the full interval")
	controller._process(1.0)
	_check(absf(controller.get_builtin_cannon_remaining(1) - 2.0) < EPSILON and absf(controller.get_builtin_cannon_remaining(2) - 2.0) < EPSILON, "Built-in Cannon countdowns decrease from gameplay state")
	controller.player_1.mech.builtin_cannon_elapsed = 2.0
	controller.player_2.mech.builtin_cannon_elapsed = 1.0
	_check(absf(controller.get_builtin_cannon_remaining(1) - 1.0) < EPSILON and absf(controller.get_builtin_cannon_remaining(2) - 2.0) < EPSILON, "Built-in Cannon countdowns are independent")
	controller.restart_match()
	_check(absf(controller.get_builtin_cannon_remaining(1) - builtin_interval) < EPSILON and absf(controller.get_builtin_cannon_remaining(2) - builtin_interval) < EPSILON, "Restart resets Built-in Cannon countdowns")
	controller._process(builtin_interval)
	_check(absf(controller.get_builtin_cannon_remaining(1) - builtin_interval) < EPSILON and absf(controller.get_builtin_cannon_remaining(2) - builtin_interval) < EPSILON, "Built-in Cannon countdowns reset after firing")
	controller.end_match()
	var stopped_remaining := controller.get_builtin_cannon_remaining(1)
	controller._process(1.0)
	_check(absf(controller.get_builtin_cannon_remaining(1) - stopped_remaining) < EPSILON, "Countdown state stops changing after match end")

	controller.restart_match()
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	light_part = MechPart.new(light, controller.player_1, 0)
	light_part.advance_construction(light.build_time)
	controller.player_1.mech.install_part(light_part, 0)
	light_part.advance_activation(0.7)
	controller.player_1.hand.append(heavy)
	controller.player_1.current_scrap = heavy.cost
	_check(controller.try_trash_part(1, 0) == PlayerState.TrashPartResult.SUCCESS, "Test setup clears the occupied slot")
	_check(controller.try_play_card(1, heavy, 0) == PlayerState.PlayPartResult.SUCCESS, "Weapon can be built in the emptied slot")
	var replacement: MechPart = controller.player_1.mech.slots[0]
	_check(replacement.card_data == heavy and replacement.is_constructing, "New weapon begins in construction")
	replacement.advance_construction(heavy.build_time)
	_check(absf(replacement.get_activation_remaining() - heavy.activation_interval) < EPSILON, "Completed weapon exposes a fresh full countdown")
	_check(controller.try_trash_part(1, 0) == PlayerState.TrashPartResult.SUCCESS and controller.player_1.mech.slots[0] == null, "Trash removes the weapon and its runtime countdown")
	light_part = MechPart.new(light, controller.player_1, 0)
	light_part.advance_construction(light.build_time)
	controller.player_1.mech.install_part(light_part, 0)
	controller.damage_debug_part(1, 0, light.max_health)
	_check(controller.player_1.mech.slots[0] == null, "Destruction removes the weapon and its runtime countdown")
	controller.free()

	_test_countdown_ui(light, heavy)

	if failures.is_empty():
		print("PHASE_11_ACTIVATION_UI_SMOKE_TEST: PASS")
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


func _test_countdown_ui(light: CardData, heavy: CardData) -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	_check("Next: 3.0s" in main_scene.p1_builtin_cannon.text and "Next: 3.0s" in main_scene.p2_builtin_cannon.text, "UI shows both Built-in Cannon countdowns")
	controller.player_1.mech.install_part(_active_part(light, controller.player_1, 0), 0)
	controller.player_2.mech.install_part(_active_part(heavy, controller.player_2, 0), 0)
	_check("Next: 2.0s" in main_scene.p1_slot_buttons[0].text and "Next: 4.0s" in main_scene.p2_slot_buttons[0].text, "Both players show fresh installed-weapon countdowns")
	_check(main_scene.p1_slot_buttons[0].get_parent().get_parent() is PanelContainer, "Installed weapon uses a card-like panel container")
	_check(not main_scene.p1_slot_buttons[0].disabled and not main_scene.p2_slot_buttons[0].disabled and main_scene.p2_trash_buttons[0].disabled, "Player modules remain interactive and occupied enemy modules are targetable without enabling enemy Trash")
	var original_hand_button: Button = main_scene.p1_hand_container.get_child(0)
	controller._process(0.5)
	main_scene._process(0.0)
	_check("Next: 1.5s" in main_scene.p1_slot_buttons[0].text and "Next: 3.5s" in main_scene.p2_slot_buttons[0].text, "UI countdown text follows independent runtime timers")
	_check(original_hand_button == main_scene.p1_hand_container.get_child(0) and is_instance_valid(original_hand_button), "Countdown refresh does not rebuild interactive hand controls")
	controller.player_1.add_scrap(10)
	original_hand_button.pressed.emit()
	_check(main_scene.selected_cards[1] != null, "Hand selection remains functional after countdown updates")

	controller.try_trash_part(1, 0)
	_check("EMPTY" in main_scene.p1_slot_buttons[0].text and "Next:" not in main_scene.p1_slot_buttons[0].text, "Trash immediately removes countdown presentation")
	controller.player_1.mech.install_part(_active_part(light, controller.player_1, 0), 0)
	controller.damage_debug_part(1, 0, light.max_health)
	_check("EMPTY" in main_scene.p1_slot_buttons[0].text and "Next:" not in main_scene.p1_slot_buttons[0].text, "Destruction leaves no ghost countdown")

	controller.player_1.mech.install_part(_active_part(light, controller.player_1, 0), 0)
	controller.player_1.hand.append(heavy)
	controller.player_1.current_scrap = heavy.cost
	_check(controller.try_play_card(1, heavy, 0) == PlayerState.PlayPartResult.SLOT_OCCUPIED, "Occupied slot blocks construction")
	controller.try_trash_part(1, 0)
	controller.try_play_card(1, heavy, 0)
	_check("Heavy Cannon" in main_scene.p1_slot_buttons[0].text and "BUILDING" in main_scene.p1_slot_buttons[0].text, "New weapon immediately shows construction")
	var built_heavy: MechPart = controller.player_1.mech.slots[0]
	built_heavy.advance_construction(heavy.build_time)
	main_scene._process(0.0)
	_check("Next: 4.0s" in main_scene.p1_slot_buttons[0].text, "Completed weapon shows its fresh countdown")
	controller.restart_match()
	_check("EMPTY" in main_scene.p1_slot_buttons[0].text and "Next: 3.0s" in main_scene.p1_builtin_cannon.text, "Restart clears modules and resets Built-in Cannon presentation")
	var margin: MarginContainer = main_scene.get_child(1)
	var minimum_size := margin.get_combined_minimum_size()
	_check(minimum_size.x <= 1280.0 and minimum_size.y <= 720.0, "Activation UI minimum size fits the configured desktop viewport")
	main_scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _active_part(card: CardData, player: PlayerState, slot_index: int) -> MechPart:
	var part := MechPart.new(card, player, slot_index)
	part.advance_construction(card.build_time)
	return part
