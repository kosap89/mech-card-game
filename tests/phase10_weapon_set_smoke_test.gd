extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const EXPECTED_WEAPONS := {
	&"light_cannon": ["Light Cannon", 2, 40, 10, 2.0],
	&"heavy_cannon": ["Heavy Cannon", 4, 70, 30, 4.0],
	&"autocannon": ["Autocannon", 3, 45, 7, 1.0],
	&"siege_cannon": ["Siege Cannon", 6, 80, 60, 7.0],
	&"twin_cannon": ["Twin Cannon", 4, 55, 16, 2.0],
	&"pulse_gun": ["Pulse Gun", 3, 40, 12, 1.5],
	&"rail_cannon": ["Rail Cannon", 5, 55, 45, 5.0],
	&"rotary_gun": ["Rotary Gun", 4, 50, 5, 0.75],
	&"plasma_cannon": ["Plasma Cannon", 5, 60, 24, 2.5],
	&"mortar": ["Mortar", 4, 45, 35, 4.5],
}
const INACTIVE_NAMES := ["Basic Cannon", "Armor Plate", "Repair Module", "Shield Emitter", "Scrap Collector", "Helper Bot", "Rocket Module"]

var failures: Array[String] = []


func _init() -> void:
	var controller := _new_controller()
	var definitions := _unique_definitions(controller.test_deck.cards)
	_check(controller.test_deck.cards.size() == 20, "Active test deck contains 20 cards")
	_check(definitions.size() == 10, "Active test deck contains exactly 10 unique weapon definitions")
	_check(controller.test_deck.cards[0] == controller.test_deck.cards[10], "Deck duplicates reuse the same CardData resource")
	for card_id in EXPECTED_WEAPONS:
		_check(definitions.has(card_id), "Active deck contains %s" % card_id)
		if not definitions.has(card_id):
			continue
		var card: CardData = definitions[card_id]
		var expected: Array = EXPECTED_WEAPONS[card_id]
		_check(card.display_name == expected[0] and card.cost == expected[1] and card.max_health == expected[2] and card.damage == expected[3] and is_equal_approx(card.activation_interval, expected[4]), "%s has the specified Phase 10 values" % card.display_name)
		_check(not card.id.is_empty() and not card.display_name.is_empty(), "%s has valid identity data" % card_id)
		_check(card.cost > 0 and card.max_health > 0 and card.damage > 0 and card.activation_interval > 0.0, "%s has positive weapon stats" % card.display_name)
		_check(controller.test_deck.cards.count(card) == 2, "%s appears exactly twice by shared reference" % card.display_name)
	for card in controller.test_deck.cards:
		_check(card.display_name not in INACTIVE_NAMES, "%s is not an active placeholder" % card.display_name)

	controller.opponent_ai.enabled = false
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	var light: CardData = definitions[&"light_cannon"]
	var heavy: CardData = definitions[&"heavy_cannon"]
	var autocannon: CardData = definitions[&"autocannon"]
	controller.player_1.mech.install_part(MechPart.new(light, controller.player_1, 0), 0)
	controller.player_1.mech.install_part(MechPart.new(autocannon, controller.player_1, 1), 1)
	controller._process(1.0)
	_check(controller.player_1.total_mech_damage_dealt == autocannon.damage, "Autocannon fires at its own interval")
	controller._process(1.0)
	_check(controller.player_1.total_mech_damage_dealt == autocannon.damage * 2 + light.damage, "Different weapons fire independently")

	controller.restart_match()
	controller.player_1.mech.install_part(MechPart.new(heavy, controller.player_1, 0), 0)
	controller._process(heavy.activation_interval)
	_check(controller.player_1.total_mech_damage_dealt == heavy.damage, "Heavy Cannon deals its configured automatic damage")

	for card_id in EXPECTED_WEAPONS:
		controller.restart_match()
		var card: CardData = definitions[card_id]
		controller.player_1.mech.install_part(MechPart.new(card, controller.player_1, 0), 0)
		var expected_return := ceili(card.cost * controller.balance.scrap_return_fraction)
		_check(controller.try_trash_part(1, 0) == PlayerState.TrashPartResult.SUCCESS, "%s can be Trashed" % card.display_name)
		_check(controller.player_1.current_scrap == expected_return and controller.player_1.mech.slots[0] == null, "%s Trash returns whole Scrap and empties its slot" % card.display_name)

	controller.restart_match()
	var old_part := MechPart.new(light, controller.player_1, 0)
	controller.player_1.mech.install_part(old_part, 0)
	controller.player_1.hand.append(heavy)
	controller.player_1.current_scrap = heavy.cost - ceili(light.cost * controller.balance.scrap_return_fraction)
	_check(controller.try_play_card(1, heavy, 0) == PlayerState.PlayPartResult.REPLACED, "Replace works between different weapon types")
	var replaced_part: MechPart = controller.player_1.mech.slots[0]
	_check(replaced_part != old_part and replaced_part.card_data == heavy and replaced_part.current_health == heavy.max_health and is_zero_approx(replaced_part.activation_elapsed), "Replace creates fresh Heavy Cannon runtime state")

	controller.restart_match()
	controller.opponent_ai.enabled = true
	controller.opponent_ai.random.seed = 1010
	controller.player_2.hand.clear()
	controller.player_2.hand.append(definitions[&"rail_cannon"])
	controller.player_2.current_scrap = definitions[&"rail_cannon"].cost
	controller.opponent_ai.advance(controller.balance.ai_decision_interval_seconds)
	_check(controller.player_2.hand.is_empty() and _occupied_slot_count(controller.player_2.mech) == 1, "AI installs a Phase 10 weapon through normal card play")

	controller.restart_match()
	_check(_occupied_slot_count(controller.player_1.mech) == 0 and _occupied_slot_count(controller.player_2.mech) == 0, "Restart removes Phase 10 runtime weapons")
	controller.free()

	_test_ui_stats()

	if failures.is_empty():
		print("PHASE_10_WEAPON_SET_SMOKE_TEST: PASS")
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


func _unique_definitions(cards: Array) -> Dictionary:
	var definitions := {}
	for card in cards:
		definitions[card.id] = card
	return definitions


func _occupied_slot_count(mech: MechState) -> int:
	var count := 0
	for part in mech.slots:
		if part != null:
			count += 1
	return count


func _test_ui_stats() -> void:
	var main_scene: Control = load("res://scenes/main/main.tscn").instantiate()
	var controller: MatchController = main_scene.get_node("MatchController")
	controller._ready()
	controller.opponent_ai.enabled = false
	main_scene.match_controller = controller
	main_scene._ready()
	var card_text: String = main_scene.p1_hand_container.get_child(0).text
	_check("Cost:" in card_text and "DMG:" in card_text and "Fire:" in card_text and "HP:" in card_text, "Hand cards display all required weapon stats")
	var light: CardData = load("res://data/cards/light_cannon.tres")
	controller.player_1.mech.install_part(MechPart.new(light, controller.player_1, 0), 0)
	var slot_text: String = main_scene.p1_slot_buttons[0].text
	_check("Light Cannon" in slot_text and "HP:" in slot_text and "DMG:" in slot_text and "Fire:" in slot_text, "Installed slots display all required weapon stats")
	main_scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
