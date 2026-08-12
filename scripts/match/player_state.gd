class_name PlayerState
extends RefCounted

signal damage_total_changed(total: int)
signal scrap_changed(current_scrap: float)
signal cards_changed(deck_count: int, hand_count: int)

var player_number: int
var mech: MechState
var total_mech_damage_dealt: int = 0
var current_scrap: float = 0.0
var starting_scrap: float = 0.0
var deck_definition: CardDeckDefinition
var deck: Array[CardData] = []
var hand: Array[CardData] = []
var draw_interval_seconds: float = 3.0
var draw_elapsed_seconds: float = 0.0


func _init(number: int, mech_max_health: int, configured_starting_scrap: float, configured_deck: CardDeckDefinition, configured_draw_interval: float) -> void:
	player_number = number
	mech = MechState.new(mech_max_health)
	starting_scrap = maxf(0.0, configured_starting_scrap)
	current_scrap = starting_scrap
	deck_definition = configured_deck
	draw_interval_seconds = maxf(0.1, configured_draw_interval)


func record_mech_damage(amount: int) -> void:
	if amount > 0:
		total_mech_damage_dealt += amount
		damage_total_changed.emit(total_mech_damage_dealt)


func add_scrap(amount: float) -> void:
	if amount <= 0.0:
		return
	current_scrap += amount
	scrap_changed.emit(current_scrap)


func can_afford(amount: float) -> bool:
	return amount >= 0.0 and current_scrap >= amount


func spend_scrap(amount: float) -> bool:
	if amount <= 0.0 or not can_afford(amount):
		return false
	current_scrap = maxf(0.0, current_scrap - amount)
	scrap_changed.emit(current_scrap)
	return true


func initialize_deck() -> void:
	deck.clear()
	if deck_definition != null:
		deck.assign(deck_definition.cards)
	shuffle_deck()
	cards_changed.emit(deck.size(), hand.size())


func shuffle_deck() -> void:
	deck.shuffle()


func draw_card() -> CardData:
	if deck.is_empty():
		return null
	var card: CardData = deck.pop_back()
	hand.append(card)
	cards_changed.emit(deck.size(), hand.size())
	return card


func remove_card_from_hand(card: CardData) -> bool:
	var card_index := hand.find(card)
	if card_index < 0:
		return false
	hand.remove_at(card_index)
	cards_changed.emit(deck.size(), hand.size())
	return true


func advance_card_draw(delta: float) -> void:
	if deck.is_empty():
		return
	draw_elapsed_seconds += delta
	while draw_elapsed_seconds >= draw_interval_seconds and not deck.is_empty():
		draw_elapsed_seconds -= draw_interval_seconds
		draw_card()


func reset(starting_hand_size: int = 0) -> void:
	total_mech_damage_dealt = 0
	current_scrap = starting_scrap
	hand.clear()
	draw_elapsed_seconds = 0.0
	initialize_deck()
	for draw_index in mini(starting_hand_size, deck.size()):
		draw_card()
	mech.reset()
	damage_total_changed.emit(total_mech_damage_dealt)
	scrap_changed.emit(current_scrap)
