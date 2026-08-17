extends Control

@onready var match_controller: MatchController = $MatchController

var state_label: Label
var result_label: Label
var p1_health: Label
var p1_health_bar: ProgressBar
var p1_damage: Label
var p1_scrap: Label
var p1_builtin_cannon: Label
var p1_hand_container: HBoxContainer
var p1_card_debug: Label
var p1_selected_label: Label
var p1_slot_buttons: Array[Button] = []
var p1_trash_buttons: Array[Button] = []
var p2_health: Label
var p2_health_bar: ProgressBar
var p2_mech_target_button: Button
var p2_damage: Label
var p2_scrap: Label
var p2_builtin_cannon: Label
var p2_hand_container: HBoxContainer
var p2_card_debug: Label
var p2_selected_label: Label
var p2_slot_buttons: Array[Button] = []
var p2_trash_buttons: Array[Button] = []
var p1_hit_button: Button
var p2_hit_button: Button
var scrap_debug_buttons: Array[Button] = []
var part_debug_buttons: Array[Button] = []
var feedback_label: Label
var enemy_area: PanelContainer
var battle_area: PanelContainer
var player_area: PanelContainer
var debug_panel: PanelContainer
var restart_button: Button
var settings_button: Button
var settings_panel: BalanceSettingsPanel
var selected_cards: Dictionary = {1: null, 2: null}
var selected_weapon_slot: int = -1
var selected_weapon_part: MechPart = null


func _ready() -> void:
	_build_placeholder_ui()
	match_controller.state_changed.connect(_refresh)
	match_controller.player_1.scrap_changed.connect(_on_scrap_changed)
	match_controller.player_2.scrap_changed.connect(_on_scrap_changed)
	match_controller.player_1.cards_changed.connect(_on_cards_changed)
	match_controller.player_2.cards_changed.connect(_on_cards_changed)
	match_controller.player_1.mech.slots_changed.connect(_on_slots_changed)
	match_controller.player_2.mech.slots_changed.connect(_on_slots_changed)
	match_controller.player_1.mech.health_changed.connect(_on_mech_health_changed)
	match_controller.player_2.mech.health_changed.connect(_on_mech_health_changed)
	match_controller.player_1.damage_total_changed.connect(_on_damage_total_changed)
	match_controller.player_2.damage_total_changed.connect(_on_damage_total_changed)
	match_controller.match_started.connect(_on_match_started)
	match_controller.ai_card_played.connect(_on_ai_card_played)
	match_controller.player_1_weapon_targets_changed.connect(_on_player_1_weapon_targets_changed)
	match_controller.weapon_exploded.connect(_on_weapon_exploded)
	_refresh()
	_build_settings_editor()


func _process(_delta: float) -> void:
	if p1_builtin_cannon == null or p2_builtin_cannon == null:
		return
	_refresh_activation_displays()


