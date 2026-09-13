extends RefCounted
## Pure source-to-anchor queries on one stable Shared Space snapshot.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const INT64_MAX: int = 9223372036854775807


static func query(anchor: Dictionary, slot: Dictionary, cubes: Array[Dictionary]) -> Dictionary:
	if not _valid_anchor(anchor):
		return _invalid(Types.ValidationCode.INVALID_ANCHOR, "anchor", "Expected a FaceAnchor value record.")
	if not _valid_frame(anchor.frame):
		return _invalid(Types.ValidationCode.INVALID_SURFACE_FRAME, "anchor.frame", "Expected a right-handed signed-axis frame.")
	if typeof(slot.get("position2")) != TYPE_VECTOR3I or typeof(slot.get("slot_id")) != TYPE_STRING_NAME or slot.get("slot_id", &"") == &"":
		return _invalid(Types.ValidationCode.LIGHT_SOURCE_INVALID, "slot", "Expected an integer CelestialSlot source.")
	var source: Vector3i = slot.position2
	var target: Vector3i = anchor.position2
	if source == target:
		return _invalid(Types.ValidationCode.LIGHT_SOURCE_INVALID, "slot.position2", "Source coincides with the anchor.")
	var ordered: Array[Dictionary] = []
	var seen: Dictionary = {}
	for index in range(cubes.size()):
		var cube: Dictionary = cubes[index]
		if not _valid_cube(cube):
			return _invalid(Types.ValidationCode.INVALID_TYPE, "cubes[%d]" % index, "Expected a ResolvedCube value record.")
		if seen.has(cube.cube_id):
			return _invalid(Types.ValidationCode.DUPLICATE_ID, "cubes[%d].cube_id" % index, "Cube IDs must be unique.")
		seen[cube.cube_id] = true
		if cube.layer == anchor.layer and cube.occludes_light:
			ordered.append(cube)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.cube_id) < String(b.cube_id))
	# Check the closed source volume even for back-facing/tangent receivers.
	for cube in ordered:
		if _contains(source, cube.center2):
			return _invalid(Types.ValidationCode.LIGHT_SOURCE_INVALID, "slot.position2", "Source lies in an occluder's closed volume.", [cube.cube_id])
	# Vector3i subtraction/dot would use 32-bit components. Promote first.
	var direction: Array[int] = []
	var incidence: int = 0
	var normal: Vector3i = anchor.frame.normal
	for axis in range(3):
		var delta: int = int(target[axis]) - int(source[axis])
		direction.append(delta)
		# A validated signed unit normal selects at most one component.
		incidence -= int(normal[axis]) * delta
	if incidence <= 0:
		return _result(Types.LightState.SHADOW, &"BACK_OR_TANGENT")
	var nearest: Array[int] = [1, 1]
	var occluder_id: StringName = &""
	for cube in ordered:
		var hit: Dictionary = _intersect(source, direction, cube.center2)
		if not hit.ok:
			return _invalid(Types.ValidationCode.ARITHMETIC_OVERFLOW, "cubes", "Exact interval comparison exceeds int64.", [cube.cube_id])
		if not hit.hit:
			continue
		var entry: Array[int] = hit.entry
		var comparison: Dictionary = _compare(entry, nearest)
		if not comparison.ok:
			return _invalid(Types.ValidationCode.ARITHMETIC_OVERFLOW, "cubes", "Exact nearest-hit comparison exceeds int64.", [cube.cube_id])
		if comparison.order < 0:
			nearest = entry
			occluder_id = cube.cube_id
		# Sorted IDs retain the first candidate for an exact tie.
	if occluder_id != &"":
		return _result(Types.LightState.SHADOW, &"OCCLUDED", occluder_id)
	return _result(Types.LightState.LIT, &"FRONT_CLEAR")


