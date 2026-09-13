extends RefCounted
## Thin, fail-closed port. Defaults load only the real rule modules; tests may
## explicitly inject dependencies. This adapter contains no puzzle rules.
const Types = preload("res://foundation/contracts/foundation_types.gd")
var _kernel: Variant
var _records: Variant
var _goal: Variant

func _init(kernel: Variant = null, records: Variant = null, goal: Variant = null) -> void:
	_kernel = kernel if kernel != null else _real("res://foundation/rules/puzzle_rule_kernel.gd")
	_records = records if records != null else _real("res://foundation/rules/rule_records.gd")
	_goal = goal if goal != null else _real("res://foundation/rules/goal_evaluator.gd")

func dependencies_ready() -> bool:
	return _kernel != null and _records != null and _goal != null

func evaluate_action(level: Dictionary, state: Dictionary, action: Dictionary, context: Dictionary) -> Dictionary:
	if _kernel == null:
		return unavailable_transition(state, action)
	return _kernel.evaluate_action(level.duplicate(true), state.duplicate(true), action.duplicate(true), context.duplicate(true)).duplicate(true)

func complete_global(level: Dictionary, state: Dictionary, context: Dictionary) -> Dictionary:
	if _kernel == null:
		var ticket: Variant = context.get("ticket", null)
		return unavailable_transition(state, ticket.get("accepted_action", {}) if ticket is Dictionary else {})
	return _kernel.complete_global(level.duplicate(true), state.duplicate(true), context.duplicate(true)).duplicate(true)

func begin_global(level: Dictionary, result: Dictionary) -> Dictionary:
	if _records == null:
		return {"ok": false, "context": null, "issues": unavailable_issues()}
	return _records.begin_global(level.duplicate(true), result.duplicate(true)).duplicate(true)

func idle_context() -> Dictionary:
	if _records == null:
		# Frozen empty execution record; this supplies no rule authorization.
		return {"global_transition_state": Types.GlobalTransitionState.IDLE, "ticket": null, "local_moves": []}
	return _records.idle_context().duplicate(true)

func is_goal(level: Dictionary, state: Dictionary) -> Dictionary:
	if _goal == null:
		return {"ok": false, "is_goal": null, "issues": unavailable_issues()}
	return _goal.is_goal(level.duplicate(true), state.duplicate(true)).duplicate(true)

static func unavailable_issues() -> Array:
	return [{"severity": Types.ValidationSeverity.ERROR, "code": Types.ValidationCode.VALIDATION_INCOMPLETE,
		"path": "runtime.dependencies", "entity_ids": [], "message": "Runtime dependencies unavailable.", "details": {"reason": "Required real Kernel, RuleRecords, Goal or Safety module is unavailable."}}]

static func unavailable_transition(state: Dictionary, action: Dictionary) -> Dictionary:
	# Frozen execution.v1 ERROR wire value; rule_types.gd is not yet available.
	return {"status": 2, "previous_state": state.duplicate(true), "next_state": null,
		"action": action.duplicate(true), "changed": false, "rejection_code": 0,
		"issues": unavailable_issues(), "global_kind": Types.GlobalTransitionKind.NONE}

static func _real(path: String) -> Variant:
	if not ResourceLoader.exists(path):
		return null
	var script = load(path)
	return script if script != null and script.can_instantiate() else null


