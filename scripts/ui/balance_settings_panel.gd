class_name BalanceSettingsPanel
extends PanelContainer

const GAME_DEFINITIONS := [
	["MECH", "mech_max_health", "Main Mech Max Health", 1.0, 100000.0, 1.0, false],
	["BUILT-IN CANNON", "builtin_cannon_damage", "Damage", 1.0, 100000.0, 1.0, false],
	["BUILT-IN CANNON", "builtin_cannon_activation_interval_seconds", "Fire Interval", 0.1, 30.0, 0.1, true],
	["SCRAP", "starting_scrap", "Starting Scrap", 0.0, 1000.0, 1.0, false],
	["SCRAP", "scrap_gain_amount", "Gain Amount", 1.0, 1000.0, 1.0, false],
	["SCRAP", "scrap_gain_interval_seconds", "Gain Interval", 0.1, 30.0, 0.1, true],
	["SCRAP", "scrap_return_fraction", "Trash Return", 0.0, 100.0, 1.0, false],
	["HAND / DRAW", "starting_hand_size", "Starting Hand Size", 0.0, 100.0, 1.0, false],
	["HAND / DRAW", "draw_interval_seconds", "Draw Interval", 0.1, 60.0, 0.1, true],
	["AI", "ai_decision_interval_seconds", "Decision Interval", 0.1, 10.0, 0.1, true],
]
const WEAPON_DEFINITIONS := [
	["cost", "Cost", 1.0, 100.0, 1.0, false],
	["damage", "Damage", 1.0, 1000.0, 1.0, false],
	["max_health", "Max Health", 1.0, 10000.0, 1.0, false],
	["activation_interval", "Fire Interval", 0.1, 30.0, 0.1, true],
	["build_time", "Build Time", 0.0, 30.0, 0.1, true],
]

var match_controller: MatchController
var game_controls := {}
var weapon_controls := {}
var feedback_label: Label
var _editor_snapshot: Dictionary


func setup(controller: MatchController) -> void:
	match_controller = controller
	name = "BalanceSettingsPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func open_editor() -> void:
	_editor_snapshot = match_controller.settings_store.get_snapshot()
	_populate_controls(_editor_snapshot)
	feedback_label.text = "Edit values, then Apply Settings. Apply saves and restarts the match."
	match_controller.set_settings_paused(true)
	visible = true


func close_editor() -> void:
	visible = false
	match_controller.set_settings_paused(false)


func get_editor_snapshot() -> Dictionary:
	return _collect_snapshot()


func load_editor_snapshot(snapshot: Dictionary) -> void:
	_editor_snapshot = snapshot.duplicate(true)
	_populate_controls(_editor_snapshot)


