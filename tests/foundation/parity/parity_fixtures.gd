extends RefCounted
## Tests-only authored witnesses. These fixed routes are not Solver output.
## DEPENDENCY_PENDING: FOUNDATION-3A owns SolutionTrace and shortest-path proof.
const RuntimeFixture = preload("res://prototype/foundation/runtime/runtime_fixture.gd")
const Reader = preload("res://foundation/level/authoring_reader.gd")
const Authoring = preload("res://tools/foundation/level/runtime_authoring.tscn")
const Baker = preload("res://foundation/level/level_baker.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Kernel = preload("res://foundation/rules/puzzle_rule_kernel.gd")
const Rules = preload("res://foundation/rules/rule_records.gd")
const Goal = preload("res://foundation/rules/goal_evaluator.gd")
const TraceDouble = preload("res://tests/foundation/parity/trace_contract_double.gd")
const VALIDATION_OPTIONS = {"max_configurations": 4096, "max_checks": 100000}


static func case_named(name: String) -> Dictionary:
	var authoring := _authoring()
	var states: Array = []
	var actions: Array = []
	var global_kinds: Array = []
	match name:
		"zero":
			authoring.goal.face_id = &"s0/TOP"
		"one":
			authoring.goal.face_id = &"s1/TOP"
			states = [_state(0, &"s1", 4, 12, [0, 0])]
			actions = [{"kind": 0, "face_axis": 0}]
			global_kinds = [0]
		"multi":
			states = [_state(0, &"s1", 4, 12, [0, 0]),
				_state(0, &"s1", 4, 15, [22, 0]), _state(1, &"i1", 4, 15, [22, 0])]
			actions = [{"kind": 0, "face_axis": 0}, {"kind": 2, "rotation_delta": 22}, {"kind": 1}]
			global_kinds = [0, 2, 4]
		"global":
			# Deliberately not shortest: the initial face already meets Goal.
			# This witness independently exercises a real global rotation token.
			authoring.goal.face_id = &"s0/TOP"
			states = [_state(0, &"s0", 4, 22, [22, 0])]
			actions = [{"kind": 2, "rotation_delta": 22}]
			global_kinds = [2]
		"shift":
			authoring.goal.face_id = &"i0/TOP"
			for face in authoring.faces:
				if face.face_id == &"s0/TOP":
					face.shift_exit_blocked = false
			states = [_state(1, &"i0", 4, 0, [0, 0])]
			actions = [{"kind": 1}]
			global_kinds = [4]
		"composite":
			authoring.goal.face_id = &"s1/FRONT"
			authoring.worlds[0].allowed_states = [0]
			authoring.worlds[0].allowed_rotation_deltas = []
			authoring.worlds[0].allowed_rotation_intents = []
			for face in authoring.faces:
				if face.face_id == &"s1/FRONT":
					face.walkable = true
				if face.face_id == &"s1/TOP":
					face.mechanism_ids = [&"plate"]
			authoring.mechanisms = [{"mechanism_id": &"plate", "face_id": &"s1/TOP",
				"trigger": &"ENTER", "action": {"kind": 4, "transition_id": &"tip"},
				"priority": 0, "initial_state": &"ready", "allowed_states": [&"ready"]}]
			authoring.face_transitions = [{"transition_id": &"tip", "source_face_id": &"s1/TOP",
				"target_face_id": &"s1/FRONT", "entry_axis": 0, "exit_axis": 0,
				"rotation_steps": [2], "required_flags": []}]
			states = [_state(0, &"s1", 0, 20, [0, 0], {&"plate": &"ready"})]
			actions = [{"kind": 0, "face_axis": 0}]
			global_kinds = [5]
		_:
			assert(false, "Unknown parity fixture: " + name)
			return {}
	var level: Dictionary
	if name == "multi":
		level = RuntimeFixture.make_level()
		assert(not level.is_empty(), "Production runtime fixture must Bake successfully.")
	else:
		var baked := Baker.bake(authoring, VALIDATION_OPTIONS)
		assert(baked.ok, "Parity fixture Bake failed: " + str(baked.issues))
		assert(baked.validation.status == 0, "Real StaticValidator must report VALID.")
		level = baked.level
	var initial := Records.initial_state(level)
	var trace := trace_from_states(level, initial, states, actions, global_kinds)
	_verify_literal_witness(level, trace)
	return {"level": level.duplicate(true), "trace": trace.duplicate(true)}


static func trace_from_states(level: Dictionary, initial: Dictionary, step_states: Array,
		actions: Array, global_kinds: Array) -> Dictionary:
	assert(step_states.size() == actions.size() and actions.size() == global_kinds.size())
	var initial_key := Key.build(level, initial)
	assert(initial_key.ok, "Fixture initial StateKey must be valid.")
	var steps: Array[Dictionary] = []
	for i in actions.size():
		var key := Key.build(level, step_states[i])
		assert(key.ok, "Fixture expected StateKey must be valid.")
		steps.append({"index": i + 1, "action": actions[i].duplicate(true),
			"expected_state": step_states[i].duplicate(true), "resulting_statekey": key.key,
			"global_kind": global_kinds[i]})
	return {"trace_version": "solutiontrace.v1", "level_hash": level.content_hash,
		"rule_version": level.rule_version, "policy_descriptor": {
			"strategy": &"BFS", "mode": 0, "validation_options": VALIDATION_OPTIONS.duplicate(true),
			"filter_descriptor": {"filter_id": &"UNFILTERED", "filter_version": "1", "disabled_mechanics": []}},
		"initial_state": initial.duplicate(true), "initial_statekey": initial_key.key,
		"steps": steps, "goal_statekey": initial_key.key if steps.is_empty() else steps[-1].resulting_statekey,
		"total_actions": steps.size(), "shortest": false}


static func _authoring() -> Dictionary:
	var scene: Node3D = Authoring.instantiate()
	var read := Reader.read_scene(scene)
	scene.free()
	assert(read.ok, "Real authoring Reader must succeed.")
	return read.authoring


static func _state(layer: int, cube_id: StringName, face: int, orientation: int,
		worlds: Array, mechanisms: Dictionary = {}) -> Dictionary:
	return {"player": {"location": {"layer": layer, "cube_id": cube_id, "face": face},
		"orientation": orientation}, "world_orientations": worlds.duplicate(),
		"celestial": {"slot_id": &"a"}, "group_orientations": {},
		"mechanism_states": mechanisms.duplicate(true), "level_flags": {}}


static func _verify_literal_witness(level: Dictionary, trace: Dictionary) -> void:
	# Checks fixed authored states; never discovers actions or derives expected states.
	var validated := TraceDouble.validate(level, trace)
	assert(validated.ok, "Fixture Trace shape invalid: " + str(validated.issues))
	var previous: Dictionary = trace.initial_state
	for step in trace.steps:
		var result := Kernel.evaluate_action(level, previous, step.action, Rules.idle_context())
		assert(result.status == 0 and result.changed, "Literal route must be APPLIED and changed: " + str(result))
		assert(result.next_state == step.expected_state, "Literal expected state disagrees with real Kernel.")
		assert(result.global_kind == step.global_kind, "Literal global kind disagrees with real Kernel.")
		previous = step.expected_state
	var goal := Goal.is_goal(level, previous)
	assert(goal.ok and goal.is_goal, "Literal route must end at real Goal.")
