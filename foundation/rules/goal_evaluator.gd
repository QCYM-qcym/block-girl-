extends RefCounted
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Derived = preload("res://foundation/rules/derived_state_resolver.gd")
const Rules = preload("res://foundation/rules/rule_records.gd")
const Safety = preload("res://foundation/validation/safety_queries.gd")


static func is_goal(level: Dictionary, state: Dictionary) -> Dictionary:
	var issues := Data.validate_state_shape(level, state)
	if not issues.is_empty():
		return {"ok": false, "is_goal": null, "issues": issues.duplicate(true)}
	var snapshot := Derived.snapshot(level, state)
	if not snapshot.ok:
		return {"ok": false, "is_goal": null, "issues": snapshot.issues.duplicate(true)}
	var safety := Rules.checked_safety(Safety.validate_state(level, state))
	if safety.status != 0:
		return {"ok": false, "is_goal": null, "issues": safety.issues.duplicate(true)}
	var reached: bool = Geometry.face_id(state.player.location.cube_id, state.player.location.face) == level.goal.face_id
	for flag in level.goal.required_flags:
		reached = reached and state.level_flags[flag]
	return {"ok": true, "is_goal": reached, "issues": []}
