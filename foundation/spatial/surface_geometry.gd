extends RefCounted
## foundation.contract.v1: exact geometry of one committed configuration.
## Queries validate external records and fail atomically; only face identity/frame
## factories retain strict already-validated ID/enum preconditions.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Code = Types.ValidationCode
const INT32_MIN := -2147483648
const INT32_MAX := 2147483647
const Orientation = preload("res://foundation/orientation/discrete_orientation.gd")


static func face_frame(face: int) -> Dictionary:
	var u: Vector3i
	var v: Vector3i
	var normal: Vector3i
	match face:
		Types.FaceDirection.FRONT:
			u = Vector3i(1,0,0); v = Vector3i(0,1,0); normal = Vector3i(0,0,1)
		Types.FaceDirection.BACK:
			u = Vector3i(-1,0,0); v = Vector3i(0,1,0); normal = Vector3i(0,0,-1)
		Types.FaceDirection.LEFT:
			u = Vector3i(0,0,1); v = Vector3i(0,1,0); normal = Vector3i(-1,0,0)
		Types.FaceDirection.RIGHT:
			u = Vector3i(0,0,-1); v = Vector3i(0,1,0); normal = Vector3i(1,0,0)
		Types.FaceDirection.TOP:
			u = Vector3i(1,0,0); v = Vector3i(0,0,-1); normal = Vector3i(0,1,0)
		Types.FaceDirection.BOTTOM:
			u = Vector3i(1,0,0); v = Vector3i(0,0,1); normal = Vector3i(0,-1,0)
		_:
			assert(false, "face_frame requires a valid FaceDirection")
			return {}
	return {"u": u, "v": v, "normal": normal}


static func face_id(cube_id: StringName, face: int) -> StringName:
	assert(Types.FaceDirection.values().has(face), "face_id requires a valid FaceDirection")
	return StringName(String(cube_id) + "/" + Types.FaceDirection.find_key(face))


static func make_face_nodes(cube_id: StringName) -> Array[Dictionary]:
	assert(_valid_id(cube_id), "make_face_nodes requires a valid CubeCellId")
	var faces: Array[Dictionary] = []
	for face in range(6):
		var mechanisms: Array[StringName] = []
		faces.append({"face_id": face_id(cube_id,face), "cube_id": cube_id, "face": face, "walkable": false, "shift_exit_blocked": false, "shift_entry_blocked": false, "mechanism_ids": mechanisms})
	return faces


