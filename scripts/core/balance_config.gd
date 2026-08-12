class_name BalanceConfig
extends Resource

@export_range(1.0, 3600.0, 1.0) var match_duration_seconds: float = 180.0
@export_range(1, 100000, 1) var mech_max_health: int = 1000
@export_range(1, 100000, 1) var debug_damage_amount: int = 100

# TODO(game design): Decide what happens when a mech reaches zero before time expires.
# The temporary default keeps the match running until the defined timer end.
@export var end_match_when_mech_reaches_zero: bool = false
