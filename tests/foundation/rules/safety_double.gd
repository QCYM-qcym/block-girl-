extends RefCounted
## TEST ONLY. Never used as a production dependency or final integration proof.
static var state_status := 0
static var motion_status := 0
static var concurrent_status := 0
static var state_calls := 0
static var motion_calls := 0
static var concurrent_calls := 0
static var malformed_result: Variant = null
static var concurrent_override: Variant = null


static func reset() -> void:
	state_status = 0
	motion_status = 0
	concurrent_status = 0
	state_calls = 0
	motion_calls = 0
	concurrent_calls = 0
	malformed_result = null
	concurrent_override = null


static func validate_state(_level: Dictionary, _state: Dictionary) -> Dictionary:
	state_calls += 1
	return _result(state_status)


static func validate_motion(_level: Dictionary, _before: Dictionary, _after: Dictionary, _action: Dictionary) -> Dictionary:
	motion_calls += 1
	return _result(motion_status)


static func validate_concurrent_motion(_level: Dictionary, _before: Dictionary, _after_local: Dictionary, _after_global: Dictionary, _local_action: Dictionary, _global_action: Dictionary) -> Dictionary:
	concurrent_calls += 1
	if concurrent_override != null:
		return concurrent_override.duplicate(true)
	return _result(concurrent_status)


static func _result(status: int) -> Dictionary:
	if malformed_result != null:
		return malformed_result.duplicate(true)
	if status == 0:
		return {"status": 0, "issues": []}
	var code := 1104 if status == 1 else (1601 if status == 2 else 1105)
	return {"status": status, "issues": [{"code": code, "severity": 0, "path": "safety.double", "entity_ids": [&"fixture"], "message": "Controlled test-only safety result", "details": {"probe": [1, 2]}}]}