static func _intersect(source: Vector3i, direction: Array[int], center: Vector3i) -> Dictionary:
	var entry: Array[int] = [0, 1]
	var leave: Array[int] = [1, 1]
	for axis in range(3):
		var low: int = int(center[axis]) - 1
		var high: int = int(center[axis]) + 1
		var origin: int = source[axis]
		var delta: int = direction[axis]
		if delta == 0:
			if origin < low or origin > high:
				return {"ok": true, "hit": false}
			continue
		var near_axis: Array[int]
		var far_axis: Array[int]
		if delta > 0:
			near_axis = [low - origin, delta]
			far_axis = [high - origin, delta]
		else:
			near_axis = [origin - high, -delta]
			far_axis = [origin - low, -delta]
		var near_cmp: Dictionary = _compare(near_axis, entry)
		var far_cmp: Dictionary = _compare(far_axis, leave)
		if not near_cmp.ok or not far_cmp.ok:
			return {"ok": false}
		if near_cmp.order > 0:
			entry = near_axis
		if far_cmp.order < 0:
			leave = far_axis
		var interval_cmp: Dictionary = _compare(entry, leave)
		if not interval_cmp.ok:
			return {"ok": false}
		if interval_cmp.order > 0:
			return {"ok": true, "hit": false}
	# Bounds are clipped to [0,1]; equality inside the open segment is grazing.
	if leave[0] <= 0 or entry[0] >= entry[1]:
		return {"ok": true, "hit": false}
	return {"ok": true, "hit": true, "entry": entry}


static func _compare(a: Array[int], b: Array[int]) -> Dictionary:
	# Numerators originate in int32 coordinates +/-1 and their differences;
	# they cannot equal INT64_MIN. Denominators are strictly positive.
	if not _product_fits(a[0], b[1]) or not _product_fits(b[0], a[1]):
		return {"ok": false}
	var left: int = a[0] * b[1]
	var right: int = b[0] * a[1]
	return {"ok": true, "order": -1 if left < right else (1 if left > right else 0)}


@warning_ignore("integer_division")
static func _product_fits(numerator: int, denominator: int) -> bool:
	return absi(numerator) <= INT64_MAX / denominator


static func _contains(point: Vector3i, center: Vector3i) -> bool:
	for axis in range(3):
		if int(point[axis]) < int(center[axis]) - 1 or int(point[axis]) > int(center[axis]) + 1:
			return false
	return true


static func _valid_layer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value in [Types.WorldLayer.SURFACE, Types.WorldLayer.INNER]


static func _valid_anchor(anchor: Dictionary) -> bool:
	return typeof(anchor.get("face_id")) == TYPE_STRING_NAME and anchor.get("face_id", &"") != &"" and _valid_layer(anchor.get("layer")) and typeof(anchor.get("position2")) == TYPE_VECTOR3I and typeof(anchor.get("frame")) == TYPE_DICTIONARY


static func _valid_cube(cube: Dictionary) -> bool:
	if typeof(cube.get("cube_id")) != TYPE_STRING_NAME or cube.get("cube_id", &"") == &"" or not _valid_layer(cube.get("layer")):
		return false
	if typeof(cube.get("center2")) != TYPE_VECTOR3I or typeof(cube.get("occludes_light")) != TYPE_BOOL:
		return false
	return typeof(cube.get("orientation")) == TYPE_INT and cube.orientation >= 0 and cube.orientation < 24


static func _valid_frame(frame: Dictionary) -> bool:
	for key in ["u", "v", "normal"]:
		if typeof(frame.get(key)) != TYPE_VECTOR3I:
			return false
		var vector: Vector3i = frame[key]
		if absi(int(vector.x)) + absi(int(vector.y)) + absi(int(vector.z)) != 1:
			return false
	var u: Vector3i = frame.u
	var v: Vector3i = frame.v
	var cross := Vector3i(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x)
	return cross == frame.normal


static func _result(state: int, reason: StringName, occluder_id: StringName = &"") -> Dictionary:
	var issues: Array[Dictionary] = []
	return {"ok": true, "light_state": state, "reason": reason, "occluder_id": occluder_id, "issues": issues}


static func _invalid(code: int, path: String, message: String, entity_ids: Array[StringName] = []) -> Dictionary:
	var issues: Array[Dictionary] = [{"code": code, "severity": Types.ValidationSeverity.ERROR, "path": path, "entity_ids": entity_ids, "message": message, "details": {}}]
	return {"ok": false, "light_state": null, "reason": &"INVALID", "occluder_id": &"", "issues": issues}
