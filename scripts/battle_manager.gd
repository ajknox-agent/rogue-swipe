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
@onready var game_over_overlay: Control = %GameOverOverlay
@onready var game_over_title: Label = %GameOverTitle
@onready var game_over_subtitle: Label = %GameOverSubtitle

@onready var edge_hint_top: Button = %EdgeHintTop
@onready var edge_hint_left: Button = %EdgeHintLeft
@onready var edge_hint_right: Button = %EdgeHintRight
@onready var edge_hint_bottom: Button = %EdgeHintBottom

func _ready() -> void:
	player_ship = ShipState.new("The Sea Skimmer", 50)
	enemy_ship = ShipState.new("Scurvy Sloop", 50)
	
	# Connect signals
	swipe_detector.action_swiped.connect(_on_action_input)
	btn_sail.pressed.connect(func(): _on_action_input(CombatResolver.Action.SAIL))
	btn_port.pressed.connect(func(): _on_action_input(CombatResolver.Action.CANNON_PORT))
	btn_starboard.pressed.connect(func(): _on_action_input(CombatResolver.Action.CANNON_STARBOARD))
	btn_board.pressed.connect(func(): _on_action_input(CombatResolver.Action.BOARD))
	
	edge_hint_top.pressed.connect(func(): _on_action_input(CombatResolver.Action.SAIL))
	edge_hint_left.pressed.connect(func(): _on_action_input(CombatResolver.Action.CANNON_PORT))
	edge_hint_right.pressed.connect(func(): _on_action_input(CombatResolver.Action.CANNON_STARBOARD))
	edge_hint_bottom.pressed.connect(func(): _on_action_input(CombatResolver.Action.BOARD))
	
	btn_restart.pressed.connect(start_new_battle)
	game_over_overlay.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			start_new_battle()
	)
	
	_start_ship_bobbing()
	start_new_battle()

func start_new_battle() -> void:
	round_number = 1
	player_ship.reset()
	enemy_ship.reset()
	current_state = State.PLAYER_TURN
	game_over_overlay.hide()
	status_banner.text = "Swipe or Tap an Action!"
	combat_log.clear()
	_log_message("[color=#62b6cb]★ Battle Commenced! (v1.3: Sail vs Board uses Cannon; Disarmed Board repelled) ★[/color]")
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
	if current_state == State.GAME_OVER:
		start_new_battle()
		return
	
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
	
	# Check cannon readiness BEFORE moves consume/trigger reload
	var player_had_cannon = player_ship.has_ready_cannon()
	var enemy_had_cannon = enemy_ship.has_ready_cannon()
	
	# Mark action cooldowns
	player_ship.use_action(player_action)
	enemy_ship.use_action(enemy_action)
	
	# Resolve combat
	var result = CombatResolver.resolve_turn(player_action, enemy_action, player_had_cannon, enemy_had_cannon)
	
	# Defensive broadside cannon consumption
	if result.player_consumed_defensive_cannon:
		player_ship.consume_one_cannon()
	if result.enemy_consumed_defensive_cannon:
		enemy_ship.consume_one_cannon()
	
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
	
	# If player has burned both cannons, armed enemy prioritizes Cannon to punish them!
	if not player_ship.has_ready_cannon():
		var cannon_acts: Array[CombatResolver.Action] = []
		for a in valid_actions:
			if CombatResolver.is_cannon(a):
				cannon_acts.append(a)
		if not cannon_acts.is_empty() and randf() < 0.65:
			return cannon_acts.pick_random()
	
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
	
	# Apply Sabotage (+1 to opponent's cannon cooldowns)
	if result.enemy_cannons_sabotaged:
		enemy_ship.sabotage_cannons(1)
		_log_message("[color=#ffb703]⚡ Enemy Cannons Sabotaged! (+1 turn added to reload)[/color]")
	if result.player_cannons_sabotaged:
		player_ship.sabotage_cannons(1)
		_log_message("[color=#e63946]⚠️ Your Cannons Were Sabotaged! (+1 turn added to reload)[/color]")
	
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
	game_over_title.text = title
	game_over_title.modulate = color
	game_over_subtitle.text = subtitle
	game_over_overlay.show()
	_set_buttons_enabled(false)

