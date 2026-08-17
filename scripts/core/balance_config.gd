class_name BalanceConfig
extends Resource

@export_range(1, 100000, 1) var mech_max_health: int = 1000
@export_range(1, 100000, 1) var debug_damage_amount: int = 100
@export_range(1, 100000, 1) var debug_part_damage_amount: int = 10

# Temporary MVP built-in cannon values. These are subject to gameplay balancing.
@export_range(1, 100000, 1) var builtin_cannon_damage: int = 10
@export_range(0.1, 3600.0, 0.1) var builtin_cannon_activation_interval_seconds: float = 3.0

# TODO(game design): Define the final Scrap return formula for Trash.
@export_range(0.0, 1.0, 0.05) var scrap_return_fraction: float = 0.5

# Temporary MVP Scrap values. These are subject to gameplay balancing.
@export_range(0, 1000, 1) var starting_scrap: int = 0
@export_range(1, 1000, 1) var scrap_gain_amount: int = 1
@export_range(0.1, 3600.0, 0.1) var scrap_gain_interval_seconds: float = 1.0
@export_range(1, 1000, 1) var debug_scrap_amount: int = 1

# Temporary MVP draw values. These are subject to gameplay balancing.
@export_range(0, 100, 1) var starting_hand_size: int = 3
@export_range(0.1, 60.0, 0.1) var draw_interval_seconds: float = 3.0

# Temporary MVP opponent pacing. This is subject to gameplay testing.
@export_range(0.1, 10.0, 0.1) var ai_decision_interval_seconds: float = 1.0

# TODO(game design): Define maximum hand size. Phase 4 leaves hands uncapped.
# TODO(game design): Define empty-deck behavior. Phase 4 stops drawing when empty.

# TODO(game design): Decide whether Scrap should have a maximum.
# Phase 3 intentionally leaves Scrap uncapped.
