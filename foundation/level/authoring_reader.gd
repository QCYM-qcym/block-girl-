extends RefCounted
## Private authoring profile. Never derives anchors or executes scene scripts.
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Math = preload("res://foundation/orientation/discrete_orientation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const EPSILON := 0.000001
const CUBE_FIELDS := ["cube_id", "layer", "group_id", "occludes_light", "tags"]
const FACE_FIELDS := ["face", "walkable", "shift_exit_blocked", "shift_entry_blocked", "mechanism_ids"]


static func read_scene(root: Node3D) -> Dictionary:
	if root == null:
		return _error(1000, "root", "Expected Node3D authoring root.")
	if not _rigid(root.basis) or not root.position.is_finite():
		return _error(1101, "root.transform", "Root placement must be a finite proper rigid transform.")
	var template: Variant = root.get_meta("foundation_authoring", null)
	if not template is Dictionary or template.has("content_hash"):
		return _error(1000, "root.foundation_authoring", "Expected eighteen-field authoring template without content_hash.")
	if template.get("cubes") != [] or template.get("faces") != [] or not template.get("celestial") is Dictionary or template.celestial.get("slots") != []:
		return _error(1000, "root.foundation_authoring", "Template cubes/faces/slots must be empty; geometry comes from authoring nodes.")
	var cube_container := root.get_node_or_null("Cubes") as Node3D
	var slot_container := root.get_node_or_null("Slots") as Node3D
	if cube_container == null or slot_container == null:
		return _error(1002, "root", "Cubes and Slots direct Node3D containers are required.")
	for container in [cube_container, slot_container]:
		if container.top_level or container.transform != Transform3D.IDENTITY:
			return _error(1101, String(container.name), "Authoring containers must have identity transforms.")
	var authoring: Dictionary = template.duplicate(true)
	var cubes: Array[Dictionary] = []
	var faces: Array[Dictionary] = []
	var slots: Array[Dictionary] = []
	for child in cube_container.get_children():
		var path := "Cubes/" + String(child.name)
		if not child is Node3D:
			return _error(1000, path, "Cubes children must be Node3D records.")
		if child.top_level:
			return _error(1101, path + ".top_level", "Cube transforms must inherit the authoring root.")
		var metadata: Variant = child.get_meta("foundation_cube", null)
		if not _exact_fields(metadata, CUBE_FIELDS):
			return _error(1000, path + ".foundation_cube", "Expected explicit cube identity/layer/group/occlusion/tags metadata.")
		if typeof(metadata.cube_id) != TYPE_STRING_NAME:
			return _error(1000, path + ".cube_id", "Cube ID must be StringName, never inferred from display name.")
		var id_pattern := RegEx.new()
		id_pattern.compile("\\A[a-z][a-z0-9_]*\\z")
		if id_pattern.search(String(metadata.cube_id)) == null:
			return _error(1004, path + ".cube_id", "Cube ID must satisfy the canonical identifier grammar before face generation.")
		# Identity direct containers mean local transform already equals root-relative
		# transform (root inverse cancels root placement), including detached scenes.
		var position_result := _position(child.position, true, path + ".position")
		if not position_result.ok:
			return position_result
		var basis_result := _orientation(child.basis, path + ".basis")
		if not basis_result.ok:
			return basis_result
		var cube: Dictionary = metadata.duplicate(true)
		cube["center2"] = position_result.value
		cube["orientation"] = basis_result.value
		var config: Variant = child.get_meta("foundation_faces", null)
		if not config is Array or config.size() != 6:
			return _error(1103, path + ".foundation_faces", "All six face configurations must be explicit.")
		var generated: Array[Dictionary] = Geometry.make_face_nodes(cube.cube_id)
		var configured: Dictionary = {}
		for attributes in config:
			if not _exact_fields(attributes, FACE_FIELDS) or typeof(attributes.face) != TYPE_INT or attributes.face < 0 or attributes.face > 5:
				return _error(1103, path + ".foundation_faces", "Expected six canonical local face configurations.")
			if configured.has(attributes.face):
				return _error(1103, path + ".foundation_faces", "Each local face must occur once.")
			configured[attributes.face] = true
			for field in FACE_FIELDS:
				generated[attributes.face][field] = attributes[field].duplicate(true) if attributes[field] is Array else attributes[field]
		cubes.append(cube)
		faces.append_array(generated)
	for child in slot_container.get_children():
		var path := "Slots/" + String(child.name)
		if not child is Node3D:
			return _error(1000, path, "Slots children must be Node3D records.")
		if child.top_level or not _rigid(child.basis):
			return _error(1101, path + ".basis", "Slot transform cannot contain scale, shear or reflection.")
		var id: Variant = child.get_meta("slot_id", null)
		if typeof(id) != TYPE_STRING_NAME:
			return _error(1000, path + ".slot_id", "Slot ID must be explicit StringName.")
		var position_result := _position(child.position, false, path + ".position")
		if not position_result.ok:
			return position_result
		slots.append({"slot_id": id, "position2": position_result.value})
	authoring["cubes"] = cubes
	authoring["faces"] = faces
	authoring.celestial["slots"] = slots
	var shape_candidate := authoring.duplicate(true)
	shape_candidate["content_hash"] = "0".repeat(64)
	var issues: Array[Dictionary] = Data.validate_level_shape(shape_candidate)
	if not issues.is_empty():
		return {"ok": false, "authoring": null, "issues": issues.duplicate(true)}
	cubes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.cube_id) < String(b.cube_id))
	faces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.face_id) < String(b.face_id))
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.slot_id) < String(b.slot_id))
	return {"ok": true, "authoring": authoring, "issues": []}


