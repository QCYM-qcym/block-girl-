extends RefCounted
## Observation input only. No traversal, authorization fallback, or rule state.
## Basis columns are [screen right, screen up, toward viewer]; screen Y is down.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const Math = preload("res://foundation/orientation/discrete_orientation.gd")
const EPSILON := 0.000001


static func map_move(frame: Dictionary, camera_basis: Basis, screen_direction: Vector2) -> Dictionary:
	for field in ["u", "v", "normal"]:
		if not frame.has(field) or typeof(frame[field]) != TYPE_VECTOR3I:
			return _failure("frame", "Movement requires a discrete surface frame.")
	if Math.from_columns(frame.u, frame.v, frame.normal) == -1:
		return _failure("frame", "Movement requires a right-handed signed-axis surface frame.")
	if not _valid_camera(camera_basis):
		return _failure("camera_basis", "Movement requires a finite orthonormal camera basis.")
	if not screen_direction.is_finite() or screen_direction.length() <= EPSILON:
		return _failure("screen_direction", "Movement requires a nonzero finite screen direction.")
	# Quantize only the canonical halfplane representative. Quantizing each sign
	# separately would break opposite pairs at +u/-v diagonal ties.
	var reverse := screen_direction.x < 0.0 or (screen_direction.x == 0.0 and screen_direction.y < 0.0)
	var representative := -screen_direction if reverse else screen_direction
	representative = representative.normalized()
	var observed := camera_basis.x * representative.x - camera_basis.y * representative.y
	var normal := Vector3(frame.normal)
	var tangent := observed - normal * observed.dot(normal)
	if not tangent.is_finite() or tangent.length() <= EPSILON:
		return _failure("screen_direction", "The camera projects this direction too close to the face normal.")
	var axes := [Vector3(frame.u), Vector3(frame.v), -Vector3(frame.u), -Vector3(frame.v)]
	var selected := 0
	var best := -INF
	for index in range(4):
		var score: float = tangent.dot(axes[index])
		# Strict comparison preserves the frozen +u,+v,-u,-v tie order.
		if score > best:
			best = score
			selected = index
	if reverse:
		selected = (selected + 2) % 4
	return _success({"kind": Types.PuzzleActionKind.MOVE, "face_axis": selected})


static func map_rotation(intent: int, camera_basis: Basis, world: Dictionary) -> Dictionary:
	if not Types.RotationIntent.values().has(intent):
		return _failure("intent", "Unknown rotation intent.")
	if not world.has("layer") or typeof(world.layer) != TYPE_INT or not Types.WorldLayer.values().has(world.layer):
		return _failure("world.layer", "Rotation requires a valid target world.")
	for field in ["allowed_rotation_intents", "allowed_rotation_deltas"]:
		if not world.has(field) or typeof(world[field]) != TYPE_ARRAY:
			return _failure("world." + field, "Rotation requires world authorization lists.")
	if not world.allowed_rotation_intents.has(intent):
		return _failure("intent", "This rotation intent is not enabled for the target world.")
	# This API consumes an already-discrete observation basis. It does not round
	# continuous camera angles into rule axes, or accept scale/shear/reflection.
	if _discrete_basis_id(camera_basis) == -1:
		return _failure("camera_basis", "Rotation requires a discrete right-handed observation basis.")
	var signed_axis: Vector3i
	match intent:
		Types.RotationIntent.TURN_LEFT:
			signed_axis = Vector3i(camera_basis.y)
		Types.RotationIntent.TURN_RIGHT:
			signed_axis = -Vector3i(camera_basis.y)
		Types.RotationIntent.TIP_UP:
			signed_axis = -Vector3i(camera_basis.x)
		Types.RotationIntent.TIP_DOWN:
			signed_axis = Vector3i(camera_basis.x)
		Types.RotationIntent.ROLL_CLOCKWISE:
			signed_axis = -Vector3i(camera_basis.z)
		Types.RotationIntent.ROLL_COUNTERCLOCKWISE:
			signed_axis = Vector3i(camera_basis.z)
	var axis := signed_axis.abs().max_axis_index()
	var delta := Math.quarter_turn(axis, signed_axis[axis])
	if not world.allowed_rotation_deltas.has(delta):
		return _failure("world.allowed_rotation_deltas", "The observed rotation delta is not enabled for the target world.")
	var kind := Types.PuzzleActionKind.ROTATE_SURFACE if world.layer == Types.WorldLayer.SURFACE else Types.PuzzleActionKind.ROTATE_INNER
	return _success({"kind": kind, "rotation_delta": delta})


static func _valid_camera(camera: Basis) -> bool:
	return camera.is_finite() and absf(camera.x.length_squared() - 1.0) <= EPSILON and absf(camera.y.length_squared() - 1.0) <= EPSILON and absf(camera.z.length_squared() - 1.0) <= EPSILON and absf(camera.x.dot(camera.y)) <= EPSILON and absf(camera.x.dot(camera.z)) <= EPSILON and absf(camera.y.dot(camera.z)) <= EPSILON and absf(camera.determinant() - 1.0) <= EPSILON


static func _discrete_basis_id(camera: Basis) -> int:
	if not camera.is_finite():
		return -1
	for id in range(24):
		var columns := Math.columns(id)
		if camera.x == Vector3(columns[0]) and camera.y == Vector3(columns[1]) and camera.z == Vector3(columns[2]):
			return id
	return -1


static func _success(action: Dictionary) -> Dictionary:
	return {"ok": true, "action": action, "issues": []}


static func _failure(path: String, message: String) -> Dictionary:
	return {"ok": false, "action": null, "issues": [{"code": Types.ValidationCode.INVALID_ACTION, "severity": Types.ValidationSeverity.ERROR, "path": path, "entity_ids": [], "message": message, "details": {}}]}
