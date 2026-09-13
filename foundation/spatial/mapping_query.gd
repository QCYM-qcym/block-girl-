extends RefCounted
## foundation.contract.v1.1: geometric mapping within one stable snapshot.
## Permission, lighting, player pose and runtime transition state belong to callers.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Validation = preload("res://foundation/spatial/spatial_validation.gd")
const Code = Types.ValidationCode
const Status = Types.MappingResolutionStatus


static func discover_mapping_candidates(snapshot_result: Dictionary, faces: Array[Dictionary], source_face: StringName, target_layer: int) -> Dictionary:
	# Validate every cube, anchor and definition before any walkable/layer filter.
	var issues: Array[Dictionary] = Validation.validate_snapshot(snapshot_result, faces)
	if not issues.is_empty():
		return _failure("pairs", issues)
	if not Geometry._valid_face_id(source_face):
		Geometry._add(issues, Code.INVALID_ID, "source_face", [source_face], "Invalid source FaceNodeId.")
	if not Types.WorldLayer.values().has(target_layer):
		Geometry._add(issues, Code.INVALID_ENUM, "target_layer", [], "Invalid target WorldLayer.")
	if not issues.is_empty():
		return _failure("pairs", Geometry._sorted(issues))
	var definitions: Dictionary = {}
	for face in faces:
		definitions[face.face_id] = face
	var anchors: Dictionary = {}
	for anchor in snapshot_result.value.anchors:
		anchors[anchor.face_id] = anchor
	if not definitions.has(source_face) or not anchors.has(source_face):
		Geometry._add(issues, Code.INVALID_REFERENCE, "source_face", [source_face], "Source face does not exist in this snapshot.")
		return _failure("pairs", issues)
	if not definitions[source_face].walkable:
		Geometry._add(issues, Code.INVALID_FACE, "source_face", [source_face], "Source face must be walkable.")
	if anchors[source_face].layer == target_layer:
		Geometry._add(issues, Code.INVALID_REFERENCE, "target_layer", [source_face], "Mapping target must be the other world layer.")
	if not issues.is_empty():
		return _failure("pairs", Geometry._sorted(issues))
	var pairs: Array[Dictionary] = []
	for face in faces:
		var anchor: Dictionary = anchors[face.face_id]
		if not face.walkable or anchor.layer != target_layer:
			continue
		var overlap: Dictionary = Geometry.anchor_overlap(anchors[source_face], anchor)
		if not overlap.ok:
			return _failure("pairs", overlap.issues)
		if overlap.overlaps:
			pairs.append({"source_face": source_face, "target_face": face.face_id})
	return {"ok": true, "pairs": _sorted_candidates(pairs), "issues": []}


static func collect_mapping_candidates(snapshot_result: Dictionary, faces: Array[Dictionary], source_face: StringName, target_layer: int, enabled_compatibilities: Array[int]) -> Dictionary:
	var issues: Array[Dictionary] = []
	var seen: Dictionary = {}
	if enabled_compatibilities.is_empty():
		Geometry._add(issues, Code.INVALID_REFERENCE, "enabled_compatibilities", [], "At least one compatibility must be enabled.")
	for index in enabled_compatibilities.size():
		var compatibility: int = enabled_compatibilities[index]
		var path := "enabled_compatibilities[%s]" % index
		if not Types.FaceCompatibility.values().has(compatibility):
			Geometry._add(issues, Code.INVALID_ENUM, path, [], "Invalid FaceCompatibility.")
		if seen.has(compatibility):
			Geometry._add(issues, Code.DUPLICATE_ID, path, [], "Compatibility must be enabled only once.")
		seen[compatibility] = true
	if not issues.is_empty():
		return _failure("candidates", Geometry._sorted(issues))
	var discovery := discover_mapping_candidates(snapshot_result, faces, source_face, target_layer)
	if not discovery.ok:
		return _failure("candidates", discovery.issues)
	var anchors: Dictionary = {}
	for anchor in snapshot_result.value.anchors:
		anchors[anchor.face_id] = anchor
	var candidates: Array[Dictionary] = []
	for pair in discovery.pairs:
		var classification: Dictionary = Geometry.classify_face_compatibility(anchors[pair.source_face], anchors[pair.target_face])
		if not classification.ok:
			return _failure("candidates", classification.issues)
		if classification.compatibility != null and enabled_compatibilities.has(classification.compatibility):
			candidates.append({"source_face": pair.source_face, "target_face": pair.target_face, "compatibility": classification.compatibility})
	return {"ok": true, "candidates": _sorted_candidates(candidates), "issues": []}


