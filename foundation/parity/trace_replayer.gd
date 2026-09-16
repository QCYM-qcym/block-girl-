extends Node
## Owns one isolated RuntimeSession per replay. It never executes rule logic itself.
const Types = preload("res://foundation/parity/parity_types.gd")
const Session = preload("res://foundation/runtime/runtime_session.gd")
const Presenter = preload("res://foundation/runtime/prototype_presenter.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Goal = preload("res://foundation/rules/goal_evaluator.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
const Validator = preload("res://foundation/validation/static_validator.gd")
const Status = Types.ParityStatus
const Mode = Types.ReplayMode
const _DEFAULTS = {"mode": 0, "max_steps": 10000, "max_runtime_ms": 0, "step_timeout_ms": 5000}
# Numeric analysis wire codes below consume the frozen contract; 3A owns the enum.
var _active := false
var _run_serial := 0
var _session: Variant
var _presenter: Node3D
var _step_evidence: Array = []
var _token: Dictionary = {}
var _options: Dictionary = {}
var _level: Dictionary = {}
var _started_at := 0
var _step_active := false
var _commit_signals := 0
var _completion_received := false
var _runtime_issues: Array = []
var _transition: Dictionary = {}
var _tweens: Array[Tween] = []
var _connections: Array = []

func _trace_api() -> Variant:
	var path := "res://foundation/solver/solution_trace.gd"
	return load(path) if ResourceLoader.exists(path) else null

func _make_session() -> Variant:
	return Session.new()

func replay(level: Dictionary, trace: Dictionary, options: Dictionary) -> Dictionary:
	var length := _trace_length(trace)
	if _active:
		return _result(Status.ERROR, length, 0, null, "", "", null,
			[_issue(3016, "replay", "This driver already has an active replay.")])
	_active = true
	_run_serial += 1
	var serial := _run_serial
	_started_at = Time.get_ticks_msec()
	_step_evidence.clear()
	_runtime_issues.clear()
	_token.clear()
	_transition.clear()
	_step_active = false
	_dispose_presenter()
	_session = null
	_options = _DEFAULTS.duplicate(true)
	for field in options:
		if typeof(field) != TYPE_STRING or not _DEFAULTS.has(field) or typeof(options[field]) != TYPE_INT:
			return _end(_result(Status.ERROR, length, 0, null, "", "", null,
				[_issue(3016, "options." + str(field), "Unknown option or non-integer value.")]))
		_options[field] = options[field]
	if not _options.mode in [Mode.LOGICAL_SESSION, Mode.GRAPHICAL] or _options.max_steps < 0 or _options.max_runtime_ms < 0 or _options.step_timeout_ms <= 0:
		return _end(_result(Status.ERROR, length, 0, null, "", "", null,
			[_issue(3016, "options", "Invalid replay mode or budget.")]))
	if not is_inside_tree():
		return _end(_result(Status.ERROR, length, 0, null, "", "", null,
			[_issue(3016, "replay", "Asynchronous replay requires a SceneTree.")]))
	_level = level.duplicate(true)
	var owned_trace := trace.duplicate(true)
	var api: Variant = _trace_api()
	if api == null:
		return _end(_result(Status.ERROR, length, 0, null, "", "", null,
			[_issue(3016, "dependencies.Trace", "DEPENDENCY_PENDING: real 3A SolutionTrace is unavailable.")]))
	var encoded: Dictionary = Codec.encode(_level)
	if not encoded.ok:
		return _end(_result(Status.ERROR, length, 0, null, "", "", null,
			[_issue(3000, "level", "Level identity or data is invalid.", {}, encoded.issues)]))
	if _expired():
		return _end(_result(Status.INCOMPLETE, length))
	var validation: Dictionary = Validator.validate(_level, {"max_configurations": 4096, "max_checks": 100000})
	if validation.status != 0:
		return _end(_result(Status.ERROR, length, 0, null, "", "", null,
			[_issue(3011 if validation.status == 2 else 3000, "level", "Static level validation did not establish VALID.", {}, validation.issues)]))
	if _expired():
		return _end(_result(Status.INCOMPLETE, length))
	var valid_trace: Dictionary = api.validate(_level, owned_trace)
	if not valid_trace.ok:
		return _end(_result(Status.ERROR, length, 0, null, "", "", null, valid_trace.issues))
	if _expired():
		return _end(_result(Status.INCOMPLETE, length))
	var spawn: Dictionary = Records.initial_state(_level)
	var spawn_key: Dictionary = Key.build(_level, spawn)
	if not spawn_key.ok:
		return _end(_result(Status.ERROR, length, 0, 0, "", "", null,
			[_issue(3006, "initial_state", "Cannot identify spawn.", {}, spawn_key.issues)]))
	if spawn_key.key != owned_trace.initial_statekey:
		return _end(_result(Status.ERROR, length, 0, 0, owned_trace.initial_statekey, spawn_key.key, null,
			[_issue(3013, "trace.initial_state", "Runtime supports only the official spawn state.", _differences(owned_trace.initial_state, spawn))]))
	if _expired():
		return _end(_result(Status.INCOMPLETE, length))
	_session = _make_session()
	_connect_owned(_session.transition_started, _on_transition_started)
	_connect_owned(_session.committed, _on_committed)
	_connect_owned(_session.feedback, _on_feedback)
	var loaded: Dictionary = _session.load_level(_level)
	if not loaded.ok:
		return _end(_result(Status.ERROR, length, 0, 0, owned_trace.initial_statekey, "", null,
			[_issue(3014, "runtime.load_level", "Runtime failed to load the validated level.", {}, loaded.issues)]))
	var initial: Dictionary = Key.build(_level, _session.state)
	if not initial.ok:
		return _end(_result(Status.ERROR, length, 0, 0, owned_trace.initial_statekey, "", null,
			[_issue(3006, "runtime.initial_state", "Cannot identify Runtime initial state.", {}, initial.issues)]))
	if initial.key != owned_trace.initial_statekey or _session.state != owned_trace.initial_state:
		return _end(_result(Status.DIVERGED, length, 0, 0, owned_trace.initial_statekey, initial.key, null,
			[_issue(3015, "runtime.initial_state", "Runtime initial state differs.", _differences(owned_trace.initial_state, _session.state))]))
	if _options.mode == Mode.GRAPHICAL:
		_presenter = Presenter.new()
		add_child(_presenter)
		var synced: Dictionary = _presenter.sync_state(_level, _session.state)
		if not synced.ok:
			return _end(_result(Status.ERROR, length, 0, 0, owned_trace.initial_statekey, initial.key, null,
				[_issue(3014, "presenter.sync_state", "Presenter could not display the initial state.", {}, synced.issues)]))
	if _expired():
		return _end(_result(Status.INCOMPLETE, length))
	var matched := 0
	for step in owned_trace.steps:
		if matched >= _options.max_steps or _expired():
			return _end(_result(Status.INCOMPLETE, length, matched))
		var outcome: Dictionary = await _replay_step(step, length, matched)
		# A removed/re-added driver may already own a new replay when this await
		# resumes. The obsolete coroutine must not clean up that newer session.
		if serial != _run_serial or not _active:
			return _result(Status.INCOMPLETE, length, matched)
		if outcome.status != Status.MATCH:
			return _end(outcome)
		matched += 1
	var goal: Dictionary = Goal.is_goal(_level, _session.state)
	if not goal.ok:
		return _end(_result(Status.ERROR, length, matched, null, "", "", null,
			[_issue(3005, "runtime.goal", "Final Goal evaluation failed.", {}, goal.issues)]))
	if not goal.is_goal:
		var final_key: Dictionary = Key.build(_level, _session.state)
		return _end(_result(Status.DIVERGED, length, matched, length, owned_trace.goal_statekey, final_key.key, null,
			[_issue(3015, "runtime.goal", "Runtime endpoint is not a Goal.")]))
	if _expired():
		return _end(_result(Status.INCOMPLETE, length, matched))
	var endpoint: Dictionary = Key.build(_level, _session.state)
	if not endpoint.ok:
		return _end(_result(Status.ERROR, length, matched, null, owned_trace.goal_statekey, "", null,
			[_issue(3006, "runtime.goal_statekey", "Cannot identify final Runtime state.", {}, endpoint.issues)]))
	if _expired():
		return _end(_result(Status.INCOMPLETE, length, matched))
	return _end(_result(Status.MATCH, length, matched, null, owned_trace.goal_statekey, endpoint.key))

func _replay_step(step: Dictionary, length: int, matched: int) -> Dictionary:
	var serial := _run_serial
	_step_active = true
	_commit_signals = 0
	_completion_received = false
	_token.clear()
	_transition.clear()
	_runtime_issues.clear()
	var baseline: int = _session.commit_count
	var generation: int = _session.generation
	var step_started := Time.get_ticks_msec()
	var requested: Dictionary = _session.request_action(step.action.duplicate(true))
	if requested.status == 2:
		_runtime_issues.append(_issue(3014, "runtime.request_action", "Runtime rejected execution with ERROR.", {}, requested.issues))
	# Signals and finish callbacks may run synchronously inside request_action.
	var settled := false
	while true:
		if serial != _run_serial or not _active or not is_inside_tree():
			return _result(Status.INCOMPLETE, length, matched)
		var actual: Dictionary = Key.build(_level, _session.state)
		var delta: int = _session.commit_count - baseline
		var details := {"commit_count_before": baseline, "commit_count_after": _session.commit_count,
			"commit_delta": delta, "commit_signals": _commit_signals, "generation_before": generation,
			"generation_after": _session.generation, "state_differences": _differences(step.expected_state, _session.state)}
		var status := -1
		var issues: Array = []
		if not _runtime_issues.is_empty():
			status = Status.ERROR
			issues = _runtime_issues.duplicate(true)
		elif not actual.ok:
			status = Status.ERROR
			issues = [_issue(3006, "runtime.state", "Runtime state identity failed.", details, actual.issues)]
		elif _session.generation != generation:
			status = Status.ERROR
			issues = [_issue(3014, "runtime.generation", "Replay session was reset during a step.", details)]
		elif requested.status == 1:
			status = Status.DIVERGED
			issues = [_issue(3015, "runtime.request_action", "Runtime rejected the trace action.", details, requested.issues)]
		elif delta > 1 or _commit_signals > 1 or (_commit_signals > 0 and delta != 1) or (_completion_received and delta != 1) or not requested.changed:
			status = Status.DIVERGED
			issues = [_issue(3015, "runtime.commit_count", "Each trace step must commit exactly once.", details)]
		elif _expired() or Time.get_ticks_msec() - step_started >= _options.step_timeout_ms:
			status = Status.INCOMPLETE
		elif _completion_received and delta == 1 and _commit_signals == 1 and _is_idle():
			# Observe a full idle frame before allowing another trace action.
			if settled:
				if actual.key != step.resulting_statekey or _session.state != step.expected_state or _transition.get("global_kind", -1) != step.global_kind:
					status = Status.DIVERGED
					details["expected_global_kind"] = step.global_kind
					details["actual_global_kind"] = _transition.get("global_kind", -1)
					issues = [_issue(3015, "trace.steps[%d]" % (step.index - 1), "Runtime endpoint differs from the trace.", details)]
				else:
					status = Status.MATCH
			else:
				settled = true
		else:
			settled = false
		if status != -1:
			_step_active = false
			_step_evidence.append({"index": step.index, "action": step.action.duplicate(true),
				"expected_statekey": step.resulting_statekey, "actual_statekey": actual.get("key", ""),
				"commit_delta": delta, "commit_signals": _commit_signals, "commit_count_before": baseline,
				"commit_count_after": _session.commit_count, "is_global": _token.get("is_global", false),
				"global_kind": _transition.get("global_kind", -1), "state_differences": details.state_differences,
				"status": status})
			return _result(status, length, matched, step.index if status != Status.MATCH else null,
				step.resulting_statekey if status != Status.MATCH else "", actual.get("key", "") if status != Status.MATCH else "",
				step.action if status != Status.MATCH else null, issues)
		await get_tree().process_frame
	return _result(Status.ERROR, length, matched)

func _on_transition_started(result: Dictionary, id: int, generation: int, is_global: bool) -> void:
	if not _active or not _step_active:
		return
	_token = {"id": id, "generation": generation, "is_global": is_global}
	_transition = result.duplicate(true)
	if _options.mode == Mode.LOGICAL_SESSION:
		_finish_token(id, generation, is_global)
		return
	var animation: Dictionary = _presenter.animate_transition(_level, result, 0.30)
	if not animation.ok:
		_runtime_issues.append(_issue(3014, "presenter.animate_transition", "Presenter could not animate the step.", {}, animation.issues))
		return
	var tween: Tween = animation.tween
	_tweens.append(tween)
	var serial := _run_serial
	_connect_owned(tween.finished, func() -> void:
		if _active and serial == _run_serial:
			_finish_token(id, generation, is_global))

func _finish_token(id: int, generation: int, is_global: bool) -> void:
	if not _active or not _step_active or _session == null or _token.get("id", 0) != id or _token.get("generation", -1) != generation or _session.generation != generation:
		return
	var serial := _run_serial
	var owned: RefCounted = _session
	var completed: Dictionary = owned.finish_global(id, generation) if is_global else owned.finish_local(id, generation)
	if serial != _run_serial or not _active or _session != owned:
		return
	_completion_received = true
	var transition: Variant = completed.get("transition")
	if transition is Dictionary and transition.get("status", 2) == 2:
		_runtime_issues.append(_issue(3014, "runtime.finish", "Runtime completion returned ERROR.", {}, transition.get("issues", [])))

func _on_committed(_state: Dictionary) -> void:
	if not _active or not _step_active:
		return
	_commit_signals += 1
	if is_instance_valid(_presenter):
		var synced: Dictionary = _presenter.sync_state(_level, _session.state)
		if not synced.ok:
			_runtime_issues.append(_issue(3014, "presenter.sync_state", "Presenter could not display the committed state.", {}, synced.issues))
		_presenter.clear_previews()

func _on_feedback(result: Dictionary) -> void:
	if _active and _step_active and result.get("status", 2) == 2:
		_runtime_issues.append(_issue(3014, "runtime.feedback", "Runtime reported ERROR.", {}, result.get("issues", [])))

func _is_idle() -> bool:
	return _session.context == {"global_transition_state": 0, "ticket": null, "local_moves": []}

func _expired() -> bool:
	return _options.max_runtime_ms > 0 and Time.get_ticks_msec() - _started_at >= _options.max_runtime_ms

func _connect_owned(signal_value: Signal, callback: Callable) -> void:
	signal_value.connect(callback)
	_connections.append([signal_value, callback])

func _end(result: Dictionary) -> Dictionary:
	_step_active = false
	for connection in _connections:
		var signal_value: Signal = connection[0]
		if not signal_value.is_null() and signal_value.is_connected(connection[1]):
			signal_value.disconnect(connection[1])
	_connections.clear()
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	if is_instance_valid(_presenter):
		_presenter.clear_previews()
	if result.status != Status.MATCH and _session != null:
		_session.reset()
	_active = false
	return result.duplicate(true)

func _dispose_presenter() -> void:
	if is_instance_valid(_presenter):
		_presenter.free()
	_presenter = null

func _exit_tree() -> void:
	if _active:
		_end(_result(Status.INCOMPLETE, 0))

static func _trace_length(trace: Dictionary) -> int:
	return trace.steps.size() if trace.get("steps") is Array else 0

static func _result(status: int, length: int, matched: int = 0, divergence: Variant = null, expected: String = "", actual: String = "", action: Variant = null, issues: Array = []) -> Dictionary:
	return {"status": status, "trace_length": length, "matched_steps": matched,
		"divergence_step": divergence, "expected_statekey": expected, "actual_statekey": actual,
		"action": action.duplicate(true) if action is Dictionary else null, "issues": issues.duplicate(true)}

static func _issue(code: int, path: String, message: String, details: Dictionary = {}, upstream: Array = []) -> Dictionary:
	return {"code": code, "severity": 0, "path": path, "message": message,
		"details": details.duplicate(true), "upstream": upstream.duplicate(true)}

static func _differences(expected: Variant, actual: Variant, path: String = "state") -> Dictionary:
	var differences: Dictionary = {}
	if typeof(expected) != typeof(actual):
		differences[path] = {"expected": expected, "actual": actual}
	elif expected is Dictionary:
		for field in expected:
			if not actual.has(field):
				differences[path + "." + str(field)] = {"expected": expected[field], "actual": null}
			else:
				differences.merge(_differences(expected[field], actual[field], path + "." + str(field)))
		for field in actual:
			if not expected.has(field):
				differences[path + "." + str(field)] = {"expected": null, "actual": actual[field]}
	elif expected is Array:
		if expected.size() != actual.size():
			differences[path] = {"expected": expected, "actual": actual}
		else:
			for index in expected.size():
				differences.merge(_differences(expected[index], actual[index], "%s[%d]" % [path, index]))
	elif expected != actual:
		differences[path] = {"expected": expected, "actual": actual}
	return differences

