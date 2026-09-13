extends RefCounted
## Exact discrete adjacency; player clearance and sweeps belong to Safety.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const RuleRecords = preload("res://foundation/rules/rule_records.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Derived = preload("res://foundation/rules/derived_state_resolver.gd")


static func query_move(level: Dictionary, state: Dictionary, face_axis: int) -> Dictionary:
	var resolved := Derived.snapshot(level, state)
	if not resolved.ok:
		return _failure(resolved.issues)
	var issues: Array[Dictionary] = []
	if not Types.FaceAxis.values().has(face_axis):
		issues.append(RuleRecords.issue(Types.ValidationCode.INVALID_ENUM, "face_axis", "Expected a valid FaceAxis."))
		return _failure(issues)
	var location: Dictionary = state.player.location
	var source_id := Geometry.face_id(location.cube_id, location.face)
	var definitions: Dictionary = {}
	for face in level.faces:
		definitions[face.face_id] = face
	var anchors: Dictionary = {}
	for anchor in resolved.value.anchors:
		anchors[anchor.face_id] = anchor
	if not definitions.has(source_id) or not anchors.has(source_id):
		issues.append(RuleRecords.issue(Types.ValidationCode.INVALID_REFERENCE, "player.location", "Source face is missing from the snapshot.", [source_id]))
		return _failure(issues)
	if not definitions[source_id].walkable:
		issues.append(RuleRecords.issue(Types.ValidationCode.INVALID_FACE, "player.location", "Source face must be walkable.", [source_id]))
		return _failure(issues)
	var source: Dictionary = anchors[source_id]
	var directions: Array[Vector3i] = [source.frame.u, source.frame.v, -source.frame.u, -source.frame.v]
	var direction: Vector3i = directions[face_axis]
	var candidates: Array[Dictionary] = []
	for target in resolved.value.anchors:
		if target.layer != source.layer or not definitions[target.face_id].walkable or target.frame.normal != source.frame.normal:
			continue
		var adjacent := true
		for axis in 3:
			# Promote each operand before adding; Vector3i arithmetic would wrap.
			if int(target.position2[axis]) != int(source.position2[axis]) + 2 * int(direction[axis]):
				adjacent = false
				break
		if adjacent:
			candidates.append(definitions[target.face_id])
	if candidates.size() > 1:
		var ids: Array[StringName] = [source_id]
		for candidate in candidates:
			ids.append(candidate.face_id)
		issues.append(RuleRecords.issue(Types.ValidationCode.INVALID_FACE, "connectivity", "More than one face occupies the requested adjacent location.", ids))
		return _failure(issues)
	var target_location: Variant = null
	if not candidates.is_empty():
		target_location = Records.make_player_location(source.layer, candidates[0].cube_id, candidates[0].face)
	return {"ok": true, "target_location": target_location, "direction": direction, "issues": []}


static func _failure(issues: Array) -> Dictionary:
	return {"ok": false, "target_location": null, "direction": null, "issues": issues.duplicate(true)}
