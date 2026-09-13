extends Node3D
## Composition root: input makes actions, session owns commits, view consumes
## committed states. Explicit dependency injection is reserved for test launchers.
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const KeyBuilder = preload("res://foundation/contracts/state_key.gd")
const Mapper = preload("res://foundation/runtime/input_mapper.gd")
const Session = preload("res://foundation/runtime/runtime_session.gd")
const Presenter = preload("res://foundation/runtime/prototype_presenter.gd")
const Fixture = preload("res://prototype/foundation/runtime/runtime_fixture.gd")
var session_override: RefCounted
var backend_label := "REAL BAKER → VALIDATOR → KERNEL → SAFETY"
var session: RefCounted
var presenter: Node3D
var camera: Camera3D
var reset_button: Button
var rotate_target := Types.WorldLayer.SURFACE
var loaded := false
var transition_seconds := 0.25
var action_log: Array[Dictionary] = []
var _status: Label
var _state_text: Label
var _target: Label
var _progress: ProgressBar
var _tweens: Array[Tween] = []

func _ready() -> void:
	_build_view()
	session = session_override if session_override != null else Session.new()
	session.committed.connect(_on_committed)
	session.feedback.connect(_on_feedback)
	session.transition_started.connect(_on_transition)
	var baked := Fixture.bake()
	var result: Dictionary = session.load_level(baked.level) if baked.ok else baked
	loaded = result.ok
	if loaded:
		_status.text = "Ready. Demo route: D → Q → Space. R restores the initial state."
	else:
		_status.text = "Level unavailable: " + str(result.issues)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_R:
		_reset()
		return
	if code == KEY_TAB:
		_select_target()
		return
	if not loaded:
		return
	var directions := {KEY_W: Vector2.UP, KEY_UP: Vector2.UP, KEY_S: Vector2.DOWN,
		KEY_DOWN: Vector2.DOWN, KEY_A: Vector2.LEFT, KEY_LEFT: Vector2.LEFT,
		KEY_D: Vector2.RIGHT, KEY_RIGHT: Vector2.RIGHT}
	if directions.has(code):
		_accept_mapping(Mapper.map_move(presenter.frame, camera.global_basis, directions[code]))
	elif code == KEY_SPACE:
		_submit(Records.make_action(Types.PuzzleActionKind.SHIFT_WORLD, {}))
	elif code == KEY_Q or code == KEY_E:
		_rotate(Types.RotationIntent.TURN_LEFT if code == KEY_Q else Types.RotationIntent.TURN_RIGHT)

func _accept_mapping(result: Dictionary) -> void:
	if result.ok:
		_submit(result.action)
	else:
		_status.text = "Input cannot resolve an allowed axis: " + str(result.issues)

func _rotate(intent: int) -> void:
	if not loaded:
		return
	for world in session.level.worlds:
		if world.layer == rotate_target:
			_accept_mapping(Mapper.map_rotation(intent, camera.global_basis, world))
			return

func _submit(action: Dictionary) -> void:
	action_log.append(action.duplicate(true))
	session.request_action(action)

func _select_target() -> void:
	rotate_target = 1 - rotate_target
	_target.text = "RotateTarget: " + ("SURFACE" if rotate_target == 0 else "INNER") + " (Tab)"

func _reset() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	presenter.clear_previews()
	_progress.value = 0
	presenter.transition_progress = 0.0
	if loaded:
		session.reset()
		_status.text = "Reset: initial state restored; stale callbacks cancelled."

func _on_committed(state: Dictionary) -> void:
	var result: Dictionary = presenter.sync_state(session.level, state)
	if not result.ok:
		_status.text = "Visual sync failed: " + str(result.issues)
		return
	var location: Dictionary = state.player.location
	_state_text.text = "%s / %s / pose %d    •    World [%d, %d]    •    Slot %s\n%s" % [
		"Surface" if location.layer == 0 else "Inner", location.cube_id, state.player.orientation,
		state.world_orientations[0], state.world_orientations[1], state.celestial.slot_id,
		KeyBuilder.build(session.level, state).key]

