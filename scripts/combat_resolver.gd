class_name CombatResolver
extends RefCounted

enum Action {
	NONE,
	SAIL,
	CANNON_PORT,
	CANNON_STARBOARD,
	BOARD
}

# Base damage constants (balanced for 50 HP ships)
const CANNON_DAMAGE: int = 15
const CANNON_VS_SAIL_DAMAGE: int = 8      # Mitigated half-damage against evasive sails
const SAIL_RAM_DAMAGE: int = 15          # Ramming/kiting damage against boarding attempt
const BOARD_CRIT_DAMAGE: int = 25        # High-risk devastating ambush against reloading cannons
const BOARD_CLASH_DAMAGE: int = 10       # Melee clash when both board

class CombatResult:
	var player_damage: int = 0
	var enemy_damage: int = 0
	var player_action_name: String = ""
	var enemy_action_name: String = ""
	var outcome_summary: String = ""
	var advantage: String = "NEUTRAL" # "PLAYER", "ENEMY", "DRAW"

static func is_cannon(action: Action) -> bool:
	return action == Action.CANNON_PORT or action == Action.CANNON_STARBOARD

static func get_action_name(action: Action) -> String:
	match action:
		Action.SAIL:
			return "Sail (Maneuver)"
		Action.CANNON_PORT:
			return "Port Cannon (Left)"
		Action.CANNON_STARBOARD:
			return "Starboard Cannon (Right)"
		Action.BOARD:
			return "Board (Grapple)"
		_:
			return "Unknown"

static func resolve_turn(player_act: Action, enemy_act: Action) -> CombatResult:
	var res = CombatResult.new()
	res.player_action_name = get_action_name(player_act)
	res.enemy_action_name = get_action_name(enemy_act)
	
	var p_cannon = is_cannon(player_act)
	var e_cannon = is_cannon(enemy_act)
	
	# Case 1: Cannon vs Cannon
	if p_cannon and e_cannon:
		res.player_damage = CANNON_DAMAGE
		res.enemy_damage = CANNON_DAMAGE
		res.outcome_summary = "Broadside Duel! Both ships exchange full cannon fire! (-%d HP each)" % CANNON_DAMAGE
		res.advantage = "DRAW"
		
	# Case 2: Cannon vs Sail
	elif p_cannon and enemy_act == Action.SAIL:
		res.player_damage = 0
		res.enemy_damage = CANNON_VS_SAIL_DAMAGE
		res.outcome_summary = "Enemy sails evasively! Cannon deals glancing hit for -%d HP." % CANNON_VS_SAIL_DAMAGE
		res.advantage = "PLAYER"
		
	elif player_act == Action.SAIL and e_cannon:
		res.player_damage = CANNON_VS_SAIL_DAMAGE
		res.enemy_damage = 0
		res.outcome_summary = "You sail evasively! Mitigated enemy cannon blast to -%d HP." % CANNON_VS_SAIL_DAMAGE
		res.advantage = "ENEMY"

	# Case 3: Cannon vs Board (Cannon deals full blast, but Boarder storms aboard for higher crit damage)
	elif p_cannon and enemy_act == Action.BOARD:
		res.player_damage = BOARD_CRIT_DAMAGE
		res.enemy_damage = CANNON_DAMAGE
		res.outcome_summary = "Brutal Exchange! Cannon blasted boarders (-%d HP), but enemy crew stormed your deck (-%d HP)!" % [CANNON_DAMAGE, BOARD_CRIT_DAMAGE]
		res.advantage = "ENEMY"

	elif player_act == Action.BOARD and e_cannon:
		res.player_damage = CANNON_DAMAGE
		res.enemy_damage = BOARD_CRIT_DAMAGE
		res.outcome_summary = "Point-Blank Ambush! You braved cannon fire (-%d HP) to storm their decks for massive -%d HP!" % [CANNON_DAMAGE, BOARD_CRIT_DAMAGE]
		res.advantage = "PLAYER"

	# Case 4: Sail vs Sail
	elif player_act == Action.SAIL and enemy_act == Action.SAIL:
		res.player_damage = 0
		res.enemy_damage = 0
		res.outcome_summary = "Both ships maneuver and circle gracefully. Stalemate! (0 damage)"
		res.advantage = "DRAW"

	# Case 5: Sail vs Board (Sail maneuvers and out-kites/rams boarders)
	elif player_act == Action.SAIL and enemy_act == Action.BOARD:
		res.player_damage = 0
		res.enemy_damage = SAIL_RAM_DAMAGE
		res.outcome_summary = "Tactical Maneuver! You outsailed and rammed their boarding party! (-%d HP to Enemy)" % SAIL_RAM_DAMAGE
		res.advantage = "PLAYER"

	elif player_act == Action.BOARD and enemy_act == Action.SAIL:
		res.player_damage = SAIL_RAM_DAMAGE
		res.enemy_damage = 0
		res.outcome_summary = "Outmaneuvered! Enemy ship cut hard, cutting down your boarding grapples! (-%d HP)" % SAIL_RAM_DAMAGE
		res.advantage = "ENEMY"

	# Case 6: Board vs Board
	elif player_act == Action.BOARD and enemy_act == Action.BOARD:
		res.player_damage = BOARD_CLASH_DAMAGE
		res.enemy_damage = BOARD_CLASH_DAMAGE
		res.outcome_summary = "Cutlass Clash! Both crews clash mid-deck with blades swinging! (-%d HP each)" % BOARD_CLASH_DAMAGE
		res.advantage = "DRAW"

	return res
