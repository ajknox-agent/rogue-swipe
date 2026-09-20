extends Control

const CombatResolver = preload("res://scripts/combat_resolver.gd")

signal action_swiped(action: int)
signal swipe_started(start_pos: Vector2)
signal swipe_updated(current_pos: Vector2)
signal swipe_ended()

@export var min_swipe_distance: float = 40.0

var _touch_start: Vector2 = Vector2.ZERO
var _is_swiping: bool = false
var _start_time: float = 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed():
			_is_swiping = true
			_touch_start = event.position
			_start_time = Time.get_ticks_msec()
			swipe_started.emit(_touch_start)
		elif _is_swiping:
			_is_swiping = false
			_process_swipe(event.position)
			swipe_ended.emit()
			queue_redraw()
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and _is_swiping):
		swipe_updated.emit(event.position)
		queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_W or event.keycode == KEY_UP:
		action_swiped.emit(CombatResolver.Action.SAIL)
	elif event.keycode == KEY_A or event.keycode == KEY_LEFT:
		action_swiped.emit(CombatResolver.Action.CANNON_PORT)
	elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
		action_swiped.emit(CombatResolver.Action.CANNON_STARBOARD)
	elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
		action_swiped.emit(CombatResolver.Action.BOARD)

func _process_swipe(end_pos: Vector2) -> void:
	var delta = end_pos - _touch_start
	if delta.length() < min_swipe_distance:
		return
	
	var action = CombatResolver.Action.NONE
	if abs(delta.y) > abs(delta.x):
		if delta.y < 0:
			action = CombatResolver.Action.SAIL # UP
		else:
			action = CombatResolver.Action.BOARD # DOWN
	else:
		if delta.x < 0:
			action = CombatResolver.Action.CANNON_PORT # LEFT
		else:
			action = CombatResolver.Action.CANNON_STARBOARD # RIGHT
	
	if action != CombatResolver.Action.NONE:
		action_swiped.emit(action)
