extends RefCounted
## Pure, uncached queries over one committed configuration.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const RuleRecords = preload("res://foundation/rules/rule_records.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Validation = preload("res://foundation/spatial/spatial_validation.gd")
const Mapping = preload("res://foundation/spatial/mapping_query.gd")
const Lighting = preload("res://foundation/celestial/logical_lighting.gd")


static func snapshot(level: Dictionary, state: Dictionary) -> Dictionary:
	var resolved := Geometry.snapshot(level, state)
	if not resolved.ok:
		return resolved.duplicate(true)
	var faces: Array[Dictionary] = []
	faces.assign(level.faces)
	var issues := Validation.validate_snapshot(resolved, faces)
	if not issues.is_empty():
		return {"ok": false, "value": null, "issues": issues.duplicate(true)}
	return resolved.duplicate(true)


static func shift_mapping(level: Dictionary, state: Dictionary) -> Dictionary:
	var resolved := snapshot(level, state)
	if not resolved.ok:
		return {"status": Types.MappingResolutionStatus.ERROR, "candidates": [], "mapping": null, "issues": resolved.issues.duplicate(true)}
	var location: Dictionary = state.player.location
	var source := Geometry.face_id(location.cube_id, location.face)
	var target_layer: int = Types.WorldLayer.INNER if location.layer == Types.WorldLayer.SURFACE else Types.WorldLayer.SURFACE
	var faces: Array[Dictionary] = []
	faces.assign(level.faces)
	var compatibilities: Array[int] = []
	compatibilities.assign(level.shift_compatibilities)
	var collection := Mapping.collect_mapping_candidates(resolved, faces, source, target_layer, compatibilities)
	return Mapping.resolve_mapping(collection).duplicate(true)


static func light(level: Dictionary, state: Dictionary, face_id: StringName) -> Dictionary:
	var resolved := snapshot(level, state)
	if not resolved.ok:
		return _light_failure(resolved.issues)
	var issues: Array[Dictionary] = []
	var anchor: Dictionary = {}
	for candidate in resolved.value.anchors:
		if candidate.face_id == face_id:
			anchor = candidate
			break
	if anchor.is_empty():
		issues.append(RuleRecords.issue(Types.ValidationCode.INVALID_REFERENCE, "face_id", "Requested face does not exist in this snapshot.", [face_id]))
		return _light_failure(issues)
	var slot: Dictionary = {}
	for candidate in level.celestial.slots:
		if candidate.slot_id == state.celestial.slot_id:
			slot = candidate
			break
	if slot.is_empty():
		issues.append(RuleRecords.issue(Types.ValidationCode.INVALID_CELESTIAL_REFERENCE, "celestial.slot_id", "Current celestial slot does not exist.", [state.celestial.slot_id]))
		return _light_failure(issues)
	var cubes: Array[Dictionary] = []
	cubes.assign(resolved.value.cubes)
	return Lighting.query(anchor, slot, cubes).duplicate(true)


static func _light_failure(issues: Array) -> Dictionary:
	return {"ok": false, "light_state": null, "reason": &"INVALID", "occluder_id": &"", "issues": issues.duplicate(true)}
