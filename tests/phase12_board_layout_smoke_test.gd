extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()

	_check(main_scene.enemy_area != null and main_scene.battle_area != null and main_scene.player_area != null, "Primary board areas build successfully")
	_check(main_scene.enemy_area.get_index() < main_scene.battle_area.get_index() and main_scene.battle_area.get_index() < main_scene.player_area.get_index(), "Enemy, battle, and human areas use top-to-bottom hierarchy")
	_check(main_scene.battle_area.size_flags_vertical == Control.SIZE_EXPAND_FILL and main_scene.battle_area.custom_minimum_size.y >= 150.0, "Central battle area owns vertical expansion and maintains a substantial visible gap")
	_check(main_scene.enemy_area.size_flags_vertical == Control.SIZE_FILL and main_scene.player_area.size_flags_vertical == Control.SIZE_FILL, "Mech areas remain content-sized instead of stretching weapon modules")
	_check(main_scene.p1_slot_buttons.size() == 4 and main_scene.p2_slot_buttons.size() == 4, "Both mechs expose exactly four weapon modules")
	_check(main_scene.player_area.is_ancestor_of(main_scene.p1_hand_container), "Player 1 hand is inside the lower human area")
	_check(main_scene.p1_hand_container.get_parent() is ScrollContainer, "Player 1 hand uses horizontal overflow scrolling")
	_check(not main_scene.p2_hand_container.visible and not main_scene.enemy_area.is_ancestor_of(main_scene.p2_hand_container), "AI hand is hidden from the primary board")
	_check(main_scene.p1_slot_buttons.all(func(button: Button) -> bool: return not button.disabled), "Player 1 slot modules remain interactive")
	_check(main_scene.p2_slot_buttons.all(func(button: Button) -> bool: return button.disabled), "Player 2 slot modules remain non-interactive")
	_check(main_scene.p2_trash_buttons.all(func(button: Button) -> bool: return not button.visible and button.disabled), "Enemy modules expose no Trash controls")
	_check(main_scene.enemy_area.is_ancestor_of(main_scene.p2_builtin_cannon) and main_scene.player_area.is_ancestor_of(main_scene.p1_builtin_cannon), "Built-in Cannon status is separate within each mech area")
	_check(main_scene.battle_area.is_ancestor_of(main_scene.result_label), "Match result occupies the central battle area")
	_check(main_scene.debug_panel.is_ancestor_of(main_scene.restart_button) and main_scene.restart_button.visible, "Restart remains accessible in the development area")
	_check(main_scene.debug_panel.get_child(0) is ScrollContainer, "Development controls use low-priority vertical scrolling when space is constrained")

	var light: CardData = load("res://data/cards/light_cannon.tres")
	controller.player_1.mech.install_part(MechPart.new(light, controller.player_1, 0), 0)
	controller.player_2.mech.install_part(MechPart.new(light, controller.player_2, 0), 0)
	controller._process(0.5)
	main_scene._process(0.0)
	_check("Next: 1.5s" in main_scene.p1_slot_buttons[0].text and "Next: 1.5s" in main_scene.p2_slot_buttons[0].text, "Activation countdowns continue updating on both board halves")
	_check("Built-in Cannon" in main_scene.p1_builtin_cannon.text and "Built-in Cannon" in main_scene.p2_builtin_cannon.text, "Both Built-in Cannon displays remain visible")

	var original_hand_button: Button = main_scene.p1_hand_container.get_child(0)
	controller._process(0.1)
	main_scene._process(0.0)
	_check(original_hand_button == main_scene.p1_hand_container.get_child(0), "Board countdown updates do not rebuild the hand")
	controller.player_1.add_scrap(10)
	original_hand_button.pressed.emit()
	_check(main_scene.selected_cards[1] != null, "Hand selection remains functional in the new board")

	controller.deal_debug_damage(1, controller.player_2.mech.current_health)
	_check(not main_scene.result_label.text.is_empty() and main_scene.battle_area.is_ancestor_of(main_scene.result_label), "Winner feedback appears prominently in the battle area")
	main_scene.restart_button.pressed.emit()
	_check(controller.match_state == MatchController.MatchState.ACTIVE and main_scene.p1_slot_buttons.all(func(button: Button) -> bool: return "EMPTY" in button.text), "Restart control resets the board")

	var margin: MarginContainer = main_scene.get_child(1)
	var minimum_size := margin.get_combined_minimum_size()
	_check(minimum_size.x <= 1024.0 and minimum_size.y <= 640.0, "Primary and development UI fit the minimum 1024x640 landscape window")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280 and ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "Project target viewport is 1280x720")
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items" and ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "Project uses responsive canvas_items expand stretching")
	main_scene.free()

	if failures.is_empty():
		print("PHASE_12_BOARD_LAYOUT_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