static func resolve_cube(cube: Dictionary, world_transform: Dictionary, group_transform: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	_validate_cube(cube, false, issues)
	_validate_transform(world_transform, "world_transform", issues)
	_validate_transform(group_transform, "group_transform", issues)
	if not issues.is_empty():
		return _result(null, issues)
	var group := _position(cube.center2, group_transform.rotation, group_transform.pivot2, "GROUP_TRANSFORM", cube.cube_id)
	if not group.ok:
		return _result(null, group.issues)
	var world := _position(group.position, world_transform.rotation, world_transform.pivot2, "WORLD_TRANSFORM", cube.cube_id)
	if not world.ok:
		return _result(null, world.issues)
	var rotation := Orientation.compose(world_transform.rotation, Orientation.compose(group_transform.rotation, cube.orientation))
	return _result({"cube_id": cube.cube_id, "layer": cube.layer, "center2": world.position, "orientation": rotation, "occludes_light": cube.occludes_light}, issues)


static func resolve_anchor(cube: Dictionary, face: int) -> Dictionary:
	var issues: Array[Dictionary] = []
	_validate_cube(cube, true, issues)
	if not Types.FaceDirection.values().has(face):
		_add(issues,Code.INVALID_FACE,"face",[],"Invalid local FaceDirection.")
	if not issues.is_empty():
		return _result(null,issues)
	var local := face_frame(face)
	var frame := {"u": Orientation.apply(cube.orientation,local.u), "v": Orientation.apply(cube.orientation,local.v), "normal": Orientation.apply(cube.orientation,local.normal)}
	var components: Array[int] = []
	var id := face_id(cube.cube_id,face)
	for axis in 3:
		# Each sum uses int64 scalars; a unit normal cannot overflow int64.
		var center: int = cube.center2[axis]
		var normal: int = frame.normal[axis]
		var value: int = center + normal
		if value < INT32_MIN or value > INT32_MAX:
			_overflow(issues,"ANCHOR_DERIVATION",axis,[center,normal],"position2",[id])
		components.append(value)
	if not issues.is_empty():
		return _result(null,issues)
	return _result({"face_id": id, "layer": cube.layer, "position2": Vector3i(components[0],components[1],components[2]), "frame": frame},issues)


static func snapshot(level: Dictionary, state: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = Data.validate_level_shape(level)
	if not issues.is_empty():
		return _result(null,issues)
	issues = Data.validate_state_shape(level,state)
	if not issues.is_empty():
		return _result(null,issues)
	var worlds: Dictionary = {}
	for world in level.worlds:
		worlds[world.layer] = {"rotation": state.world_orientations[world.layer], "pivot2": world.pivot2}
	var groups: Dictionary = {}
	for group in level.groups:
		groups[group.group_id] = {"rotation": state.group_orientations[group.group_id], "pivot2": group.pivot2}
	var identity := {"rotation": 0, "pivot2": Vector3i.ZERO}
	var definitions: Array = level.cubes.duplicate(true)
	definitions.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return String(a.cube_id) < String(b.cube_id))
	var cubes: Array[Dictionary] = []
	var anchors: Array[Dictionary] = []
	for index in definitions.size():
		var cube: Dictionary = definitions[index]
		var resolved := resolve_cube(cube,worlds[cube.layer],identity if cube.group_id == &"" else groups[cube.group_id])
		if not resolved.ok:
			return _result(null,_relocate(resolved.issues,"cubes[%s]" % index))
		cubes.append(resolved.value)
	for cube in cubes:
		var faces := make_face_nodes(cube.cube_id)
		faces.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return String(a.face_id) < String(b.face_id))
		for face in faces:
			var anchor := resolve_anchor(cube,face.face)
			if not anchor.ok:
				return _result(null,_relocate(anchor.issues,"anchors[%s]" % anchors.size()))
			anchors.append(anchor.value)
	return _result({"cubes": cubes, "anchors": anchors},issues)