func _build_ui() -> void:
	var outer := VBoxContainer.new()
	outer.name = "SettingsRoot"
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := _label("DEVELOPMENT BALANCE SETTINGS", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close (Discard Unapplied)"
	close_button.pressed.connect(close_editor)
	header.add_child(close_button)
	var tabs := TabContainer.new()
	tabs.name = "SettingsCategories"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(tabs)
	_build_game_tab(tabs)
	_build_weapon_tab(tabs)
	feedback_label = _label("", 13)
	feedback_label.custom_minimum_size.y = 24
	outer.add_child(feedback_label)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	outer.add_child(actions)
	var primary_actions := HBoxContainer.new()
	primary_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(primary_actions)
	var apply_button := Button.new()
	apply_button.name = "ApplySettingsButton"
	apply_button.text = "Apply Settings (Save + Restart Match)"
	apply_button.pressed.connect(_on_apply_pressed)
	primary_actions.add_child(apply_button)
	var defaults_button := Button.new()
	defaults_button.name = "ResetDefaultsButton"
	defaults_button.text = "Reset Editor to Defaults"
	defaults_button.pressed.connect(_on_defaults_pressed)
	primary_actions.add_child(defaults_button)
	var presets := GridContainer.new()
	presets.name = "PresetActions"
	presets.columns = 3
	presets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(presets)
	for slot in range(1, 4):
		var preset_label := _label("PRESET %d" % slot, 12)
		presets.add_child(preset_label)
		var save_button := Button.new()
		save_button.text = "Save"
		save_button.pressed.connect(_on_save_preset.bind(slot))
		save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(save_button)
		var load_button := Button.new()
		load_button.text = "Load"
		load_button.pressed.connect(_on_load_preset.bind(slot))
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(load_button)


func _build_game_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "GAME SETTINGS"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	scroll.add_child(content)
	var last_category := ""
	for definition in GAME_DEFINITIONS:
		if definition[0] != last_category:
			last_category = definition[0]
			content.add_child(_label(last_category, 16))
		var suffix := "%" if definition[1] == "scrap_return_fraction" else (" s" if definition[6] else "")
		game_controls[definition[1]] = _add_numeric_row(content, definition[2], definition[3], definition[4], definition[5], suffix)


func _build_weapon_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "CARD / WEAPON SETTINGS"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	for card in match_controller.settings_store.get_unique_runtime_cards():
		var panel := PanelContainer.new()
		content.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		box.add_child(_label(card.display_name.to_upper(), 16))
		var controls := {}
		for definition in WEAPON_DEFINITIONS:
			controls[definition[0]] = _add_numeric_row(box, definition[1], definition[2], definition[3], definition[4], " s" if definition[5] else "")
		weapon_controls[String(card.id)] = controls


func _add_numeric_row(parent: Control, label_text: String, minimum: float, maximum: float, step: float, suffix: String) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name_label := _label(label_text, 13)
	name_label.custom_minimum_size.x = 180
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.suffix = suffix
	spin.custom_minimum_size.x = 130
	row.add_child(spin)
	slider.value_changed.connect(func(value: float) -> void: spin.value = value)
	spin.value_changed.connect(func(value: float) -> void: slider.value = value)
	return spin


func _populate_controls(snapshot: Dictionary) -> void:
	for field in game_controls:
		var value: float = snapshot["game"][field]
		game_controls[field].value = value * 100.0 if field == "scrap_return_fraction" else value
	for weapon_id in weapon_controls:
		for field in weapon_controls[weapon_id]:
			weapon_controls[weapon_id][field].value = snapshot["weapons"][weapon_id][field]


func _collect_snapshot() -> Dictionary:
	var snapshot := match_controller.settings_store.get_default_snapshot()
	for field in game_controls:
		var value: float = game_controls[field].value
		if field == "scrap_return_fraction":
			value /= 100.0
		var fallback = snapshot["game"][field]
		snapshot["game"][field] = int(value) if typeof(fallback) == TYPE_INT else value
	for weapon_id in weapon_controls:
		for field in weapon_controls[weapon_id]:
			var value: float = weapon_controls[weapon_id][field].value
			var fallback = snapshot["weapons"][weapon_id][field]
			snapshot["weapons"][weapon_id][field] = int(value) if typeof(fallback) == TYPE_INT else value
	return snapshot


func _on_apply_pressed() -> void:
	var saved := match_controller.apply_settings_snapshot(_collect_snapshot())
	_editor_snapshot = match_controller.settings_store.get_snapshot()
	_populate_controls(_editor_snapshot)
	feedback_label.text = "Settings applied, current configuration saved, and match restarted." if saved else "Settings applied and match restarted, but current settings could not be saved."


func _on_defaults_pressed() -> void:
	load_editor_snapshot(match_controller.settings_store.get_default_snapshot())
	feedback_label.text = "Repository defaults loaded into the editor. Press Apply to use them."


func _on_save_preset(slot: int) -> void:
	feedback_label.text = "Preset %d saved." % slot if match_controller.settings_store.save_preset(slot, _collect_snapshot()) else "Preset %d could not be saved." % slot


func _on_load_preset(slot: int) -> void:
	var snapshot := match_controller.settings_store.load_preset(slot)
	if snapshot.is_empty():
		feedback_label.text = "Preset %d is empty." % slot
		return
	load_editor_snapshot(snapshot)
	feedback_label.text = "Preset %d loaded into the editor. Press Apply to use it." % slot


func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
