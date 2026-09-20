extends Control

const CombatResolver = preload("res://scripts/combat_resolver.gd")
const ShipState = preload("res://scripts/ship_state.gd")
const SwipeDetector = preload("res://scripts/swipe_detector.gd")

# State Machine
enum State { PLAYER_TURN, RESOLVING, GAME_OVER }

var current_state: State = State.PLAYER_TURN
var round_number: int = 1

var player_ship
var enemy_ship

# Node references (connected in scene)
@onready var swipe_detector = $SwipeDetector
@onready var enemy_hp_bar: ProgressBar = %EnemyHPBar
@onready var enemy_hp_label: Label = %EnemyHPLabel
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_label: Label = %PlayerHPLabel

@onready var btn_sail: Button = %BtnSail
@onready var btn_port: Button = %BtnPort
@onready var btn_starboard: Button = %BtnStarboard
@onready var btn_board: Button = %BtnBoard

@onready var player_port_cd_label: Label = %PlayerPortCD
@onready var player_starboard_cd_label: Label = %PlayerStarboardCD
@onready var enemy_port_cd_label: Label = %EnemyPortCD
@onready var enemy_starboard_cd_label: Label = %EnemyStarboardCD

@onready var combat_log: RichTextLabel = %CombatLog
@onready var round_info_label: Label = %RoundInfoLabel
@onready var player_ship_visual: Control = %PlayerShipVisual
@onready var enemy_ship_visual: Control = %EnemyShipVisual
@onready var status_banner: Label = %StatusBanner
@onready var btn_restart: Button = %BtnRestart

func _ready() -> void:
	player_ship = ShipState.new("The Sea Skimmer", 50)
	enemy_ship = ShipState.new("Scurvy Sloop", 50)
	
	# Connect signals
	swipe_detector.action_swiped.connect(_on_action_input)
	btn_sail.pressed.connect(func(): _on_action_input(CombatResolver.Action.SAIL))
	btn_port.pressed.connect(func(): _on_action_input(CombatResolver.Action.CANNON_PORT))
	btn_starboard.pressed.connect(func(): _on_action_input(CombatResolver.Action.CANNON_STARBOARD))
	btn_board.pressed.connect(func(): _on_action_input(CombatResolver.Action.BOARD))
	btn_restart.pressed.connect(start_new_battle)
	
	_start_ship_bobbing()
	start_new_battle()

func start_new_battle() -> void:
	round_number = 1
	player_ship.reset()
	enemy_ship.reset()
	current_state = State.PLAYER_TURN
	btn_restart.hide()
	status_banner.text = "Swipe or Tap an Action!"
	combat_log.clear()
	_log_message("[color=#62b6cb]★ Battle Commenced! Prepare for ship-to-ship combat! ★[/color]")
	_update_ui()

func _start_ship_bobbing() -> void:
	# Bouncy cute wave bobbing
	var t1 = create_tween().set_loops()
	t1.tween_property(player_ship_visual, "position:y", player_ship_visual.position.y - 8.0, 1.2).set_trans(Tween.TRANS_SINE)
	t1.tween_property(player_ship_visual, "position:y", player_ship_visual.position.y + 8.0, 1.2).set_trans(Tween.TRANS_SINE)

	var t2 = create_tween().set_loops()
	t2.tween_property(enemy_ship_visual, "position:y", enemy_ship_visual.position.y + 6.0, 1.5).set_trans(Tween.TRANS_SINE)
	t2.tween_property(enemy_ship_visual, "position:y", enemy_ship_visual.position.y - 6.0, 1.5).set_trans(Tween.TRANS_SINE)

func _on_action_input(action: CombatResolver.Action) -> void:
	if current_state != State.PLAYER_TURN:
		return
	
	if not player_ship.is_action_available(action):
		var act_name = CombatResolver.get_action_name(action)
		_flash_status("%s is reloading!" % act_name, Color(1.0, 0.4, 0.4))
		return
	
	_execute_round(action)

func _execute_round(player_action: CombatResolver.Action) -> void:
	current_state = State.RESOLVING
	_set_buttons_enabled(false)
	
	# Choose Enemy AI Action
	var enemy_action = _choose_enemy_action()
	
	# Mark action cooldowns
	player_ship.use_action(player_action)
	enemy_ship.use_action(enemy_action)
	
	# Resolve combat
	var result = CombatResolver.resolve_turn(player_action, enemy_action)
	
	# Apply damage
	player_ship.take_damage(result.player_damage)
	enemy_ship.take_damage(result.enemy_damage)
	
	# Visual animations
	_animate_combat(player_action, enemy_action, result)

func _choose_enemy_action() -> CombatResolver.Action:
	var valid_actions: Array[CombatResolver.Action] = []
	if enemy_ship.is_action_available(CombatResolver.Action.CANNON_PORT):
		valid_actions.append(CombatResolver.Action.CANNON_PORT)
	if enemy_ship.is_action_available(CombatResolver.Action.CANNON_STARBOARD):
		valid_actions.append(CombatResolver.Action.CANNON_STARBOARD)
	valid_actions.append(CombatResolver.Action.SAIL)
	valid_actions.append(CombatResolver.Action.BOARD)
	
	return valid_actions.pick_random()

