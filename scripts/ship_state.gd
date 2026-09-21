extends RefCounted

const CombatResolver = preload("res://scripts/combat_resolver.gd")

const MAX_DEFAULT_HP: int = 50

var name: String = "Ship"
var max_hp: int = MAX_DEFAULT_HP
var hp: int = MAX_DEFAULT_HP
var port_cooldown_turns: int = 1
var starboard_cooldown_turns: int = 0
var board_cooldown_turns: int = 0

var port_cannon_cd: int = 0
var starboard_cannon_cd: int = 0
var board_cd: int = 0
var config: RefCounted = null

func _init(p_name: String = "Ship", p_config: RefCounted = null) -> void:
	name = p_name
	if p_config:
		apply_config(p_config)
	else:
		hp = max_hp

func apply_config(p_config: RefCounted) -> void:
	config = p_config
	if "max_hp" in config:
		max_hp = config.max_hp
	if "port_cooldown_turns" in config:
		port_cooldown_turns = config.port_cooldown_turns
	if "starboard_cooldown_turns" in config:
		starboard_cooldown_turns = config.starboard_cooldown_turns
	if "board_cooldown_turns" in config:
		board_cooldown_turns = config.board_cooldown_turns

func reset() -> void:
	if config:
		apply_config(config)
	hp = max_hp
	port_cannon_cd = 0
	starboard_cannon_cd = 0
	board_cd = 0

func is_action_available(action: CombatResolver.Action) -> bool:
	match action:
		CombatResolver.Action.SAIL:
			return true
		CombatResolver.Action.BOARD:
			return board_cd <= 0
		CombatResolver.Action.CANNON_PORT:
			return port_cannon_cd <= 0
		CombatResolver.Action.CANNON_STARBOARD:
			return starboard_cannon_cd <= 0
		_:
			return false

func use_action(action: CombatResolver.Action) -> void:
	match action:
		CombatResolver.Action.CANNON_PORT:
			port_cannon_cd = (port_cooldown_turns + 1) if port_cooldown_turns > 0 else 0
		CombatResolver.Action.CANNON_STARBOARD:
			starboard_cannon_cd = (starboard_cooldown_turns + 1) if starboard_cooldown_turns > 0 else 0
		CombatResolver.Action.BOARD:
			board_cd = (board_cooldown_turns + 1) if board_cooldown_turns > 0 else 0

func tick_cooldowns() -> void:
	if port_cannon_cd > 0:
		port_cannon_cd -= 1
	if starboard_cannon_cd > 0:
		starboard_cannon_cd -= 1
	if board_cd > 0:
		board_cd -= 1

func take_damage(amount: int) -> int:
	var actual = mini(amount, hp)
	hp = maxi(0, hp - amount)
	return actual

func is_dead() -> bool:
	return hp <= 0

func sabotage_cannons(amount: int = 1) -> void:
	port_cannon_cd = mini(3, port_cannon_cd + amount)
	starboard_cannon_cd = mini(3, starboard_cannon_cd + amount)

func has_ready_cannon() -> bool:
	return port_cannon_cd <= 0 or starboard_cannon_cd <= 0

func get_ready_cannon_count() -> int:
	var count = 0
	if port_cannon_cd <= 0:
		count += 1
	if starboard_cannon_cd <= 0:
		count += 1
	return count

func consume_one_cannon() -> CombatResolver.Action:
	# Puts one ready cannon on cooldown (prefer port, then starboard)
	if port_cannon_cd <= 0:
		port_cannon_cd = (port_cooldown_turns + 1) if port_cooldown_turns > 0 else 0
		return CombatResolver.Action.CANNON_PORT
	elif starboard_cannon_cd <= 0:
		starboard_cannon_cd = (starboard_cooldown_turns + 1) if starboard_cooldown_turns > 0 else 0
		return CombatResolver.Action.CANNON_STARBOARD
	return CombatResolver.Action.NONE