static func _exact_fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size():
		return false
	for field in value:
		if typeof(field) != TYPE_STRING or field not in fields:
			return false
	return true


static func _position(position: Vector3, cube_center: bool, path: String) -> Dictionary:
	var components: Array[int] = []
	for axis in range(3):
		var doubled: float = float(position[axis]) * 2.0
		if not is_finite(doubled):
			return _error(1105, path, "Logical coordinate must be finite and within int32.")
		var quantized: float = signf(doubled) * floor(absf(doubled) + 0.5)
		if quantized < -2147483648.0 or quantized > 2147483647.0:
			return _error(1105, path, "Logical coordinate exceeds int32 before Vector3i construction.")
		if absf(doubled - quantized) > EPSILON:
			return _error(1100, path, "Authoring coordinate is off the half-grid lattice.")
		var integer := int(quantized)
		if cube_center and integer % 2 != 0:
			return _error(1100, path, "Cube center2 components must be even.")
		components.append(integer)
	return {"ok": true, "value": Vector3i(components[0], components[1], components[2])}


static func _orientation(basis: Basis, path: String) -> Dictionary:
	var columns: Array[Vector3i] = []
	for column in [basis.x, basis.y, basis.z]:
		if not column.is_finite():
			return _error(1101, path, "Cube basis must be a finite signed-axis orientation.")
		var values: Array[int] = []
		for axis in range(3):
			var value: float = column[axis]
			var nearest: float = round(value)
			if nearest < -1.0 or nearest > 1.0 or absf(value - nearest) > EPSILON:
				return _error(1101, path, "Cube basis cannot contain rotation between states, scale or shear.")
			values.append(int(nearest))
		columns.append(Vector3i(values[0], values[1], values[2]))
	var orientation: int = Math.from_columns(columns[0], columns[1], columns[2])
	if orientation < 0:
		return _error(1101, path, "Cube basis is not a proper cube24 orientation.")
	return {"ok": true, "value": orientation}


static func _rigid(basis: Basis) -> bool:
	if not basis.x.is_finite() or not basis.y.is_finite() or not basis.z.is_finite():
		return false
	for column in [basis.x, basis.y, basis.z]:
		if absf(column.length_squared() - 1.0) > EPSILON:
			return false
	return absf(basis.x.dot(basis.y)) <= EPSILON and absf(basis.y.dot(basis.z)) <= EPSILON and absf(basis.z.dot(basis.x)) <= EPSILON and absf(basis.determinant() - 1.0) <= EPSILON


static func _error(code: int, path: String, message: String) -> Dictionary:
	return {"ok": false, "authoring": null, "issues": [{"code": code, "severity": Types.ValidationSeverity.ERROR, "path": path, "entity_ids": [], "message": message, "details": {}}]}
