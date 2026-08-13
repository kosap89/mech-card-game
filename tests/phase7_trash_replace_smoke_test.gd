extends SceneTree

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const EPSILON := 0.0001

var failures: Array[String] = []


func _init() -> void:
	var controller := _new_controller()
	var cannon: CardData = load("res://data/cards/basic_cannon.tres")
	var armor: CardData = load("res://data/cards/armor_plate.tres")
	var player := controller.player_1

	var cannon_part := _install_test_part(player, cannon, 0)
	controller._process(cannon.activation_interval)
	var damage_before := player.total_mech_damage_dealt
	var hand_before := player.hand.size()
	var deck_before := player.deck.size()
	var mech_health_before := player.mech.current_health
	var scrap_before := player.current_scrap
	var expected_return := cannon.cost * controller.balance.scrap_return_fraction
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
	player.current_scrap = 1.0
	player.hand.append(cannon)
	var hand_size := player.hand.size()
	var cannon_copies_before := player.hand.count(cannon)
	var result := controller.try_play_card(1, cannon, 0)
	_check(result == PlayerState.PlayPartResult.REPLACED, "Replace can use returned Scrap toward new card cost")
	_check(player.mech.slots[0] != old_part and player.mech.slots[0].card_data == cannon, "Replace swaps the part in the same slot")
	_check(absf(player.current_scrap) < EPSILON, "Replace applies return then charges normal new-card cost")
	_check(player.hand.size() == hand_size - 1 and player.hand.count(cannon) == cannon_copies_before - 1, "Replace removes exactly one selected-card entry")
	_check(player.mech.slots[0].current_health == cannon.max_health and is_zero_approx(player.mech.slots[0].activation_elapsed), "Replacement part starts with fresh Health and activation state")

	controller.restart_match()
	player = controller.player_1
	old_part = _install_test_part(player, armor, 0)
	player.current_scrap = 0.0
	var expensive_card: CardData = load("res://data/cards/heavy_cannon.tres")
	player.hand.append(expensive_card)
	hand_size = player.hand.size()
	scrap_before = player.current_scrap
	result = controller.try_play_card(1, expensive_card, 0)
	_check(result == PlayerState.PlayPartResult.NOT_ENOUGH_SCRAP, "Unaffordable Replace fails")
	_check(player.mech.slots[0] == old_part, "Failed Replace preserves old part")
	_check(player.hand.size() == hand_size and player.hand.find(expensive_card) >= 0, "Failed Replace preserves new card")
	_check(absf(player.current_scrap - scrap_before) < EPSILON, "Failed Replace preserves Scrap")

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
	_check(_all_slots_empty(controller.player_1.mech) and _all_slots_empty(controller.player_2.mech), "Restart clears Trash and Replace runtime state")
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
	controller.test_deck = load("res://data/cards/test_deck.tres")
	controller._ready()
	return controller


func _install_test_part(player: PlayerState, card: CardData, slot_index: int) -> MechPart:
	var part := MechPart.new(card, player, slot_index)
	_check(player.mech.install_part(part, slot_index), "Test part installs in empty slot")
	return part


func _all_slots_empty(mech: MechState) -> bool:
	for part in mech.slots:
		if part != null:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
