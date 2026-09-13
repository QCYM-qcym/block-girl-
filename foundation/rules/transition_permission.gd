extends RefCounted
## Busy admission proves both serial orders and the complete concurrent sweep.
## Callables point to Kernel's idle/trusted transaction path, avoiding preload cycles.
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Math = preload("res://foundation/orientation/discrete_orientation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Rules = preload("res://foundation/rules/rule_records.gd")
const RuleTypes = preload("res://foundation/rules/rule_types.gd")
const Derived = preload("res://foundation/rules/derived_state_resolver.gd")
const Connectivity = preload("res://foundation/rules/connectivity_resolver.gd")
const Effects = preload("res://foundation/rules/mechanism_effects.gd")
const Code = Types.ValidationCode
const Kind = Types.PuzzleActionKind


static func evaluate(level: Dictionary, state: Dictionary, action: Dictionary, context: Dictionary, evaluate_idle: Callable, evaluate_trusted: Callable, safety: Script) -> Dictionary:
	var replay := _replay(level, state, context, evaluate_idle, evaluate_trusted, safety)
	if not replay.ok:
		return Rules.error(state, action, replay.issues)
	if action.kind != Kind.MOVE:
		return Rules.rejected(state, action, Code.GLOBAL_TRANSITION_BUSY)
	var proof := _prove(level, state, replay.after_global, action, context.ticket.accepted_action, evaluate_idle, evaluate_trusted, safety)
	if not proof.ok:
		return proof.result
	return Rules.applied(state, proof.after_local, action)


static func complete(level: Dictionary, state: Dictionary, context: Dictionary, evaluate_idle: Callable, evaluate_trusted: Callable, safety: Script) -> Dictionary:
	var replay := _replay(level, state, context, evaluate_idle, evaluate_trusted, safety)
	if not replay.ok:
		return Rules.error(state, context.ticket.accepted_action, replay.issues)
	return Rules.applied(state, replay.after_global, context.ticket.accepted_action, replay.global_kind)


static func _replay(level: Dictionary, state: Dictionary, context: Dictionary, evaluate_idle: Callable, evaluate_trusted: Callable, safety: Script) -> Dictionary:
	var ticket: Dictionary = context.ticket
	var granted: Dictionary = evaluate_idle.call(level, ticket.base_state, ticket.accepted_action)
	if granted.status == RuleTypes.TransitionStatus.ERROR:
		return {"ok": false, "issues": granted.issues.duplicate(true)}
	if granted.status != RuleTypes.TransitionStatus.APPLIED or not Rules.begin_global(level, granted).ok:
		return _invalid_trace("Ticket action cannot be re-authorized from its original base.")
	var before: Dictionary = ticket.base_state.duplicate(true)
	var after_global: Dictionary = granted.next_state.duplicate(true)
	for local_action in context.local_moves:
		var proof := _prove(level, before, after_global, local_action, ticket.accepted_action, evaluate_idle, evaluate_trusted, safety)
		if not proof.ok:
			if proof.result.status == RuleTypes.TransitionStatus.ERROR:
				return {"ok": false, "issues": proof.result.issues.duplicate(true)}
			return _invalid_trace("Recorded MOVE is not a permitted committed busy MOVE.")
		before = proof.after_local
		after_global = proof.after_both
	var expected := Key.build(level, before)
	var actual := Key.build(level, state)
	if not expected.ok or not actual.ok:
		return {"ok": false, "issues": expected.issues + actual.issues}
	if expected.key != actual.key:
		return _invalid_trace("Ticket base plus committed MOVE trace does not equal the current state.")
	return {"ok": true, "after_global": after_global, "global_kind": granted.global_kind, "issues": []}


static func _prove(level: Dictionary, before: Dictionary, after_global: Dictionary, local_action: Dictionary, accepted: Dictionary, evaluate_idle: Callable, evaluate_trusted: Callable, safety: Script) -> Dictionary:
	var connection := Connectivity.query_move(level, before, local_action.face_axis)
	if not connection.ok:
		return _failed(Rules.error(before, local_action, connection.issues))
	if connection.target_location == null:
		return _failed(Rules.rejected(before, local_action, RuleTypes.ActionRejectionCode.MOVE_BLOCKED))
	var source_id := _face(before.player.location)
	var target_id := _face(connection.target_location)
	if source_id == level.goal.face_id or target_id == level.goal.face_id or not Effects.enter_effects(level, source_id, target_id).is_empty():
		return _not_commutative(before, local_action)
	var effect := _effective_action(level, accepted)
	if effect.kind == Kind.LOCAL_GROUP_ROTATE:
		var group: Dictionary = {}
		for record in level.groups:
			if record.group_id == effect.group_id:
				group = record
		if group.cube_ids.has(before.player.location.cube_id) != group.cube_ids.has(connection.target_location.cube_id):
			return _not_commutative(before, local_action)
	var local_result: Dictionary = evaluate_idle.call(level, before, local_action)
	if local_result.status != RuleTypes.TransitionStatus.APPLIED:
		return _failed(local_result)
	# Reapply only the already-granted transaction, retaining its original authority.
	var global_after_local: Dictionary = evaluate_trusted.call(level, local_result.next_state, accepted)
	if global_after_local.status != RuleTypes.TransitionStatus.APPLIED:
		return _failed(Rules.error(before, local_action, global_after_local.issues)) if global_after_local.status == RuleTypes.TransitionStatus.ERROR else _not_commutative(before, local_action)
	var delta := Math.compose(after_global.player.orientation, Math.inverse(before.player.orientation))
	var direction := Math.apply(delta, connection.direction)
	var snapshot := Derived.snapshot(level, after_global)
	if not snapshot.ok:
		return _failed(Rules.error(before, local_action, snapshot.issues))
	var source_after: Dictionary = {}
	for anchor in snapshot.value.anchors:
		if anchor.face_id == _face(after_global.player.location):
			source_after = anchor
	var frame: Dictionary = source_after.frame
	var axes: Array[Vector3i] = [frame.u, frame.v, -frame.u, -frame.v]
	var mapped_axis := axes.find(direction)
	if mapped_axis < 0:
		return _not_commutative(before, local_action)
	var mapped_action := {"kind": Kind.MOVE, "face_axis": mapped_axis}
	var mapped_connection := Connectivity.query_move(level, after_global, mapped_axis)
	if not mapped_connection.ok:
		return _failed(Rules.error(before, local_action, mapped_connection.issues))
	if mapped_connection.target_location == null:
		return _not_commutative(before, local_action)
	var mapped_source := _face(after_global.player.location)
	var mapped_target := _face(mapped_connection.target_location)
	if mapped_source == level.goal.face_id or mapped_target == level.goal.face_id or not Effects.enter_effects(level, mapped_source, mapped_target).is_empty():
		return _not_commutative(before, local_action)
	var local_after_global: Dictionary = evaluate_idle.call(level, after_global, mapped_action)
	if local_after_global.status != RuleTypes.TransitionStatus.APPLIED:
		return _failed(Rules.error(before, local_action, local_after_global.issues)) if local_after_global.status == RuleTypes.TransitionStatus.ERROR else _not_commutative(before, local_action)
	var first := Key.build(level, global_after_local.next_state)
	var second := Key.build(level, local_after_global.next_state)
	if not first.ok or not second.ok:
		return _failed(Rules.error(before, local_action, first.issues + second.issues))
	if first.key != second.key:
		return _not_commutative(before, local_action)
	var concurrent := Rules.checked_safety(safety.validate_concurrent_motion(level, before, local_result.next_state, after_global, local_action, effect))
	if concurrent.status != 0:
		var is_error: bool = concurrent.status == 3
		for diagnostic in concurrent.issues:
			is_error = is_error or diagnostic.code == Code.ARITHMETIC_OVERFLOW
		if is_error:
			return _failed(Rules.error(before, local_action, concurrent.issues))
		return _failed(Rules.rejected(before, local_action, Code.MOVE_NOT_COMMUTATIVE, concurrent.issues))
	return {"ok": true, "after_local": local_result.next_state, "after_both": global_after_local.next_state}


static func _effective_action(level: Dictionary, accepted: Dictionary) -> Dictionary:
	if accepted.kind == Kind.TRIGGER_MECHANISM:
		for mechanism in level.mechanisms:
			if mechanism.mechanism_id == accepted.mechanism_id:
				return mechanism.action
	return accepted


static func _face(location: Dictionary) -> StringName:
	return Geometry.face_id(location.cube_id, location.face)


static func _failed(result: Dictionary) -> Dictionary:
	return {"ok": false, "result": result}


static func _not_commutative(state: Dictionary, action: Dictionary) -> Dictionary:
	return _failed(Rules.rejected(state, action, Code.MOVE_NOT_COMMUTATIVE))


static func _invalid_trace(message: String) -> Dictionary:
	return {"ok": false, "issues": [Rules.issue(Code.INVALID_ACTION, "context.ticket", message)]}
