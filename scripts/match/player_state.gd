class_name PlayerState
extends RefCounted

enum PlayPartResult {
	SUCCESS,
	INVALID_CARD,
	INVALID_SLOT,
	SLOT_OCCUPIED,
	NOT_ENOUGH_SCRAP,
	NOT_A_PART,
}

enum TrashPartResult { SUCCESS, INVALID_SLOT, EMPTY_SLOT }

signal damage_total_changed(total: int)
signal scrap_changed(current_scrap: int)
signal cards_changed(deck_count: int, hand_count: int)

var player_number: int
var mech: MechState
var total_mech_damage_dealt: int = 0
var current_scrap: int = 0
var starting_scrap: int = 0
var scrap_generation_elapsed: float = 0.0
var deck_definition: CardDeckDefinition
var deck: Array[CardData] = []
var hand: Array[CardData] = []
var draw_interval_seconds: float = 3.0
var draw_elapsed_seconds: float = 0.0


func _init(number: int, mech_max_health: int, configured_starting_scrap: int, configured_deck: CardDeckDefinition, configured_draw_interval: float) -> void:
	player_number = number
	mech = MechState.new(mech_max_health)
	starting_scrap = maxi(0, configured_starting_scrap)
	current_scrap = starting_scrap
	deck_definition = configured_deck
	draw_interval_seconds = maxf(0.1, configured_draw_interval)


func record_mech_damage(amount: int) -> void:
	if amount > 0:
		total_mech_damage_dealt += amount
		damage_total_changed.emit(total_mech_damage_dealt)


func add_scrap(amount: int) -> void:
	if amount <= 0:
		return
	current_scrap += amount
	scrap_changed.emit(current_scrap)


func can_afford(amount: int) -> bool:
	return amount >= 0 and current_scrap >= amount


func spend_scrap(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false
	current_scrap = maxi(0, current_scrap - amount)
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


func try_play_part(card: CardData, slot_index: int) -> int:
	var validation_result := validate_play_part(card, slot_index)
	if validation_result != PlayPartResult.SUCCESS:
		return validation_result
	spend_scrap(card.cost)
	remove_card_from_hand(card)
	var part := MechPart.new(card, self, slot_index)
	mech.install_part(part, slot_index)
	return validation_result


func validate_play_part(card: CardData, slot_index: int) -> int:
	if card == null or hand.find(card) < 0:
		return PlayPartResult.INVALID_CARD
	if card.card_type != CardData.CardType.PART:
		return PlayPartResult.NOT_A_PART
	if not mech.is_valid_slot(slot_index):
		return PlayPartResult.INVALID_SLOT
	if not mech.is_slot_empty(slot_index):
		return PlayPartResult.SLOT_OCCUPIED
	if not can_afford(card.cost):
		return PlayPartResult.NOT_ENOUGH_SCRAP
	return PlayPartResult.SUCCESS


func calculate_scrap_return(part: MechPart, scrap_return_fraction: float) -> int:
	if part == null:
		return 0
	# TODO(game design): The 50% return and upward rounding are temporary MVP rules.
	return ceili(part.card_data.cost * clampf(scrap_return_fraction, 0.0, 1.0))


func try_trash_part(slot_index: int, scrap_return_fraction: float) -> int:
	if not mech.is_valid_slot(slot_index):
		return TrashPartResult.INVALID_SLOT
	var part: MechPart = mech.slots[slot_index]
	if part == null:
		return TrashPartResult.EMPTY_SLOT
	var scrap_return := calculate_scrap_return(part, scrap_return_fraction)
	mech.take_part(slot_index)
	add_scrap(scrap_return)
	return TrashPartResult.SUCCESS


func advance_card_draw(delta: float) -> void:
	if deck.is_empty():
		return
	draw_elapsed_seconds += delta
	while draw_elapsed_seconds >= draw_interval_seconds and not deck.is_empty():
		draw_elapsed_seconds -= draw_interval_seconds
		draw_card()


func advance_scrap_generation(delta: float, gain_amount: int, gain_interval_seconds: float) -> void:
	if gain_amount <= 0 or gain_interval_seconds <= 0.0:
		return
	scrap_generation_elapsed += maxf(0.0, delta)
	while scrap_generation_elapsed >= gain_interval_seconds:
		scrap_generation_elapsed -= gain_interval_seconds
		add_scrap(gain_amount)


func reset(starting_hand_size: int = 0) -> void:
	total_mech_damage_dealt = 0
	current_scrap = starting_scrap
	scrap_generation_elapsed = 0.0
	hand.clear()
	draw_elapsed_seconds = 0.0
	initialize_deck()
	for draw_index in mini(starting_hand_size, deck.size()):
		draw_card()
	mech.reset()
	damage_total_changed.emit(total_mech_damage_dealt)
	scrap_changed.emit(current_scrap)
