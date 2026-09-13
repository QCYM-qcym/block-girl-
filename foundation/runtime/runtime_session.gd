extends RefCounted
## Scheduler only: all proposals and completion endpoints come from KernelPort.
const Port = preload("res://foundation/runtime/kernel_port.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Types = preload("res://foundation/contracts/foundation_types.gd")
# Private frozen execution.v1 wire values while rule_types.gd is unavailable.
const _APPLIED := 0
const _REJECTED := 1
const _ERROR := 2
signal committed(state: Dictionary)
signal transition_started(result: Dictionary, transaction_id: int, generation: int, is_global: bool)
signal feedback(result: Dictionary)
var state: Dictionary = {}
var level: Dictionary = {}
var context: Dictionary = {}
var transaction_id := 0
var generation := 0
var commit_count := 0
var last_result: Dictionary = {}
var ready := false
var is_loaded: bool:
	get: return ready
var _port: Variant
var _safety: Variant
var _serial := 0
var _local_id := 0
var _global_id := 0
var _local_result: Dictionary = {}
var _global_arrived := false

func _init(kernel_port: Variant = null, safety: Variant = null) -> void:
	_port = kernel_port if kernel_port != null else Port.new()
	_safety = safety
	if _safety == null and ResourceLoader.exists("res://foundation/validation/safety_queries.gd"):
		_safety = load("res://foundation/validation/safety_queries.gd")

func load_level(definition: Dictionary) -> Dictionary:
	generation += 1
	ready = false
	_clear_activity()
	var issues: Array = Data.validate_level_shape(definition)
	if not issues.is_empty():
		return {"ok": false, "issues": issues.duplicate(true)}
	if _safety == null or (_port.has_method("dependencies_ready") and not _port.dependencies_ready()):
		return {"ok": false, "issues": Port.unavailable_issues()}
	var candidate: Dictionary = Records.initial_state(definition)
	issues = Data.validate_state_shape(definition, candidate)
	if not issues.is_empty():
		return {"ok": false, "issues": issues.duplicate(true)}
	var safety_result: Dictionary = _safety.validate_state(definition.duplicate(true), candidate.duplicate(true))
	# Frozen SafetyStatus.SAFE wire value. Safety alone owns its enum and checks.
	if safety_result.get("status", -1) != 0 or not safety_result.get("issues", []).is_empty():
		return {"ok": false, "issues": safety_result.get("issues", Port.unavailable_issues()).duplicate(true)}
	level = definition.duplicate(true)
	state = candidate.duplicate(true)
	context = _port.idle_context().duplicate(true)
	commit_count = 0
	last_result = {}
	ready = true
	committed.emit(state.duplicate(true))
	return {"ok": true, "issues": []}

func request_action(action: Dictionary) -> Dictionary:
	if not ready:
		return _publish(Port.unavailable_transition(state, action))
	if _local_id != 0:
		return _publish({"status": _REJECTED, "previous_state": state.duplicate(true), "next_state": null,
			"action": action.duplicate(true), "changed": false, "rejection_code": Types.ValidationCode.GLOBAL_TRANSITION_BUSY,
			"issues": [], "global_kind": Types.GlobalTransitionKind.NONE})
	var result: Dictionary = _checked_transition(_port.evaluate_action(level, state, action, context), action)
	if result.status != _APPLIED or not result.changed:
		return _publish(result)
	# MOVE+ENTER stays one local proposal even when it has a global effect.
	var is_global: bool = result.global_kind != Types.GlobalTransitionKind.NONE and action.kind != Types.PuzzleActionKind.MOVE
	if is_global:
		var begun: Dictionary = _port.begin_global(level, result)
		if not begun.ok:
			var failed := Port.unavailable_transition(state, action)
			failed.issues = begun.issues.duplicate(true)
			return _publish(failed)
		context = begun.context.duplicate(true)
		_global_id = _next_id()
		transaction_id = _global_id
		_global_arrived = false
	else:
		_local_result = result.duplicate(true)
		_local_id = _next_id()
		transaction_id = _global_id if _global_id != 0 else _local_id
	var started_generation := generation
	var started_serial := _serial
	var started_global_id := _global_id
	var started_local_id := _local_id
	transition_started.emit(result.duplicate(true), _global_id if is_global else _local_id, generation, is_global)
	# A start observer can synchronously finish this very token without changing
	# generation/serial, so include its local identity in the continuation check.
	if _same_continuation(started_generation, started_serial, started_global_id) and _local_id == started_local_id:
		return _publish(result)
	return result.duplicate(true)

func finish_local(id: int, callback_generation: int) -> Dictionary:
	if callback_generation != generation or id == 0 or id != _local_id or not ready:
		return {"ignored": true, "transition": null}
	var result := _local_result.duplicate(true)
	var callback_serial := _serial
	var callback_global_id := _global_id
	_local_id = 0
	_local_result = {}
	_commit(result, _global_id != 0 and result.action.kind == Types.PuzzleActionKind.MOVE)
	# Signals are synchronous: observers may Reset/load, complete the global
	# transaction, or start a new transaction. Those operations own later feedback.
	if not _same_continuation(callback_generation, callback_serial, callback_global_id):
		return {"ignored": false, "transition": result.duplicate(true)}
	_publish(result)
	if _same_continuation(callback_generation, callback_serial, callback_global_id) and _global_arrived and _global_id != 0:
		finish_global(_global_id, generation)
	return {"ignored": false, "transition": result.duplicate(true)}

func finish_global(id: int, callback_generation: int) -> Dictionary:
	if callback_generation != generation or id == 0 or id != _global_id or not ready:
		return {"ignored": true, "transition": null}
	if _local_id != 0:
		_global_arrived = true
		return {"ignored": true, "transition": null}
	var result: Dictionary = _checked_transition(_port.complete_global(level, state, context), context.ticket.accepted_action)
	var callback_serial := _serial
	_clear_activity()
	if result.status == _APPLIED and result.changed:
		_commit(result)
	if _same_continuation(callback_generation, callback_serial, 0):
		_publish(result)
	return {"ignored": false, "transition": result.duplicate(true)}

func reset() -> void:
	generation += 1
	_clear_activity()
	if not ready:
		return
	state = Records.initial_state(level)
	commit_count = 0
	last_result = {}
	committed.emit(state.duplicate(true))

func _next_id() -> int:
	_serial += 1
	return _serial

func _commit(result: Dictionary, append_move: bool = false) -> void:
	state = result.next_state.duplicate(true)
	commit_count += 1
	if append_move:
		context.local_moves.append(result.action.duplicate(true))
	committed.emit(state.duplicate(true))

func _publish(result: Dictionary) -> Dictionary:
	last_result = result.duplicate(true)
	feedback.emit(result.duplicate(true))
	return result.duplicate(true)

func _clear_activity() -> void:
	_local_id = 0
	_global_id = 0
	_global_arrived = false
	_local_result = {}
	context = _port.idle_context().duplicate(true)

func _checked_transition(result: Dictionary, action: Dictionary) -> Dictionary:
	if result.get("status", _ERROR) != _APPLIED:
		return result.duplicate(true)
	var issues: Array = []
	if not result.get("next_state") is Dictionary:
		issues = [{"code": Types.ValidationCode.INVALID_TYPE, "severity": Types.ValidationSeverity.ERROR,
			"path": "result.next_state", "entity_ids": [], "message": "Kernel next_state must be a complete Dictionary.", "details": {}}]
	else:
		issues = Data.validate_state_shape(level, result.next_state)
	if issues.is_empty():
		return result.duplicate(true)
	return {"status": _ERROR, "previous_state": state.duplicate(true), "next_state": null,
		"action": action.duplicate(true), "changed": false, "rejection_code": 0,
		"issues": issues.duplicate(true), "global_kind": Types.GlobalTransitionKind.NONE}

func _same_continuation(callback_generation: int, callback_serial: int, callback_global_id: int) -> bool:
	return ready and generation == callback_generation and _serial == callback_serial and _global_id == callback_global_id

