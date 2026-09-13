extends RefCounted
## Pure atomic action evaluation. Only complete next_state values leave this module.
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Math = preload("res://foundation/orientation/discrete_orientation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Celestial = preload("res://foundation/celestial/celestial_rules.gd")
const Rules = preload("res://foundation/rules/rule_records.gd")
const RuleTypes = preload("res://foundation/rules/rule_types.gd")
const Derived = preload("res://foundation/rules/derived_state_resolver.gd")
const Connectivity = preload("res://foundation/rules/connectivity_resolver.gd")
const Effects = preload("res://foundation/rules/mechanism_effects.gd")
const Permission = preload("res://foundation/rules/transition_permission.gd")
const Safety = preload("res://foundation/validation/safety_queries.gd")
const Kind = Types.PuzzleActionKind
const Global = Types.GlobalTransitionKind
const Code = Types.ValidationCode
const Reject = RuleTypes.ActionRejectionCode


static func evaluate_action(level: Dictionary, state: Dictionary, action: Dictionary, context: Dictionary) -> Dictionary:
	var issues := _shape(level, state, action)
	if issues.is_empty():
		issues = Rules.context_issues(level, context)
	if not issues.is_empty():
		return Rules.error(state, action, issues)
	var current := _current(level, state, action)
	if not current.is_empty():
		return current
	if context.global_transition_state != Types.GlobalTransitionState.IDLE:
		return Permission.evaluate(level, state, action, context, _evaluate_idle, _evaluate_trusted, Safety)
	return _evaluate_idle(level, state, action)


static func complete_global(level: Dictionary, state: Dictionary, context: Dictionary) -> Dictionary:
	var action: Dictionary = {}
	if context.get("ticket") is Dictionary and context.ticket.get("accepted_action") is Dictionary:
		action = context.ticket.accepted_action
	var issues := Data.validate_state_shape(level, state)
	if issues.is_empty():
		issues = Rules.context_issues(level, context)
	if issues.is_empty() and context.global_transition_state == Types.GlobalTransitionState.IDLE:
		issues.append(Rules.issue(Code.INVALID_ACTION, "context", "No accepted global transaction to complete."))
	if not issues.is_empty():
		return Rules.error(state, action, issues)
	var current := _current(level, state, action)
	if not current.is_empty():
		return current
	return Permission.complete(level, state, context, _evaluate_idle, _evaluate_trusted, Safety)


static func _shape(level: Dictionary, state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var issues := Data.validate_level_shape(level)
	if issues.is_empty():
		issues = Data.validate_state_shape(level, state)
	if issues.is_empty():
		issues = Data.validate_action_shape(level, action)
	return issues


static func _current(level: Dictionary, state: Dictionary, action: Dictionary) -> Dictionary:
	var snapshot := Derived.snapshot(level, state)
	if not snapshot.ok:
		return Rules.error(state, action, snapshot.issues)
	var safety := Rules.checked_safety(Safety.validate_state(level, state))
	if safety.status != 0:
		return Rules.error(state, action, safety.issues)
	return {}


static func _evaluate_idle(level: Dictionary, state: Dictionary, action: Dictionary) -> Dictionary:
	return _transaction(level, state, action, false, &"USE", true)


static func _evaluate_trusted(level: Dictionary, state: Dictionary, action: Dictionary) -> Dictionary:
	# Only Permission invokes this after recomputing the original ticket grant.
	return _transaction(level, state, action, true, &"USE", false)


static func _transaction(level: Dictionary, state: Dictionary, action: Dictionary, granted: bool, trigger: StringName, allow_enter: bool) -> Dictionary:
	var issues := _shape(level, state, action)
	if not issues.is_empty():
		return Rules.error(state, action, issues)
	var current := _current(level, state, action)
	if not current.is_empty():
		return current
	issues = _profile(level)
	if not issues.is_empty():
		return Rules.error(state, action, issues)
	var effect := action.duplicate(true)
	if action.kind in [Kind.TRIGGER_MECHANISM, Kind.LOCAL_GROUP_ROTATE, Kind.MOVE_CELESTIAL]:
		if not granted:
			var authorization := Effects.authorize(level, state, action, trigger)
			if not authorization.ok:
				return Rules.rejected(state, action, Code.UNAUTHORIZED_MECHANISM, authorization.issues)
			effect = authorization.effect
		elif action.kind == Kind.TRIGGER_MECHANISM:
			effect = _find(level.mechanisms, "mechanism_id", action.mechanism_id).action.duplicate(true)
	var candidate := state.duplicate(true)
	var global_kind := Global.NONE
	var rejection := Reject.ROTATION_STATE_INVALID
	match effect.kind:
		Kind.MOVE:
			rejection = Reject.MOVE_BLOCKED
			var move := Connectivity.query_move(level, state, effect.face_axis)
			if not move.ok:
				return Rules.error(state, action, move.issues)
			if move.target_location == null:
				return Rules.rejected(state, action, Reject.MOVE_BLOCKED)
			var snapshot := Derived.snapshot(level, state)
			var source := _find(snapshot.value.anchors, "face_id", _face(state))
			var axis := _cross(source.frame.normal, move.direction)
			var delta := _quarter_axis(axis)
			candidate.player.location = move.target_location.duplicate(true)
			candidate.player.orientation = Math.compose(delta, state.player.orientation)
		Kind.SHIFT_WORLD:
			global_kind = Global.SHIFT
			var mapping := Derived.shift_mapping(level, state)
			if mapping.status == Types.MappingResolutionStatus.NONE:
				return Rules.rejected(state, action, Code.NO_SHIFT_MAPPING, mapping.issues)
			if mapping.status in [Types.MappingResolutionStatus.AMBIGUOUS, Types.MappingResolutionStatus.ERROR]:
				return Rules.error(state, action, mapping.issues)
			var source_face := _find(level.faces, "face_id", mapping.mapping.source_face)
			var target_face := _find(level.faces, "face_id", mapping.mapping.target_face)
			if source_face.shift_exit_blocked:
				return Rules.rejected(state, action, Code.SHIFT_EXIT_BLOCKED)
			if target_face.shift_entry_blocked:
				return Rules.rejected(state, action, Code.SHIFT_ENTRY_BLOCKED)
			if state.player.location.layer == Types.WorldLayer.SURFACE:
				var light := Derived.light(level, state, source_face.face_id)
				if not light.ok:
					return Rules.error(state, action, light.issues)
				if light.light_state != Types.LightState.SHADOW:
					return Rules.rejected(state, action, Code.SHIFT_REQUIRES_SHADOW)
			var snapshot := Derived.snapshot(level, state)
			var target := _find(snapshot.value.anchors, "face_id", target_face.face_id)
			candidate.player.location = {"layer": target.layer, "cube_id": target_face.cube_id, "face": target_face.face}
			if mapping.mapping.compatibility == Types.FaceCompatibility.OPPOSITE_NORMAL:
				var source := _find(snapshot.value.anchors, "face_id", source_face.face_id)
				candidate.player.orientation = Math.reframe(_frame_id(source.frame), _frame_id(target.frame), state.player.orientation)
		Kind.ROTATE_SURFACE, Kind.ROTATE_INNER:
			global_kind = Global.WORLD_ROTATION
			var layer := Types.WorldLayer.SURFACE if effect.kind == Kind.ROTATE_SURFACE else Types.WorldLayer.INNER
			var world := _find(level.worlds, "layer", layer)
			var target := Math.compose(effect.rotation_delta, state.world_orientations[layer])
			if not world.allowed_rotation_deltas.has(effect.rotation_delta) or not world.allowed_states.has(target):
				return Rules.rejected(state, action, Reject.ROTATION_NOT_ALLOWED)
			candidate.world_orientations[layer] = target
			if state.player.location.layer == layer:
				candidate.player.orientation = Math.compose(effect.rotation_delta, state.player.orientation)
		Kind.LOCAL_GROUP_ROTATE:
			global_kind = Global.GROUP_ROTATION
			var group := _find(level.groups, "group_id", effect.group_id)
			var old: int = state.group_orientations[effect.group_id]
			var target := Math.compose(effect.rotation_delta, old)
			var edge_found := false
			for edge in group.edges:
				if edge.from_orientation == old and edge.rotation_delta == effect.rotation_delta and edge.to_orientation == target:
					edge_found = true
			if not group.allowed_rotation_deltas.has(effect.rotation_delta) or not group.allowed_states.has(target) or not edge_found:
				return Rules.rejected(state, action, Reject.ROTATION_NOT_ALLOWED)
			candidate.group_orientations[effect.group_id] = target
			if group.cube_ids.has(state.player.location.cube_id):
				var world: int = state.world_orientations[group.layer]
				var delta := Math.compose(Math.compose(world, effect.rotation_delta), Math.inverse(world))
				candidate.player.orientation = Math.compose(delta, state.player.orientation)
		Kind.USE_FACE_TRANSITION:
			global_kind = Global.FACE_TRANSITION
			rejection = Reject.FACE_TRANSITION_NOT_AVAILABLE
			var transition := _find(level.face_transitions, "transition_id", effect.transition_id)
			if _face(state) != transition.source_face_id:
				return Rules.rejected(state, action, rejection)
			for flag in transition.required_flags:
				if not state.level_flags[flag]:
					return Rules.rejected(state, action, rejection)
			var snapshot := Derived.snapshot(level, state)
			var cube := _find(snapshot.value.cubes, "cube_id", state.player.location.cube_id)
			var target_face := _find(level.faces, "face_id", transition.target_face_id)
			for step in transition.rotation_steps:
				var delta := Math.compose(Math.compose(cube.orientation, step), Math.inverse(cube.orientation))
				candidate.player.orientation = Math.compose(delta, candidate.player.orientation)
			candidate.player.location.face = target_face.face
		Kind.MOVE_CELESTIAL:
			global_kind = Global.CELESTIAL
			var slot := Celestial.resolve_slot_request(level.celestial, state.celestial.slot_id, effect.celestial_op, effect.target_slot_id, effect.alternate_slot_id)
			if not slot.ok:
				var only_step: bool = not slot.issues.is_empty()
				for diagnostic in slot.issues:
					only_step = only_step and diagnostic.code == Code.SLOT_STEP_UNAVAILABLE
				return Rules.rejected(state, action, Code.SLOT_STEP_UNAVAILABLE, slot.issues) if only_step else Rules.error(state, action, slot.issues)
			candidate.celestial.slot_id = slot.next_slot_id
	# Never feed a partial/failed spatial result to Safety or Lighting.
	var completed := _finish_candidate(level, state, candidate, action, effect, global_kind, rejection)
	if completed.status != RuleTypes.TransitionStatus.APPLIED:
		return completed
	var entered := Effects.enter_effects(level, _face(state), _face(candidate))
	if effect.kind in [Kind.SHIFT_WORLD, Kind.USE_FACE_TRANSITION] and not entered.is_empty():
		return Rules.error(state, action, [Rules.issue(Code.INVALID_ACTION, "mechanisms", "Global entry cannot chain an ENTER effect.")])
	if effect.kind == Kind.MOVE and allow_enter and not entered.is_empty():
		if entered.size() > 1:
			return Rules.error(state, action, [Rules.issue(Code.MULTIPLE_GLOBAL_MUTATIONS, "mechanisms", "One MOVE cannot accept multiple global effects.")])
		var applied_effect := _transaction(level, candidate, entered[0].action, false, &"ENTER", false)
		if applied_effect.status == RuleTypes.TransitionStatus.ERROR:
			return Rules.error(state, action, applied_effect.issues)
		if applied_effect.status == RuleTypes.TransitionStatus.REJECTED:
			return Rules.rejected(state, action, applied_effect.rejection_code, applied_effect.issues)
		return Rules.applied(state, applied_effect.next_state, action, applied_effect.global_kind)
	return completed


static func _finish_candidate(level: Dictionary, state: Dictionary, candidate: Dictionary, action: Dictionary, effect: Dictionary, global_kind: int, rejection: int) -> Dictionary:
	var snapshot := Derived.snapshot(level, candidate)
	if not snapshot.ok:
		return Rules.error(state, action, snapshot.issues)
	var safety := Rules.checked_safety(Safety.validate_state(level, candidate))
	if safety.status != 0:
		return _safety_failure(state, action, safety, rejection)
	if candidate != state:
		safety = Rules.checked_safety(Safety.validate_motion(level, state, candidate, effect))
		if safety.status != 0:
			return _safety_failure(state, action, safety, rejection)
	var ordered_faces: Array = level.faces.duplicate(true)
	ordered_faces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.face_id) < String(b.face_id))
	for face in ordered_faces:
		if not face.walkable:
			continue
		var light := Derived.light(level, candidate, face.face_id)
		if not light.ok:
			return Rules.error(state, action, light.issues)
	var issues := Data.validate_state_shape(level, candidate)
	if not issues.is_empty():
		return Rules.error(state, action, issues)
	return Rules.applied(state, candidate, action, global_kind)


