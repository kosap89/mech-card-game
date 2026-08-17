extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const TEST_CURRENT := "user://phase17_test_current.cfg"
const TEST_PRESET_1 := "user://phase17_test_preset_1.cfg"
const TEST_PRESET_2 := "user://phase17_test_preset_2.cfg"
const TEST_MISSING := "user://phase17_test_missing_fields.cfg"

var failures: Array[String] = []


func _init() -> void:
	_cleanup_test_files()
	_test_serialization_presets_and_defaults()
	_test_apply_and_runtime_resources()
	_test_settings_ui_and_pause()
	_cleanup_test_files()
	if failures.is_empty():
		print("PHASE_17_BALANCE_SETTINGS_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_serialization_presets_and_defaults() -> void:
	var default_balance: BalanceConfig = load("res://data/balance/default_balance.tres")
	var default_deck: CardDeckDefinition = load("res://data/cards/test_deck.tres")
	var store := BalanceSettingsStore.new(default_balance, default_deck)
	var changed := store.get_snapshot()
	changed["game"]["mech_max_health"] = 1234
	changed["game"]["draw_interval_seconds"] = 1.7
	changed["game"]["scrap_return_fraction"] = 0.65
	changed["weapons"]["light_cannon"]["damage"] = 77
	changed["weapons"]["light_cannon"]["build_time"] = 2.3
	_check(store.save_snapshot(TEST_CURRENT, changed), "Current settings serialize to ConfigFile")
	var recreated := BalanceSettingsStore.new(default_balance, default_deck)
	_check(recreated.load_current(TEST_CURRENT), "A recreated runtime store loads persistent current settings")
	var loaded := recreated.get_snapshot()
	_check(loaded["game"]["mech_max_health"] == 1234 and typeof(loaded["game"]["mech_max_health"]) == TYPE_INT, "Integer game settings retain integer type")
	_check(is_equal_approx(loaded["game"]["draw_interval_seconds"], 1.7) and is_equal_approx(loaded["game"]["scrap_return_fraction"], 0.65), "Float game settings retain precision")
	_check(loaded["weapons"]["light_cannon"]["damage"] == 77 and is_equal_approx(loaded["weapons"]["light_cannon"]["build_time"], 2.3), "Weapon fields save and load")

	_check(store.save_snapshot(TEST_PRESET_1, changed), "Preset 1 saves a complete snapshot")
	var alternate := store.get_default_snapshot()
	alternate["game"]["mech_max_health"] = 2222
	alternate["weapons"]["light_cannon"]["damage"] = 22
	_check(store.save_snapshot(TEST_PRESET_2, alternate), "Preset 2 saves independently")
	_check(store.load_snapshot(TEST_PRESET_1)["game"]["mech_max_health"] == 1234 and store.load_snapshot(TEST_PRESET_2)["game"]["mech_max_health"] == 2222, "Preset slots remain independent")
	_check(store.load_snapshot("user://phase17_missing_preset.cfg").is_empty(), "Missing preset loads safely without changing settings")

	var partial := ConfigFile.new()
	partial.set_value("meta", "settings_version", 1)
	partial.set_value("game", "mech_max_health", 4321)
	partial.save(TEST_MISSING)
	var partial_snapshot := store.load_snapshot(TEST_MISSING)
	_check(partial_snapshot["game"]["mech_max_health"] == 4321 and partial_snapshot["game"]["builtin_cannon_damage"] == default_balance.builtin_cannon_damage, "Missing fields fall back to repository defaults")
	_check(partial_snapshot["weapons"]["heavy_cannon"]["damage"] == 30, "Missing weapon sections fall back to repository defaults")

	store.apply_snapshot(changed)
	store.apply_snapshot(store.get_default_snapshot())
	_check(store.get_snapshot()["game"]["mech_max_health"] == default_balance.mech_max_health and store.get_snapshot()["weapons"]["light_cannon"]["damage"] == 10, "Reset snapshot restores all repository defaults")
	_check(FileAccess.file_exists(TEST_PRESET_1) and FileAccess.file_exists(TEST_PRESET_2), "Resetting defaults does not delete presets")


func _test_apply_and_runtime_resources() -> void:
	var controller := _new_controller(TEST_CURRENT)
	var source_light: CardData = load("res://data/cards/light_cannon.tres")
	var snapshot := controller.settings_store.get_snapshot()
	snapshot["game"]["mech_max_health"] = 1500
	snapshot["game"]["starting_scrap"] = 9
	snapshot["game"]["builtin_cannon_damage"] = 17
	snapshot["game"]["builtin_cannon_activation_interval_seconds"] = 1.4
	snapshot["game"]["draw_interval_seconds"] = 1.2
	snapshot["game"]["ai_decision_interval_seconds"] = 1.8
	snapshot["weapons"]["light_cannon"]["cost"] = 8
	snapshot["weapons"]["light_cannon"]["damage"] = 44
	snapshot["weapons"]["light_cannon"]["max_health"] = 88
	snapshot["weapons"]["light_cannon"]["activation_interval"] = 1.6
	snapshot["weapons"]["light_cannon"]["build_time"] = 2.4
	snapshot["weapons"]["heavy_cannon"]["damage"] = 53
	_check(controller.apply_settings_snapshot(snapshot), "Apply persists the current configuration")
	_check(controller.player_1.mech.max_health == 1500 and controller.player_1.mech.current_health == 1500, "Apply automatically restarts with edited mech Health")
	_check(controller.player_1.current_scrap == 9 and controller.player_1.draw_interval_seconds == 1.2, "Restart uses edited Scrap and draw settings")
	_check(controller.opponent_ai.decision_interval_seconds == 1.8 and controller.balance.builtin_cannon_damage == 17, "AI and Built-in Cannon use edited settings")
	var runtime_light := _runtime_card(controller, &"light_cannon")
	_check(runtime_light.cost == 8 and runtime_light.damage == 44 and runtime_light.max_health == 88 and is_equal_approx(runtime_light.activation_interval, 1.6) and is_equal_approx(runtime_light.build_time, 2.4), "All editable weapon fields apply to runtime CardData")
	_check(runtime_light != source_light and source_light.damage == 10, "Runtime CardData is duplicated without mutating repository defaults")
	_check(controller.test_deck.cards[0] == controller.test_deck.cards[10], "Repeated deck entries share one runtime definition per weapon ID")

	var runtime_heavy := _runtime_card(controller, &"heavy_cannon")
	var heavy_part := MechPart.new(runtime_heavy, controller.player_2, 0)
	heavy_part.advance_construction(runtime_heavy.build_time)
	controller.player_2.mech.install_part(heavy_part, 0)
	var health_before := controller.player_2.mech.current_health
	controller.damage_debug_part(2, 0, runtime_heavy.max_health)
	_check(controller.player_2.mech.current_health == health_before - 53, "Explosion damage derives from edited runtime weapon Damage")
	controller.free()

	var loaded_controller := _new_controller(TEST_CURRENT, true)
	_check(loaded_controller.balance.mech_max_health == 1500 and _runtime_card(loaded_controller, &"light_cannon").damage == 44, "New application runtime loads applied current settings")
	loaded_controller.free()


func _test_settings_ui_and_pause() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller.load_persisted_settings = false
	controller.current_settings_path = TEST_CURRENT
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	_check(main_scene.settings_button != null and main_scene.settings_panel != null, "Board exposes an obvious Balance Settings overlay")
	main_scene.settings_button.pressed.emit()
	var panel: BalanceSettingsPanel = main_scene.settings_panel
	_check(panel.visible and controller.settings_paused, "Opening settings pauses gameplay")
	_check(panel.game_controls.size() == BalanceSettingsStore.GAME_FIELDS.size(), "Game Settings expose every live non-debug balance field")
	_check(panel.weapon_controls.size() == 10, "Weapon Settings enumerate all ten active definitions")
	_check(panel.weapon_controls["light_cannon"].size() == 5, "Each weapon exposes Cost, Damage, HP, Fire Interval, and Build Time")
	_check(_numeric_controls_are_wheel_safe(panel), "All Game and dynamically generated Weapon numeric rows reserve the mouse wheel for scrolling")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	_check(panel._is_mouse_wheel_event(wheel), "Balance editor recognizes vertical wheel input without consuming it")
	var categories: TabContainer = panel.get_node("SettingsRoot/SettingsCategories")
	_check(categories.get_child(0) is ScrollContainer and categories.get_child(1) is ScrollContainer, "Game and Weapon categories use independent scrolling views")
	_check(panel.get_combined_minimum_size().x <= 1024.0 and panel.get_combined_minimum_size().y <= 640.0, "Settings editor minimum size remains usable near 1024x640")
	var scrap_before := controller.player_1.current_scrap
	var builtin_before := controller.player_1.mech.builtin_cannon_elapsed
	var ai_before := controller.opponent_ai.decision_elapsed_seconds
	controller._process(5.0)
	_check(controller.player_1.current_scrap == scrap_before and controller.player_1.mech.builtin_cannon_elapsed == builtin_before and controller.opponent_ai.decision_elapsed_seconds == ai_before, "Scrap, combat, construction, draw, and AI simulation stay paused behind settings")
	panel.game_controls["mech_max_health"].value = 1777
	panel.close_editor()
	_check(not controller.settings_paused and controller.balance.mech_max_health != 1777, "Closing without Apply discards editor-only changes")
	controller._process(controller.balance.scrap_gain_interval_seconds)
	_check(controller.player_1.current_scrap == scrap_before + controller.balance.scrap_gain_amount, "Closing settings safely resumes gameplay")
	main_scene.free()


func _numeric_controls_are_wheel_safe(panel: BalanceSettingsPanel) -> bool:
	var all_spins: Array[SpinBox] = []
	for spin: SpinBox in panel.game_controls.values():
		all_spins.append(spin)
	for controls: Dictionary in panel.weapon_controls.values():
		for spin: SpinBox in controls.values():
			all_spins.append(spin)
	for spin in all_spins:
		var slider := spin.get_parent().get_child(1) as HSlider
		if slider == null or slider.scrollable:
			return false
		if not slider.mouse_force_pass_scroll_events or not spin.mouse_force_pass_scroll_events or not spin.get_line_edit().mouse_force_pass_scroll_events:
			return false
	return true


func _new_controller(path: String, load_current: bool = false) -> MatchController:
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres")
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller.current_settings_path = path
	controller.load_persisted_settings = load_current
	controller._ready()
	controller.opponent_ai.enabled = false
	return controller


func _runtime_card(controller: MatchController, card_id: StringName) -> CardData:
	for card in controller.settings_store.get_unique_runtime_cards():
		if card.id == card_id:
			return card
	return null


func _cleanup_test_files() -> void:
	for path in [TEST_CURRENT, TEST_PRESET_1, TEST_PRESET_2, TEST_MISSING, "user://phase17_missing_preset.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
