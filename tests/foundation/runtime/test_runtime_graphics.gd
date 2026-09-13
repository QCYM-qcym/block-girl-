extends SceneTree
## Real RenderingDevice/window event tests; no OS keyboard claim.
const Key = preload("res://foundation/contracts/state_key.gd")
const Math = preload("res://foundation/orientation/discrete_orientation.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Fixture = preload("res://prototype/foundation/runtime/runtime_fixture.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Lighting = preload("res://foundation/celestial/logical_lighting.gd")
const Mapping = preload("res://foundation/spatial/mapping_query.gd")
var failures: Array[String] = []
var checks := 0
var evidence := "res://.godot/foundation-2d-evidence/graphics"
var states: Dictionary = {}
var scene: Node

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(DisplayServer.get_name() != "headless", "actual graphical display")
	for path in ["res://prototype/foundation/runtime/foundation_runtime.tscn",
		"res://tests/foundation/runtime/kernel_double.gd"]:
		if not ResourceLoader.exists(path):
			check(false, "runtime implementation exists: " + path)
			quit(1)
			return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			evidence = argument.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	var double: RefCounted = load("res://tests/foundation/runtime/kernel_double.gd").new()
	var port: RefCounted = load("res://foundation/runtime/kernel_port.gd").new(double, double, double)
	var session: RefCounted = load("res://foundation/runtime/runtime_session.gd").new(port, double)
	scene = load("res://prototype/foundation/runtime/foundation_runtime.tscn").instantiate()
	scene.session_override = session
	scene.transition_seconds = 0.5
	scene.backend_label = "TEST DOUBLE / fixed contract results; real Kernel + Safety not integrated"
	root.add_child(scene)
	if OS.get_cmdline_user_args().has("--interactive"):
		return
	await create_timer(0.4).timeout
	check(Data.validate_level_shape(scene.session.level).is_empty(), "technical fixture formal shape")
	check(scene.loaded, "scene initialized through session")
	var initial: String = key()
	await capture("initial")
	var visual_before: Transform3D = scene.presenter.player.transform
	await press(KEY_SPACE)
	check(key() == initial and scene.presenter.player.transform == visual_before, "rejected Shift leaves logic and visual untouched")
	check(scene.session.last_result.rejection_code == 1404, "kernel rejection displayed")
	check(scene.get("_status").text.contains("Shift exit is blocked"), "rejection includes readable reason")
	await capture("rejected_shift")
	await press(KEY_D, false)
	check(key() == initial, "MOVE waits for local visual completion")
	check(scene.presenter.previews.get_child_count() > 0, "authorized transition creates an interpolated visual preview")
	var ghost: Node3D = scene.presenter.previews.get_child(0).get_child(0)
	var ghost_before := ghost.transform
	await create_timer(0.05).timeout
	check(ghost.transform != ghost_before and key() == initial, "visual interpolation advances while logical state remains committed")
	await capture("move_preview")
	check(key() == initial, "preview screenshot precedes logical commit")
	await create_timer(0.65).timeout
	check(scene.session.state.player.location.cube_id == &"s1", "semantic MOVE reaches canned destination")
	check(scene.session.commit_count == 1, "MOVE commits exactly once")
	check_pose(12)
	await capture("move")
	await press(KEY_Q)
	check(scene.session.state.world_orientations == [22,0], "world rotation complete state")
	check_pose(15)
	await capture("world_rotate")
	# These are calls to the real first-wave owners, confined to test evidence.
	# They establish the fixture's Shadow/mapping data, not motion Safety proof.
	var snapshot := Geometry.snapshot(scene.session.level, scene.session.state)
	var faces: Array[Dictionary] = []
	faces.assign(scene.session.level.faces)
	var compatibilities: Array[int] = [0]
	var mapping := Mapping.resolve_mapping(Mapping.collect_mapping_candidates(snapshot, faces, &"s1/TOP", 1, compatibilities))
	check(mapping.status == 1 and mapping.mapping.target_face == &"i1/TOP", "formal Mapping confirms unique fixture overlap")
	for anchor in snapshot.value.anchors:
		if anchor.face_id == &"s1/TOP":
			var lighting := Lighting.query(anchor, scene.session.level.celestial.slots[0], snapshot.value.cubes)
			check(lighting.ok and lighting.light_state == 1, "formal Lighting confirms fixture source is SHADOW")
	await press(KEY_SPACE)
	check(scene.session.state.player.location.layer == 1, "Shift reaches Inner from fixed Shadow fixture")
	check_pose(15)
	check(scene.session.commit_count == 3, "three atomic route commits")
	await capture("shadow_shift")
	var stable := key()
	await press(KEY_TAB)
	check(scene.rotate_target == 1 and key() == stable, "RotateTarget UI does not change state")
	scene.camera.size += 0.25
	check(key() == stable, "camera does not change state")
	var presentation: Transform3D = scene.presenter.player.transform
	var replay: Dictionary = scene.presenter.sync_state(scene.session.level, scene.session.state)
	check(replay.ok and scene.presenter.player.transform == presentation, "same committed result sync is deterministic")
	# Mouse reset exercises the actual Control input path, not its callback directly.
	var point: Vector2 = scene.reset_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	# Viewport-local coordinates avoid hidden-window desktop cursor transforms.
	root.push_input(motion, true)
	await process_frame
	var mouse := InputEventMouseButton.new()
	mouse.position = point
	mouse.global_position = point
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	mouse.pressed = true
	root.push_input(mouse, true)
	await process_frame
	mouse = mouse.duplicate()
	mouse.pressed = false
	mouse.button_mask = 0
	root.push_input(mouse, true)
	await create_timer(0.1).timeout
	check(key() == initial, "mouse Reset restores initial state")
	await capture("reset")
	var error_result: Dictionary = double.error(scene.session.state, {"kind": 0, "face_axis": 0})
	error_result.issues[0].code = 1105
	double.override_result = error_result
	visual_before = scene.presenter.player.transform
	var before_syncs: int = scene.presenter.sync_count
	await press(KEY_D)
	check(key() == initial and scene.presenter.player.transform == visual_before and scene.presenter.sync_count == before_syncs, "ERROR 1105 performs no partial logical or visual sync")
	check(scene.session.last_result.issues[0].code == 1105, "Arithmetic overflow diagnostic preserved")
	await capture("error")
	# Renderer can be replayed with every formal discrete pose, independently of
	# rule authorization. These view-only probes never mutate session.state.
	for pose in range(24):
		var view_state: Dictionary = scene.session.state.duplicate(true)
		view_state.player.orientation = pose
		check(scene.presenter.sync_state(scene.session.level, view_state).ok, "pose view probe accepted")
		check_pose(pose)
	var invalid: Dictionary = scene.session.state.duplicate(true)
	invalid.player.orientation = 24
	visual_before = scene.presenter.player.transform
	check(not scene.presenter.sync_state(scene.session.level, invalid).ok and scene.presenter.player.transform == visual_before, "invalid view input is atomic")
	scene.presenter.sync_state(scene.session.level, scene.session.state)
	await press(KEY_D, false)
	await press(KEY_R)
	check(key() == initial, "keyboard Reset restores initial state")
	check(scene.presenter.previews.get_child_count() == 0 and scene.session.commit_count == 0, "Reset cancels active preview and stale callback")
	# Compare graphics commits against direct contract evaluation, not presenter
	# transforms or a second serialization implementation.
	var replay_backend: RefCounted = double.get_script().new()
	var replay_state: Dictionary = replay_backend.route_states(scene.session.level)[0]
	var route := [[{"kind":0,"face_axis":0}, "move"], [{"kind":2,"rotation_delta":22}, "world_rotate"], [{"kind":1}, "shadow_shift"]]
	for step in route:
		var transition: Dictionary = replay_backend.evaluate_action(scene.session.level, replay_state, step[0], replay_backend.idle_context())
		check(transition.status == 0, "pure double route is applied")
		replay_state = transition.next_state
		check(Key.build(scene.session.level, replay_state).key == states[step[1]], "graphics / pure double complete StateKey parity: " + step[1])
	var inputs: Array = []
	for call in double.calls:
		if call.method == "evaluate_action":
			inputs.append(call.action)
	check(inputs[0] == {"kind":1} and inputs[1] == {"kind":0,"face_axis":0} and inputs[2] == {"kind":2,"rotation_delta":22}, "actual keyboard events arrive at Kernel as semantic actions")
	# Production source ownership guard: no test backend or rule query imports in scene/session.
	for path in ["foundation/runtime/kernel_port.gd", "foundation/runtime/runtime_session.gd",
		"foundation/runtime/prototype_presenter.gd", "prototype/foundation/runtime/foundation_runtime.gd"]:
		var source := FileAccess.get_file_as_string("res://" + path)
		for forbidden in ["tests/foundation/", "collect_mapping_candidates(", "resolve_mapping(",
			"logical_lighting.gd", "query_move(", "resolve_slot_request("]:
			check(not source.contains(forbidden), path + " has no " + forbidden)
	var report := {"display": DisplayServer.get_name(), "checks": checks, "failures": failures,
		"backend": "explicit test double", "real_kernel_safety_integration": "NOT RUN - dependencies absent",
		"input": "Godot Input.parse_input_event keys + Viewport.push_input mouse; system manual keyboard/mouse NOT RUN", "state_keys": states}
	FileAccess.open(evidence.path_join("runtime_report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("FOUNDATION_RUNTIME_GRAPHICS_", "PASS" if failures.is_empty() else "FAIL", " checks=", checks)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func key() -> String:
	return Key.build(scene.session.level, scene.session.state).key

func press(code: Key, settle := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	if settle:
		await create_timer(0.65).timeout

func check_pose(id: int) -> void:
	var cols := Math.columns(id)
	check(scene.presenter.player.basis.is_equal_approx(Basis(Vector3(cols[0]), Vector3(cols[1]), Vector3(cols[2]))), "visual pose equals formal cube24 " + str(id))

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	states[label] = key()
	var result := root.get_texture().get_image().save_png(evidence.path_join(label + ".png"))
	check(result == OK, "screenshot " + label)
