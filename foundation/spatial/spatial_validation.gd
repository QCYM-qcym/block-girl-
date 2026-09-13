extends RefCounted
## Checks a canonical SpatialQueryResult and propagates upstream failure.
## No mapping, lighting, path search, swept collision, or full-level safety verdict.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const Orientation = preload("res://foundation/orientation/discrete_orientation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Code = Types.ValidationCode


static func validate_snapshot(snapshot_result: Dictionary, faces: Array[Dictionary]) -> Array[Dictionary]:
	var issues := Geometry._validate_result(snapshot_result,"value",TYPE_DICTIONARY,null)
	if not issues.is_empty():
		return issues
	var snapshot: Dictionary = snapshot_result.value
	if not _record(snapshot, {"cubes": TYPE_ARRAY, "anchors": TYPE_ARRAY}, "", issues):
		return _sorted(issues)
	var cubes: Dictionary = {}
	var cube_paths: Dictionary = {}
	for index in snapshot.cubes.size():
		var path := "cubes[%s]" % index
		var cube: Variant = snapshot.cubes[index]
		if not _record(cube, {"cube_id": TYPE_STRING_NAME, "layer": TYPE_INT, "center2": TYPE_VECTOR3I, "orientation": TYPE_INT, "occludes_light": TYPE_BOOL}, path, issues):
			continue
		if not _valid_id(cube.cube_id):
			_add(issues, Code.INVALID_ID, path + ".cube_id", [cube.cube_id], "Invalid CubeCellId.")
			continue
		if cubes.has(cube.cube_id):
			_add(issues, Code.DUPLICATE_ID, path + ".cube_id", [cube.cube_id], "Duplicate resolved cube.")
			continue
		if not Types.WorldLayer.values().has(cube.layer):
			_add(issues, Code.INVALID_ENUM, path + ".layer", [cube.cube_id], "Invalid WorldLayer.")
			continue
		if not Orientation.is_valid(cube.orientation):
			_add(issues, Code.INVALID_ORIENTATION, path + ".orientation", [cube.cube_id], "Invalid cube24.v1 orientation.")
			continue
		if cube.center2.x % 2 != 0 or cube.center2.y % 2 != 0 or cube.center2.z % 2 != 0:
			_add(issues, Code.OFF_LATTICE, path + ".center2", [cube.cube_id], "Resolved cube center must have even components.")
		cubes[cube.cube_id] = cube
		cube_paths[cube.cube_id] = path
	var definitions: Dictionary = {}
	for index in faces.size():
		var face := faces[index]
		var path := "faces[%s]" % index
		if not _record(face, {"face_id": TYPE_STRING_NAME, "cube_id": TYPE_STRING_NAME, "face": TYPE_INT, "walkable": TYPE_BOOL, "shift_exit_blocked": TYPE_BOOL, "shift_entry_blocked": TYPE_BOOL, "mechanism_ids": TYPE_ARRAY}, path, issues):
			continue
		for mechanism_index in face.mechanism_ids.size():
			var mechanism: Variant = face.mechanism_ids[mechanism_index]
			var mechanism_path := path + ".mechanism_ids[%s]" % mechanism_index
			if typeof(mechanism) != TYPE_STRING_NAME:
				_add(issues, Code.INVALID_TYPE, mechanism_path, [face.face_id], "Mechanism IDs require StringName values.")
			elif not _valid_id(mechanism):
				_add(issues, Code.INVALID_ID, mechanism_path, [mechanism], "Invalid MechanismId.")
		if not Types.FaceDirection.values().has(face.face):
			_add(issues, Code.INVALID_FACE, path + ".face", [face.face_id], "Invalid local FaceDirection.")
			continue
		if face.face_id != Geometry.face_id(face.cube_id, face.face):
			_add(issues, Code.INVALID_FACE, path + ".face_id", [face.face_id], "Face identity must use its cube and local face.")
			continue
		if definitions.has(face.face_id):
			_add(issues, Code.DUPLICATE_ID, path + ".face_id", [face.face_id], "Duplicate FaceNode definition.")
			continue
		if not cubes.has(face.cube_id):
			_add(issues, Code.INVALID_REFERENCE, path + ".cube_id", [face.face_id, face.cube_id], "Face has no valid resolved cube.")
			continue
		definitions[face.face_id] = face
	var anchors: Dictionary = {}
	for index in snapshot.anchors.size():
		var path := "anchors[%s]" % index
		var anchor: Variant = snapshot.anchors[index]
		if not _record(anchor, {"face_id": TYPE_STRING_NAME, "layer": TYPE_INT, "position2": TYPE_VECTOR3I, "frame": TYPE_DICTIONARY}, path, issues):
			continue
		if anchors.has(anchor.face_id):
			_add(issues, Code.DUPLICATE_ID, path + ".face_id", [anchor.face_id], "Duplicate derived FaceAnchor.")
			continue
		anchors[anchor.face_id] = anchor
		if not definitions.has(anchor.face_id):
			_add(issues, Code.INVALID_REFERENCE, path + ".face_id", [anchor.face_id], "Anchor has no matching FaceNode.")
			continue
		var definition: Dictionary = definitions[anchor.face_id]
		var cube: Dictionary = cubes[definition.cube_id]
		var derived := Geometry.resolve_anchor(cube, definition.face)
		if not derived.ok:
			issues.append_array(Geometry._relocate(derived.issues,path))
			continue
		var expected: Dictionary = derived.value
		if anchor.layer != cube.layer or anchor.position2 != expected.position2:
			_add(issues, Code.INVALID_ANCHOR, path, [anchor.face_id], "Anchor must match the cube layer and exact normal offset.")
		if not _record(anchor.frame, {"u": TYPE_VECTOR3I, "v": TYPE_VECTOR3I, "normal": TYPE_VECTOR3I}, path + ".frame", issues):
			continue
		if Orientation.from_columns(anchor.frame.u, anchor.frame.v, anchor.frame.normal) == -1:
			_add(issues, Code.INVALID_SURFACE_FRAME, path + ".frame", [anchor.face_id], "SurfaceFrame must be a right-handed unit-axis basis.")
		elif anchor.frame != expected.frame:
			_add(issues, Code.INVALID_SURFACE_FRAME, path + ".frame", [anchor.face_id], "SurfaceFrame does not match the resolved cube orientation.")
	for cube_id in cubes:
		for face in Types.FaceDirection.values():
			var id := Geometry.face_id(cube_id, face)
			if not definitions.has(id):
				_add(issues, Code.INVALID_FACE, cube_paths[cube_id], [id], "Resolved cube requires six FaceNode definitions.")
			if not anchors.has(id):
				_add(issues, Code.INVALID_ANCHOR, cube_paths[cube_id], [id], "Resolved cube requires six derived anchors.")
	var ids: Array = cubes.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for index in ids.size():
		for other in range(index + 1, ids.size()):
			var a: Dictionary = cubes[ids[index]]
			var b: Dictionary = cubes[ids[other]]
			if a.layer != b.layer:
				continue
			# Scalar differences use int64, avoiding Vector3i subtraction wrap.
			var dx: int = int(b.center2.x) - int(a.center2.x)
			var dy: int = int(b.center2.y) - int(a.center2.y)
			var dz: int = int(b.center2.z) - int(a.center2.z)
			if absi(dx) < 2 and absi(dy) < 2 and absi(dz) < 2:
				_add(issues, Code.SAME_WORLD_CUBE_OVERLAP, cube_paths[b.cube_id], [a.cube_id, b.cube_id], "Same-world cube interiors overlap.")
			elif (absi(dx) == 2 and dy == 0 and dz == 0) or (absi(dy) == 2 and dx == 0 and dz == 0) or (absi(dz) == 2 and dx == 0 and dy == 0):
				var toward_b := Vector3i(signi(dx), signi(dy), signi(dz))
				_check_sealed(a, b.cube_id, toward_b, definitions, cube_paths[a.cube_id], issues)
				_check_sealed(b, a.cube_id, -toward_b, definitions, cube_paths[b.cube_id], issues)
	return _sorted(issues)


