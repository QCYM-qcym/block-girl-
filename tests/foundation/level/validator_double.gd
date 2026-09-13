extends RefCounted
## Failure propagation only. Never a substitute for real Bake acceptance.

static func reject_invalid(_level: Dictionary, _options: Dictionary) -> Dictionary:
	return _result(1, 1006, "reference", "Test double: invalid reference.")

static func reject_incomplete(_level: Dictionary, _options: Dictionary) -> Dictionary:
	return _result(2, 1600, "options.max_checks", "Test double: incomplete budget.")

static func malformed_result(_level: Dictionary, _options: Dictionary) -> Dictionary:
	return {"status": 0}

static func _result(status: int, code: int, path: String, message: String) -> Dictionary:
	return {"status": status, "issues": [{"code": code, "severity": 0, "path": path, "entity_ids": [], "message": message, "details": {"source": "failure-only-test-double"}}], "configurations_checked": 1, "checks_performed": 1}
