extends RefCounted
## Pure orchestration. The public entry is always bound to the real 2B Validator.
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
const Validator = preload("res://foundation/validation/static_validator.gd")
const ValidationTypes = preload("res://foundation/validation/validation_types.gd")


static func bake(authoring: Dictionary, options: Dictionary) -> Dictionary:
	return _bake_with_validator(authoring, options, Validator.validate)


static func _bake_with_validator(authoring: Dictionary, options: Dictionary, validate: Callable) -> Dictionary:
	if authoring.has("content_hash"):
		return _error(Types.ValidationCode.UNKNOWN_FIELD, "content_hash", "Content identity is produced only by the Baker.")
	if options.size() != 2 or not options.has_all(["max_configurations", "max_checks"]):
		return _error(Types.ValidationCode.INVALID_TYPE, "options", "Expected only max_configurations and max_checks budgets.")
	for key in options:
		if typeof(key) != TYPE_STRING or typeof(options[key]) != TYPE_INT or options[key] <= 0:
			return _error(Types.ValidationCode.INVALID_TYPE, "options", "Validation budgets must be positive integers.")
	var level := authoring.duplicate(true)
	level["content_hash"] = "0".repeat(64)
	var issues: Array[Dictionary] = Data.validate_level_shape(level)
	if not issues.is_empty():
		return _failure(issues)
	var identity: Dictionary = Codec.compute_content_hash(level)
	if not identity.ok:
		return _failure(identity.issues)
	level.content_hash = identity.content_hash
	var encoded: Dictionary = Codec.encode(level)
	if not encoded.ok:
		return _failure(encoded.issues)
	var decoded: Dictionary = Codec.decode(encoded.text)
	if not decoded.ok:
		return _failure(decoded.issues)
	level = decoded.level
	# Bind the same pipeline in tests to explicit failure-only doubles. No
	# option can select a double, skip validation or turn incomplete into success.
	var result: Variant = validate.call(level.duplicate(true), options.duplicate(true))
	if not _valid_result(result):
		return _error(Types.ValidationCode.INVALID_TYPE, "validation", "Validator returned an invalid execution-contract result.")
	var validation: Dictionary = result.duplicate(true)
	if validation.status != ValidationTypes.ValidationStatus.VALID:
		return _failure(validation.issues, validation)
	return {"ok": true, "level": level.duplicate(true), "issues": [], "validation": validation}


static func _valid_result(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4 or not value.has_all(["status", "issues", "configurations_checked", "checks_performed"]):
		return false
	if typeof(value.status) != TYPE_INT or value.status not in ValidationTypes.ValidationStatus.values() or not value.issues is Array:
		return false
	for field in ["configurations_checked", "checks_performed"]:
		if typeof(value[field]) != TYPE_INT or value[field] < 0:
			return false
	if value.status == ValidationTypes.ValidationStatus.VALID:
		return value.issues.is_empty()
	if value.issues.is_empty():
		return false
	for issue in value.issues:
		if not issue is Dictionary or issue.size() != 6 or not issue.has_all(["code", "severity", "path", "entity_ids", "message", "details"]):
			return false
		if typeof(issue.code) != TYPE_INT or typeof(issue.severity) != TYPE_INT or not issue.path is String or not issue.message is String or not issue.entity_ids is Array or not issue.details is Dictionary:
			return false
	return true


static func _failure(issues: Array, validation: Variant = null) -> Dictionary:
	return {"ok": false, "level": null, "issues": issues.duplicate(true), "validation": validation.duplicate(true) if validation is Dictionary else null}


static func _error(code: int, path: String, message: String) -> Dictionary:
	return _failure([{"code": code, "severity": Types.ValidationSeverity.ERROR, "path": path, "entity_ids": [], "message": message, "details": {}}])
