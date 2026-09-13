extends SceneTree
const Fixture = preload("res://tests/foundation/rules/kernel_fixture.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Double = preload("res://tests/foundation/rules/safety_double.gd")
var Kernel
var RuleRecords
var unit_mode := false
var checks := 0
var failures: Array[String] = []


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
	if not FileAccess.file_exists(root + "transition_permission.gd"):
		printerr("FAIL: busy permission implementation missing")
		quit(1)
		return
	if not unit_mode and not FileAccess.file_exists("res://foundation/validation/safety_queries.gd"):
		printerr("FAIL: REAL_SAFETY_DEPENDENCY_MISSING")
		quit(1)
		return
	Kernel = load(root + "puzzle_rule_kernel.gd")
	RuleRecords = load(root + "rule_records.gd")
	Double.reset()
	_test_completion()
	_test_busy_rejections()
	_test_ticket_validation()
	_test_carrier_boundary()
	print("BUSY_TRANSITION checks=", checks, " failures=", failures)
	if failures.is_empty():
		print("UNIT_TESTS_WITH_DOUBLE_PASS" if unit_mode else "BUSY_TRANSITION_REAL_SUITE_PASS")
	else:
		printerr("FAIL: busy assertions")
	quit(0 if failures.is_empty() else 1)


func evaluate(level: Dictionary, state: Dictionary, action: Dictionary, context: Dictionary) -> Dictionary:
	var original := var_to_bytes([level, state, action, context])
	var result: Dictionary = Kernel.evaluate_action(level, state, action, context)
	check(var_to_bytes([level, state, action, context]) == original, "busy query preserves all input bytes")
	return result


func _test_completion() -> void:
	for global_type in ["celestial", "world", "group"]:
		var level := Fixture.group_level() if global_type == "group" else Fixture.make_level()
		var state := Records.initial_state(level)
		var action: Dictionary = Fixture.celestial_action()
		if global_type == "world":
			action = {"kind": 2, "rotation_delta": 2}
		elif global_type == "group":
			action = level.mechanisms[1].action
		var base := state.duplicate(true)
		var prepared := evaluate(level, state, action, RuleRecords.idle_context())
		check(prepared.status == 0 and prepared.changed, global_type + " global prepared")
		if prepared.status != 0:
			continue
		var opened: Dictionary = RuleRecords.begin_global(level, prepared)
		check(opened.ok and state == base, global_type + " begin is not a commit")
		if not opened.ok:
			continue
		var context: Dictionary = opened.context
		for step in range(2):
			var local := evaluate(level, state, {"kind": 0, "face_axis": 0}, context)
			check(local.status == 0, global_type + " busy MOVE allowed " + str(local))
			if local.status != 0:
				break
			check(local.global_kind == 0, "busy MOVE opens no second global")
			state = local.next_state
			context.local_moves.append({"kind": 0, "face_axis": 0})
		var before := var_to_bytes([state, context])
		var completed: Dictionary = Kernel.complete_global(level, state, context)
		check(var_to_bytes([state, context]) == before, "completion is pure")
		check(completed.status == 0, global_type + " completion " + str(completed))
		if completed.status == 0:
			check(completed.next_state.player.location.cube_id == &"end", "latest player retained after two local moves")
			var serial: Dictionary = prepared.next_state
			for step in range(2):
				var moved := evaluate(level, serial, {"kind": 0, "face_axis": 0}, RuleRecords.idle_context())
				if moved.status == 0:
					serial = moved.next_state
			check(Key.build(level, serial).key == Key.build(level, completed.next_state).key, "two orders have identical full StateKey " + global_type)
		if unit_mode:
			check(Double.concurrent_calls > 0, "busy must invoke shared concurrent sweep")


func _test_busy_rejections() -> void:
	var level := Fixture.group_level()
	var state := Records.initial_state(level)
	var prepared := evaluate(level, state, Fixture.celestial_action(), RuleRecords.idle_context())
	if prepared.status != 0:
		check(false, "busy rejection fixture must prepare")
		return
	var context: Dictionary = RuleRecords.begin_global(level, prepared).context
	for phase in [1,2]:
		context.global_transition_state = phase
		for action in [{"kind": 1}, {"kind": 2, "rotation_delta": 2}, {"kind": 3, "rotation_delta": 2}, {"kind": 4, "transition_id": &"tip"}, {"kind": 5, "mechanism_id": &"console"}, level.mechanisms[1].action, Fixture.celestial_action()]:
			var rejected := evaluate(level, state, action, context)
			check(rejected.status == 1 and rejected.rejection_code == 1500 and rejected.next_state == null, "every global rejected during phase %d" % phase)
		check(context.keys().size() == 3 and context.local_moves.is_empty(), "rejection leaves no queue or trace")
	var blocked := evaluate(level, state, {"kind": 0, "face_axis": 1}, context)
	check(blocked.status == 1 and blocked.rejection_code == 2000, "busy ordinary missing neighbor remains MOVE_BLOCKED")
	Fixture.add_mechanism(level, &"plate", &"step/TOP", Fixture.celestial_action(&"plate"), &"ENTER")
	state = Records.initial_state(level)
	context = RuleRecords.begin_global(level, evaluate(level, state, Fixture.celestial_action(), RuleRecords.idle_context())).context
	var enter := evaluate(level, state, {"kind": 0, "face_axis": 0}, context)
	check(enter.status == 1 and enter.rejection_code == 1504, "busy ENTER denied without deferred effect")
	level = Fixture.group_level()
	state = Records.initial_state(level)
	context = RuleRecords.begin_global(level, evaluate(level, state, Fixture.celestial_action(), RuleRecords.idle_context())).context
	level.goal.face_id = &"step/TOP"
	var goal := evaluate(level, state, {"kind": 0, "face_axis": 0}, context)
	check(goal.status == 1 and goal.rejection_code == 1504, "busy entering goal denied")
	level.goal.face_id = &"floor/TOP"
	goal = evaluate(level, state, {"kind": 0, "face_axis": 0}, context)
	check(goal.status == 1 and goal.rejection_code == 1504, "busy leaving goal denied")
	if unit_mode:
		level = Fixture.group_level()
		Double.concurrent_status = 2
		var unproven := evaluate(level, state, {"kind": 0, "face_axis": 0}, context)
		check(unproven.status == 1 and unproven.rejection_code == 1504, "serial safety cannot substitute for concurrent proof")
		Double.concurrent_status = 3
		var overflow := evaluate(level, state, {"kind": 0, "face_axis": 0}, context)
		check(overflow.status == 2 and overflow.issues[0].code == 1105, "concurrent overflow propagated")
		Double.reset()
		for broken in [{}, {"status": 99, "issues": [RuleRecords.issue(1601, "concurrent", "Unknown status")]}, {"status": 0, "issues": [RuleRecords.issue(1105, "concurrent", "Overflow")]}, {"status": 3, "issues": []}]:
			Double.concurrent_override = broken
			var failed := evaluate(level, state, {"kind": 0, "face_axis": 0}, context)
			check(failed.status == 2 and failed.next_state == null, "malformed concurrent-only wrapper is ERROR")
		Double.reset()


func _test_ticket_validation() -> void:
	var level := Fixture.make_level()
	var state := Records.initial_state(level)
	var prepared := evaluate(level, state, Fixture.celestial_action(), RuleRecords.idle_context())
	if prepared.status != 0:
		check(false, "ticket fixture must prepare")
		return
	var original: Dictionary = RuleRecords.begin_global(level, prepared).context
	for mutation in ["hash", "trace", "grant", "state"]:
		var context := original.duplicate(true)
		var current := state.duplicate(true)
		match mutation:
			"hash":
				context.ticket.level_hash = "0".repeat(64)
			"trace":
				context.local_moves.append({"kind": 0, "face_axis": 0})
			"grant":
				context.ticket.accepted_action.target_slot_id = &"a"
			"state":
				current.player.location.cube_id = &"step"
		var before := var_to_bytes([current, context])
		var completed: Dictionary = Kernel.complete_global(level, current, context)
		check(completed.status == 2 and completed.next_state == null, "tampered ticket rejected " + mutation)
		check(var_to_bytes([current, context]) == before, "failed completion immutable " + mutation)
	var ctx: Dictionary = RuleRecords.idle_context()
	var absent: Dictionary = Kernel.complete_global(level, state, ctx)
	check(absent.status == 2, "IDLE completion fails explicitly")
	var malformed := original.duplicate(true)
	var shape_error := evaluate(level, state, {"kind": 1, "unknown": true}, malformed)
	check(shape_error.status == 2 and shape_error.rejection_code == 0, "bad shape has priority over busy denial")


func _test_carrier_boundary() -> void:
	var level := Fixture.group_level()
	level.groups[0].cube_ids = [&"floor"]
	for cube in level.cubes:
		if cube.cube_id in [&"step", &"end"]:
			cube.group_id = &""
	var state := Records.initial_state(level)
	var action: Dictionary = level.mechanisms[1].action
	var prepared := evaluate(level, state, action, RuleRecords.idle_context())
	if prepared.status != 0:
		check(false, "carrier boundary fixture must prepare")
		return
	var ctx: Dictionary = RuleRecords.begin_global(level, prepared).context
	var crossing := evaluate(level, state, {"kind": 0, "face_axis": 0}, ctx)
	check(crossing.status == 1 and crossing.rejection_code == 1504, "busy cannot cross moving carrier boundary")
