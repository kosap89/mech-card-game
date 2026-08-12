class_name BalanceConfig
extends Resource

@export_range(1.0, 3600.0, 1.0) var match_duration_seconds: float = 180.0
@export_range(1, 100000, 1) var mech_max_health: int = 1000
@export_range(1, 100000, 1) var debug_damage_amount: int = 100

# Temporary MVP Scrap values. These are subject to gameplay balancing.
@export_range(0.0, 1000.0, 0.1) var starting_scrap: float = 0.0
@export_range(0.0, 1000.0, 0.1) var scrap_per_second: float = 1.0
@export_range(0.1, 1000.0, 0.1) var debug_scrap_amount: float = 1.0

# Temporary MVP draw values. These are subject to gameplay balancing.
@export_range(0, 100, 1) var starting_hand_size: int = 3
@export_range(0.1, 60.0, 0.1) var draw_interval_seconds: float = 3.0

# TODO(game design): Define maximum hand size. Phase 4 leaves hands uncapped.
# TODO(game design): Define empty-deck behavior. Phase 4 stops drawing when empty.

# TODO(game design): Decide whether Scrap should have a maximum.
# Phase 3 intentionally leaves Scrap uncapped.

# TODO(game design): Decide what happens when a mech reaches zero before time expires.
# The temporary default keeps the match running until the defined timer end.
@export var end_match_when_mech_reaches_zero: bool = false
