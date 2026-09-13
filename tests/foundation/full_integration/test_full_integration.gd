extends SceneTree
## Real owner chain. No dependency injection or test doubles.
const Reader = preload("res://foundation/level/authoring_reader.gd")
const Baker = preload("res://foundation/level/level_baker.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
const Validator = preload("res://foundation/validation/static_validator.gd")
const Safety = preload("res://foundation/validation/safety_queries.gd")
const Kernel = preload("res://foundation/rules/puzzle_rule_kernel.gd")
const Rules = preload("res://foundation/rules/rule_records.gd")
const Derived = preload("res://foundation/rules/derived_state_resolver.gd")
const Goal = preload("res://foundation/rules/goal_evaluator.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const OPTIONS := {"max_configurations":4096,"max_checks":100000}
const AUTHORING := "res://tools/foundation/level/runtime_authoring.tscn"
var checks := 0
var failures: Array[String] = []
var scene: Node
var evidence := "res://.godot/foundation-2-full/manual"
var route_keys: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func read_authoring(path: String) -> Dictionary:
	var node: Node3D = load(path).instantiate()
	var read := Reader.read_scene(node)
	node.free()
	check(read.ok,"authoring Reader succeeds: " + path)
	return read

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			evidence = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	var original := Baker.bake(read_authoring("res://tools/foundation/level/minimal_authoring.tscn").authoring,OPTIONS)
	check(original.ok and original.validation.status == 0,"original 2C authoring bakes through real Validator")
	if original.ok:
		check(Validator.validate(original.level,OPTIONS).status == 0,"Validator directly consumes original baked object")
	var input := read_authoring(AUTHORING)
	var baked := Baker.bake(input.authoring,OPTIONS)
	check(baked.ok and baked.validation.status == 0,"runtime authoring produces valid canonical level: " + str(baked.issues))
	if not baked.ok:
		finish()
		return
	var level: Dictionary = baked.level
	var level_bytes := var_to_bytes(level)
	check(level.size() == 19 and level.celestial.slots.size() == 2,"canonical nineteen fields and two slots")
	check(Validator.validate(level,OPTIONS).status == 0,"Validator consumes exact runtime Baker output")
	var encoded := Codec.encode(level)
	check(encoded.ok and Codec.decode(encoded.text).level == level,"canonical artifact roundtrip")
	FileAccess.open(evidence.path_join("runtime.level.json"),FileAccess.WRITE).store_string(encoded.text)
	var bad_node: Node3D = load(AUTHORING).instantiate()
	bad_node.get_node("Cubes/SurfaceStep").position = Vector3.ZERO
	var bad_read := Reader.read_scene(bad_node)
	bad_node.free()
	check(bad_read.ok,"invalid geometry remains readable authoring")
	var bad := Baker.bake(bad_read.authoring,OPTIONS)
	check(not bad.ok and bad.level == null and bad.validation.status == 1,"real Validator INVALID blocks runtime artifact")
	check(not bad.issues.is_empty(),"invalid authoring retains diagnostics")
	var limited := Baker.bake(input.authoring,{"max_configurations":1,"max_checks":1})
	check(not limited.ok and limited.level == null and limited.validation.status == 2,"INCOMPLETE cannot publish runtime artifact")
	var initial := Records.initial_state(level)
	check(Safety.validate_state(level,initial).status == 0,"initial real Safety SAFE")
	var actions := [{"kind":0,"face_axis":0},{"kind":2,"rotation_delta":22},{"kind":1}]
	var expected := initial.duplicate(true)
	var expected_states: Array[Dictionary] = []
	for index in range(actions.size()):
		var before := var_to_bytes(expected)
		var result := Kernel.evaluate_action(level,expected,actions[index],Rules.idle_context())
		check(result.status == 0 and result.changed,"real Kernel route step applied " + str(index) + ": " + str(result))
		check(var_to_bytes(expected) == before,"pure Kernel leaves prior state unchanged")
		if result.status != 0:
			finish()
			return
		expected = result.next_state
		expected_states.append(expected.duplicate(true))
		check(Safety.validate_state(level,expected).status == 0,"real route endpoint Safety")
	check(expected_states[0].player == {"location":{"layer":0,"cube_id":&"s1","face":4},"orientation":12},"literal MOVE pose and location")
	check(expected_states[1].world_orientations == [22,0] and expected_states[1].player.orientation == 15,"literal world rotation pose")
	check(expected.player == {"location":{"layer":1,"cube_id":&"i1","face":4},"orientation":15},"literal Shadow Shift destination and pose")
	var mapped := Derived.shift_mapping(level,expected_states[1])
	var light := Derived.light(level,expected_states[1],&"s1/TOP")
	check(mapped.status == 1 and mapped.mapping.target_face == &"i1/TOP","real Spatial mapping UNIQUE")
	check(light.ok and light.light_state == 1,"current Celestial slot drives real SHADOW query")
	check(Goal.is_goal(level,expected).is_goal,"real Goal observes baked exit")
	scene = load("res://prototype/foundation/runtime/foundation_runtime.tscn").instantiate()
	scene.transition_seconds = 0.5
	root.add_child(scene)
	await process_frame
	check(scene.loaded,"production scene uses default real dependencies")
	check(scene.session.level == level,"production scene consumes exact Baker definition rather than hand-authored data")
	if not scene.loaded or scene.session.level != level:
		finish()
		return
	check(scene.session_override == null,"no injected Kernel/Safety session")
	await capture("initial")
	var initial_key := key()
	var initial_visual := visual()
	await press(KEY_SPACE)
	check(scene.session.last_result.status == 1 and scene.session.last_result.rejection_code == 1404,"real input Shift rejected by permission")
	check(key() == initial_key and visual() == initial_visual,"REJECTED preserves logical and authoritative visual state")
	var syncs: int = scene.presenter.sync_count
	scene._submit({"kind":0,"face_axis":99})
	check(scene.session.last_result.status == 2,"malformed semantic action gets real Kernel ERROR")
	check(key() == initial_key and visual() == initial_visual and scene.presenter.sync_count == syncs,"ERROR preserves logic and every authoritative transform")
	await capture("error")
	var keys := [KEY_D,KEY_Q,KEY_SPACE]
	var names := ["move","world_rotate","shadow_shift"]
	for index in range(keys.size()):
		var before_key := key()
		var before_visual := visual()
		var commits: int = scene.session.commit_count
		await press(keys[index],false)
		check(scene.action_log[-1] == actions[index],"physical input maps to exact semantic action")
		check(scene.session.last_result.status == 0,"runtime real Kernel APPLIED")
		check(key() == before_key and visual() == before_visual,"proposal does not partially commit")
		await create_timer(0.08).timeout
		var progress: float = scene.presenter.transition_progress
		check(progress > 0 and progress < 1 and key() == before_key,"visual interpolation advances independently of stable state")
		var id: int = scene.session.transaction_id
		var generation: int = scene.session.generation
		if index == 0:
			scene.session.finish_local(id,generation)
		else:
			scene.session.finish_global(id,generation)
		check(key() == Key.build(level,expected_states[index]).key,"runtime full StateKey equals direct real Kernel replay")
		check(scene.session.commit_count == commits + 1,"whole state commits exactly once")
		check(scene.presenter.transition_progress == progress,"logical completion does not infer state from animation progress")
		check(visual() != before_visual,"committed state drives new visual authority")
		await create_timer(0.55).timeout
		check(scene.session.commit_count == commits + 1,"later animation callback cannot double commit")
		route_keys[names[index]] = key()
		await capture(names[index])
	check(scene.session.state == expected,"full route state matches pure replay")
	scene.presenter.player.position = Vector3(99,99,99)
	await press(KEY_R)
	check(key() == initial_key and visual() == initial_visual,"Reset reconstructs initial state without reading altered visuals")
	# A second replay relies solely on the production animation callbacks.
	# Breaking scene completion must fail even though manual token tests pass.
	for index in range(keys.size()):
		await press(keys[index])
		check(scene.session.state == expected_states[index],"natural scene callback commits complete real endpoint")
		check(scene.session.commit_count == index + 1,"natural input route commits exactly once per action")
		var settled_visual := visual()
		check(scene.presenter.sync_state(level,expected_states[index]).ok and visual() == settled_visual,"natural visual authority already matches committed state")
	await press(KEY_R)
	await press(KEY_D,false)
	var stale_id: int = scene.session.transaction_id
	var stale_generation: int = scene.session.generation
	await press(KEY_R)
	check(scene.session.finish_local(stale_id,stale_generation).ignored and key() == initial_key,"Reset cancels stale local completion")
	await press(KEY_Q,false)
	stale_id = scene.session.transaction_id
	stale_generation = scene.session.generation
	await press(KEY_R)
	check(scene.session.finish_global(stale_id,stale_generation).ignored and key() == initial_key,"Reset cancels stale global completion")
	check(scene.presenter.previews.get_child_count() == 0 and scene.session.commit_count == 0,"Reset clears previews and transaction count")
	check(var_to_bytes(level) == level_bytes,"entire consumer chain leaves baked definition immutable")
	await capture("reset")
	finish()

func key() -> String:
	return Key.build(scene.session.level,scene.session.state).key

func visual() -> Dictionary:
	var value := {"player":scene.presenter.player.transform,"celestial":scene.presenter.celestial.transform}
	for id in scene.presenter.cubes:
		value[id] = scene.presenter.cubes[id].transform
	return value

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
		await create_timer(0.6).timeout

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label + ".png")) == OK,"capture " + label)

func finish() -> void:
	var report := {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"backend":"REAL Kernel + Safety; real Baker definition","route_state_keys":route_keys}
	FileAccess.open(evidence.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FOUNDATION_2_E2E_", "PASS" if failures.is_empty() else "FAIL", " checks=",checks)
	if is_instance_valid(scene):
		scene.free()
	quit(0 if failures.is_empty() else 1)
