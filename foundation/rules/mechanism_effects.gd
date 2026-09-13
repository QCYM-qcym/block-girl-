extends RefCounted
## Authorization and edge-event collection only; Kernel executes effects atomically.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const RuleRecords = preload("res://foundation/rules/rule_records.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Kind = Types.PuzzleActionKind
const Code = Types.ValidationCode


static func validate_profile(level: Dictionary) -> Array[Dictionary]:
	# DATA shape/reference validation is a precondition for this internal helper.
	var issues: Array[Dictionary] = []
	for index in level.mechanisms.size():
		var mechanism: Dictionary = level.mechanisms[index]
		var path := "mechanisms[%s]" % index
		if mechanism.action.kind not in [Kind.MOVE_CELESTIAL, Kind.LOCAL_GROUP_ROTATE, Kind.USE_FACE_TRANSITION]:
			issues.append(RuleRecords.issue(Code.INVALID_ACTION, path + ".action", "Mechanism action is outside the execution profile.", [mechanism.mechanism_id]))
		if mechanism.allowed_states.size() != 1 or mechanism.allowed_states[0] != mechanism.initial_state:
			issues.append(RuleRecords.issue(Code.INVALID_ACTION, path + ".allowed_states", "Mechanisms require one fixed initial state.", [mechanism.mechanism_id]))
		if mechanism.action.has("mechanism_id") and mechanism.action.mechanism_id != mechanism.mechanism_id:
			issues.append(RuleRecords.issue(Code.INVALID_ACTION, path + ".action.mechanism_id", "Bound action must identify its own mechanism.", [mechanism.mechanism_id, mechanism.action.mechanism_id]))
	return RuleRecords.sorted_issues(issues)


static func authorize(level: Dictionary, state: Dictionary, action: Dictionary, trigger: StringName = &"USE") -> Dictionary:
	var issues := Data.validate_level_shape(level)
	if not issues.is_empty():
		return _result(null, issues)
	issues = Data.validate_state_shape(level, state)
	if not issues.is_empty():
		return _result(null, issues)
	issues = Data.validate_action_shape(level, action)
	if not issues.is_empty():
		return _result(null, issues)
	issues = validate_profile(level)
	if not issues.is_empty():
		return _result(null, issues)
	if trigger not in [&"USE", &"ENTER"] or action.kind not in [Kind.TRIGGER_MECHANISM, Kind.LOCAL_GROUP_ROTATE, Kind.MOVE_CELESTIAL]:
		issues.append(RuleRecords.issue(Code.INVALID_ACTION, "action", "Expected a mechanism request and a supported trigger."))
		return _result(null, issues)
	var location: Dictionary = state.player.location
	var current_face := Geometry.face_id(location.cube_id, location.face)
	for mechanism in level.mechanisms:
		if mechanism.mechanism_id != action.mechanism_id:
			continue
		var listed := false
		for face in level.faces:
			if face.face_id == current_face and face.mechanism_ids.has(mechanism.mechanism_id):
				listed = true
		if mechanism.face_id != current_face or mechanism.trigger != trigger or not listed:
			break
		if action.kind != Kind.TRIGGER_MECHANISM and action != mechanism.action:
			break
		return _result(mechanism.action, issues)
	issues.append(RuleRecords.issue(Code.UNAUTHORIZED_MECHANISM, "action.mechanism_id", "Current face and trigger do not authorize this exact mechanism action.", [action.mechanism_id, current_face]))
	return _result(null, issues)


static func enter_effects(level: Dictionary, source_face: StringName, target_face: StringName) -> Array[Dictionary]:
	# Internal caller has validated DATA/profile and a successful entry event.
	var effects: Array[Dictionary] = []
	if source_face == target_face:
		return effects
	for mechanism in level.mechanisms:
		if mechanism.face_id == target_face and mechanism.trigger == &"ENTER":
			effects.append(mechanism.duplicate(true))
	effects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		return String(a.mechanism_id) < String(b.mechanism_id)
	)
	return effects


static func _result(effect: Variant, issues: Array[Dictionary]) -> Dictionary:
	return {"ok": issues.is_empty(), "effect": effect.duplicate(true) if effect != null and issues.is_empty() else null, "issues": issues.duplicate(true)}