static func resolve_mapping(collection_result: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = Geometry._validate_result(collection_result, "candidates", TYPE_ARRAY, [])
	if not issues.is_empty():
		return _resolution_error(issues)
	var candidates: Array[Dictionary] = []
	var pairs: Dictionary = {}
	var sources: Dictionary = {}
	for index in collection_result.candidates.size():
		var candidate: Variant = collection_result.candidates[index]
		var path := "candidates[%s]" % index
		if not Geometry._record(candidate, {"source_face": TYPE_STRING_NAME, "target_face": TYPE_STRING_NAME, "compatibility": TYPE_INT}, path, issues):
			continue
		var valid_ids := true
		for field in ["source_face", "target_face"]:
			if not Geometry._valid_face_id(candidate[field]):
				Geometry._add(issues, Code.INVALID_ID, path + "." + field, [candidate[field]], "Invalid candidate FaceNodeId.")
				valid_ids = false
		if not Types.FaceCompatibility.values().has(candidate.compatibility):
			Geometry._add(issues, Code.INVALID_ENUM, path + ".compatibility", [], "Invalid candidate FaceCompatibility.")
		if not valid_ids:
			continue
		# Face IDs cannot contain a pipe; this is an unambiguous pair identity.
		var pair_key: String = String(candidate.source_face) + "|" + String(candidate.target_face)
		if pairs.has(pair_key):
			Geometry._add(issues, Code.DUPLICATE_ID, path, [candidate.source_face, candidate.target_face], "Duplicate mapping pair.")
		pairs[pair_key] = true
		sources[candidate.source_face] = true
		candidates.append(candidate.duplicate(true))
	if sources.size() > 1:
		var source_ids: Array[StringName] = []
		source_ids.assign(sources.keys())
		Geometry._add(issues, Code.INVALID_REFERENCE, "candidates", source_ids, "Candidates must have one source face.")
	if not issues.is_empty():
		return _resolution_error(Geometry._sorted(issues))
	candidates = _sorted_candidates(candidates)
	if candidates.is_empty():
		Geometry._add(issues, Code.NO_SHIFT_MAPPING, "mapping", [], "No geometric shift mapping exists.")
		return {"status": Status.NONE, "candidates": candidates, "mapping": null, "issues": issues}
	if candidates.size() == 1:
		return {"status": Status.UNIQUE, "candidates": candidates, "mapping": candidates[0].duplicate(true), "issues": []}
	var entities: Array[StringName] = []
	var serialized: Array[Dictionary] = []
	for candidate in candidates:
		for id in [candidate.source_face, candidate.target_face]:
			if not entities.has(id):
				entities.append(id)
		serialized.append({"source_face": String(candidate.source_face), "target_face": String(candidate.target_face), "compatibility": String(Types.FaceCompatibility.find_key(candidate.compatibility))})
	Geometry._add(issues, Code.AMBIGUOUS_SHIFT_MAPPING, "mapping", entities, "More than one geometric shift mapping exists.", {"candidates": serialized})
	return {"status": Status.AMBIGUOUS, "candidates": candidates, "mapping": null, "issues": issues}


static func _failure(field: String, issues: Array[Dictionary]) -> Dictionary:
	return {"ok": false, field: [], "issues": issues.duplicate(true)}


static func _resolution_error(issues: Array[Dictionary]) -> Dictionary:
	return {"status": Status.ERROR, "candidates": [], "mapping": null, "issues": issues.duplicate(true)}


static func _sorted_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = candidates.duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.source_face != b.source_face:
			return String(a.source_face) < String(b.source_face)
		return String(a.target_face) < String(b.target_face)
	)
	return result