static func anchor_overlap(source: Dictionary, target: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	_validate_anchor(source,"source",issues)
	_validate_anchor(target,"target",issues)
	return {"ok": issues.is_empty(), "overlaps": source.position2 == target.position2 if issues.is_empty() else null, "issues": _sorted(issues)}


static func classify_face_compatibility(source: Dictionary, target: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	_validate_anchor(source,"source",issues)
	_validate_anchor(target,"target",issues)
	var compatibility: Variant = null
	if issues.is_empty():
		if source.frame.normal == target.frame.normal:
			compatibility = Types.FaceCompatibility.SAME_NORMAL
		elif source.frame.normal == -target.frame.normal:
			compatibility = Types.FaceCompatibility.OPPOSITE_NORMAL
	return {"ok": issues.is_empty(), "compatibility": compatibility, "issues": _sorted(issues)}


static func _position(center: Vector3i, rotation: int, pivot: Vector3i, operation: String, id: StringName) -> Dictionary:
	var columns := Orientation.columns(rotation)
	var delta: Array[int] = []
	for axis in 3:
		delta.append(int(center[axis]) - int(pivot[axis]))
	var output: Array[int] = []
	var issues: Array[Dictionary] = []
	for axis in 3:
		var value: int = pivot[axis]
		var operands: Array[int] = [int(pivot[axis])]
		for column in 3:
			var coefficient: int = columns[column][axis]
			value += coefficient * delta[column]
			operands.append(coefficient)
			operands.append(delta[column])
		# Valid cube24 columns are a signed permutation. With int32 inputs,
		# int64 intermediates are bounded by 3*2^31 and cannot overflow int64.
		if value < INT32_MIN or value > INT32_MAX:
			_overflow(issues,operation,axis,operands,"center2",[id])
		output.append(value)
	return {"ok": issues.is_empty(), "position": Vector3i(output[0],output[1],output[2]) if issues.is_empty() else null, "issues": issues}


static func _overflow(issues: Array[Dictionary], operation: String, axis: int, operands: Array[int], path: String, ids: Array[StringName]) -> void:
	_add(issues,Code.ARITHMETIC_OVERFLOW,path,ids,"Exact spatial output exceeds int32.",{"operation": operation, "component": ["x","y","z"][axis], "representation": "int32", "operands": operands.duplicate(), "minimum": INT32_MIN, "maximum": INT32_MAX})


static func _validate_cube(cube: Dictionary, resolved: bool, issues: Array[Dictionary]) -> void:
	var fields := {"cube_id": TYPE_STRING_NAME, "layer": TYPE_INT, "center2": TYPE_VECTOR3I, "orientation": TYPE_INT, "occludes_light": TYPE_BOOL}
	if not resolved:
		fields.merge({"group_id": TYPE_STRING_NAME, "tags": TYPE_ARRAY})
	if not _record(cube,fields,"",issues):
		return
	if not _valid_id(cube.cube_id):
		_add(issues,Code.INVALID_ID,"cube_id",[cube.cube_id],"Invalid CubeCellId.")
	if not Types.WorldLayer.values().has(cube.layer):
		_add(issues,Code.INVALID_ENUM,"layer",[cube.cube_id],"Invalid WorldLayer.")
	if not Orientation.is_valid(cube.orientation):
		_add(issues,Code.INVALID_ORIENTATION,"orientation",[cube.cube_id],"Invalid cube24.v1 orientation.")
	if not resolved:
		if cube.group_id != &"" and not _valid_id(cube.group_id):
			_add(issues,Code.INVALID_ID,"group_id",[cube.group_id],"Invalid group reference ID.")
		for index in cube.tags.size():
			if typeof(cube.tags[index]) != TYPE_STRING_NAME:
				_add(issues,Code.INVALID_TYPE,"tags[%s]" % index,[],"Tags require StringName values.")
		if cube.center2.x % 2 != 0 or cube.center2.y % 2 != 0 or cube.center2.z % 2 != 0:
			_add(issues,Code.OFF_LATTICE,"center2",[cube.cube_id],"Definition center must have even components.")


static func _validate_transform(transform: Dictionary, path: String, issues: Array[Dictionary]) -> void:
	if _record(transform,{"rotation": TYPE_INT, "pivot2": TYPE_VECTOR3I},path,issues) and not Orientation.is_valid(transform.rotation):
		_add(issues,Code.INVALID_ORIENTATION,path + ".rotation",[],"Invalid transform rotation.")


static func _validate_anchor(anchor: Dictionary, path: String, issues: Array[Dictionary]) -> void:
	if not _record(anchor,{"face_id": TYPE_STRING_NAME, "layer": TYPE_INT, "position2": TYPE_VECTOR3I, "frame": TYPE_DICTIONARY},path,issues):
		return
	if not _valid_face_id(anchor.face_id):
		_add(issues,Code.INVALID_FACE,path + ".face_id",[anchor.face_id],"Invalid local face identity.")
	if not Types.WorldLayer.values().has(anchor.layer):
		_add(issues,Code.INVALID_ENUM,path + ".layer",[anchor.face_id],"Invalid WorldLayer.")
	if _record(anchor.frame,{"u": TYPE_VECTOR3I,"v": TYPE_VECTOR3I,"normal": TYPE_VECTOR3I},path + ".frame",issues):
		if Orientation.from_columns(anchor.frame.u,anchor.frame.v,anchor.frame.normal) == -1:
			_add(issues,Code.INVALID_SURFACE_FRAME,path + ".frame",[anchor.face_id],"Expected a right-handed signed unit-axis frame.")


static func _result(value: Variant, issues: Array[Dictionary]) -> Dictionary:
	return {"ok": issues.is_empty(), "value": value if issues.is_empty() else null, "issues": _sorted(issues.duplicate(true))}


static func _relocate(issues: Array[Dictionary], prefix: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = issues.duplicate(true)
	for issue in result:
		issue.path = prefix if issue.path.is_empty() else prefix + "." + issue.path
	return _sorted(result)


static func _validate_result(result: Dictionary, value_field: String, payload_type: int, empty_value: Variant) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if not _record(result,{"ok":TYPE_BOOL,"issues":TYPE_ARRAY,value_field:TYPE_NIL},"",issues,[value_field]):
		return _sorted(issues)
	for index in result.issues.size():
		_validate_issue(result.issues[index],"issues[%s]" % index,issues)
	if not issues.is_empty():
		return _sorted(issues)
	if result.ok:
		if typeof(result[value_field]) != payload_type:
			_add(issues,Code.INVALID_TYPE,value_field,[],"Successful query requires its canonical payload.")
		if not result.issues.is_empty():
			_add(issues,Code.INVALID_TYPE,"issues",[],"Successful query cannot contain issues.")
	else:
		if result[value_field] != empty_value or typeof(result[value_field]) != typeof(empty_value):
			_add(issues,Code.INVALID_TYPE,value_field,[],"Failure cannot contain a partial payload.")
		var has_error := false
		for issue in result.issues:
			if issue.severity == Types.ValidationSeverity.ERROR:
				has_error = true
		if not has_error:
			_add(issues,Code.INVALID_TYPE,"issues",[],"Failed query requires an ERROR issue.")
		if issues.is_empty():
			var upstream: Array[Dictionary] = []
			upstream.assign(result.issues.duplicate(true))
			return upstream
	return _sorted(issues)


static func _validate_issue(issue: Variant, path: String, issues: Array[Dictionary]) -> void:
	if not _record(issue,{"code":TYPE_INT,"severity":TYPE_INT,"path":TYPE_STRING,"entity_ids":TYPE_ARRAY,"message":TYPE_STRING,"details":TYPE_DICTIONARY},path,issues):
		return
	if not Types.ValidationCode.values().has(issue.code):
		_add(issues,Code.INVALID_ENUM,path + ".code",[],"Unknown ValidationCode.")
	if not Types.ValidationSeverity.values().has(issue.severity):
		_add(issues,Code.INVALID_ENUM,path + ".severity",[],"Unknown ValidationSeverity.")
	for index in issue.entity_ids.size():
		if typeof(issue.entity_ids[index]) != TYPE_STRING_NAME:
			_add(issues,Code.INVALID_TYPE,path + ".entity_ids[%s]" % index,[],"Entity IDs must be StringName.")
	if not _canonical_details(issue.details):
		_add(issues,Code.INVALID_TYPE,path + ".details",[],"Issue details must contain canonical scalar/array/record data.")


static func _canonical_details(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item in value:
				if not _canonical_details(item,depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not _canonical_details(value[key],depth + 1):
					return false
			return true
	return false


static func _valid_face_id(id: StringName) -> bool:
	var parts := String(id).split("/")
	return parts.size() == 2 and _valid_id(StringName(parts[0])) and Types.FaceDirection.has(parts[1])


static func _record(value: Variant, fields: Dictionary, path: String, issues: Array[Dictionary], any_type: Array = []) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		_add(issues, Code.INVALID_TYPE, path, [], "Expected a record.")
		return false
	var valid := true
	for key in fields:
		var field_path: String = key if path.is_empty() else path + "." + key
		if not value.has(key):
			_add(issues, Code.MISSING_FIELD, field_path, [], "Required field is missing.")
			valid = false
		elif not any_type.has(key) and typeof(value[key]) != fields[key]:
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


static func _add(issues: Array[Dictionary], code: int, path: String, ids: Array[StringName], message: String, details: Dictionary = {}) -> void:
	var entities: Array[StringName] = ids.duplicate()
	entities.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	issues.append({"code": code, "severity": Types.ValidationSeverity.ERROR, "path": path, "entity_ids": entities, "message": message, "details": details.duplicate(true)})


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
