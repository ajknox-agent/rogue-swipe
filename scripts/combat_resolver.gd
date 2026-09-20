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
const SAIL_RAM_DAMAGE: int = 15          # Defensive broadside damage against boarding attempt
const BOARD_CRIT_DAMAGE: int = 25        # High-risk devastating ambush against reloading cannons
const BOARD_CLASH_DAMAGE: int = 10       # Melee clash when both board
const GRAPESHOT_REPEL_DAMAGE: int = 20   # Grapeshot devastation against unsuppressed boarders

class CombatResult:
	var player_damage: int = 0
	var enemy_damage: int = 0
	var player_cannons_sabotaged: bool = false
	var enemy_cannons_sabotaged: bool = false
	var player_consumed_defensive_cannon: bool = false
	var enemy_consumed_defensive_cannon: bool = false
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

static func resolve_turn(
	player_act: Action,
	enemy_act: Action,
	player_has_cannon: bool = true,
	enemy_has_cannon: bool = true,
	config: RefCounted = null
) -> CombatResult:
	var res = CombatResult.new()
	res.player_action_name = get_action_name(player_act)
	res.enemy_action_name = get_action_name(enemy_act)
	
	# Resolve damage constants dynamically from config or defaults
	var c_dmg = config.cannon_damage if config and "cannon_damage" in config else CANNON_DAMAGE
	var c_v_s_dmg = config.cannon_vs_sail_damage if config and "cannon_vs_sail_damage" in config else CANNON_VS_SAIL_DAMAGE
	var s_ram_dmg = config.sail_ram_damage if config and "sail_ram_damage" in config else SAIL_RAM_DAMAGE
	var b_crit_dmg = config.board_crit_damage if config and "board_crit_damage" in config else BOARD_CRIT_DAMAGE
	var b_clash_dmg = config.board_clash_damage if config and "board_clash_damage" in config else BOARD_CLASH_DAMAGE
	var grape_dmg = config.grapeshot_repel_damage if config and "grapeshot_repel_damage" in config else GRAPESHOT_REPEL_DAMAGE
	var penalize_unsuppressed = config.unsuppressed_board_penalized if config and "unsuppressed_board_penalized" in config else true
	var sail_consumes = config.sail_consumes_cannon if config and "sail_consumes_cannon" in config else true
	
	var p_cannon = is_cannon(player_act)
	var e_cannon = is_cannon(enemy_act)
	
	# Case 1: Cannon vs Cannon
	if p_cannon and e_cannon:
		res.player_damage = c_dmg
		res.enemy_damage = c_dmg
		res.outcome_summary = "Broadside Duel! Both ships exchange full cannon fire! (-%d HP each)" % c_dmg
		res.advantage = "DRAW"
		
	# Case 2: Cannon vs Sail
	elif p_cannon and enemy_act == Action.SAIL:
		res.player_damage = 0
		res.enemy_damage = c_v_s_dmg
		res.outcome_summary = "Enemy sails evasively! Cannon deals glancing hit for -%d HP." % c_v_s_dmg
		res.advantage = "PLAYER"
		
	elif player_act == Action.SAIL and e_cannon:
		res.player_damage = c_v_s_dmg
		res.enemy_damage = 0
		res.outcome_summary = "You sail evasively! Mitigated enemy cannon blast to -%d HP." % c_v_s_dmg
		res.advantage = "ENEMY"

	# Case 3: Cannon vs Board
	elif p_cannon and enemy_act == Action.BOARD:
		if enemy_has_cannon or not penalize_unsuppressed:
			# Suppressed boarding: Boarder has covering fire, inflicts crit damage & sabotage
			res.player_damage = b_crit_dmg
			res.enemy_damage = c_dmg
			res.player_cannons_sabotaged = true
			res.outcome_summary = "Brutal Clash! Cannon fired (-%d HP), but enemy crew stormed your deck (-%d HP) and SABOTAGED your cannons (+1 Reload)!" % [c_dmg, b_crit_dmg]
			res.advantage = "ENEMY"
		else:
			# Unsuppressed boarding: Enemy has NO ready cannons! Point-blank grapeshot wipes them out!
			res.player_damage = 0
			res.enemy_damage = grape_dmg
			res.player_cannons_sabotaged = false
			res.outcome_summary = "💥 Grapeshot Defense! Enemy boarded without covering fire! Your point-blank broadside shredded their boarding party! (-%d HP to Enemy, 0 to You)" % grape_dmg
			res.advantage = "PLAYER"

	elif player_act == Action.BOARD and e_cannon:
		if player_has_cannon or not penalize_unsuppressed:
			# Suppressed boarding: Player has covering fire, inflicts crit damage & sabotage
			res.player_damage = c_dmg
			res.enemy_damage = b_crit_dmg
			res.enemy_cannons_sabotaged = true
			res.outcome_summary = "Point-Blank Ambush! You braved cannon fire (-%d HP) to storm their decks (-%d HP) and SABOTAGED their cannons (+1 Reload)!" % [c_dmg, b_crit_dmg]
			res.advantage = "PLAYER"
		else:
			# Unsuppressed boarding: Player has NO ready cannons! Repelled with heavy damage!
			res.player_damage = grape_dmg
			res.enemy_damage = 0
			res.enemy_cannons_sabotaged = false
			res.outcome_summary = "☠️ Repelled by Grapeshot! Boarding with no ready cannons left you exposed! Enemy broadside wiped out your boarding party! (-%d HP to You, 0 to Enemy)" % grape_dmg
			res.advantage = "ENEMY"

	# Case 4: Sail vs Sail
	elif player_act == Action.SAIL and enemy_act == Action.SAIL:
		res.player_damage = 0
		res.enemy_damage = 0
		res.outcome_summary = "Both ships maneuver and circle gracefully. Stalemate! (0 damage)"
		res.advantage = "DRAW"

	# Case 5: Sail vs Board
	elif player_act == Action.SAIL and enemy_act == Action.BOARD:
		if player_has_cannon or not sail_consumes:
			# Evade AND fire defensive broadside (consumes 1 cannon if enabled)
			res.player_damage = 0
			res.enemy_damage = s_ram_dmg
			res.player_consumed_defensive_cannon = sail_consumes
			res.outcome_summary = "💥 Defensive Broadside! You evaded their grapple and blasted their boarding party with a ready cannon! (-%d HP to Enemy, 1 Cannon Reloading)" % s_ram_dmg
			res.advantage = "PLAYER"
		else:
			# Disarmed: Evade only, cannot return fire!
			res.player_damage = 0
			res.enemy_damage = 0
			res.player_consumed_defensive_cannon = false
			res.outcome_summary = "💨 Evasive Maneuver! You slipped past their grapple, but had no loaded cannons to return fire! (0 damage)"
			res.advantage = "DRAW"

	elif player_act == Action.BOARD and enemy_act == Action.SAIL:
		if enemy_has_cannon or not sail_consumes:
			# Enemy evades and fires defensive broadside into player
			res.player_damage = s_ram_dmg
			res.enemy_damage = 0
			res.enemy_consumed_defensive_cannon = sail_consumes
			res.outcome_summary = "⚡ Outmaneuvered! Enemy dodged your grapple and raked your deck with a defensive broadside! (-%d HP to You, Enemy spent a Cannon)" % s_ram_dmg
			res.advantage = "ENEMY"
		else:
			# Enemy disarmed: Evades only
			res.player_damage = 0
			res.enemy_damage = 0
			res.enemy_consumed_defensive_cannon = false
			res.outcome_summary = "💨 Grapple Evaded! Enemy slipped away, but had no loaded cannons to fire back! (0 damage)"
			res.advantage = "DRAW"

	# Case 6: Board vs Board
	elif player_act == Action.BOARD and enemy_act == Action.BOARD:
		res.player_damage = b_clash_dmg
		res.enemy_damage = b_clash_dmg
		res.outcome_summary = "Cutlass Clash! Both crews clash mid-deck with blades swinging! (-%d HP each)" % b_clash_dmg
		res.advantage = "DRAW"

	return res
