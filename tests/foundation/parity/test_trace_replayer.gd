extends SceneTree
## PROVISIONAL: only Trace records/validation are adapted; Session/Kernel/Safety are real.
const Key = preload("res://foundation/contracts/state_key.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Fixtures = preload("res://tests/foundation/parity/parity_fixtures.gd")
const Double = preload("res://tests/foundation/parity/trace_contract_double.gd")
const Driver = preload("res://foundation/parity/trace_replayer.gd")

class MissingTraceDriver extends "res://foundation/parity/trace_replayer.gd":
	func _trace_api() -> Variant:
		return null

class TestDriver extends "res://foundation/parity/trace_replayer.gd":
	var fault := ""
	var stale: Dictionary = {}
	func _trace_api() -> Variant:
		return Double
	func _finish_token(id: int, generation: int, is_global: bool) -> void:
		match fault:
			"missing":
				return
			"zero":
				_session.committed.emit(_session.state.duplicate(true))
				return
			"reset":
				_session.reset()
				stale = _session.finish_global(id, generation) if is_global else _session.finish_local(id, generation)
				return
			"error", "error_budget":
				if fault == "error_budget":
					OS.delay_msec(10)
				_session.feedback.emit({"status": 2, "previous_state": _session.state.duplicate(true),
					"next_state": null, "action": _transition.action.duplicate(true), "changed": false,
					"rejection_code": 0, "global_kind": 0,
					"issues": [{"code": 1105, "severity": 0, "path": "mapping.fixture", "entity_ids": [&"s0"],
						"message": "Test observer runtime error", "details": {"fixture": true}}]})
				return
		super._finish_token(id, generation, is_global)
		if fault == "duplicate":
			_session.committed.emit(_session.state.duplicate(true))
		elif fault == "double_commit":
			# A hostile observer starts a second actual action before the driver can continue.
			fault = ""
			_session.request_action({"kind": 2, "rotation_delta": 22})

var checks := 0
var failures: Array[String] = []
var evidence: Array = []
var parallel_result: Dictionary = {}
var lifecycle_results: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func record(label: String, result: Dictionary, driver: Variant) -> void:
	var fields := result.keys()
	fields.sort()
	check(fields == ["action", "actual_statekey", "divergence_step", "expected_statekey", "issues", "matched_steps", "status", "trace_length"], label + ": exact eight result fields")
	for issue in result.issues:
		var keys: Array = issue.keys()
		keys.sort()
		check(keys == ["code", "details", "message", "path", "severity", "upstream"], label + ": exact AnalysisIssue fields")
	evidence.append({"label": label, "result": result.duplicate(true), "steps": driver._step_evidence.duplicate(true)})

func make_driver() -> TestDriver:
	var driver := TestDriver.new()
	root.add_child(driver)
	return driver

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var real := MissingTraceDriver.new()
	root.add_child(real)
	var zero: Dictionary = Fixtures.case_named("zero")
	var missing: Dictionary = await real.replay(zero.level, zero.trace, {})
	check(missing.status == 2 and missing.issues[0].code == 3016, "missing real 3A Trace fails closed")
	record("dependency_pending", missing, real)
	real.free()
	var driver := make_driver()
	for name in ["zero", "one", "multi", "global", "shift", "composite"]:
		var fixture: Dictionary = Fixtures.case_named(name)
		var before := fixture.duplicate(true)
		var result: Dictionary = await driver.replay(fixture.level, fixture.trace, {})
		check(result.status == 0 and result.matched_steps == fixture.trace.total_actions and result.trace_length == fixture.trace.total_actions, name + ": every semantic step matches")
		check(result.expected_statekey == fixture.trace.goal_statekey and result.actual_statekey == fixture.trace.goal_statekey, name + ": MATCH retains verified final complete keys")
		check(result.divergence_step == null and result.action == null and result.issues.is_empty(), name + ": no divergence on MATCH")
		check(driver._session.commit_count == fixture.trace.total_actions, name + ": initial signal excluded from commits")
		check(fixture == before, name + ": owns copies without mutating caller data")
		for step in driver._step_evidence:
			check(step.commit_delta == 1 and step.commit_signals == 1 and step.actual_statekey == step.expected_statekey, name + ": one real commit and complete StateKey")
		if name in ["global", "shift", "composite"]:
			check(driver._step_evidence[0].is_global == (name != "composite"), name + ": callback selected by actual local/global token")
		record(name, result, driver)
	var one: Dictionary = Fixtures.case_named("one")
	var multi: Dictionary = Fixtures.case_named("multi")
	var filtered: Dictionary = one.trace.duplicate(true)
	filtered.policy_descriptor.filter_descriptor = {"filter_id": &"MECHANIC_ABLATION", "filter_version": "1", "disabled_mechanics": [3]}
	var filtered_result: Dictionary = await driver.replay(one.level, filtered, {})
	check(filtered_result.status == 0 and driver._session.state == one.trace.steps[0].expected_state,"filtered trace still executes unchanged real Runtime rules")
	record("filtered_witness",filtered_result,driver)
	for options in [{&"max_steps": 1}, {"extra": 1}, {"mode": 2}, {"mode": true}, {"max_steps": -1}, {"max_runtime_ms": -1}, {"step_timeout_ms": 0}, {"step_timeout_ms": 1.5}]:
		var result: Dictionary = await driver.replay(one.level, one.trace, options)
		check(result.status == 2 and result.issues[0].code == 3016, "invalid options fail before Session creation")
		check(driver._session == null, "invalid options do not start a session")
		record("invalid_options", result, driver)
	for defect in ["hash", "version", "index", "key", "extra", "steps_type", "action"]:
		var malformed: Dictionary = one.trace.duplicate(true)
		match defect:
			"hash": malformed.level_hash = "incorrect"
			"version": malformed.rule_version = "other.rules"
			"index": malformed.steps[0].index = 0
			"key": malformed.steps[0].resulting_statekey = "incorrect"
			"extra": malformed["unknown"] = true
			"steps_type": malformed.steps = "invalid"
			"action": malformed.steps[0].action["extra"] = 1
		var result: Dictionary = await driver.replay(one.level, malformed, {})
		check(result.status == 2 and driver._session == null, defect + ": malformed trace is ERROR before runtime")
		check(result.trace_length == (0 if defect == "steps_type" else 1), defect + ": safe trace length on bad input")
		record("malformed_" + defect, result, driver)
	var bad_level: Dictionary = one.level.duplicate(true)
	bad_level.content_hash = "not_the_real_hash"
	var invalid_level: Dictionary = await driver.replay(bad_level, one.trace, {})
	check(invalid_level.status == 2 and invalid_level.issues[0].code == 3000, "Codec validates real content hash")
	record("invalid_level", invalid_level, driver)
	var nonspawn: Dictionary = one.trace.duplicate(true)
	nonspawn.initial_state = nonspawn.steps[0].expected_state.duplicate(true)
	nonspawn.initial_statekey = nonspawn.goal_statekey
	nonspawn.steps = []
	nonspawn.total_actions = 0
	check(Double.validate(one.level, nonspawn).ok, "nonspawn trace is structurally valid Goal witness")
	var unsupported: Dictionary = await driver.replay(one.level, nonspawn, {})
	check(unsupported.status == 2 and unsupported.issues[0].code == 3013 and unsupported.divergence_step == 0, "nonspawn returns specific unsupported error")
	check(driver._session == null, "nonspawn is never forced into Runtime")
	record("nonspawn", unsupported, driver)
	for fixture in [zero, one]:
		var result: Dictionary = await driver.replay(fixture.level, fixture.trace, {"max_steps": 0})
		check(result.status == (0 if fixture.trace.total_actions == 0 else 3) and result.matched_steps == 0, "zero step budget distinguishes zero Goal from pending work")
		record("zero_budget", result, driver)
	var limited: Dictionary = await driver.replay(multi.level, multi.trace, {"max_steps": 1})
	check(limited.status == 3 and limited.matched_steps == 1 and driver._step_evidence.size() == 1, "step budget preserves only checked prefix")
	record("prefix_budget", limited, driver)
	var wrong: Dictionary = multi.trace.duplicate(true)
	wrong.steps[1].expected_state.player.orientation = (wrong.steps[1].expected_state.player.orientation + 1) % 24
	wrong.steps[1].resulting_statekey = Key.build(multi.level, wrong.steps[1].expected_state).key
	check(Double.validate(multi.level, wrong).ok, "wrong intermediate expectation remains structurally valid")
	var divergence: Dictionary = await driver.replay(multi.level, wrong, {})
	check(divergence.status == 1 and divergence.matched_steps == 1 and divergence.divergence_step == 2 and divergence.issues[0].code == 3015, "first wrong state stops at exact step after matched prefix")
	check(divergence.expected_statekey != divergence.actual_statekey and divergence.action == wrong.steps[1].action and not divergence.issues[0].details.state_differences.is_empty(), "divergence retains action full keys and field differences")
	record("wrong_state_key", divergence, driver)
	var rejected_trace: Dictionary = one.trace.duplicate(true)
	rejected_trace.steps[0].action = {"kind": 0, "face_axis": 1}
	check(Double.validate(one.level, rejected_trace).ok, "rejected action trace is structurally valid")
	var rejected: Dictionary = await driver.replay(one.level, rejected_trace, {})
	check(rejected.status == 1 and rejected.divergence_step == 1 and rejected.issues[0].code == 3015, "Runtime REJECTED is divergence")
	check(driver._step_evidence[0].commit_delta == 0, "rejected action never partially commits")
	record("runtime_rejected", rejected, driver)
	for fault in ["missing", "zero", "duplicate", "double_commit", "reset", "error", "error_budget"]:
		driver.fault = fault
		var fixture: Dictionary = multi if fault == "double_commit" else one
		var options := {"step_timeout_ms": 200}
		if fault == "error_budget":
			options.step_timeout_ms = 1
		var result: Dictionary = await driver.replay(fixture.level, fixture.trace, options)
		var expected := 3 if fault == "missing" else (2 if fault in ["reset", "error", "error_budget"] else 1)
		check(result.status == expected and result.matched_steps == 0 and result.divergence_step == 1, fault + ": fail closed without matching step")
		if fault == "double_commit":
			check(driver._step_evidence[0].commit_delta == 2, "two genuine commits detected")
		if fault == "reset":
			check(driver.stale.get("ignored", false), "old generation cannot commit after Reset")
		if fault in ["error", "error_budget"]:
			check(driver._step_evidence[0].commit_delta == 0 and result.issues[0].upstream[0].code == 1105, "ERROR preserves upstream and has no partial commit, even on timeout")
		record(fault, result, driver)
	driver.fault = "missing"
	var timed: Dictionary = await driver.replay(one.level, one.trace, {"max_runtime_ms": 50, "step_timeout_ms": 20000})
	check(timed.status == 3, "total wall clock budget stops missing callback")
	record("total_timeout", timed, driver)
	driver.fault = ""
	parallel_result = {}
	start_parallel(driver, multi)
	var original_session: Variant = driver._session
	var busy: Dictionary = await driver.replay(one.level, one.trace, {})
	check(busy.status == 2 and busy.issues[0].code == 3016 and driver._session == original_session, "reentrant request errors without replacing active session")
	while parallel_result.is_empty():
		await process_frame
	check(parallel_result.status == 0 and parallel_result.matched_steps == 3, "first replay completes unaffected by reentrant request")
	record("reentrancy_original", parallel_result, driver)
	var old_token: Dictionary = driver._token.duplicate(true)
	var old_session: Variant = driver._session
	var again: Dictionary = await driver.replay(one.level, one.trace, {})
	driver._finish_token(old_token.id, old_token.generation, old_token.is_global)
	check(again.status == 0 and driver._session != old_session and driver._session.commit_count == 1, "fresh run owns new Session and stale completion cannot add commits")
	record("fresh_session", again, driver)
	driver.fault = "missing"
	start_lifecycle(driver, one, "old")
	root.remove_child(driver)
	driver.fault = ""
	root.add_child(driver)
	start_lifecycle(driver, one, "new")
	while lifecycle_results.size() < 2:
		await process_frame
	check(lifecycle_results.old.status == 3, "removed run remains INCOMPLETE after immediate restart")
	check(lifecycle_results.new.status == 0 and driver._session.commit_count == 1, "cancelled coroutine cannot clean or consume replacement replay")
	record("remove_readd_new", lifecycle_results.new, driver)
	driver.free()
	var folder := "res://.godot/foundation-3d/headless"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			folder = argument.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var output := FileAccess.open(folder.path_join("headless_report.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "PROVISIONAL_TRACE_RECORD_ADAPTER_REAL_RUNTIME", "cases": evidence}, "\t"))
		output.close()
	print("FOUNDATION_PARITY_LOGICAL_", "PASS" if failures.is_empty() else "FAIL", " checks=", checks)
	if failures.is_empty():
		print("FOUNDATION_RUNTIME_PARITY_HEADLESS_PROVISIONAL_PASS")
	quit(0 if failures.is_empty() else 1)

func start_parallel(driver: TestDriver, fixture: Dictionary) -> void:
	parallel_result = await driver.replay(fixture.level, fixture.trace, {})

func start_lifecycle(driver: TestDriver, fixture: Dictionary, label: String) -> void:
	lifecycle_results[label] = await driver.replay(fixture.level, fixture.trace, {})

