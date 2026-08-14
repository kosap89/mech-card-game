extends Control

@onready var match_controller: MatchController = $MatchController

var state_label: Label
var result_label: Label
var p1_health: Label
var p1_health_bar: ProgressBar
var p1_damage: Label
var p1_scrap: Label
var p1_hand_container: HBoxContainer
var p1_card_debug: Label
var p1_selected_label: Label
var p1_slot_buttons: Array[Button] = []
var p1_trash_buttons: Array[Button] = []
var p2_health: Label
var p2_health_bar: ProgressBar
var p2_damage: Label
var p2_scrap: Label
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
var selected_cards: Dictionary = {1: null, 2: null}


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
	_refresh()


func _build_placeholder_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	margin.add_child(root)
	root.add_child(_label("MECH CARD GAME - PHASE 10 TEST MATCH", 20))
	state_label = _label("", 16)
	root.add_child(state_label)
	result_label = _label("", 18)
	result_label.custom_minimum_size.y = 22
	root.add_child(result_label)
	var players := HBoxContainer.new()
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players.add_theme_constant_override("separation", 10)
	root.add_child(players)
	var p1_widgets := _build_player_panel(players, 1)
	p1_health = p1_widgets[0]
	p1_health_bar = p1_widgets[1]
	p1_damage = p1_widgets[2]
	p1_scrap = p1_widgets[3]
	p1_hand_container = p1_widgets[4]
	p1_card_debug = p1_widgets[5]
	p1_selected_label = p1_widgets[6]
	p1_slot_buttons.assign(p1_widgets[7])
	p1_trash_buttons.assign(p1_widgets[8])
	var p2_widgets := _build_player_panel(players, 2)
	p2_health = p2_widgets[0]
	p2_health_bar = p2_widgets[1]
	p2_damage = p2_widgets[2]
	p2_scrap = p2_widgets[3]
	p2_hand_container = p2_widgets[4]
	p2_card_debug = p2_widgets[5]
	p2_selected_label = p2_widgets[6]
	p2_slot_buttons.assign(p2_widgets[7])
	p2_trash_buttons.assign(p2_widgets[8])
	_build_debug_panel(root)
	feedback_label = _label("Select a card, then select one of that player's slots.", 16)
	root.add_child(feedback_label)


func _build_player_panel(parent: Control, player_number: int) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label("PLAYER %d - %s" % [player_number, "HUMAN" if player_number == 1 else "AI"], 18))
	var health_label := _label("", 14)
	box.add_child(health_label)
	var health_bar := ProgressBar.new()
	health_bar.show_percentage = false
	box.add_child(health_bar)
	var damage_label := _label("", 14)
	box.add_child(damage_label)
	var scrap_label := _label("SCRAP: 0", 17)
	box.add_child(scrap_label)
	var cannon_interval_text := ("%.1f" % match_controller.balance.builtin_cannon_activation_interval_seconds).trim_suffix(".0")
	box.add_child(_label("Built-in Cannon: %d DMG / %ss" % [match_controller.balance.builtin_cannon_damage, cannon_interval_text], 13))
	box.add_child(_label("Exactly 4 generic mech slots", 14))
	var slots := GridContainer.new()
	slots.columns = 2
	box.add_child(slots)
	var slot_buttons: Array[Button] = []
	var trash_buttons: Array[Button] = []
	for index in MechState.SLOT_COUNT:
		var slot := Button.new()
		slot.text = "Slot %d\nEMPTY" % (index + 1)
		slot.pressed.connect(_on_slot_pressed.bind(player_number, index))
		slot.custom_minimum_size = Vector2(0, 62)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(slot)
		slot_buttons.append(slot)
	var trash_grid := GridContainer.new()
	trash_grid.columns = 4
	trash_grid.add_theme_constant_override("h_separation", 3)
	box.add_child(trash_grid)
	for index in MechState.SLOT_COUNT:
		var trash_button := Button.new()
		trash_button.text = "Trash S%d" % (index + 1)
		trash_button.pressed.connect(_on_trash_pressed.bind(player_number, index))
		trash_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trash_grid.add_child(trash_button)
		trash_buttons.append(trash_button)
	var selected_label := _label("Selected card: None", 13)
	box.add_child(selected_label)
	box.add_child(_label("HAND - select a card to install", 13))
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = 84
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(hand_scroll)
	var hand_container := HBoxContainer.new()
	hand_container.add_theme_constant_override("separation", 6)
	hand_scroll.add_child(hand_container)
	var card_debug := _label("Deck: 0 | Hand: 0", 12)
	box.add_child(card_debug)
	return [health_label, health_bar, damage_label, scrap_label, hand_container, card_debug, selected_label, slot_buttons, trash_buttons]


