extends RefCounted
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const RuleTypes = preload("res://foundation/rules/rule_types.gd")
const Code = Types.ValidationCode


static func idle_context() -> Dictionary:
	return {"global_transition_state": Types.GlobalTransitionState.IDLE, "ticket": null, "local_moves": []}


static func begin_global(level: Dictionary, result: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = Data.validate_level_shape(level)
	if issues.is_empty():
		issues = fields(result, {"status": TYPE_INT, "previous_state": TYPE_DICTIONARY, "next_state": TYPE_DICTIONARY, "action": TYPE_DICTIONARY, "changed": TYPE_BOOL, "rejection_code": TYPE_INT, "issues": TYPE_ARRAY, "global_kind": TYPE_INT}, "result")
	if issues.is_empty():
		issues = Data.validate_state_shape(level, result.previous_state)
		issues.append_array(Data.validate_state_shape(level, result.next_state))
		issues.append_array(Data.validate_action_shape(level, result.action))
	if issues.is_empty():
		if result.status != RuleTypes.TransitionStatus.APPLIED or not result.changed or result.next_state == result.previous_state or result.global_kind == Types.GlobalTransitionKind.NONE or not Types.GlobalTransitionKind.values().has(result.global_kind) or result.action.kind == Types.PuzzleActionKind.MOVE or result.rejection_code != 0 or not result.issues.is_empty():
			issues.append(issue(Code.INVALID_ACTION, "result", "Only a changed, pure global APPLIED result may open a ticket."))
	if not issues.is_empty():
		return {"ok": false, "context": null, "issues": sorted_issues(issues)}
	return {"ok": true, "context": {"global_transition_state": Types.GlobalTransitionState.MOVING, "ticket": {"level_hash": level.content_hash, "base_state": result.previous_state.duplicate(true), "accepted_action": result.action.duplicate(true)}, "local_moves": []}, "issues": []}


static func context_issues(level: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var issues := fields(context, {"global_transition_state": TYPE_INT, "ticket": -1, "local_moves": TYPE_ARRAY}, "context")
	if not issues.is_empty():
		return issues
	if not Types.GlobalTransitionState.values().has(context.global_transition_state):
		issues.append(issue(Code.INVALID_ENUM, "context.global_transition_state", "Unknown global transition state."))
	elif context.global_transition_state == Types.GlobalTransitionState.IDLE:
		if context.ticket != null or not context.local_moves.is_empty():
			issues.append(issue(Code.INVALID_ACTION, "context", "IDLE requires no ticket or local trace."))
	else:
		if not context.ticket is Dictionary:
			issues.append(issue(Code.INVALID_TYPE, "context.ticket", "Busy requires a ticket."))
		else:
			issues.append_array(fields(context.ticket, {"level_hash": TYPE_STRING, "base_state": TYPE_DICTIONARY, "accepted_action": TYPE_DICTIONARY}, "context.ticket"))
			if issues.is_empty():
				issues.append_array(Data.validate_state_shape(level, context.ticket.base_state))
				issues.append_array(Data.validate_action_shape(level, context.ticket.accepted_action))
				if context.ticket.level_hash != level.content_hash:
					issues.append(issue(Code.INVALID_ACTION, "context.ticket.level_hash", "Ticket belongs to a different level."))
	for index in context.local_moves.size():
		var action: Variant = context.local_moves[index]
		if not action is Dictionary:
			issues.append(issue(Code.INVALID_TYPE, "context.local_moves[%d]" % index, "Trace must contain semantic MOVE records."))
		else:
			var action_issues := Data.validate_action_shape(level, action)
			issues.append_array(action_issues)
			if action_issues.is_empty() and action.kind != Types.PuzzleActionKind.MOVE:
				issues.append(issue(Code.INVALID_ACTION, "context.local_moves[%d]" % index, "Trace records only already committed ordinary MOVE."))
	return sorted_issues(issues)


static func applied(before: Dictionary, after: Dictionary, action: Dictionary, kind: int = 0) -> Dictionary:
	var changed := before != after
	return {"status": RuleTypes.TransitionStatus.APPLIED, "previous_state": before.duplicate(true), "next_state": after.duplicate(true), "action": action.duplicate(true), "changed": changed, "rejection_code": 0, "issues": [], "global_kind": kind if changed else Types.GlobalTransitionKind.NONE}


static func rejected(state: Dictionary, action: Dictionary, code: int, issues: Array = []) -> Dictionary:
	return {"status": RuleTypes.TransitionStatus.REJECTED, "previous_state": state.duplicate(true), "next_state": null, "action": action.duplicate(true), "changed": false, "rejection_code": code, "issues": sorted_issues(issues), "global_kind": Types.GlobalTransitionKind.NONE}


static func error(state: Dictionary, action: Dictionary, issues: Array) -> Dictionary:
	assert(not issues.is_empty(), "ERROR requires diagnostics")
	return {"status": RuleTypes.TransitionStatus.ERROR, "previous_state": state.duplicate(true), "next_state": null, "action": action.duplicate(true), "changed": false, "rejection_code": 0, "issues": sorted_issues(issues), "global_kind": Types.GlobalTransitionKind.NONE}


static func issue(code: int, path: String, message: String, ids: Array = [], details: Dictionary = {}) -> Dictionary:
	var entities := ids.duplicate(true)
	entities.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	return {"code": code, "severity": Types.ValidationSeverity.ERROR, "path": path, "entity_ids": entities, "message": message, "details": details.duplicate(true)}


static func sorted_issues(issues: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for diagnostic in issues:
		result.append(diagnostic.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.path != b.path:
			return a.path < b.path
		if a.code != b.code:
			return a.code < b.code
		for index in mini(a.entity_ids.size(), b.entity_ids.size()):
			if a.entity_ids[index] != b.entity_ids[index]:
				return String(a.entity_ids[index]) < String(b.entity_ids[index])
		return a.entity_ids.size() < b.entity_ids.size()
	)
	return result


static func fields(record: Dictionary, schema: Dictionary, path: String) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	for key in record:
		if not key is String or not schema.has(key):
			issues.append(issue(Code.UNKNOWN_FIELD, path + "." + str(key), "Unknown record field."))
	for key in schema:
		if not record.has(key):
			issues.append(issue(Code.MISSING_FIELD, path + "." + key, "Required record field missing."))
		elif schema[key] != -1 and typeof(record[key]) != schema[key]:
			issues.append(issue(Code.INVALID_TYPE, path + "." + key, "Record field has the wrong type."))
	return sorted_issues(issues)


static func checked_safety(result: Dictionary) -> Dictionary:
	# Validate the execution boundary without reproducing any Safety algorithm.
	var malformed := fields(result, {"status": TYPE_INT, "issues": TYPE_ARRAY}, "safety")
	var diagnostics: Array[Dictionary] = []
	if result.get("issues") is Array:
		for value in result.issues:
			if not value is Dictionary:
				malformed.append(issue(Code.INVALID_TYPE, "safety.issues", "Expected a ValidationIssue record."))
				continue
			var invalid := fields(value, {"code": TYPE_INT, "severity": TYPE_INT, "path": TYPE_STRING, "entity_ids": TYPE_ARRAY, "message": TYPE_STRING, "details": TYPE_DICTIONARY}, "safety.issues")
			if invalid.is_empty():
				if not Code.values().has(value.code) or not Types.ValidationSeverity.values().has(value.severity):
					invalid.append(issue(Code.INVALID_ENUM, "safety.issues", "Unknown diagnostic code or severity."))
				for id in value.entity_ids:
					if not id is StringName:
						invalid.append(issue(Code.INVALID_TYPE, "safety.issues.entity_ids", "Entity IDs must be StringName values."))
			if invalid.is_empty():
				diagnostics.append(value.duplicate(true))
			else:
				malformed.append_array(invalid)
	if malformed.is_empty():
		if result.status not in [0,1,2,3]:
			malformed.append(issue(Code.INVALID_ENUM, "safety.status", "Unknown SafetyStatus."))
		elif (result.status == 0 and not diagnostics.is_empty()) or (result.status != 0 and diagnostics.is_empty()):
			malformed.append(issue(Code.INVALID_ACTION, "safety", "Safety status contradicts its diagnostic payload."))
		elif result.status == 3:
			var has_error := false
			for diagnostic in diagnostics:
				has_error = has_error or diagnostic.severity == Types.ValidationSeverity.ERROR
			if not has_error:
				malformed.append(issue(Code.INVALID_ACTION, "safety", "Safety ERROR requires an ERROR diagnostic."))
	if not malformed.is_empty():
		diagnostics.append_array(malformed)
		return {"status": 3, "issues": sorted_issues(diagnostics)}
	for diagnostic in diagnostics:
		if diagnostic.code == Code.ARITHMETIC_OVERFLOW:
			var has_error := false
			for original in diagnostics:
				has_error = has_error or original.severity == Types.ValidationSeverity.ERROR
			if not has_error:
				diagnostics.append(issue(Code.INVALID_ACTION, "safety", "Overflow cannot be reported with only non-error severity."))
			return {"status": 3, "issues": sorted_issues(diagnostics)}
	return result.duplicate(true)
