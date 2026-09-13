extends SceneTree

var failures: Array[String] = []
var checks := 0
const Fixture = preload("res://tests/foundation/rules/kernel_fixture.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Math = preload("res://foundation/orientation/discrete_orientation.gd")
const Double = preload("res://tests/foundation/rules/safety_double.gd")
const Mapping = preload("res://foundation/spatial/mapping_query.gd")
var Kernel
var RuleRecords
var Goal
var unit_mode := false


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	var root := "res://foundation/rules/"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rules-root="):
			root = argument.trim_prefix("--rules-root=")
			unit_mode = true
	var path := root + "puzzle_rule_kernel.gd"
	if not FileAccess.file_exists(path):
		printerr("FAIL: PuzzleRuleKernel implementation missing")
		quit(1)
		return
	if not unit_mode and not FileAccess.file_exists("res://foundation/validation/safety_queries.gd"):
		printerr("FAIL: REAL_SAFETY_DEPENDENCY_MISSING; final integration cannot run")
		quit(1)
		return
	Kernel = load(path)
	RuleRecords = load(root + "rule_records.gd")
	Goal = load(root + "goal_evaluator.gd")
	if Kernel == null or not Kernel.can_instantiate() or RuleRecords == null or Goal == null:
		printerr("FAIL: rule modules cannot load")
		quit(1)
		return
	Double.reset()
	_test_actions()
	_test_shift()
	_test_mechanisms_and_goal()
	_test_bad_inputs()
	_test_diagnostic_records()
	_test_order_and_group_frame()
	_test_channels_and_entry_atomicity()
	if unit_mode:
		_test_safety_failures()
		_test_mapping_and_late_errors()
	print("RULE_KERNEL checks=", checks, " failures=", failures)
	if failures.is_empty():
		print("UNIT_TESTS_WITH_DOUBLE_PASS" if unit_mode else "RULE_KERNEL_REAL_SUITE_PASS")
	else:
		printerr("FAIL: rule kernel assertions")
	quit(0 if failures.is_empty() else 1)


func run_action(level: Dictionary, state: Dictionary, action: Dictionary, expected: int, label: String, code: int = 0, context: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = RuleRecords.idle_context() if context.is_empty() else context
	var before := var_to_bytes([level, state, action, ctx])
	var key_before: Dictionary = Key.build(level, state)
	var result: Dictionary = Kernel.evaluate_action(level, state, action, ctx)
	check(var_to_bytes([level, state, action, ctx]) == before, label + " inputs byte-identical")
	check(Key.build(level, state) == key_before, label + " input StateKey unchanged")
	check(result.keys().size() == 8, label + " closed eight-field result")
	check(result.status == expected, label + " status " + str(result))
	check(result.previous_state == state and result.action == action, label + " original values preserved")
	if expected != 0:
		check(result.next_state == null and not result.changed and result.global_kind == 0, label + " no partial candidate")
		check(result.rejection_code == code, label + " rejection code")
		if expected == 2:
			check(not result.issues.is_empty(), label + " ERROR has diagnostics")
			var has_error := false
			for diagnostic in result.issues:
				has_error = has_error or diagnostic.severity == 0
			check(has_error, label + " ERROR has ERROR-severity diagnostic")
	elif result.status == 0:
		check(Data.validate_state_shape(level, result.next_state).is_empty(), label + " complete next state shape")
		check(result.issues.is_empty() and result.rejection_code == 0, label + " clean success metadata")
		check(result.changed == (state != result.next_state), label + " changed matches full state")
		check(Key.build(level, result.next_state).ok, label + " next StateKey builds")
	var output_copy := result.duplicate(true)
	if output_copy.previous_state.has("level_flags"):
		result.previous_state.level_flags[&"output_only"] = true
		if result.next_state is Dictionary:
			check(not result.next_state.level_flags.has(&"output_only"), label + " previous and next do not alias")
	result.action["output_only"] = true
	check(var_to_bytes([level, state, action, ctx]) == before, label + " output mutations isolated")
	return output_copy


func _test_actions() -> void:
	var level := Fixture.make_level()
	check(Data.validate_level_shape(level).is_empty(), "business fixture valid DATA shape")
	var state := Records.initial_state(level)
	var move := run_action(level, state, {"kind": 0, "face_axis": 0}, 0, "MOVE")
	if move.status == 0:
		check(move.next_state.player.location.cube_id == &"step" and move.next_state.player.orientation == 12, "MOVE +X on TOP physically rolls Z-")
		var back := run_action(level, move.next_state, {"kind": 0, "face_axis": 2}, 0, "MOVE reverse")
		check(back.next_state == state, "MOVE round trip")
	run_action(level, state, {"kind": 0, "face_axis": 1}, 1, "MOVE edge does not wrap to FRONT", 2000)
	for kind in [2, 3]:
		var rotated := run_action(level, state, {"kind": kind, "rotation_delta": 2}, 0, "world rotation %d" % kind)
		if rotated.status == 0:
			check(rotated.next_state.world_orientations[kind - 2] == 2, "world pose updated")
			check(rotated.next_state.player.location == state.player.location, "carrier keeps local location identity")
			check(rotated.next_state.player.orientation == (2 if kind == 2 else 0), "only carrier rotates player")
		var restricted := level.duplicate(true)
		restricted.worlds[kind - 2].allowed_rotation_deltas = [3]
		run_action(restricted, state, {"kind": kind, "rotation_delta": 2}, 1, "world not allowed %d" % kind, 2001)
	var transition := run_action(level, state, {"kind": 4, "transition_id": &"tip"}, 0, "FaceTransition")
	if transition.status == 0:
		check(transition.next_state.player.location.face == 0 and transition.next_state.player.orientation == 2, "FaceTransition physical step golden")
		var reverse := run_action(level, transition.next_state, {"kind": 4, "transition_id": &"untip"}, 0, "FaceTransition inverse")
		check(reverse.next_state == state, "FaceTransition round trip")
	run_action(level, state, {"kind": 4, "transition_id": &"untip"}, 1, "FaceTransition wrong source", 2003)
	var group_level := Fixture.group_level()
	var group_state := Records.initial_state(group_level)
	var group_action: Dictionary = group_level.mechanisms[1].action
	var grouped := run_action(group_level, group_state, group_action, 0, "LOCAL_GROUP_ROTATE")
	if grouped.status == 0:
		check(grouped.next_state.group_orientations.bridge == 2 and grouped.next_state.player.orientation == 2, "group and player commit together")
	group_level.groups[0].edges = []
	run_action(group_level, group_state, group_action, 1, "group edge absent", 2001)
	for operation in range(4):
		var slot_level := Fixture.make_level()
		var slot_state := Records.initial_state(slot_level)
		var slot_action := Fixture.celestial_action(&"console", operation, &"b" if operation == 0 else (&"a" if operation == 3 else &""), &"b" if operation == 3 else &"")
		if operation == 2:
			slot_state.celestial.slot_id = &"b"
		slot_level.mechanisms[0].action = slot_action
		var slotted := run_action(slot_level, slot_state, slot_action, 0, "Celestial operation %d" % operation)
		if slotted.status == 0:
			check(slotted.next_state.celestial.slot_id == (&"a" if operation == 2 else &"b"), "formal slot result applied")
	level.celestial.edges = []
	run_action(level, state, Fixture.celestial_action(), 1, "Celestial graph rejects", 1301)
	level.mechanisms[0].action = Fixture.celestial_action(&"console", 0, &"a")
	var unchanged := run_action(level, state, level.mechanisms[0].action, 0, "SET current slot")
	check(not unchanged.changed and unchanged.global_kind == 0, "same slot no animation kind")
	check(not RuleRecords.begin_global(level, unchanged).ok, "same slot cannot open ticket")


func _test_shift() -> void:
	for twisted in [false, true]:
		var level := Fixture.opposite_level(twisted)
		var state := Records.initial_state(level)
		var shifted := run_action(level, state, {"kind": 1}, 0, "OPPOSITE shift %s" % twisted)
		if shifted.status == 0:
			check(shifted.next_state.player.orientation == (19 if twisted else 1), "OPPOSITE full-frame golden")
	var level := Fixture.make_level()
	var state := Records.initial_state(level)
	var shifted := run_action(level, state, {"kind": 1}, 0, "SHADOW SAME shift")
	if shifted.status == 0:
		check(shifted.next_state.player.orientation == 0 and shifted.next_state.player.location.layer == 1, "SAME preserves shared pose")
		var inner: Dictionary = shifted.next_state
		inner.celestial.slot_id = &"b"
		var returned := run_action(level, inner, {"kind": 1}, 0, "Inner LIT returns without Shadow")
		check(returned.next_state.player.location.layer == 0, "Inner returns Surface")
	state.celestial.slot_id = &"b"
	run_action(level, state, {"kind": 1}, 1, "Surface LIT rejected", 1403)
	Fixture.face(level, &"floor/TOP").shift_exit_blocked = true
	run_action(level, state, {"kind": 1}, 1, "exit block precedes lighting", 1404)
	Fixture.face(level, &"floor/TOP").shift_exit_blocked = false
	Fixture.face(level, &"mirror/TOP").shift_entry_blocked = true
	run_action(level, state, {"kind": 1}, 1, "entry block precedes lighting", 1405)
	Fixture.face(level, &"mirror/TOP").walkable = false
	run_action(level, state, {"kind": 1}, 1, "NONE mapping precedes lighting and blocks", 1400)


func _test_mechanisms_and_goal() -> void:
	var level := Fixture.make_level()
	var state := Records.initial_state(level)
	var triggered := run_action(level, state, {"kind": 5, "mechanism_id": &"console"}, 0, "TRIGGER_MECHANISM delegates")
	if triggered.status == 0:
		check(triggered.next_state.celestial.slot_id == &"b", "mechanism uses same slot transaction")
	var remote := state.duplicate(true)
	remote.player.location.cube_id = &"step"
	run_action(level, remote, {"kind": 5, "mechanism_id": &"console"}, 1, "remote trigger denied", 1503)
	run_action(level, remote, Fixture.celestial_action(), 1, "remote direct celestial denied", 1503)
	var forged := Fixture.celestial_action(&"console", 0, &"a")
	run_action(level, state, forged, 1, "known mechanism cannot authorize different payload", 1503)
	Fixture.add_mechanism(level, &"plate", &"step/TOP", Fixture.celestial_action(&"plate"), &"ENTER")
	state = Records.initial_state(level)
	var entered := run_action(level, state, {"kind": 0, "face_axis": 0}, 0, "MOVE ENTER atomic effect")
	if entered.status == 0:
		check(entered.next_state.player.location.cube_id == &"step" and entered.next_state.celestial.slot_id == &"b", "MOVE and slot one candidate")
		check(not RuleRecords.begin_global(level, entered).ok, "MOVE plus ENTER never split into ticket")
		check(entered.next_state.level_flags == state.level_flags and entered.next_state.mechanism_states == state.mechanism_states, "all flags and mechanism states preserved")
	Fixture.add_mechanism(level, &"plate_two", &"step/TOP", Fixture.celestial_action(&"plate_two"), &"ENTER")
	state = Records.initial_state(level)
	var multi := run_action(level, state, {"kind": 0, "face_axis": 0}, 2, "two ENTER globals fail atomically")
	check(_has_code(multi.issues, 1501), "two globals keep code 1501")
	level = Fixture.make_level()
	state = Records.initial_state(level)
	var before := var_to_bytes([level, state])
	var goal: Dictionary = Goal.is_goal(level, state)
	check(goal.ok and not goal.is_goal, "goal false")
	check(var_to_bytes([level, state]) == before, "goal read only")
	state.player.location.cube_id = &"goal"
	goal = Goal.is_goal(level, state)
	check(goal.ok and goal.is_goal, "goal face and flags satisfied")
	state.level_flags.open = false
	goal = Goal.is_goal(level, state)
	check(goal.ok and not goal.is_goal, "goal requires flags")
	state.player.location.cube_id = &"absent"
	goal = Goal.is_goal(level, state)
	check(not goal.ok and goal.is_goal == null and not goal.issues.is_empty(), "bad goal input explicit ERROR")


func _test_bad_inputs() -> void:
	var level := Fixture.make_level()
	var state := Records.initial_state(level)
	run_action({}, state, {"kind": 0, "face_axis": 0}, 2, "bad level")
	run_action(level, {}, {"kind": 0, "face_axis": 0}, 2, "bad state")
	run_action(level, state, {"kind": 0, "face_axis": 0, "WASD": "W"}, 2, "unknown action field")
	run_action(level, state, {"kind": 99}, 2, "unknown action")
	var ctx: Dictionary = RuleRecords.idle_context()
	ctx["queue"] = []
	run_action(level, state, {"kind": 0, "face_axis": 0}, 2, "context unknown field", 0, ctx)
	level.mechanisms[0].allowed_states.append(&"on")
	run_action(level, state, {"kind": 5, "mechanism_id": &"console"}, 2, "unsupported mechanism FSM profile")
	level = Fixture.make_level()
	level.face_transitions[0].target_face_id = &"step/TOP"
	run_action(level, state, {"kind": 4, "transition_id": &"tip"}, 2, "cross-Cube transition profile rejected")
	level = Fixture.make_level()
	level.cubes[0].center2 = Vector3i(-2147483648,0,0)
	var overflow := run_action(level, state, {"kind": 1}, 2, "snapshot overflow short circuits")
	check(_has_code(overflow.issues, 1105), "snapshot error preserves 1105")


func _test_safety_failures() -> void:
	var level := Fixture.make_level()
	var state := Records.initial_state(level)
	for status in [1,2,3]:
		Double.reset()
		Double.motion_status = status
		var rejected := run_action(level, state, {"kind": 2, "rotation_delta": 2}, 2 if status == 3 else 1, "motion safety %d" % status, 0 if status == 3 else 2002)
		if status == 3:
			check(_has_code(rejected.issues, 1105), "motion 1105 remains ERROR")
			check(rejected.issues[0].details == {"probe": [1,2]}, "bottom issue details preserved")
	Double.reset()
	Double.state_status = 3
	var failure := run_action(level, state, {"kind": 0, "face_axis": 0}, 2, "bad current safety")
	check(_has_code(failure.issues, 1105) and Double.motion_calls == 0, "current safety error short circuits motion")
	Double.reset()
	for malformed in [{}, {"status": 99, "issues": [RuleRecords.issue(1104, "safety", "unknown status")]}, {"status": 3, "issues": []}, {"status": 0, "issues": [], "extra": true}]:
		Double.malformed_result = malformed
		run_action(level, state, {"kind": 0, "face_axis": 0}, 2, "malformed Safety wrapper " + str(malformed))
		var bad_goal: Dictionary = Goal.is_goal(level, state)
		check(not bad_goal.ok and bad_goal.is_goal == null, "Goal rejects malformed Safety wrapper")
	Double.reset()
	Double.malformed_result = {"status": 0, "issues": [RuleRecords.issue(1105, "safety", "SAFE cannot hide overflow")]}
	var malformed := run_action(level, state, {"kind": 0, "face_axis": 0}, 2, "SAFE with overflow issues is an ERROR")
	check(_has_code(malformed.issues, 1105), "malformed SAFE retains overflow diagnostic")
	var warning: Dictionary = RuleRecords.issue(1105, "safety", "Overflow mislabeled as warning")
	warning.severity = 1
	Double.malformed_result = {"status": 2, "issues": [warning]}
	var normalized := run_action(level, state, {"kind": 0, "face_axis": 0}, 2, "UNPROVEN with WARNING overflow still has an ERROR diagnostic")
	check(normalized.issues.has(warning), "original lower WARNING diagnostic retained unchanged")
	Double.reset()


func _has_code(issues: Array, code: int) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false


func _test_diagnostic_records() -> void:
	var original_ids := [&"z", &"a"]
	var diagnostic: Dictionary = RuleRecords.issue(1105, "same", "fixture", original_ids, {"probe": [1]})
	check(diagnostic.entity_ids == [&"a", &"z"] and original_ids == [&"z", &"a"], "diagnostic entity IDs sorted without mutating input")
	var issues: Array = [RuleRecords.issue(1105, "same", "prefix", [&"a", &"b"]), RuleRecords.issue(1105, "same", "empty", []), RuleRecords.issue(1105, "same", "short", [&"a"])]
	var sorted: Array = RuleRecords.sorted_issues(issues)
	check(sorted[0].entity_ids == [] and sorted[1].entity_ids == [&"a"] and sorted[2].entity_ids == [&"a", &"b"], "issue ordering is lexicographic by complete entity ID arrays")


func _test_mapping_and_late_errors() -> void:
	var level := Fixture.make_level()
	var state := Records.initial_state(level)
	# Formal resolver constructs AMBIGUOUS; this is not claimed to be a valid
	# geometric level with two sealed/coincident walkable target faces.
	Fixture.mapping_override = Mapping.resolve_mapping({"ok": true, "candidates": [{"source_face": &"floor/TOP", "target_face": &"mirror/TOP", "compatibility": 0}, {"source_face": &"floor/TOP", "target_face": &"mirror/BOTTOM", "compatibility": 1}], "issues": []})
	Fixture.light_calls = 0
	var ambiguous := run_action(level, state, {"kind": 1}, 2, "formal AMBIGUOUS resolution preserved")
	check(_has_code(ambiguous.issues, 1401) and Fixture.light_calls == 0, "AMBIGUOUS does not query lighting")
	var diagnostic: Dictionary = RuleRecords.issue(1105, "mapping.overflow", "fixture", [&"floor/TOP"], {"operation": "probe", "operands": [2147483647, 1]})
	Fixture.mapping_override = {"status": 3, "candidates": [], "mapping": null, "issues": [diagnostic]}
	var mapped_error := run_action(level, state, {"kind": 1}, 2, "mapping ERROR preserves lower issue")
	check(mapped_error.issues == [diagnostic] and Fixture.light_calls == 0, "mapping issue details lossless and lighting short-circuited")
	Fixture.mapping_override = null
	Fixture.snapshot_failure = {"ok": false, "value": null, "issues": [diagnostic]}
	Fixture.fail_snapshot_at_slot = &"b"
	var late_error := run_action(level, state, Fixture.celestial_action(), 2, "candidate slot changes then spatial ERROR is all-or-nothing")
	check(late_error.issues == [diagnostic] and state.celestial.slot_id == &"a", "late candidate error retains old slot and diagnostics")
	Fixture.add_mechanism(level, &"late_plate", &"step/TOP", Fixture.celestial_action(&"late_plate"), &"ENTER")
	state = Records.initial_state(level)
	var late_enter := run_action(level, state, {"kind": 0, "face_axis": 0}, 2, "late ENTER ERROR rolls back both player and slot")
	check(late_enter.issues == [diagnostic] and state.player.location.cube_id == &"floor", "late ENTER retains full original player")
	Fixture.snapshot_failure = {}
	Fixture.fail_snapshot_at_slot = &""


func _test_order_and_group_frame() -> void:
	var level := Fixture.make_level()
	var state := Records.initial_state(level)
	var action := Fixture.celestial_action()
	var forward := run_action(level, state, action, 0, "ordered valid level")
	var reversed := level.duplicate(true)
	for field in ["worlds", "cubes", "faces", "mechanisms", "face_transitions", "flag_definitions"]:
		reversed[field].reverse()
	var backward := run_action(reversed, state, action, 0, "shuffled valid level")
	check(forward == backward, "declaration collection order does not alter successful result")
	level.celestial.slots[1].position2 = Vector3i.ZERO
	var first_error := run_action(level, state, action, 2, "target Slot in occluder")
	level.faces.reverse()
	var second_error := run_action(level, state, action, 2, "target Slot in occluder with reversed faces")
	check(first_error == second_error, "lighting failure uses canonical face order")
	var grouped := Fixture.group_level()
	grouped.mechanisms[1].action.rotation_delta = 22
	var group_state := Records.initial_state(grouped)
	group_state.world_orientations[0] = 2
	var group_result := run_action(grouped, group_state, grouped.mechanisms[1].action, 0, "group delta in rotated parent World")
	if group_result.status == 0:
		check(group_result.next_state.player.orientation == 9, "Rx times Ry times Rx inverse gives Rz, not Ry")
		check(group_result.next_state.group_orientations.bridge == 22, "group stores parent-space delta")


func _test_channels_and_entry_atomicity() -> void:
	var level := Fixture.make_level()
	for item in [[&"fourth", Vector3i(6,0,0)], [&"fifth", Vector3i(8,0,0)]]:
		level.cubes.append(Fixture.cube(item[0], 0, item[1]))
		for record in Geometry.make_face_nodes(item[0]):
			record.walkable = record.face == 4
			level.faces.append(record)
	var state := Records.initial_state(level)
	for step in range(4):
		var moved := run_action(level, state, {"kind": 0, "face_axis": 0}, 0, "four consecutive physical rolls %d" % step)
		if moved.status != 0:
			break
		state = moved.next_state
	check(state.player.orientation == 0 and state.player.location.cube_id == &"fifth", "four MOVE rolls restore pose without resetting location")
	level = Fixture.make_level()
	Fixture.face(level, &"floor/BACK").walkable = true
	level.face_transitions.append({"transition_id": &"long_channel", "source_face_id": &"floor/TOP", "target_face_id": &"floor/BACK", "entry_axis": 0, "exit_axis": 2, "rotation_steps": [2,2,2], "required_flags": []})
	state = Records.initial_state(level)
	var channel := run_action(level, state, {"kind": 4, "transition_id": &"long_channel"}, 0, "explicit multi-step same-Cube channel")
	if channel.status == 0:
		check(channel.next_state.player.location.face == 1 and channel.next_state.player.orientation == 3, "three X+ channel steps give X- physical pose")
	level = Fixture.make_level()
	Fixture.add_mechanism(level, &"plate", &"step/TOP", Fixture.celestial_action(&"plate"), &"ENTER")
	state = Records.initial_state(level)
	level.celestial.edges = []
	run_action(level, state, {"kind": 0, "face_axis": 0}, 1, "ENTER rejected effect rolls back MOVE", 1301)
	var standing := state.duplicate(true)
	standing.player.location.cube_id = &"step"
	run_action(level, standing, {"kind": 5, "mechanism_id": &"plate"}, 1, "standing cannot USE an ENTER plate", 1503)
	level = Fixture.make_level()
	level.cubes.append(Fixture.cube(&"cap", 1, Vector3i(0,2,0)))
	for record in Geometry.make_face_nodes(&"cap"):
		record.walkable = record.face == 5
		level.faces.append(record)
	state = Records.initial_state(level)
	var sealed := run_action(level, state, {"kind": 1}, 2, "real sealed multi-target geometry fails before mapping")
	check(_has_code(sealed.issues, 1201), "sealed faces preserve formal 1201")
