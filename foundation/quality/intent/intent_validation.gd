extends RefCounted
## Closed sidecar validation. Does not modify or revalidate the LevelDefinition.
const Types = preload("res://foundation/contracts/foundation_types.gd")
const IntentTypes = preload("res://foundation/quality/intent/intent_types.gd")


static func validate(level: Dictionary, intent: Dictionary) -> Dictionary:
	var shape := _record(intent, ["intent_version", "intent_id", "level_hash", "rule_version", "required_mechanics", "optional_mechanics", "expected_milestones", "forbidden_bypasses"], "intent")
	if not shape.ok:
		return shape
	for field in ["intent_version", "level_hash", "rule_version"]:
		if typeof(intent[field]) != TYPE_STRING:
			return _error("intent." + field, "Expected String.")
	if not _valid_id(intent.intent_id):
		return _error("intent.intent_id", "Expected a core lowercase StringName ID.")
	for binding in [["intent_version", "puzzleintent.v1"], ["level_hash", level.get("content_hash")], ["rule_version", level.get("rule_version")]]:
		if intent[binding[0]] != binding[1]:
			return _error("intent." + binding[0], "Intent version or level identity does not match.", 3010)
	for field in ["required_mechanics", "optional_mechanics"]:
		var tags := _tags(intent[field], "intent." + field, true)
		if not tags.ok:
			return tags
	for tag in intent.required_mechanics:
		if tag in intent.optional_mechanics:
			return _error("intent.optional_mechanics", "Required and optional mechanics must not overlap.")
	var milestones := _milestones(level, intent.expected_milestones)
	if not milestones.ok:
		return milestones
	return _bypasses(intent.forbidden_bypasses)


static func _milestones(level: Dictionary, value: Variant) -> Dictionary:
	if not value is Array:
		return _error("intent.expected_milestones", "Expected Array.")
	var seen := {}
	for index in range(value.size()):
		var path := "intent.expected_milestones[%d]" % index
		var item: Variant = value[index]
		var shape := _record(item, ["milestone_id", "required", "predicate"], path)
		if not shape.ok:
			return shape
		if not _valid_id(item.milestone_id):
			return _error(path + ".milestone_id", "Expected a core lowercase StringName ID.")
		if seen.has(item.milestone_id):
			return _error(path + ".milestone_id", "Milestone IDs must be unique.")
		seen[item.milestone_id] = true
		if typeof(item.required) != TYPE_BOOL:
			return _error(path + ".required", "Expected bool.")
		var predicate := _predicate(level, item.predicate, path + ".predicate")
		if not predicate.ok:
			return predicate
	return _success()


static func _predicate(level: Dictionary, value: Variant, path: String) -> Dictionary:
	if not value is Dictionary or not value.has("kind"):
		return _error(path, "Expected a predicate record with kind.")
	if not _enum_value(value.kind, IntentTypes.PredicateKind.values()):
		return _error(path + ".kind", "Unknown predicate kind.")
	var payload := ""
	match value.kind:
		IntentTypes.PredicateKind.AT_FACE:
			payload = "face_id"
		IntentTypes.PredicateKind.IN_LAYER:
			payload = "layer"
		IntentTypes.PredicateKind.FACE_LIGHT:
			payload = "light_state"
		IntentTypes.PredicateKind.MECHANIC_USED:
			payload = "mechanic"
	var fields := ["kind"]
	if not payload.is_empty():
		fields.append(payload)
	var shape := _record(value, fields, path)
	if not shape.ok:
		return shape
	match value.kind:
		IntentTypes.PredicateKind.AT_FACE:
			if typeof(value.face_id) != TYPE_STRING_NAME:
				return _error(path + ".face_id", "Expected StringName face reference.")
			var found := false
			for face in level.get("faces", []):
				if face is Dictionary and face.get("face_id") == value.face_id:
					found = true
					break
			if not found:
				return _error(path + ".face_id", "Face reference does not exist in this level.")
		IntentTypes.PredicateKind.IN_LAYER:
			if not _enum_value(value.layer, Types.WorldLayer.values()):
				return _error(path + ".layer", "Unknown world layer.")
		IntentTypes.PredicateKind.FACE_LIGHT:
			if not _enum_value(value.light_state, Types.LightState.values()):
				return _error(path + ".light_state", "Unknown light state.")
		IntentTypes.PredicateKind.MECHANIC_USED:
			if not _enum_value(value.mechanic, IntentTypes.MechanicTag.values()):
				return _error(path + ".mechanic", "Unknown mechanic tag.")
	return _success()


static func _bypasses(value: Variant) -> Dictionary:
	if not value is Array:
		return _error("intent.forbidden_bypasses", "Expected Array.")
	var seen := {}
	for index in range(value.size()):
		var path := "intent.forbidden_bypasses[%d]" % index
		var item: Variant = value[index]
		var shape := _record(item, ["bypass_id", "disabled_mechanics"], path)
		if not shape.ok:
			return shape
		if not _valid_id(item.bypass_id):
			return _error(path + ".bypass_id", "Expected a core lowercase StringName ID.")
		if seen.has(item.bypass_id):
			return _error(path + ".bypass_id", "Bypass IDs must be unique.")
		seen[item.bypass_id] = true
		var tags := _tags(item.disabled_mechanics, path + ".disabled_mechanics", false)
		if not tags.ok:
			return tags
	return _success()


static func _tags(value: Variant, path: String, allow_empty: bool) -> Dictionary:
	if not value is Array:
		return _error(path, "Expected Array of mechanic tags.")
	if not allow_empty and value.is_empty():
		return _error(path, "Disabled mechanic set must not be empty.")
	var previous := -1
	for index in range(value.size()):
		if not _enum_value(value[index], IntentTypes.MechanicTag.values()):
			return _error(path + "[%d]" % index, "Unknown mechanic tag.")
		if value[index] <= previous:
			return _error(path + "[%d]" % index, "Mechanic tags must be unique and sorted ascending.")
		previous = value[index]
	return _success()


static func _record(value: Variant, fields: Array, path: String) -> Dictionary:
	if not value is Dictionary:
		return _error(path, "Expected Dictionary.")
	if value.size() != fields.size() or not value.has_all(fields):
		return _error(path, "Record must contain exactly its defined fields.")
	for key in value:
		if typeof(key) != TYPE_STRING:
			return _error(path, "Record field names must be Strings.")
	return _success()


static func _valid_id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING_NAME:
		return false
	var id := String(value)
	if id.is_empty() or not id[0] in "abcdefghijklmnopqrstuvwxyz":
		return false
	for character in id:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true


static func _enum_value(value: Variant, allowed: Array) -> bool:
	return typeof(value) == TYPE_INT and value in allowed


static func _success() -> Dictionary:
	return {"ok": true, "issues": []}


static func _error(path: String, message: String, code: int = 3016) -> Dictionary:
	# Frozen AnalysisIssue codes; the AnalysisCode enum remains owned by 3A.
	return {"ok": false, "issues": [{"code": code, "severity": Types.ValidationSeverity.ERROR,
		"path": path, "message": message, "details": {}, "upstream": []}]}
