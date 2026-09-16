extends SceneTree
const Fixtures = preload("res://tests/foundation/solver/solver_fixtures.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL: ", label)

func _initialize() -> void:
	if "--intentional-failure" in OS.get_cmdline_user_args():
		check(false,"intentional wrapper rejection probe")
	if not FileAccess.file_exists("res://foundation/solver/action_generator.gd"):
		check(false, "ActionGenerator entry missing")
		finish()
		return
	var actions = load("res://foundation/solver/action_generator.gd")
	var level := Fixtures.static_domain()
	var state := Records.initial_state(level)
	var before := var_to_bytes([level, state])
	var generated: Dictionary = actions.generate(level, state)
	check(generated.ok, "static domain valid: " + str(generated.issues))
	if generated.ok:
		var expected := [{"kind":0,"face_axis":0},{"kind":0,"face_axis":1},{"kind":0,"face_axis":2},{"kind":0,"face_axis":3},
			{"kind":1},{"kind":2,"rotation_delta":2},{"kind":2,"rotation_delta":3},{"kind":2,"rotation_delta":22},
			{"kind":3,"rotation_delta":2},{"kind":3,"rotation_delta":3},{"kind":3,"rotation_delta":22},
			{"kind":4,"transition_id":&"turn"},{"kind":5,"mechanism_id":&"group_use"},{"kind":5,"mechanism_id":&"toggle_sky"},
			{"kind":6,"group_id":&"island","rotation_delta":22,"mechanism_id":&"group_use"},
			{"kind":7,"celestial_op":3,"target_slot_id":&"a","alternate_slot_id":&"b","mechanism_id":&"toggle_sky"}]
		check(generated.actions == expected, "literal sorted static domain; direct and wrapper retained; ENTER and Reset absent")
		check(var_to_bytes([level,state]) == before, "inputs immutable")
		var other := state.duplicate(true)
		other.player.location.cube_id = &"exit"
		check(actions.generate(level,other).actions == expected, "remote mechanisms are still candidates")
		for field in ["cubes","faces","groups","worlds","mechanisms","face_transitions"]:
			level[field].reverse()
		check(actions.generate(level,state).actions == expected, "declaration order independent")
		generated.actions[-1].target_slot_id = &"changed"
		check(actions.generate(level,state).actions == expected, "output owns nested action payload")
	var bad := state.duplicate(true)
	bad["camera"] = 1
	var invalid: Dictionary = actions.generate(level,bad)
	check(not invalid.ok and invalid.actions.is_empty() and not invalid.issues.is_empty(), "unknown state field rejected")
	level.worlds[0].allowed_rotation_deltas.append(2)
	check(not actions.generate(level,state).ok, "duplicate domain does not repair invalid level")
	var minimal := Fixtures.corridor()
	check(actions.generate(minimal,Records.initial_state(minimal)).actions.size() == 5, "disabled rotations pruned statically")
	finish()

func finish() -> void:
	print("ACTION_GENERATOR_PASS checks=%d" % checks if failures.is_empty() else "ACTION_GENERATOR_FAIL checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)
