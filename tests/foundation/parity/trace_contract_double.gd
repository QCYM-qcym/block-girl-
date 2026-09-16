extends RefCounted
## Narrow tests-only adapter for the frozen 3A Trace.validate contract.
## DEPENDENCY_PENDING: this is not the production Trace owner, a Solver, or a
## semantic replay. In particular, correct-key wrong expected states pass here.
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Goal = preload("res://foundation/rules/goal_evaluator.gd")
const Types = preload("res://foundation/contracts/foundation_types.gd")
const TRACE_FIELDS = ["trace_version", "level_hash", "rule_version", "policy_descriptor",
	"initial_state", "initial_statekey", "steps", "goal_statekey", "total_actions", "shortest"]
const STEP_FIELDS = ["index", "action", "expected_state", "resulting_statekey", "global_kind"]


static func validate(level: Dictionary, trace: Dictionary) -> Dictionary:
	var level_issues := Data.validate_level_shape(level)
	if not level_issues.is_empty():
		return _failure(3000, "level", "Invalid level DATA.", level_issues)
	var encoded := Codec.encode(level)
	if not encoded.ok:
		return _failure(3000, "level.content_hash", "Level identity is not authentic.", encoded.issues)
	if not _exact(trace, TRACE_FIELDS):
		return _invalid("trace", "Expected the frozen ten-field SolutionTrace record.")
	for field in ["trace_version", "level_hash", "rule_version", "initial_statekey", "goal_statekey"]:
		if typeof(trace[field]) != TYPE_STRING:
			return _invalid("trace." + field, "Expected String.")
	if trace.trace_version != "solutiontrace.v1" or trace.rule_version != level.rule_version:
		return _failure(3010, "trace", "Trace version or rule identity differs from the level.")
	if trace.level_hash != level.content_hash:
		return _invalid("trace.level_hash", "Trace level hash differs from the level.")
	if not _valid_policy(trace.policy_descriptor):
		return _invalid("trace.policy_descriptor", "Invalid frozen policy descriptor.")
	if not trace.initial_state is Dictionary or not trace.steps is Array:
		return _invalid("trace", "Expected a Dictionary initial_state and Array steps.")
	if typeof(trace.total_actions) != TYPE_INT or trace.total_actions != trace.steps.size():
		return _invalid("trace.total_actions", "Action count must equal the number of steps.")
	if typeof(trace.shortest) != TYPE_BOOL:
		return _invalid("trace.shortest", "Expected bool; this adapter does not prove shortestness.")
	var checked := _state_key(level, trace.initial_state, trace.initial_statekey, "trace.initial_state")
	if not checked.ok:
		return checked
	var last_state: Dictionary = trace.initial_state
	var last_key: String = trace.initial_statekey
	for i in trace.steps.size():
		var step: Variant = trace.steps[i]
		var path := "trace.steps[%d]" % i
		if not _exact(step, STEP_FIELDS):
			return _invalid(path, "Expected the frozen five-field trace step.")
		if typeof(step.index) != TYPE_INT or step.index != i + 1:
			return _invalid(path + ".index", "Step indices must start at one and be consecutive.")
		if not step.action is Dictionary or not step.expected_state is Dictionary:
			return _invalid(path, "Expected Dictionary action and expected_state.")
		if typeof(step.resulting_statekey) != TYPE_STRING:
			return _invalid(path + ".resulting_statekey", "Expected String.")
		if typeof(step.global_kind) != TYPE_INT or step.global_kind not in Types.GlobalTransitionKind.values():
			return _invalid(path + ".global_kind", "Invalid frozen global transition kind.")
		var action_issues := Data.validate_action_shape(level, step.action)
		if not action_issues.is_empty():
			return _failure(3008, path + ".action", "Invalid action DATA.", action_issues)
		checked = _state_key(level, step.expected_state, step.resulting_statekey, path + ".expected_state")
		if not checked.ok:
			return checked
		last_state = step.expected_state
		last_key = step.resulting_statekey
	if trace.goal_statekey != last_key:
		return _invalid("trace.goal_statekey", "Goal key must equal the final recorded state key.")
	var goal := Goal.is_goal(level, last_state)
	if not goal.ok:
		return _failure(3005, "trace.goal_statekey", "Official Goal evaluation failed.", goal.issues)
	if not goal.is_goal:
		return _invalid("trace.goal_statekey", "Final recorded state does not meet official Goal.")
	return {"ok": true, "issues": []}


static func _state_key(level: Dictionary, state: Dictionary, expected: String, path: String) -> Dictionary:
	var issues := Data.validate_state_shape(level, state)
	if not issues.is_empty():
		return _failure(3008, path, "Invalid state DATA.", issues)
	var result := Key.build(level, state)
	if not result.ok:
		return _failure(3006, path, "Official StateKey failed.", result.issues)
	if result.key != expected:
		return _invalid(path, "Recorded key differs from official StateKey.")
	return {"ok": true, "issues": []}


static func _valid_policy(value: Variant) -> bool:
	if not _exact(value, ["strategy", "mode", "validation_options", "filter_descriptor"]):
		return false
	if typeof(value.strategy) != TYPE_STRING_NAME or value.strategy != &"BFS":
		return false
	if typeof(value.mode) != TYPE_INT or value.mode not in [0, 1]:
		return false
	if not _exact(value.validation_options, ["max_configurations", "max_checks"]):
		return false
	for field in ["max_configurations", "max_checks"]:
		if typeof(value.validation_options[field]) != TYPE_INT or value.validation_options[field] <= 0:
			return false
	var filter: Variant = value.filter_descriptor
	if not _exact(filter, ["filter_id", "filter_version", "disabled_mechanics"]):
		return false
	if typeof(filter.filter_id) != TYPE_STRING_NAME or filter.filter_id not in [&"UNFILTERED", &"MECHANIC_ABLATION"]:
		return false
	if typeof(filter.filter_version) != TYPE_STRING or filter.filter_version != "1" or not filter.disabled_mechanics is Array:
		return false
	if filter.filter_id == &"UNFILTERED":
		return filter.disabled_mechanics.is_empty()
	if filter.disabled_mechanics.is_empty():
		return false
	var previous := -1
	for tag in filter.disabled_mechanics:
		# Specific MechanicTag taxonomy remains owned by 3C.
		if typeof(tag) != TYPE_INT or tag < 0 or tag <= previous:
			return false
		previous = tag
	return true


static func _exact(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size() or not value.has_all(fields):
		return false
	for key in value:
		if typeof(key) != TYPE_STRING:
			return false
	return true


static func _invalid(path: String, message: String) -> Dictionary:
	return _failure(3008, path, message)


static func _failure(code: int, path: String, message: String, upstream: Array = []) -> Dictionary:
	# Numeric AnalysisCode literals are confined to this tests-only adapter.
	# No new production enum or shared validation-code namespace is introduced.
	return {"ok": false, "issues": [{"code": code, "severity": Types.ValidationSeverity.ERROR,
		"path": path, "message": message, "details": {}, "upstream": upstream.duplicate(true)}]}