func _build_placeholder_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := _label("MECH CARD GAME - PHASE 17 BALANCE EDITOR", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	settings_button = Button.new()
	settings_button.name = "BalanceSettingsButton"
	settings_button.text = "Balance Settings"
	settings_button.pressed.connect(_on_settings_pressed)
	header.add_child(settings_button)
	state_label = _label("", 14)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(state_label)
	_build_enemy_area(root)
	_build_battle_area(root)
	_build_player_area(root)
	_build_debug_panel(root)


func _build_enemy_area(parent: Control) -> void:
	enemy_area = PanelContainer.new()
	enemy_area.name = "EnemyArea"
	enemy_area.size_flags_vertical = Control.SIZE_FILL
	parent.add_child(enemy_area)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	enemy_area.add_child(box)
	var status := HBoxContainer.new()
	box.add_child(status)
	p2_mech_target_button = Button.new()
	p2_mech_target_button.pressed.connect(_on_enemy_mech_target_pressed)
	p2_mech_target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(p2_mech_target_button)
	p2_health = _label("", 14)
	p2_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(p2_health)
	p2_damage = _label("", 12)
	p2_damage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(p2_damage)
	p2_scrap = _label("SCRAP: 0", 12)
	status.add_child(p2_scrap)
	var mech_row := HBoxContainer.new()
	mech_row.add_theme_constant_override("separation", 8)
	box.add_child(mech_row)
	p2_health_bar = ProgressBar.new()
	p2_health_bar.show_percentage = false
	p2_health_bar.custom_minimum_size = Vector2(160, 10)
	p2_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mech_row.add_child(p2_health_bar)
	p2_builtin_cannon = _label("", 13)
	mech_row.add_child(p2_builtin_cannon)
	var slot_widgets := _build_slot_row(box, 2, false)
	p2_slot_buttons.assign(slot_widgets[0])
	p2_trash_buttons.assign(slot_widgets[1])


func _build_battle_area(parent: Control) -> void:
	battle_area = PanelContainer.new()
	battle_area.name = "BattleArea"
	battle_area.custom_minimum_size.y = 150
	battle_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_area.size_flags_stretch_ratio = 3.0
	parent.add_child(battle_area)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	battle_area.add_child(box)
	box.add_child(_label("BATTLE", 16))
	result_label = _label("", 20)
	result_label.custom_minimum_size.y = 24
	result_label.clip_text = true
	box.add_child(result_label)
	feedback_label = _label("Select a card, then select an empty Player 1 slot.", 13)
	feedback_label.custom_minimum_size.y = 20
	feedback_label.clip_text = true
	box.add_child(feedback_label)


func _build_player_area(parent: Control) -> void:
	player_area = PanelContainer.new()
	player_area.name = "PlayerArea"
	player_area.size_flags_vertical = Control.SIZE_FILL
	parent.add_child(player_area)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	player_area.add_child(box)
	var slot_widgets := _build_slot_row(box, 1, true)
	p1_slot_buttons.assign(slot_widgets[0])
	p1_trash_buttons.assign(slot_widgets[1])
	p1_builtin_cannon = _label("", 13)
	var status := HBoxContainer.new()
	box.add_child(status)
	var heading := _label("PLAYER 1 - HUMAN", 17)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(heading)
	p1_health = _label("", 14)
	p1_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(p1_health)
	p1_damage = _label("", 12)
	p1_damage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(p1_damage)
	p1_scrap = _label("SCRAP: 0", 18)
	status.add_child(p1_scrap)
	var mech_row := HBoxContainer.new()
	mech_row.add_theme_constant_override("separation", 8)
	box.add_child(mech_row)
	p1_health_bar = ProgressBar.new()
	p1_health_bar.show_percentage = false
	p1_health_bar.custom_minimum_size = Vector2(160, 10)
	p1_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mech_row.add_child(p1_health_bar)
	mech_row.add_child(p1_builtin_cannon)
	p1_selected_label = _label("PLAYER 1 HAND | Selected card: None", 12)
	box.add_child(p1_selected_label)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "PlayerHandScroll"
	hand_scroll.custom_minimum_size.y = 64
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(hand_scroll)
	p1_hand_container = HBoxContainer.new()
	p1_hand_container.add_theme_constant_override("separation", 6)
	hand_scroll.add_child(p1_hand_container)
	p1_card_debug = _label("Deck: 0 | Hand: 0", 11)
	box.add_child(p1_card_debug)


func _build_slot_row(parent: Control, player_number: int, show_trash: bool) -> Array:
	var row := HBoxContainer.new()
	row.name = "Player%dWeaponRow" % player_number
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var slot_buttons: Array[Button] = []
	var trash_buttons: Array[Button] = []
	for index in MechState.SLOT_COUNT:
		var module_panel := PanelContainer.new()
		module_panel.custom_minimum_size = Vector2(0, 56 if not show_trash else 80)
		module_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(module_panel)
		var module_box := VBoxContainer.new()
		module_box.add_theme_constant_override("separation", 1)
		module_panel.add_child(module_box)
		var slot := Button.new()
		slot.text = "SLOT %d\nEMPTY" % (index + 1)
		slot.pressed.connect(_on_slot_pressed.bind(player_number, index))
		slot.custom_minimum_size = Vector2(0, 50)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		module_box.add_child(slot)
		slot_buttons.append(slot)
		var trash_button := Button.new()
		trash_button.text = "Trash"
		trash_button.pressed.connect(_on_trash_pressed.bind(player_number, index))
		trash_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trash_button.custom_minimum_size.y = 24
		trash_button.visible = show_trash
		trash_button.disabled = not show_trash
		module_box.add_child(trash_button)
		trash_buttons.append(trash_button)
	return [slot_buttons, trash_buttons]


func _build_debug_panel(parent: Control) -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "DevelopmentDebugArea"
	debug_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debug_panel.size_flags_stretch_ratio = 1.0
	parent.add_child(debug_panel)
	var debug_scroll := ScrollContainer.new()
	debug_scroll.custom_minimum_size.y = 54
	debug_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	debug_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	debug_panel.add_child(debug_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	debug_scroll.add_child(box)
	var debug_header := HBoxContainer.new()
	box.add_child(debug_header)
	var debug_title := _label("DEVELOPMENT DEBUG - not game mechanics", 11)
	debug_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_header.add_child(debug_title)
	p2_card_debug = _label("AI Deck: 0 | Hand: 0", 11)
	p2_card_debug.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_header.add_child(p2_card_debug)
	p2_selected_label = _label("Selected card: None", 10)
	p2_selected_label.visible = false
	box.add_child(p2_selected_label)
	p2_hand_container = HBoxContainer.new()
	p2_hand_container.name = "HiddenAIHand"
	p2_hand_container.visible = false
	box.add_child(p2_hand_container)
	var buttons := GridContainer.new()
	buttons.columns = 5
	buttons.add_theme_constant_override("h_separation", 4)
	buttons.add_theme_constant_override("v_separation", 4)
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
		add_scrap_button.text = "P%d +%d Scrap" % [player_number, match_controller.balance.debug_scrap_amount]
		add_scrap_button.pressed.connect(_on_add_scrap_pressed.bind(player_number))
		buttons.add_child(add_scrap_button)
		scrap_debug_buttons.append(add_scrap_button)
		var spend_scrap_button := Button.new()
		spend_scrap_button.text = "P%d Spend %d Scrap" % [player_number, match_controller.balance.debug_scrap_amount]
		spend_scrap_button.pressed.connect(_on_spend_scrap_pressed.bind(player_number))
		buttons.add_child(spend_scrap_button)
		scrap_debug_buttons.append(spend_scrap_button)
		var damage_part_button := Button.new()
		damage_part_button.text = "P%d Slot 1 -%d HP" % [player_number, match_controller.balance.debug_part_damage_amount]
		damage_part_button.pressed.connect(_on_damage_part_pressed.bind(player_number))
		buttons.add_child(damage_part_button)
		part_debug_buttons.append(damage_part_button)
	restart_button = Button.new()
	restart_button.text = "Restart / Play Again"
	restart_button.pressed.connect(match_controller.restart_match)
	buttons.add_child(restart_button)


func _build_settings_editor() -> void:
	settings_panel = BalanceSettingsPanel.new()
	add_child(settings_panel)
	settings_panel.setup(match_controller)


func _on_settings_pressed() -> void:
	settings_panel.open_editor()


func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _on_p1_hit_pressed() -> void:
	match_controller.deal_debug_damage(1)


func _on_p2_hit_pressed() -> void:
	match_controller.deal_debug_damage(2)


func _on_add_scrap_pressed(player_number: int) -> void:
	match_controller.add_debug_scrap(player_number)


func _on_spend_scrap_pressed(player_number: int) -> void:
	match_controller.spend_debug_scrap(player_number)


func _on_damage_part_pressed(player_number: int) -> void:
	match_controller.damage_debug_part(player_number, 0)


func _on_scrap_changed(_current_scrap: int) -> void:
	_refresh_scrap()


func _on_cards_changed(_deck_count: int, _hand_count: int) -> void:
	_clear_invalid_selections()
	_refresh_cards()


func _on_slots_changed() -> void:
	_clear_invalid_weapon_selection()
	_refresh_slots()


func _on_mech_health_changed(_current_health: int, _max_health: int) -> void:
	_refresh_mech_combat_state()


func _on_damage_total_changed(_total: int) -> void:
	_refresh_mech_combat_state()


func _on_match_started() -> void:
	selected_cards[1] = null
	selected_cards[2] = null
	_clear_weapon_selection()
	if feedback_label != null:
		feedback_label.text = "New match started. Select a card, then an empty own slot."
	_refresh()


func _on_card_pressed(player_number: int, card: CardData) -> void:
	if player_number != 1:
		feedback_label.text = "Player 2 is controlled by the AI."
		return
	if match_controller.match_state != MatchController.MatchState.ACTIVE:
		feedback_label.text = "Cards cannot be selected after the match ends."
		return
	_clear_weapon_selection()
	selected_cards[player_number] = card
	feedback_label.text = "Player %d selected %s (Cost %d)." % [player_number, card.display_name, card.cost]
	_refresh_slots()
	_refresh_target_presentation()
	_refresh_cards()


func _on_slot_pressed(player_number: int, slot_index: int) -> void:
	if player_number == 2:
		if selected_weapon_slot < 0:
			feedback_label.text = "Select one of your installed weapons first."
			return
		if match_controller.set_player_1_weapon_target_part(selected_weapon_slot, slot_index):
			var target_part: MechPart = match_controller.player_2.mech.slots[slot_index]
			feedback_label.text = "%s now targets enemy %s." % [selected_weapon_part.card_data.display_name, target_part.card_data.display_name]
			_clear_weapon_selection()
			_refresh_slots()
			_refresh_target_presentation()
		else:
			feedback_label.text = "Only occupied enemy weapon slots can be targeted."
		return
	var card: CardData = selected_cards[player_number]
	if card == null:
		var own_part: MechPart = match_controller.player_1.mech.slots[slot_index]
		if own_part == null:
			feedback_label.text = "Select a card before clicking an empty slot."
			return
		if own_part.is_constructing:
			feedback_label.text = "This weapon is still building and cannot select a target."
			return
		selected_weapon_slot = slot_index
		selected_weapon_part = own_part
		feedback_label.text = "Select a target for %s." % own_part.card_data.display_name
		_refresh_slots()
		_refresh_target_presentation()
		return
	var result := match_controller.try_play_card(player_number, card, slot_index)
	match result:
		PlayerState.PlayPartResult.SUCCESS:
			feedback_label.text = "%s construction started in Player %d Slot %d." % [card.display_name, player_number, slot_index + 1]
			selected_cards[player_number] = null
		PlayerState.PlayPartResult.SLOT_OCCUPIED:
			feedback_label.text = "Slot occupied. Trash the weapon first."
		PlayerState.PlayPartResult.NOT_ENOUGH_SCRAP:
			feedback_label.text = "Not enough Scrap to build this weapon."
		PlayerState.PlayPartResult.INVALID_SLOT:
			feedback_label.text = "Invalid mech slot."
		PlayerState.PlayPartResult.NOT_A_PART:
			feedback_label.text = "Only part cards can be installed in Phase 5."
		_:
			feedback_label.text = "Card installation is not available."
	_refresh()


func _on_enemy_mech_target_pressed() -> void:
	if selected_weapon_slot < 0:
		feedback_label.text = "Select one of your installed weapons first."
		return
	if match_controller.set_player_1_weapon_target_main_mech(selected_weapon_slot):
		feedback_label.text = "%s now targets the enemy main mech." % selected_weapon_part.card_data.display_name
		_clear_weapon_selection()
		_refresh_slots()
		_refresh_target_presentation()


func _on_player_1_weapon_targets_changed() -> void:
	_refresh_target_presentation()
	_refresh_slots()


func _on_trash_pressed(player_number: int, slot_index: int) -> void:
	if player_number != 1:
		feedback_label.text = "Player 2 is controlled by the AI."
		return
	var player := match_controller.get_player(player_number)
	var part: MechPart = null if player == null or not player.mech.is_valid_slot(slot_index) else player.mech.slots[slot_index]
	if part == null:
		feedback_label.text = "No installed part to Trash."
		return
	var part_name := part.card_data.display_name
	var scrap_return: int = player.calculate_scrap_return(part, match_controller.balance.scrap_return_fraction)
	var result := match_controller.try_trash_part(player_number, slot_index)
	if result == PlayerState.TrashPartResult.SUCCESS:
		_clear_invalid_weapon_selection()
		feedback_label.text = "Trashed %s for %d Scrap." % [part_name, scrap_return]
	else:
		feedback_label.text = "Part cannot be Trashed right now."


func _refresh_cards() -> void:
	_refresh_player_cards(match_controller.player_1, p1_hand_container, p1_card_debug, p1_selected_label)
	_refresh_player_cards(match_controller.player_2, p2_hand_container, p2_card_debug, p2_selected_label)


func _refresh_player_cards(player: PlayerState, container: HBoxContainer, debug_label: Label, selected_label: Label) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for card in player.hand:
		var card_display := Button.new()
		var selected: bool = selected_cards[player.player_number] == card
		card_display.text = "%s%s\nCost: %d | DMG: %d | HP: %d\nFire: %ss | Build: %ss" % ["[SELECTED] " if selected else "", card.display_name, card.cost, card.damage, card.max_health, _format_activation_interval(card.activation_interval), _format_activation_interval(card.build_time)]
		card_display.disabled = match_controller.match_state != MatchController.MatchState.ACTIVE or player.player_number != 1
		card_display.pressed.connect(_on_card_pressed.bind(player.player_number, card))
		card_display.custom_minimum_size = Vector2(150, 62)
		container.add_child(card_display)
	debug_label.text = "DEVELOPMENT CARD INFO - Deck: %d | Hand: %d" % [player.deck.size(), player.hand.size()]
	var selected_card: CardData = selected_cards[player.player_number]
	selected_label.text = "PLAYER 1 HAND | Selected card: %s" % ("None" if selected_card == null else "%s (Cost %d)" % [selected_card.display_name, selected_card.cost])
	if player.player_number != 1:
		selected_label.text = "Selected card: %s" % ("None" if selected_card == null else "%s (Cost %d)" % [selected_card.display_name, selected_card.cost])


func _refresh_slots() -> void:
	_refresh_player_slots(match_controller.player_1, p1_slot_buttons, p1_trash_buttons)
	_refresh_player_slots(match_controller.player_2, p2_slot_buttons, p2_trash_buttons)


func _refresh_player_slots(player: PlayerState, buttons: Array[Button], trash_buttons: Array[Button]) -> void:
	var active := match_controller.match_state == MatchController.MatchState.ACTIVE
	var human_controlled := player.player_number == 1
	for slot_index in MechState.SLOT_COUNT:
		var part: MechPart = player.mech.slots[slot_index]
		var target_prefix := ""
		if player.player_number == 1 and selected_weapon_slot == slot_index and selected_weapon_part == part:
			target_prefix = "[SELECT TARGET] "
		elif player.player_number == 2 and _selected_weapon_targets_enemy_slot(slot_index):
			target_prefix = "[CURRENT TARGET] "
		var target_text := ""
		if player.player_number == 1 and part != null and not part.is_constructing:
			target_text = " | Target: %s" % _get_weapon_target_text(part)
		if part == null:
			buttons[slot_index].text = "%sSLOT %d\nEMPTY" % [target_prefix, slot_index + 1]
		elif part.is_constructing:
			buttons[slot_index].text = "SLOT %d - %s\n[BUILDING]\nBuild: %.1fs remaining" % [slot_index + 1, part.card_data.display_name, part.get_build_remaining()]
		else:
			buttons[slot_index].text = "%sSLOT %d - %s\nDMG %d | HP %d/%d | Fire %ss\nNext: %.1fs%s" % [target_prefix, slot_index + 1, part.card_data.display_name, part.card_data.damage, part.current_health, part.max_health, _format_activation_interval(part.card_data.activation_interval), part.get_activation_remaining(), target_text]
		buttons[slot_index].disabled = not active or (not human_controlled and (part == null or part.is_constructing))
		trash_buttons[slot_index].disabled = not active or not human_controlled or part == null


func _refresh_activation_displays() -> void:
	p1_builtin_cannon.text = "Built-in Cannon | DMG: %d | Next: %.1fs" % [match_controller.balance.builtin_cannon_damage, match_controller.get_builtin_cannon_remaining(1)]
	p2_builtin_cannon.text = "Built-in Cannon | DMG: %d | Next: %.1fs" % [match_controller.balance.builtin_cannon_damage, match_controller.get_builtin_cannon_remaining(2)]
	_refresh_slots()


func _on_ai_card_played(card_name: String, slot_index: int) -> void:
	feedback_label.text = "AI started building %s in Slot %d." % [card_name, slot_index + 1]


func _on_weapon_exploded(weapon_name: String, owner_player_number: int, explosion_damage: int) -> void:
	feedback_label.text = "%s destroyed! Explosion dealt %d damage to Player %d mech." % [weapon_name, explosion_damage, owner_player_number]


func _format_activation_interval(seconds: float) -> String:
	var formatted := "%.2f" % seconds
	if formatted.ends_with("0"):
		formatted = formatted.trim_suffix("0")
	return formatted


func _clear_invalid_selections() -> void:
	for player_number in [1, 2]:
		var selected_card: CardData = selected_cards[player_number]
		var player := match_controller.get_player(player_number)
		if selected_card != null and player.hand.find(selected_card) < 0:
			selected_cards[player_number] = null


func _refresh_scrap() -> void:
	p1_scrap.text = "SCRAP: %d" % match_controller.player_1.current_scrap
	p2_scrap.text = "SCRAP: %d" % match_controller.player_2.current_scrap


func _refresh_mech_combat_state() -> void:
	p1_health.text = "Health: %d / %d" % [match_controller.player_1.mech.current_health, match_controller.player_1.mech.max_health]
	p1_health_bar.max_value = match_controller.player_1.mech.max_health
	p1_health_bar.value = match_controller.player_1.mech.current_health
	p1_damage.text = "Total mech damage dealt: %d" % match_controller.player_1.total_mech_damage_dealt
	p2_health.text = "Health: %d / %d" % [match_controller.player_2.mech.current_health, match_controller.player_2.mech.max_health]
	p2_health_bar.max_value = match_controller.player_2.mech.max_health
	p2_health_bar.value = match_controller.player_2.mech.current_health
	p2_damage.text = "Total mech damage dealt: %d" % match_controller.player_2.total_mech_damage_dealt
	_refresh_target_presentation()


func _refresh_target_presentation() -> void:
	if p2_mech_target_button == null:
		return
	var targeting_mech := selected_weapon_part != null and selected_weapon_part.target_type == MechPart.TargetType.MAIN_MECH
	p2_mech_target_button.text = "%sPLAYER 2 - AI\nEnemy Main Mech" % ("[CURRENT TARGET]\n" if targeting_mech else "")
	p2_mech_target_button.disabled = match_controller.match_state != MatchController.MatchState.ACTIVE


func _selected_weapon_targets_enemy_slot(enemy_slot_index: int) -> bool:
	return selected_weapon_part != null and not selected_weapon_part.is_constructing and selected_weapon_part.target_type == MechPart.TargetType.PART and selected_weapon_part.target_slot_index == enemy_slot_index


func _get_weapon_target_text(weapon: MechPart) -> String:
	if weapon.target_type != MechPart.TargetType.PART:
		return "Enemy Mech"
	if match_controller.player_2.mech.is_valid_slot(weapon.target_slot_index):
		var enemy_part: MechPart = match_controller.player_2.mech.slots[weapon.target_slot_index]
		if enemy_part != null and not enemy_part.is_constructing and enemy_part == weapon.target_part:
			return "%s (Enemy Slot %d)" % [enemy_part.card_data.display_name, weapon.target_slot_index + 1]
	return "Enemy Mech"


func _clear_invalid_weapon_selection() -> void:
	if selected_weapon_slot < 0:
		return
	if not match_controller.player_1.mech.is_valid_slot(selected_weapon_slot) or match_controller.player_1.mech.slots[selected_weapon_slot] != selected_weapon_part:
		_clear_weapon_selection()


func _clear_weapon_selection() -> void:
	selected_weapon_slot = -1
	selected_weapon_part = null


func _refresh() -> void:
	if match_controller.match_state != MatchController.MatchState.ACTIVE:
		_clear_weapon_selection()
	state_label.text = "State: %s" % match_controller.get_state_name()
	result_label.text = match_controller.result_text
	_refresh_mech_combat_state()
	_refresh_scrap()
	var active := match_controller.match_state == MatchController.MatchState.ACTIVE
	p1_hit_button.disabled = not active
	p2_hit_button.disabled = not active
	for button in scrap_debug_buttons:
		button.disabled = not active
	for button in part_debug_buttons:
		button.disabled = not active
	_refresh_cards()
	_refresh_activation_displays()
