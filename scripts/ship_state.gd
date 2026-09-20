extends RefCounted

const CombatResolver = preload("res://scripts/combat_resolver.gd")

const MAX_HP: int = 50
const CANNON_COOLDOWN_TURNS: int = 2 # 2 turns cooldown after use (meaning it takes 3 turns total to re-use)

var name: String = "Ship"
var hp: int = MAX_HP
var port_cannon_cd: int = 0
var starboard_cannon_cd: int = 0

func _init(p_name: String = "Ship", p_hp: int = MAX_HP) -> void:
	name = p_name
	hp = p_hp
	port_cannon_cd = 0
	starboard_cannon_cd = 0

func reset() -> void:
	hp = MAX_HP
	port_cannon_cd = 0
	starboard_cannon_cd = 0

func is_action_available(action: CombatResolver.Action) -> bool:
	match action:
		CombatResolver.Action.SAIL:
			return true
		CombatResolver.Action.BOARD:
			return true
		CombatResolver.Action.CANNON_PORT:
			return port_cannon_cd <= 0
		CombatResolver.Action.CANNON_STARBOARD:
			return starboard_cannon_cd <= 0
		_:
			return false

func use_action(action: CombatResolver.Action) -> void:
	match action:
		CombatResolver.Action.CANNON_PORT:
			port_cannon_cd = CANNON_COOLDOWN_TURNS + 1
		CombatResolver.Action.CANNON_STARBOARD:
			starboard_cannon_cd = CANNON_COOLDOWN_TURNS + 1

func tick_cooldowns() -> void:
	if port_cannon_cd > 0:
		port_cannon_cd -= 1
	if starboard_cannon_cd > 0:
		starboard_cannon_cd -= 1

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
		port_cannon_cd = CANNON_COOLDOWN_TURNS + 1
		return CombatResolver.Action.CANNON_PORT
	elif starboard_cannon_cd <= 0:
		starboard_cannon_cd = CANNON_COOLDOWN_TURNS + 1
		return CombatResolver.Action.CANNON_STARBOARD
	return CombatResolver.Action.NONE