func _unhandled_input(event: InputEvent) -> void:
	if current_state == State.GAME_OVER:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed):
			start_new_battle()
			get_viewport().set_input_as_handled()

func _set_buttons_enabled(enabled: bool) -> void:
	var can_sail = enabled and player_ship.is_action_available(CombatResolver.Action.SAIL)
	var can_port = enabled and player_ship.is_action_available(CombatResolver.Action.CANNON_PORT)
	var can_starboard = enabled and player_ship.is_action_available(CombatResolver.Action.CANNON_STARBOARD)
	var can_board = enabled and player_ship.is_action_available(CombatResolver.Action.BOARD)

	btn_sail.disabled = not can_sail
	btn_port.disabled = not can_port
	btn_starboard.disabled = not can_starboard
	btn_board.disabled = not can_board

	edge_hint_top.disabled = not can_sail
	edge_hint_left.disabled = not can_port
	edge_hint_right.disabled = not can_starboard
	edge_hint_bottom.disabled = not can_board

func _update_ui() -> void:
	var p_cannons_ready = player_ship.get_ready_cannon_count()
	
	# Round Header
	if p_cannons_ready == 0:
		round_info_label.text = "ROUND %d • ⚠️ ALL GUNS RELOADING (DISARMED)!" % round_number
	else:
		round_info_label.text = "ROUND %d • v1.3 (Defensive Cannons Active)" % round_number
	
	# Health Bars
	player_hp_bar.value = player_ship.hp
	player_hp_label.text = "%d / %d HP" % [player_ship.hp, ShipState.MAX_HP]
	
	enemy_hp_bar.value = enemy_ship.hp
	enemy_hp_label.text = "%d / %d HP" % [enemy_ship.hp, ShipState.MAX_HP]
	
	# Cooldown Badges
	player_port_cd_label.text = "Port: " + _cd_str(player_ship.port_cannon_cd)
	player_starboard_cd_label.text = "Starboard: " + _cd_str(player_ship.starboard_cannon_cd)
	
	if p_cannons_ready == 0:
		player_port_cd_label.modulate = Color(1.0, 0.4, 0.4)
		player_starboard_cd_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		player_port_cd_label.modulate = Color(0.85, 0.85, 0.85)
		player_starboard_cd_label.modulate = Color(0.85, 0.85, 0.85)
	
	enemy_port_cd_label.text = "Port: " + _cd_str(enemy_ship.port_cannon_cd)
	enemy_starboard_cd_label.text = "Starboard: " + _cd_str(enemy_ship.starboard_cannon_cd)
	
	# Button Text with Cooldown Indicator
	if player_ship.port_cannon_cd > 0:
		btn_port.text = "◄ PORT [%d]" % player_ship.port_cannon_cd
		edge_hint_left.text = "◄ PORT\n[%d]" % player_ship.port_cannon_cd
	else:
		btn_port.text = "◄ PORT CANNON"
		edge_hint_left.text = "◄ PORT\nCANNON"

	if player_ship.starboard_cannon_cd > 0:
		btn_starboard.text = "STARBOARD [%d] ►" % player_ship.starboard_cannon_cd
		edge_hint_right.text = "STARBOARD ►\n[%d]" % player_ship.starboard_cannon_cd
	else:
		btn_starboard.text = "STARBOARD CANNON ►"
		edge_hint_right.text = "STARBOARD ►\nCANNON"

	# Dynamic Sail / Board hints based on cannon readiness
	if p_cannons_ready == 0:
		btn_sail.text = "▲ SAIL (EVADE - 0 DMG) ▲"
		edge_hint_top.text = "▲ SWIPE UP: SAIL (EVADE) ▲"
		btn_board.text = "▼ BOARD (⚠️ NO COVER) ▼"
		edge_hint_bottom.text = "▼ SWIPE DOWN: BOARD (⚠️ NO COVER) ▼"
	else:
		btn_sail.text = "▲ SAIL (DEFENSIVE SHOT) ▲"
		edge_hint_top.text = "▲ SWIPE UP: SAIL ▲"
		btn_board.text = "▼ BOARD (GRAPPLE) ▼"
		edge_hint_bottom.text = "▼ SWIPE DOWN: BOARD ▼"

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
