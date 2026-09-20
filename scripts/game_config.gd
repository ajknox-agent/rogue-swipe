class_name GameConfig
extends RefCounted

signal config_updated(config: GameConfig)

# Metadata
var config_version: String = "1.4.0"
var config_name: String = "Defensive Broadside & Grapeshot"

# Health
var max_hp: int = 50

# Damage Values
var cannon_damage: int = 15
var cannon_vs_sail_damage: int = 8
var sail_ram_damage: int = 15
var board_crit_damage: int = 25
var board_clash_damage: int = 10
var grapeshot_repel_damage: int = 20

# Cooldowns & Turn Counters
var cannon_cooldown_turns: int = 2  # Turns on reload after firing (3 turns total cycle)
var board_sabotage_turns: int = 1   # Turns added to enemy cannons upon successful board

# Mechanics Toggles
var sail_consumes_cannon: bool = true
var unsuppressed_board_penalized: bool = true

# AI Settings
var enemy_ai_aggression: float = 0.65

# Live Sync Status
var is_live_synced: bool = false
var last_sync_time: String = "defaults"

func apply_dict(data: Dictionary) -> void:
	if data.has("config_version"):
		config_version = str(data["config_version"])
	if data.has("config_name"):
		config_name = str(data["config_name"])
	if data.has("max_hp"):
		max_hp = int(data["max_hp"])
	if data.has("cannon_damage"):
		cannon_damage = int(data["cannon_damage"])
	if data.has("cannon_vs_sail_damage"):
		cannon_vs_sail_damage = int(data["cannon_vs_sail_damage"])
	if data.has("sail_ram_damage"):
		sail_ram_damage = int(data["sail_ram_damage"])
	if data.has("board_crit_damage"):
		board_crit_damage = int(data["board_crit_damage"])
	if data.has("board_clash_damage"):
		board_clash_damage = int(data["board_clash_damage"])
	if data.has("grapeshot_repel_damage"):
		grapeshot_repel_damage = int(data["grapeshot_repel_damage"])
	if data.has("cannon_cooldown_turns"):
		cannon_cooldown_turns = int(data["cannon_cooldown_turns"])
	if data.has("board_sabotage_turns"):
		board_sabotage_turns = int(data["board_sabotage_turns"])
	if data.has("sail_consumes_cannon"):
		sail_consumes_cannon = bool(data["sail_consumes_cannon"])
	if data.has("unsuppressed_board_penalized"):
		unsuppressed_board_penalized = bool(data["unsuppressed_board_penalized"])
	if data.has("enemy_ai_aggression"):
		enemy_ai_aggression = float(data["enemy_ai_aggression"])
	
	is_live_synced = true
	emit_signal("config_updated", self)