func _animate_combat(p_act: CombatResolver.Action, e_act: CombatResolver.Action, result: CombatResolver.CombatResult) -> void:
	var tween = create_tween().set_parallel(false)
	
	# Step 1: Lurch forward / attack surge
	var orig_p_pos = player_ship_visual.position
	var orig_e_pos = enemy_ship_visual.position
	
	tween.tween_property(player_ship_visual, "position:y", orig_p_pos.y - 15.0, 0.2)
	tween.parallel().tween_property(enemy_ship_visual, "position:y", orig_e_pos.y + 15.0, 0.2)
	
	# Step 2: Impact shake if damage taken
	if result.player_damage > 0 or result.enemy_damage > 0:
		tween.tween_callback(func():
			if result.enemy_damage > 0:
				_shake_node(enemy_ship_visual)
			if result.player_damage > 0:
				_shake_node(player_ship_visual)
		)
	
	tween.tween_interval(0.3)
	tween.tween_property(player_ship_visual, "position", orig_p_pos, 0.2)
	tween.parallel().tween_property(enemy_ship_visual, "position", orig_e_pos, 0.2)
	
	tween.tween_callback(func(): _finish_round(p_act, e_act, result))

func _shake_node(node: Control) -> void:
	var shake_tween = create_tween()
	var base_x = node.position.x
	shake_tween.tween_property(node, "position:x", base_x + 8.0, 0.05)
	shake_tween.tween_property(node, "position:x", base_x - 8.0, 0.05)
	shake_tween.tween_property(node, "position:x", base_x + 4.0, 0.05)
	shake_tween.tween_property(node, "position:x", base_x, 0.05)

func _finish_round(p_act: CombatResolver.Action, e_act: CombatResolver.Action, result: CombatResolver.CombatResult) -> void:
	# Log details
	_log_message("[b]Round %d:[/b] You: [color=#b5e48c]%s[/color] vs Enemy: [color=#f3c68f]%s[/color]" % [
		round_number, result.player_action_name, result.enemy_action_name
	])
	_log_message("» %s" % result.outcome_summary)
	
	# Tick cooldowns for next turn
	player_ship.tick_cooldowns()
	enemy_ship.tick_cooldowns()
	
	_update_ui()
	
	# Check Win / Loss
	if player_ship.is_dead() and enemy_ship.is_dead():
		_game_over("MUTUAL SINKING!", "Both vessels met Davy Jones!", Color(1.0, 0.7, 0.2))
	elif enemy_ship.is_dead():
		_game_over("VICTORY!", "Enemy ship sent to the ocean floor!", Color(0.3, 0.9, 0.4))
	elif player_ship.is_dead():
		_game_over("DEFEAT!", "Your ship has sunk! Arrr!", Color(0.9, 0.3, 0.3))
	else:
		round_number += 1
		current_state = State.PLAYER_TURN
		_set_buttons_enabled(true)
		status_banner.text = "Choose your next move!"

func _game_over(title: String, subtitle: String, color: Color) -> void:
	current_state = State.GAME_OVER
	status_banner.text = "%s - %s" % [title, subtitle]
	status_banner.modulate = color
	_log_message("[color=%s][b]*** %s ***[/b][/color]" % [color.to_html(), title])
	btn_restart.show()
	_set_buttons_enabled(false)

func _set_buttons_enabled(enabled: bool) -> void:
	btn_sail.disabled = not enabled or not player_ship.is_action_available(CombatResolver.Action.SAIL)
	btn_port.disabled = not enabled or not player_ship.is_action_available(CombatResolver.Action.CANNON_PORT)
	btn_starboard.disabled = not enabled or not player_ship.is_action_available(CombatResolver.Action.CANNON_STARBOARD)
	btn_board.disabled = not enabled or not player_ship.is_action_available(CombatResolver.Action.BOARD)

func _update_ui() -> void:
	# Round Header
	round_info_label.text = "ROUND %d" % round_number
	
	# Health Bars
	player_hp_bar.value = player_ship.hp
	player_hp_label.text = "%d / %d HP" % [player_ship.hp, ShipState.MAX_HP]
	
	enemy_hp_bar.value = enemy_ship.hp
	enemy_hp_label.text = "%d / %d HP" % [enemy_ship.hp, ShipState.MAX_HP]
	
	# Cooldown Badges
	player_port_cd_label.text = "Port: " + _cd_str(player_ship.port_cannon_cd)
	player_starboard_cd_label.text = "Starboard: " + _cd_str(player_ship.starboard_cannon_cd)
	
	enemy_port_cd_label.text = "Port: " + _cd_str(enemy_ship.port_cannon_cd)
	enemy_starboard_cd_label.text = "Starboard: " + _cd_str(enemy_ship.starboard_cannon_cd)
	
	_set_buttons_enabled(current_state == State.PLAYER_TURN)

func _cd_str(cd: int) -> String:
	if cd <= 0:
		return "[READY]"
	return "[RELOAD: %d]" % cd

func _flash_status(msg: String, color: Color) -> void:
	status_banner.text = msg
	status_banner.modulate = color
	var t = create_tween()
	t.tween_property(status_banner, "modulate", Color.WHITE, 1.0)

func _log_message(bbcode: String) -> void:
	combat_log.append_text(bbcode + "\n")