static func _safety_failure(state: Dictionary, action: Dictionary, safety: Dictionary, rejection: int) -> Dictionary:
	var error_status: bool = safety.status == 3
	for diagnostic in safety.issues:
		error_status = error_status or diagnostic.code == Code.ARITHMETIC_OVERFLOW
	return Rules.error(state, action, safety.issues) if error_status else Rules.rejected(state, action, rejection, safety.issues)


static func _profile(level: Dictionary) -> Array[Dictionary]:
	var issues := Effects.validate_profile(level)
	for world in level.worlds:
		if world.allowed_rotation_deltas.is_empty() != world.allowed_rotation_intents.is_empty():
			issues.append(Rules.issue(Code.INVALID_ACTION, "worlds", "Rotation delta and intent availability must agree."))
	for group in level.groups:
		for edge in group.edges:
			if Math.compose(edge.rotation_delta, edge.from_orientation) != edge.to_orientation:
				issues.append(Rules.issue(Code.INVALID_ROTATION_EDGE, "groups.edges", "Declared edge does not match the formal rotation."))
	for transition in level.face_transitions:
		var source := _find(level.faces, "face_id", transition.source_face_id)
		var target := _find(level.faces, "face_id", transition.target_face_id)
		if source.cube_id != target.cube_id or source.face == target.face or not source.walkable or not target.walkable or transition.rotation_steps.is_empty():
			issues.append(Rules.issue(Code.INVALID_ROTATION_EDGE, "face_transitions", "Transition must connect different walkable faces of one Cube."))
			continue
		var source_frame := Geometry.face_frame(source.face)
		var target_frame := Geometry.face_frame(target.face)
		var normal: Vector3i = source_frame.normal
		var direction := _direction(source_frame, transition.entry_axis)
		for step in transition.rotation_steps:
			var next_normal := Math.apply(step, normal)
			if next_normal == normal:
				issues.append(Rules.issue(Code.INVALID_ROTATION_EDGE, "face_transitions.rotation_steps", "A channel step cannot spin about its current normal."))
			normal = next_normal
			direction = Math.apply(step, direction)
		if normal != target_frame.normal or direction != _direction(target_frame, transition.exit_axis):
			issues.append(Rules.issue(Code.INVALID_ROTATION_EDGE, "face_transitions", "Declared normal or entry/exit direction does not match the full path."))
	return Rules.sorted_issues(issues)


static func _find(records: Array, field: String, value: Variant) -> Dictionary:
	for record in records:
		if record[field] == value:
			return record
	return {}


static func _face(state: Dictionary) -> StringName:
	return Geometry.face_id(state.player.location.cube_id, state.player.location.face)


static func _frame_id(frame: Dictionary) -> int:
	return Math.from_columns(frame.u, frame.v, frame.normal)


static func _direction(frame: Dictionary, axis: int) -> Vector3i:
	var directions: Array[Vector3i] = [frame.u, frame.v, -frame.u, -frame.v]
	return directions[axis]


static func _cross(a: Vector3i, b: Vector3i) -> Vector3i:
	return Vector3i(a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x)


static func _quarter_axis(axis: Vector3i) -> int:
	for component in range(3):
		if axis[component] != 0:
			return Math.quarter_turn(component, axis[component])
	assert(false, "A valid face movement defines a signed unit roll axis")
	return -1
