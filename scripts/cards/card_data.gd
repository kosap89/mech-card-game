class_name CardData
extends Resource

# TODO(balance): Phase 10 weapon names and values are temporary combat-flow test data.
# Special weapon identities may be added only when their gameplay is explicitly designed.

enum CardType { PART }

@export var id: StringName
@export var display_name: String
@export_range(0, 1000, 1) var cost: int = 0
@export var card_type: CardType = CardType.PART
@export_range(1, 100000, 1) var max_health: int = 40
@export_range(0, 100000, 1) var damage: int = 0
@export_range(0.0, 3600.0, 0.1) var activation_interval: float = 0.0
# TODO(balance): Phase 15 construction times are temporary MVP values.
@export_range(0.0, 3600.0, 0.1) var build_time: float = 1.0
