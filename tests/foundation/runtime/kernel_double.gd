extends RefCounted
## TEST ONLY: finite prerecorded execution contract records. No geometry, mapping,
## light, permission, or orientation calculations. Unknown routes reject 1502.
const Records = preload("res://foundation/contracts/contract_records.gd")
var calls: Array = []
var override_result: Variant = null
var completion_result: Variant = null
var safety_result := {"status": 0, "issues": []} # Explicit test Safety stub.
var _results: Array = []

func queue_result(result: Dictionary) -> void:
	_results.append(result.duplicate(true))

func route_states(level: Dictionary) -> Array:
	var initial: Dictionary = Records.initial_state(level)
	var moved := initial.duplicate(true)
	moved.player = {"location": {"layer": 0, "cube_id": &"s1", "face": 4}, "orientation": 12}
	var rotated := moved.duplicate(true)
	rotated.world_orientations = [22, 0]
	rotated.player = {"location": {"layer": 0, "cube_id": &"s1", "face": 4}, "orientation": 15}
	var shifted := rotated.duplicate(true)
	shifted.player = {"location": {"layer": 1, "cube_id": &"i1", "face": 4}, "orientation": 15}
	return [initial, moved, rotated, shifted]

func idle_context() -> Dictionary:
	return {"global_transition_state": 0, "ticket": null, "local_moves": []}

func validate_state(level: Dictionary, state: Dictionary) -> Dictionary:
	calls.append({"method": "validate_state", "level": level.duplicate(true), "state": state.duplicate(true)})
	return safety_result.duplicate(true)

func evaluate_action(level: Dictionary, state: Dictionary, action: Dictionary, context: Dictionary) -> Dictionary:
	calls.append({"method": "evaluate_action", "level": level.duplicate(true), "state": state.duplicate(true), "action": action.duplicate(true), "context": context.duplicate(true)})
	if override_result != null:
		var result: Dictionary = override_result.duplicate(true)
		override_result = null
		return result
	if not _results.is_empty():
		return _results.pop_front().duplicate(true)
	var states := route_states(level)
	# Whole-state/action lookup: deliberately only these three prerecorded edges.
	var routes := [[states[0], {"kind": 0, "face_axis": 0}, states[1], 0],
		[states[1], {"kind": 2, "rotation_delta": 22}, states[2], 2],
		[states[2], {"kind": 1}, states[3], 4]]
	if context == idle_context():
		for route in routes:
			if state == route[0] and action == route[1]:
				return applied(state, route[2], action, route[3])
		if state == states[0] and action == {"kind": 1}:
			return rejected(state, action, 1404)
	return rejected(state, action, 1502)

func begin_global(level: Dictionary, result: Dictionary) -> Dictionary:
	calls.append({"method": "begin_global", "level": level.duplicate(true), "result": result.duplicate(true)})
	return {"ok": true, "context": {"global_transition_state": 1,
		"ticket": {"level_hash": level.content_hash, "base_state": result.previous_state.duplicate(true), "accepted_action": result.action.duplicate(true)},
		"local_moves": []}, "issues": []}

func complete_global(level: Dictionary, state: Dictionary, context: Dictionary) -> Dictionary:
	calls.append({"method": "complete_global", "level": level.duplicate(true), "state": state.duplicate(true), "context": context.duplicate(true)})
	if completion_result != null:
		return completion_result.duplicate(true)
	var states := route_states(level)
	if context.ticket.accepted_action == {"kind": 2, "rotation_delta": 22} and state == states[1] and context.local_moves == []:
		return applied(state, states[2], context.ticket.accepted_action, 2)
	if context.ticket.accepted_action == {"kind": 1} and state == states[2] and context.local_moves == []:
		return applied(state, states[3], context.ticket.accepted_action, 4)
	return rejected(state, context.ticket.accepted_action, 1502)

func is_goal(level: Dictionary, state: Dictionary) -> Dictionary:
	calls.append({"method": "is_goal", "level": level.duplicate(true), "state": state.duplicate(true)})
	return {"ok": true, "is_goal": state == route_states(level)[3], "issues": []}

static func applied(before: Dictionary, after: Dictionary, action: Dictionary, global_kind: int = 0) -> Dictionary:
	return {"status": 0, "previous_state": before.duplicate(true), "next_state": after.duplicate(true), "action": action.duplicate(true), "changed": before != after, "rejection_code": 0, "issues": [], "global_kind": global_kind}

static func rejected(before: Dictionary, action: Dictionary, code: int) -> Dictionary:
	return {"status": 1, "previous_state": before.duplicate(true), "next_state": null, "action": action.duplicate(true), "changed": false, "rejection_code": code, "issues": [], "global_kind": 0}

static func error(before: Dictionary, action: Dictionary) -> Dictionary:
	return {"status": 2, "previous_state": before.duplicate(true), "next_state": null, "action": action.duplicate(true), "changed": false, "rejection_code": 0, "issues": [{"severity": 0, "code": 1502, "path": "test_double", "entity_ids": [], "message": "Canned test error.", "details": {"reason": "canned error"}}], "global_kind": 0}

