extends Node
## Input adapter; Movement/Perspective remain the only action lock authorities.
signal reset_requested
signal debug_requested
signal shift_rejected
var mover
var view
var drag_origin:=Vector2.ZERO
func bind(player,perspective) -> void:
	mover=player
	view=perspective
func rotate(left: bool) -> void:
	if mover.phase!="idle" or view.busy: return
	if left: view.request_rotate_left()
	else: view.request_rotate_right()
func _input(event: InputEvent) -> void:
	if not mover: return
	if event is InputEventKey:
		if event.echo: return
		var supported: Array=[KEY_W,KEY_D,KEY_S,KEY_A,KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT,KEY_Q,KEY_E,KEY_SPACE,KEY_R,KEY_F3]
		var key: int=event.physical_keycode if event.physical_keycode in supported else event.keycode
		var directions: Dictionary={KEY_W:0,KEY_UP:0,KEY_D:1,KEY_RIGHT:1,KEY_S:2,KEY_DOWN:2,KEY_A:3,KEY_LEFT:3}
		if directions.has(key):
			if event.pressed: mover.press(key,directions[key])
			else: mover.release(key)
		elif event.pressed:
			match key:
				KEY_Q: rotate(true)
				KEY_E: rotate(false)
				KEY_SPACE:
					if mover.phase=="idle" and not view.busy and not mover.shift(): shift_rejected.emit()
				KEY_R: reset_requested.emit()
				KEY_F3: debug_requested.emit()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if mover.phase=="idle" and view.begin_drag(): drag_origin=event.position
		elif view.dragging: view.end_drag(event.position-drag_origin)
	elif event is InputEventMouseMotion and view.dragging:
		view.preview_drag(event.position-drag_origin)
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and mover:
		mover.clear_held()
		if view.dragging: view.end_drag(Vector2.ZERO)
