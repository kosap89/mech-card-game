extends Control

@onready var match_controller: MatchController = $MatchController

var timer_label: Label
var state_label: Label
var result_label: Label
var p1_health: Label
var p1_health_bar: ProgressBar
var p1_damage: Label
var p1_scrap: Label
var p2_health: Label
var p2_health_bar: ProgressBar
var p2_damage: Label
var p2_scrap: Label
var p1_hit_button: Button
var p2_hit_button: Button
var scrap_debug_buttons: Array[Button] = []


func _ready() -> void:
	_build_placeholder_ui()
	match_controller.time_changed.connect(_update_timer)
	match_controller.state_changed.connect(_refresh)
	match_controller.player_1.scrap_changed.connect(_on_scrap_changed)
	match_controller.player_2.scrap_changed.connect(_on_scrap_changed)
	_refresh()


func _build_placeholder_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_label("MECH CARD GAME - PHASE 3 TEST MATCH", 24))
	timer_label = _label("3:00", 36)
	root.add_child(timer_label)
	state_label = _label("", 16)
	root.add_child(state_label)
	result_label = _label("", 22)
	result_label.custom_minimum_size.y = 30
	root.add_child(result_label)
	var players := HBoxContainer.new()
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players.add_theme_constant_override("separation", 18)
	root.add_child(players)
	var p1_widgets := _build_player_panel(players, 1)
	p1_health = p1_widgets[0]
	p1_health_bar = p1_widgets[1]
	p1_damage = p1_widgets[2]
	p1_scrap = p1_widgets[3]
	var p2_widgets := _build_player_panel(players, 2)
	p2_health = p2_widgets[0]
	p2_health_bar = p2_widgets[1]
	p2_damage = p2_widgets[2]
	p2_scrap = p2_widgets[3]
	_build_debug_panel(root)


func _build_player_panel(parent: Control, player_number: int) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_label("PLAYER %d MECH" % player_number, 22))
	var health_label := _label("", 16)
	box.add_child(health_label)
	var health_bar := ProgressBar.new()
	health_bar.show_percentage = false
	box.add_child(health_bar)
	var damage_label := _label("", 16)
	box.add_child(damage_label)
	var scrap_label := _label("SCRAP: 0.0", 20)
	box.add_child(scrap_label)
	box.add_child(_label("Exactly 4 generic mech slots", 16))
	var slots := GridContainer.new()
	slots.columns = 2
	box.add_child(slots)
	for index in MechState.SLOT_COUNT:
		var slot := Button.new()
		slot.text = "Slot %d: Empty" % (index + 1)
		slot.disabled = true
		slot.custom_minimum_size = Vector2(0, 52)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(slot)
	return [health_label, health_bar, damage_label, scrap_label]


func _build_debug_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label("DEVELOPMENT DEBUG CONTROLS - not game mechanics", 16))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	p1_hit_button = Button.new()
	p1_hit_button.text = "P1 hits P2 (-%d)" % match_controller.balance.debug_damage_amount
	p1_hit_button.pressed.connect(_on_p1_hit_pressed)
	buttons.add_child(p1_hit_button)
	p2_hit_button = Button.new()
	p2_hit_button.text = "P2 hits P1 (-%d)" % match_controller.balance.debug_damage_amount
	p2_hit_button.pressed.connect(_on_p2_hit_pressed)
	buttons.add_child(p2_hit_button)
	for player_number in [1, 2]:
		var add_scrap_button := Button.new()
		add_scrap_button.text = "P%d +%.1f Scrap" % [player_number, match_controller.balance.debug_scrap_amount]
		add_scrap_button.pressed.connect(_on_add_scrap_pressed.bind(player_number))
		buttons.add_child(add_scrap_button)
		scrap_debug_buttons.append(add_scrap_button)
		var spend_scrap_button := Button.new()
		spend_scrap_button.text = "P%d Spend %.1f Scrap" % [player_number, match_controller.balance.debug_scrap_amount]
		spend_scrap_button.pressed.connect(_on_spend_scrap_pressed.bind(player_number))
		buttons.add_child(spend_scrap_button)
		scrap_debug_buttons.append(spend_scrap_button)
	var restart := Button.new()
	restart.text = "Restart / Play Again"
	restart.pressed.connect(match_controller.restart_match)
	buttons.add_child(restart)


func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _update_timer(seconds: float) -> void:
	var whole := ceili(seconds)
	timer_label.text = "%d:%02d" % [whole / 60, whole % 60]


func _on_p1_hit_pressed() -> void:
	match_controller.deal_debug_damage(1)


func _on_p2_hit_pressed() -> void:
	match_controller.deal_debug_damage(2)


func _on_add_scrap_pressed(player_number: int) -> void:
	match_controller.add_debug_scrap(player_number)


func _on_spend_scrap_pressed(player_number: int) -> void:
	match_controller.spend_debug_scrap(player_number)


func _on_scrap_changed(_current_scrap: float) -> void:
	_refresh()


func _refresh() -> void:
	state_label.text = "State: %s" % match_controller.get_state_name()
	result_label.text = match_controller.result_text
	p1_health.text = "Health: %d / %d" % [match_controller.player_1.mech.current_health, match_controller.player_1.mech.max_health]
	p1_health_bar.max_value = match_controller.player_1.mech.max_health
	p1_health_bar.value = match_controller.player_1.mech.current_health
	p1_damage.text = "Total mech damage dealt: %d" % match_controller.player_1.total_mech_damage_dealt
	p1_scrap.text = "SCRAP: %.1f" % match_controller.player_1.current_scrap
	p2_health.text = "Health: %d / %d" % [match_controller.player_2.mech.current_health, match_controller.player_2.mech.max_health]
	p2_health_bar.max_value = match_controller.player_2.mech.max_health
	p2_health_bar.value = match_controller.player_2.mech.current_health
	p2_damage.text = "Total mech damage dealt: %d" % match_controller.player_2.total_mech_damage_dealt
	p2_scrap.text = "SCRAP: %.1f" % match_controller.player_2.current_scrap
	var active := match_controller.match_state == MatchController.MatchState.ACTIVE
	p1_hit_button.disabled = not active
	p2_hit_button.disabled = not active
	for button in scrap_debug_buttons:
		button.disabled = not active