func _build_debug_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label("DEVELOPMENT DEBUG CONTROLS - not game mechanics", 14))
	var buttons := GridContainer.new()
	buttons.columns = 4
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
	_refresh_slots()


func _on_mech_health_changed(_current_health: int, _max_health: int) -> void:
	_refresh_mech_combat_state()


func _on_damage_total_changed(_total: int) -> void:
	_refresh_mech_combat_state()


func _on_match_started() -> void:
	selected_cards[1] = null
	selected_cards[2] = null
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
	selected_cards[player_number] = card
	feedback_label.text = "Player %d selected %s (Cost %d)." % [player_number, card.display_name, card.cost]
	_refresh_cards()


func _on_slot_pressed(player_number: int, slot_index: int) -> void:
	if player_number != 1:
		feedback_label.text = "Player 2 slots are controlled by the AI."
		return
	var card: CardData = selected_cards[player_number]
	if card == null:
		feedback_label.text = "Select a Player %d card first." % player_number
		return
	var old_part: MechPart = match_controller.get_player(player_number).mech.slots[slot_index]
	var old_part_name := "" if old_part == null else old_part.card_data.display_name
	var result := match_controller.try_play_card(player_number, card, slot_index)
	match result:
		PlayerState.PlayPartResult.SUCCESS:
			feedback_label.text = "%s installed in Player %d Slot %d." % [card.display_name, player_number, slot_index + 1]
			selected_cards[player_number] = null
		PlayerState.PlayPartResult.REPLACED:
			feedback_label.text = "Replaced %s with %s." % [old_part_name, card.display_name]
			selected_cards[player_number] = null
		PlayerState.PlayPartResult.NOT_ENOUGH_SCRAP:
			feedback_label.text = "Not enough Scrap to install or replace this part."
		PlayerState.PlayPartResult.INVALID_SLOT:
			feedback_label.text = "Invalid mech slot."
		PlayerState.PlayPartResult.NOT_A_PART:
			feedback_label.text = "Only part cards can be installed in Phase 5."
		_:
			feedback_label.text = "Card installation is not available."
	_refresh()


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
		card_display.text = "%s%s\nCost: %d\nDMG: %d | Fire: %ss\nHP: %d" % ["[SELECTED] " if selected else "", card.display_name, card.cost, card.damage, _format_activation_interval(card.activation_interval), card.max_health]
		card_display.disabled = match_controller.match_state != MatchController.MatchState.ACTIVE or player.player_number != 1
		card_display.pressed.connect(_on_card_pressed.bind(player.player_number, card))
		card_display.custom_minimum_size = Vector2(150, 80)
		container.add_child(card_display)
	debug_label.text = "DEVELOPMENT CARD INFO - Deck: %d | Hand: %d" % [player.deck.size(), player.hand.size()]
	var selected_card: CardData = selected_cards[player.player_number]
	selected_label.text = "Selected card: %s" % ("None" if selected_card == null else "%s (Cost %d)" % [selected_card.display_name, selected_card.cost])


func _refresh_slots() -> void:
	_refresh_player_slots(match_controller.player_1, p1_slot_buttons, p1_trash_buttons)
	_refresh_player_slots(match_controller.player_2, p2_slot_buttons, p2_trash_buttons)


func _refresh_player_slots(player: PlayerState, buttons: Array[Button], trash_buttons: Array[Button]) -> void:
	var active := match_controller.match_state == MatchController.MatchState.ACTIVE
	var human_controlled := player.player_number == 1
	for slot_index in MechState.SLOT_COUNT:
		var part: MechPart = player.mech.slots[slot_index]
		buttons[slot_index].text = "Slot %d\nEMPTY" % (slot_index + 1) if part == null else "Slot %d - %s\nHP: %d / %d | DMG: %d\nFire: %ss" % [slot_index + 1, part.card_data.display_name, part.current_health, part.max_health, part.card_data.damage, _format_activation_interval(part.card_data.activation_interval)]
		buttons[slot_index].disabled = not active or not human_controlled
		trash_buttons[slot_index].disabled = not active or not human_controlled or part == null


func _on_ai_card_played(card_name: String, slot_index: int, replaced: bool, old_part_name: String) -> void:
	if replaced:
		feedback_label.text = "AI replaced %s with %s in Slot %d." % [old_part_name, card_name, slot_index + 1]
	else:
		feedback_label.text = "AI installed %s in Slot %d." % [card_name, slot_index + 1]


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


func _refresh() -> void:
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
	_refresh_slots()
