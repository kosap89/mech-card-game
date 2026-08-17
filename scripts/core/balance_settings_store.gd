class_name BalanceSettingsStore
extends RefCounted

const SETTINGS_VERSION := 1
const CURRENT_SETTINGS_PATH := "user://current_balance.cfg"
const PRESET_PATH_TEMPLATE := "user://balance_preset_%d.cfg"
const GAME_FIELDS := [
	"mech_max_health",
	"builtin_cannon_damage",
	"builtin_cannon_activation_interval_seconds",
	"starting_scrap",
	"scrap_gain_amount",
	"scrap_gain_interval_seconds",
	"scrap_return_fraction",
	"starting_hand_size",
	"draw_interval_seconds",
	"ai_decision_interval_seconds",
]
const WEAPON_FIELDS := ["cost", "damage", "max_health", "activation_interval", "build_time"]

var runtime_balance: BalanceConfig
var runtime_deck: CardDeckDefinition
var _default_snapshot: Dictionary


func _init(default_balance: BalanceConfig, default_deck: CardDeckDefinition) -> void:
	_default_snapshot = _snapshot_resources(default_balance, default_deck)
	runtime_balance = default_balance.duplicate(true) as BalanceConfig
	runtime_deck = _duplicate_deck(default_deck)
	apply_snapshot(_default_snapshot)


func get_snapshot() -> Dictionary:
	return _snapshot_resources(runtime_balance, runtime_deck)


func get_default_snapshot() -> Dictionary:
	return _default_snapshot.duplicate(true)


func apply_snapshot(snapshot: Dictionary) -> void:
	var safe := _merge_with_defaults(snapshot)
	var game: Dictionary = safe["game"]
	for field in GAME_FIELDS:
		runtime_balance.set(field, game[field])
	var weapons: Dictionary = safe["weapons"]
	for card in get_unique_runtime_cards():
		var values: Dictionary = weapons.get(String(card.id), {})
		for field in WEAPON_FIELDS:
			card.set(field, values[field])


func load_current(path: String = CURRENT_SETTINGS_PATH) -> bool:
	var snapshot := load_snapshot(path)
	if snapshot.is_empty():
		return false
	apply_snapshot(snapshot)
	return true


func save_current(path: String = CURRENT_SETTINGS_PATH) -> bool:
	return save_snapshot(path, get_snapshot())


func save_preset(slot: int, snapshot: Dictionary) -> bool:
	return save_snapshot(PRESET_PATH_TEMPLATE % slot, snapshot)


func load_preset(slot: int) -> Dictionary:
	return load_snapshot(PRESET_PATH_TEMPLATE % slot)


func save_snapshot(path: String, snapshot: Dictionary) -> bool:
	var safe := _merge_with_defaults(snapshot)
	var config := ConfigFile.new()
	config.set_value("meta", "settings_version", SETTINGS_VERSION)
	for field in GAME_FIELDS:
		config.set_value("game", field, safe["game"][field])
	for weapon_id in safe["weapons"]:
		var section := "weapon:%s" % weapon_id
		for field in WEAPON_FIELDS:
			config.set_value(section, field, safe["weapons"][weapon_id][field])
	return config.save(path) == OK


func load_snapshot(path: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return {}
	var result := get_default_snapshot()
	for field in GAME_FIELDS:
		result["game"][field] = _typed_value(config.get_value("game", field, result["game"][field]), result["game"][field])
	for weapon_id in result["weapons"]:
		var section := "weapon:%s" % weapon_id
		for field in WEAPON_FIELDS:
			var fallback = result["weapons"][weapon_id][field]
			result["weapons"][weapon_id][field] = _typed_value(config.get_value(section, field, fallback), fallback)
	return _merge_with_defaults(result)


func get_unique_runtime_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	var seen := {}
	for card_value in runtime_deck.cards:
		var card: CardData = card_value
		if card == null or seen.has(card.id):
			continue
		seen[card.id] = true
		result.append(card)
	return result


func _snapshot_resources(balance: BalanceConfig, deck: CardDeckDefinition) -> Dictionary:
	var game := {}
	for field in GAME_FIELDS:
		game[field] = balance.get(field)
	var weapons := {}
	for card_value in deck.cards:
		var card: CardData = card_value
		if card == null or weapons.has(String(card.id)):
			continue
		var values := {"display_name": card.display_name}
		for field in WEAPON_FIELDS:
			values[field] = card.get(field)
		weapons[String(card.id)] = values
	return {"settings_version": SETTINGS_VERSION, "game": game, "weapons": weapons}


func _duplicate_deck(source: CardDeckDefinition) -> CardDeckDefinition:
	var result := CardDeckDefinition.new()
	var cards_by_id := {}
	for card_value in source.cards:
		var source_card: CardData = card_value
		var key := String(source_card.id)
		if not cards_by_id.has(key):
			cards_by_id[key] = source_card.duplicate(true)
		result.cards.append(cards_by_id[key])
	return result


func _merge_with_defaults(snapshot: Dictionary) -> Dictionary:
	var result := get_default_snapshot()
	var source_game: Dictionary = snapshot.get("game", {})
	for field in GAME_FIELDS:
		if source_game.has(field):
			result["game"][field] = _sanitize_game_value(field, source_game[field])
	var source_weapons: Dictionary = snapshot.get("weapons", {})
	for weapon_id in result["weapons"]:
		var source_values: Dictionary = source_weapons.get(weapon_id, {})
		for field in WEAPON_FIELDS:
			if source_values.has(field):
				result["weapons"][weapon_id][field] = _sanitize_weapon_value(field, source_values[field])
	return result


func _sanitize_game_value(field: String, value: Variant) -> Variant:
	match field:
		"mech_max_health": return clampi(int(value), 1, 100000)
		"builtin_cannon_damage": return clampi(int(value), 1, 100000)
		"starting_scrap": return clampi(int(value), 0, 1000)
		"scrap_gain_amount": return clampi(int(value), 1, 1000)
		"starting_hand_size": return clampi(int(value), 0, 100)
		"scrap_return_fraction": return clampf(float(value), 0.0, 1.0)
		"ai_decision_interval_seconds": return clampf(float(value), 0.1, 10.0)
		"draw_interval_seconds": return clampf(float(value), 0.1, 60.0)
		_: return clampf(float(value), 0.1, 3600.0)


func _sanitize_weapon_value(field: String, value: Variant) -> Variant:
	match field:
		"cost": return clampi(int(value), 1, 1000)
		"damage": return clampi(int(value), 1, 100000)
		"max_health": return clampi(int(value), 1, 100000)
		"activation_interval": return clampf(float(value), 0.1, 3600.0)
		"build_time": return clampf(float(value), 0.0, 3600.0)
	return value


func _typed_value(value: Variant, fallback: Variant) -> Variant:
	return int(value) if typeof(fallback) == TYPE_INT else float(value)
