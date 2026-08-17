extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const EPSILON := 0.0001

var failures: Array[String] = []


func _init() -> void:
	var controller := _new_controller()
	var cannon: CardData = load("res://data/cards/light_cannon.tres")
	var armor: CardData = load("res://data/cards/armor_plate.tres")
	var player := controller.player_1

	var cannon_part := _install_test_part(player, cannon, 0)
	controller._process(cannon.activation_interval)
	var damage_before := player.total_mech_damage_dealt
	var hand_before := player.hand.size()
	var deck_before := player.deck.size()
	var mech_health_before := player.mech.current_health
	var scrap_before := player.current_scrap
	var expected_return := ceili(cannon.cost * controller.balance.scrap_return_fraction)
	_check(controller.try_trash_part(1, 0) == PlayerState.TrashPartResult.SUCCESS, "Installed part can be Trashed")
	_check(player.mech.slots[0] == null, "Trash empties the slot")
	_check(absf(player.current_scrap - (scrap_before + expected_return)) < EPSILON, "Trash returns configured Scrap fraction")
	_check(player.hand.size() == hand_before and player.deck.size() == deck_before, "Trash does not change hand or deck")
	_check(player.mech.current_health == mech_health_before, "Trash does not damage the owning mech")
	controller._process(cannon.activation_interval)
	_check(player.total_mech_damage_dealt == damage_before, "Trashed weapon stops attacking immediately")

	controller.restart_match()
	player = controller.player_1
	cannon_part = _install_test_part(player, cannon, 0)
	scrap_before = player.current_scrap
	controller.damage_debug_part(1, 0, cannon.max_health)
	_check(player.mech.slots[0] == null, "Destroyed part is removed")
	_check(absf(player.current_scrap - scrap_before) < EPSILON, "Destroyed part grants no Scrap")

	controller.restart_match()
	player = controller.player_1
	var old_part := _install_test_part(player, armor, 0)
	player.current_scrap = 1
	player.hand.append(cannon)
	var hand_size := player.hand.size()
	var result := controller.try_play_card(1, cannon, 0)
	_check(result == PlayerState.PlayPartResult.SLOT_OCCUPIED, "Occupied slot rejects card play even when Scrap return could have covered the cost")
	_check(player.mech.slots[0] == old_part, "Occupied-slot rejection preserves the installed part")
	_check(player.current_scrap == 1 and player.hand.size() == hand_size, "Occupied-slot rejection preserves Scrap and hand state")

	controller.restart_match()
	player = controller.player_1
	old_part = _install_test_part(player, armor, 0)
	player.current_scrap = 0
	var expensive_card: CardData = load("res://data/cards/heavy_cannon.tres")
	player.hand.append(expensive_card)
	hand_size = player.hand.size()
	scrap_before = player.current_scrap
	result = controller.try_play_card(1, expensive_card, 0)
	_check(result == PlayerState.PlayPartResult.SLOT_OCCUPIED, "Occupied-slot validation takes priority without using Scrap")
	_check(player.mech.slots[0] == old_part, "Blocked occupied-slot play preserves old part")
	_check(player.hand.size() == hand_size and player.hand.find(expensive_card) >= 0, "Blocked occupied-slot play preserves new card")
	_check(absf(player.current_scrap - scrap_before) < EPSILON, "Blocked occupied-slot play preserves Scrap")

	controller.restart_match()
	player = controller.player_1
	_install_test_part(player, cannon, 0)
	_install_test_part(player, cannon, 1)
	controller._process(cannon.activation_interval)
	damage_before = player.total_mech_damage_dealt
	controller.try_trash_part(1, 0)
	controller._process(cannon.activation_interval)
	_check(player.total_mech_damage_dealt == damage_before + cannon.damage, "Trashing one weapon leaves the other weapon active")

	controller.end_match()
	scrap_before = player.current_scrap
	_check(controller.try_trash_part(1, 1) != PlayerState.TrashPartResult.SUCCESS, "Trash is blocked after match end")
	_check(player.mech.slots[1] != null and absf(player.current_scrap - scrap_before) < EPSILON, "Blocked Trash changes no state")

	controller.restart_match()
	_check(_all_slots_empty(controller.player_1.mech) and _all_slots_empty(controller.player_2.mech), "Restart clears Trash and weapon runtime state")
	controller.free()

	if failures.is_empty():
		print("PHASE_7_TRASH_REPLACE_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _new_controller() -> MatchController:
	var controller: MatchController = MatchControllerScript.new()
	controller.balance = load("res://data/balance/default_balance.tres")
	controller.balance.builtin_cannon_activation_interval_seconds = 10000.0
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()
	controller.opponent_ai.enabled = false
	return controller


func _install_test_part(player: PlayerState, card: CardData, slot_index: int) -> MechPart:
	var part := MechPart.new(card, player, slot_index)
	_check(player.mech.install_part(part, slot_index), "Test part installs in empty slot")
	part.advance_construction(card.build_time)
	return part


func _all_slots_empty(mech: MechState) -> bool:
	for part in mech.slots:
		if part != null:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