static func _check_sealed(cube: Dictionary, neighbor: StringName, normal: Vector3i, definitions: Dictionary, path: String, issues: Array[Dictionary]) -> void:
	for face in Types.FaceDirection.values():
		var id := Geometry.face_id(cube.cube_id, face)
		if not definitions.has(id) or not definitions[id].walkable:
			continue
		if Orientation.apply(cube.orientation, Geometry.face_frame(face).normal) == normal:
			_add(issues, Code.SEALED_WALKABLE_FACE, path, [id, neighbor], "Walkable face is completely sealed by a same-world neighbor.")


static func _record(value: Variant, fields: Dictionary, path: String, issues: Array[Dictionary]) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		_add(issues, Code.INVALID_TYPE, path, [], "Expected a record.")
		return false
	var valid := true
	for key in fields:
		var field_path: String = key if path.is_empty() else path + "." + key
		if not value.has(key):
			_add(issues, Code.MISSING_FIELD, field_path, [], "Required field is missing.")
			valid = false
		elif typeof(value[key]) != fields[key]:
			_add(issues, Code.INVALID_TYPE, field_path, [], "Field has the wrong memory type.")
			valid = false
	for key in value:
		if typeof(key) != TYPE_STRING or not fields.has(key):
			_add(issues, Code.UNKNOWN_FIELD, path, [], "Unknown or non-String field key.")
			valid = false
	return valid


static func _valid_id(id: StringName) -> bool:
	var value := String(id)
	if value.is_empty() or value[0] < "a" or value[0] > "z":
		return false
	for character in value:
		if not ((character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "_"):
			return false
	return true


static func _add(issues: Array[Dictionary], code: int, path: String, ids: Array[StringName], message: String) -> void:
	var entities: Array[StringName] = ids.duplicate()
	entities.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	issues.append({"code": code, "severity": Types.ValidationSeverity.ERROR, "path": path, "entity_ids": entities, "message": message, "details": {}})


static func _sorted(issues: Array[Dictionary]) -> Array[Dictionary]:
	issues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.path != b.path:
			return a.path < b.path
		if a.code != b.code:
			return a.code < b.code
		for index in mini(a.entity_ids.size(), b.entity_ids.size()):
			if a.entity_ids[index] != b.entity_ids[index]:
				return String(a.entity_ids[index]) < String(b.entity_ids[index])
		return a.entity_ids.size() < b.entity_ids.size()
	)
	return issues