func _on_feedback(result: Dictionary) -> void:
	# Frozen wire statuses are display labels, never an alternative rule decision.
	if result.status == 1:
		var reasons := {1400: "No matching face", 1403: "Source face requires Shadow",
			1404: "Shift exit is blocked", 1405: "Shift entry is blocked",
			1500: "A transition is still active", 1502: "Action is unavailable in this backend",
			1503: "Mechanism is not authorized", 1504: "Concurrent movement is not proven",
			2000: "Movement is blocked", 2001: "Rotation is not allowed",
			2002: "Rotation destination is unsafe", 2003: "Face transition is unavailable"}
		_status.text = "REJECTED %d — %s; state unchanged" % [result.rejection_code,
			reasons.get(result.rejection_code, "Backend rejected this action")]
	elif result.status == 2:
		_status.text = "ERROR — state unchanged: " + str(result.issues)
	else:
		_status.text = "APPLIED — complete state authorized by backend"

func _on_transition(result: Dictionary, id: int, generation: int, is_global: bool) -> void:
	# The preview uses result records, never visual transforms as rule input.
	_tweens = _tweens.filter(func(active: Tween) -> bool: return active.is_valid() and active.is_running())
	var preview: Dictionary = presenter.animate_transition(session.level, result, transition_seconds)
	if preview.ok:
		_tweens.append(preview.tween)
	var tween := create_tween()
	_tweens.append(tween)
	tween.tween_method(func(value: float) -> void:
		presenter.transition_progress = value
		_progress.value = value * 100.0, 0.0, 1.0, transition_seconds)
	tween.tween_callback(func() -> void:
		if is_global:
			session.finish_global(id, generation)
		else:
			session.finish_local(id, generation)
		if preview.ok and is_instance_valid(preview.preview):
			preview.preview.queue_free()
		_progress.value = 0
		presenter.transition_progress = 0.0)

func _build_view() -> void:
	get_window().size = Vector2i(1200, 760)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("111a2b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d4e1fc")
	env.environment.ambient_light_energy = 0.75
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.light_energy = 1.1
	add_child(light)
	camera = Camera3D.new()
	# Identity observation basis is explicitly discrete; off-axis perspective
	# position exposes cube sides without inventing an input rotation basis.
	camera.position = Vector3(0,-0.2,10)
	camera.fov = 52
	camera.current = true
	add_child(camera)
	presenter = Presenter.new()
	add_child(presenter)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "BLOCK GIRL  /  FOUNDATION RUNTIME"
	title.add_theme_font_size_override("font_size", 27)
	column.add_child(title)
	var backend := Label.new()
	backend.text = backend_label
	backend.add_theme_color_override("font_color", Color("efbc75"))
	column.add_child(backend)
	var flow := Label.new()
	flow.text = "Input → PuzzleAction → Kernel contract → TransitionResult → PuzzleState → Visual sync"
	flow.add_theme_font_size_override("font_size", 16)
	column.add_child(flow)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var layers := Label.new()
	layers.text = "SURFACE                                       INNER"
	layers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layers.add_theme_font_size_override("font_size", 20)
	column.add_child(layers)
	_target = Label.new()
	_target.text = "RotateTarget: SURFACE (Tab)"
	column.add_child(_target)
	_state_text = Label.new()
	_state_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state_text.add_theme_font_size_override("font_size", 14)
	column.add_child(_state_text)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("c5d5ef"))
	column.add_child(_status)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 5
	column.add_child(_progress)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	for caption in ["Reset · R", "Rotate · Q", "Target · Tab"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(160,40)
		button.focus_mode = Control.FOCUS_NONE
		row.add_child(button)
		if caption.begins_with("Reset"):
			reset_button = button
			button.pressed.connect(_reset)
		elif caption.begins_with("Rotate"):
			button.pressed.connect(func() -> void: _rotate(Types.RotationIntent.TURN_LEFT))
		else:
			button.pressed.connect(_select_target)
	var help := Label.new()
	help.text = "WASD / arrows: move  •  Space: Shift  •  Q/E: rotate  •  Tab: target  •  R: reset\nIndependent technical fixture. Layer spacing is display-only. Visual lights do not grant Shift permission."
	help.add_theme_font_size_override("font_size", 14)
	column.add_child(help)
