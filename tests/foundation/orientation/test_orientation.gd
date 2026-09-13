extends SceneTree

var failures: Array[String] = []
var checks: int = 0

# Contract cube24.v1 order, independent of the implementation's storage.
const AXES: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const DELTAS: Array[int] = [2, 3, 22, 18, 9, 12]
const TABLE_NAMES: Array[String] = [
	"ROT_X_POS", "ROT_X_NEG", "ROT_Y_POS", "ROT_Y_NEG", "ROT_Z_POS", "ROT_Z_NEG",
]
# Read-only contract fixtures, ordered FRONT/BACK/LEFT/RIGHT/TOP/BOTTOM.
# FaceDirection enum ownership remains DATA; no new enum or production adapter.
const FACE_NORMALS: Array[Vector3i] = [
	Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(-1, 0, 0),
	Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
]
const FACE_FRAMES: Array = [
	{"u": Vector3i(1, 0, 0), "v": Vector3i(0, 1, 0), "normal": Vector3i(0, 0, 1)},
	{"u": Vector3i(-1, 0, 0), "v": Vector3i(0, 1, 0), "normal": Vector3i(0, 0, -1)},
	{"u": Vector3i(0, 0, 1), "v": Vector3i(0, 1, 0), "normal": Vector3i(-1, 0, 0)},
	{"u": Vector3i(0, 0, -1), "v": Vector3i(0, 1, 0), "normal": Vector3i(1, 0, 0)},
	{"u": Vector3i(1, 0, 0), "v": Vector3i(0, 0, -1), "normal": Vector3i(0, 1, 0)},
	{"u": Vector3i(1, 0, 0), "v": Vector3i(0, 0, 1), "normal": Vector3i(0, -1, 0)},
]
const FACE_FRAME_IDS: Array[int] = [0, 4, 18, 22, 3, 2]


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	var path := "res://foundation/orientation/discrete_orientation.gd"
	if not FileAccess.file_exists(path):
		printerr("FAIL: orientation implementation missing")
		quit(1)
		return
	var math = load(path)
	if math == null or not math.can_instantiate():
		printerr("FAIL: orientation implementation cannot load")
		quit(1)
		return
	for method in ["is_valid", "columns", "from_columns", "apply", "compose", "inverse", "quarter_turn"]:
		check(math.has_method(method), "required method: " + method)
	if not failures.is_empty():
		_finish()
		return
	check(math.columns(0) == [Vector3i.RIGHT, Vector3i.UP, Vector3i(0, 0, 1)], "identity golden columns")
	check(math.apply(2, Vector3i.UP) == Vector3i(0, 0, 1), "X+ sends Y to Z")
	check(math.from_columns(Vector3i.RIGHT, Vector3i.UP, Vector3i(0, 0, -1)) == -1, "reject reflection")
	_test_bases(math)
	_test_group(math)
	check(math.has_method("reframe"), "required method: reframe")
	if math.has_method("reframe"):
		_test_reframe(math)
		_test_opposite_frames(math)
	_test_faces_and_frames(math)
	_test_legacy_parity(math)
	_finish()


func _test_bases(math) -> void:
	for invalid in [-9223372036854775807, -24, -1, 24, 25, 9223372036854775807]:
		check(not math.is_valid(invalid), "reject ID %d" % invalid)
	var id := 0
	var seen: Dictionary = {}
	for right in AXES:
		for up in AXES:
			if _dot(right, up) != 0:
				continue
			var forward := _cross(right, up)
			var basis: Array[Vector3i] = math.columns(id)
			check(math.is_valid(id), "valid ID %d" % id)
			check(basis == [right, up, forward], "contract basis %d" % id)
			check(math.from_columns(right, up, forward) == id, "contract basis lookup %d" % id)
			check(not seen.has(basis), "unique basis %d" % id)
			seen[basis.duplicate()] = true
			check(_cross(basis[0], basis[1]) == basis[2], "right-handed basis %d" % id)
			check(_dot(basis[0], basis[1]) == 0 and _dot(basis[1], basis[2]) == 0 and _dot(basis[2], basis[0]) == 0, "orthogonal basis %d" % id)
			for column in basis:
				check(_dot(column, column) == 1, "unit axis %d" % id)
			for vector in [Vector3i.ZERO, Vector3i(3, -5, 7), Vector3i(-101, 47, -19)]:
				check(math.apply(id, vector) == right * vector.x + up * vector.y + forward * vector.z, "integer application %d / %s" % [id, vector])
			basis[0] = Vector3i.ZERO
			basis.clear()
			check(math.columns(id) == [right, up, forward], "columns defensive copy %d" % id)
			id += 1
	check(id == 24 and seen.size() == 24, "exactly 24 bases")
	# Exhaust the signed-axis input domain, including all reflections and repeats.
	for right in AXES:
		for up in AXES:
			for forward in AXES:
				var result: int = math.from_columns(right, up, forward)
				if _cross(right, up) == forward:
					check(math.is_valid(result), "proper basis accepted")
				else:
					check(result == -1, "improper basis rejected")
	for bad in [Vector3i.ZERO, Vector3i(2, 0, 0), Vector3i(1, 1, 0), Vector3i(2147483647, 0, 0)]:
		check(math.from_columns(bad, AXES[2], AXES[4]) == -1, "invalid right rejected")
		check(math.from_columns(AXES[0], bad, AXES[4]) == -1, "invalid up rejected")
		check(math.from_columns(AXES[0], AXES[2], bad) == -1, "invalid forward rejected")


func _test_group(math) -> void:
	check(math.RotationAxis.X == 0 and math.RotationAxis.Y == 1 and math.RotationAxis.Z == 2, "axis contract")
	var constants: Dictionary = math.get_script_constant_map()
	for index in range(6):
		var axis: int = index / 2
		var sign_value := 1 if index % 2 == 0 else -1
		check(math.quarter_turn(axis, sign_value) == DELTAS[index], "golden quarter turn %d" % index)
		var table: Array = constants.get(TABLE_NAMES[index], [])
		check(table.size() == 24, "24 entries in " + TABLE_NAMES[index])
		for id in range(24):
			var turned: int = math.compose(DELTAS[index], id)
			var basis: Array[Vector3i] = math.columns(id)
			var expected: Array[Vector3i] = []
			for column in basis:
				expected.append(_turn_vector(axis, sign_value, column))
			check(math.columns(turned) == expected, "left quarter turn %d/%d" % [index, id])
			if table.size() == 24:
				check(table[id] == turned, "turn table %d/%d" % [index, id])
			var restored := id
			for step in range(4):
				restored = math.compose(DELTAS[index], restored)
			check(restored == id, "four turns restore %d/%d" % [index, id])
	# Ry: [-Z, +Y, +X], then Rx -> [+Y, +Z, +X] = ID 10.
	check(math.compose(2, 22) == 10, "X+ after Y+ golden")
	# Rx: [+X, +Z, -Y], then Ry -> [-Z, +X, -Y] = ID 20.
	check(math.compose(22, 2) == 20, "Y+ after X+ golden")
	check(math.apply(22, Vector3i(0, 0, 1)) == Vector3i.RIGHT, "Y+ sends Z to X")
	check(math.apply(9, Vector3i.RIGHT) == Vector3i.UP, "Z+ sends X to Y")
	for a in range(24):
		var inverse_id: int = math.inverse(a)
		check(math.is_valid(inverse_id), "valid inverse %d" % a)
		check(math.compose(a, inverse_id) == 0 and math.compose(inverse_id, a) == 0, "two-sided inverse %d" % a)
		check(math.inverse(inverse_id) == a, "inverse involution %d" % a)
		check(math.compose(0, a) == a and math.compose(a, 0) == a, "two-sided identity %d" % a)
		for b in range(24):
			var composed: int = math.compose(a, b)
			check(math.is_valid(composed), "composition closure %d/%d" % [a, b])
			for vector in [Vector3i.RIGHT, Vector3i.UP, Vector3i(0, 0, 1), Vector3i(3, -5, 7)]:
				check(math.apply(composed, vector) == math.apply(a, math.apply(b, vector)), "right operand first %d/%d/%s" % [a, b, vector])


func _test_reframe(math) -> void:
	check(math.reframe(3, 2, 0) == 1, "TOP to BOTTOM")
	check(math.reframe(3, 17, 0) == 19, "opposite normal with different tangents")
	check(math.reframe(3, 3, 9) == 9, "same full frame keeps pose")
	# Same normal but rotated tangents must still follow the generic frame formula.
	# Shift eligibility and SAME_NORMAL behavior are outside this math operation.
	check(math.reframe(0, 9, 0) == 9, "same normal still transforms tangents")
	for source in range(24):
		for target in range(24):
			for pose in range(24):
				var original: Array[int] = [source, target, pose]
				var source_columns: Array[Vector3i] = math.columns(source)
				var target_columns: Array[Vector3i] = math.columns(target)
				var pose_columns: Array[Vector3i] = math.columns(pose)
				var reframed: int = math.reframe(source, target, pose)
				check(math.is_valid(reframed), "reframe closure %s" % [original])
				check(math.reframe(target, source, reframed) == pose, "reframe round trip %s" % [original])
				# Independent coordinate projection into source followed by target expansion.
				var expected: Array[Vector3i] = []
				for column in pose_columns:
					expected.append(target_columns[0] * _dot(source_columns[0], column) + target_columns[1] * _dot(source_columns[1], column) + target_columns[2] * _dot(source_columns[2], column))
				check(math.columns(reframed) == expected, "reframe frame-coordinate mapping %s" % [original])
				check(math.compose(math.compose(source, target), pose) == math.compose(source, math.compose(target, pose)), "composition associativity %s" % [original])
				check([source, target, pose] == original and math.columns(source) == source_columns and math.columns(target) == target_columns and math.columns(pose) == pose_columns, "inputs preserved %s" % [original])


func _test_faces_and_frames(math) -> void:
	var start_checks := checks
	var identities := 0
	for rotation in range(24):
		var transformed_normals: Dictionary = {}
		var fixes_all_faces := true
		for face in range(6):
			var frame: Dictionary = FACE_FRAMES[face]
			var saved_frame: Dictionary = frame.duplicate(true)
			check(math.from_columns(frame.u, frame.v, frame.normal) == FACE_FRAME_IDS[face], "face frame contract %d" % face)
			var normal: Vector3i = math.apply(rotation, FACE_NORMALS[face])
			check(FACE_NORMALS.has(normal), "FaceDirection remains signed unit axis %d/%d" % [rotation, face])
			transformed_normals[normal] = true
			fixes_all_faces = fixes_all_faces and normal == FACE_NORMALS[face]
			var u: Vector3i = math.apply(rotation, frame.u)
			var v: Vector3i = math.apply(rotation, frame.v)
			var n: Vector3i = math.apply(rotation, frame.normal)
			check(n == normal, "SurfaceFrame normal matches FaceDirection %d/%d" % [rotation, face])
			check(_dot(u, v) == 0 and _dot(v, n) == 0 and _dot(n, u) == 0, "SurfaceFrame stays orthogonal %d/%d" % [rotation, face])
			check(_dot(u, u) == 1 and _dot(v, v) == 1 and _dot(n, n) == 1, "SurfaceFrame stays unit %d/%d" % [rotation, face])
			check(_cross(u, v) == n, "SurfaceFrame U cross V equals N %d/%d" % [rotation, face])
			var frame_id: int = math.from_columns(u, v, n)
			check(math.is_valid(frame_id), "transformed SurfaceFrame encodes in cube24 %d/%d" % [rotation, face])
			check(frame_id == math.compose(rotation, FACE_FRAME_IDS[face]), "SurfaceFrame and CubeOrientation transformation agree %d/%d" % [rotation, face])
			check(math.from_columns(u, v, -n) == -1, "mirrored SurfaceFrame rejected %d/%d" % [rotation, face])
			check(math.from_columns(u, u, n) == -1, "parallel SurfaceFrame tangents rejected %d/%d" % [rotation, face])
			check(frame == saved_frame, "SurfaceFrame fixture unchanged %d/%d" % [rotation, face])
		check(transformed_normals.size() == 6, "FaceDirection transform is a permutation %d" % rotation)
		if fixes_all_faces:
			identities += 1
			check(rotation == 0, "only ID 0 fixes all face directions")
		for axis in range(3):
			var positive: int = math.quarter_turn(axis, 1)
			var negative: int = math.quarter_turn(axis, -1)
			check(math.compose(negative, math.compose(positive, rotation)) == rotation, "+90 then -90 restores pose %d/%d" % [axis, rotation])
			check(math.compose(positive, math.compose(negative, rotation)) == rotation, "-90 then +90 restores pose %d/%d" % [axis, rotation])
	check(identities == 1, "identity exists and is unique")
	# Explicit FRONT/+Z goldens catch FRONT/FORWARD or rotation sign confusion.
	check(math.apply(2, FACE_NORMALS[0]) == FACE_NORMALS[5], "X+ sends FRONT to BOTTOM")
	check(math.apply(22, FACE_NORMALS[0]) == FACE_NORMALS[3], "Y+ sends FRONT to RIGHT")
	check(math.apply(9, FACE_NORMALS[3]) == FACE_NORMALS[4], "Z+ sends RIGHT to TOP")
	print("FACE_FRAME checks=", checks - start_checks)


func _test_opposite_frames(math) -> void:
	var start_checks := checks
	var opposite_pairs := 0
	for source in range(24):
		var s: Array[Vector3i] = math.columns(source)
		for target in range(24):
			var t: Array[Vector3i] = math.columns(target)
			if s[2] != -t[2]:
				continue
			opposite_pairs += 1
			var delta: int = math.compose(target, math.inverse(source))
			check(math.is_valid(delta), "OPPOSITE_NORMAL has defined cube24 delta %d/%d" % [source, target])
			for axis in range(3):
				check(math.apply(delta, s[axis]) == t[axis], "OPPOSITE_NORMAL maps full U/V/N %d/%d/%d" % [source, target, axis])
			check(math.compose(delta, delta) == 0, "opposite-normal frame delta is a half turn %d/%d" % [source, target])
			for pose in range(24):
				var result: int = math.reframe(source, target, pose)
				check(math.is_valid(result) and result == math.compose(delta, pose), "OPPOSITE_NORMAL maps every CubeOrientation %d/%d/%d" % [source, target, pose])
	check(opposite_pairs == 96, "24 frames each have four opposite-normal tangent frames")
	print("OPPOSITE_FRAME pairs=", opposite_pairs, " checks=", checks - start_checks)


func _test_legacy_parity(math) -> void:
	var start_checks := checks
	var path := "res://prototype/perspective/cube_orientation.gd"
	check(FileAccess.file_exists(path), "legacy CubeOrientation available for read-only parity")
	if not FileAccess.file_exists(path):
		return
	var legacy = load(path)
	check(legacy != null and legacy.can_instantiate(), "legacy CubeOrientation loads")
	if legacy == null or not legacy.can_instantiate():
		return
	# Same reachability approach as existing test_perspective_logic.gd.
	# Traversal discovers old poses only; frozen IDs come from exact column lookup.
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT]
	var roll_deltas: Array[int] = [3, 2, 12, 9]
	var reached: Dictionary = {}
	var queue: Array = [legacy.new()]
	while not queue.is_empty() and reached.size() <= 24:
		var pose = queue.pop_back()
		if reached.has(pose.key()):
			continue
		reached[pose.key()] = pose
		for direction in directions:
			var next = pose.copy()
			next.roll(direction)
			queue.append(next)
	check(reached.size() == 24, "legacy graph reaches exactly 24 states")
	var matched: Dictionary = {}
	for pose in reached.values():
		var id: int = math.from_columns(pose.right, pose.up, pose.forward)
		check(math.is_valid(id), "legacy columns map to frozen ID")
		if not math.is_valid(id):
			continue
		check(not matched.has(id), "legacy to cube24 mapping is injective %d" % id)
		matched[id] = true
		check(math.apply(id, Vector3i(0, 0, 1)) == pose.face_direction(), "legacy physical +Z face parity %d" % id)
		for index in range(4):
			var next = pose.copy()
			next.roll(directions[index])
			var next_id: int = math.from_columns(next.right, next.up, next.forward)
			check(next_id == math.compose(roll_deltas[index], id), "legacy roll transition parity %d/%d" % [id, index])
		for index in range(6):
			var axis: Vector3i = AXES[index]
			var legacy_columns: Array[Vector3i] = [pose.quarter(pose.right, axis), pose.quarter(pose.up, axis), pose.quarter(pose.forward, axis)]
			check(math.columns(math.compose(DELTAS[index], id)) == legacy_columns, "legacy six-axis quarter parity %d/%d" % [id, index])
	check(matched.size() == 24, "legacy to cube24 mapping is bijective")
	print("LEGACY_PARITY states=", reached.size(), " rolls=96 quarter_turns=144 checks=", checks - start_checks)


func _dot(a: Vector3i, b: Vector3i) -> int:
	return a.x * b.x + a.y * b.y + a.z * b.z


func _cross(a: Vector3i, b: Vector3i) -> Vector3i:
	return Vector3i(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)


func _turn_vector(axis: int, sign_value: int, vector: Vector3i) -> Vector3i:
	match axis:
		0:
			return Vector3i(vector.x, -sign_value * vector.z, sign_value * vector.y)
		1:
			return Vector3i(sign_value * vector.z, vector.y, -sign_value * vector.x)
		_:
			return Vector3i(-sign_value * vector.y, sign_value * vector.x, vector.z)


func _finish() -> void:
	print("ORIENTATION checks=", checks, " failures=", failures)
	if not failures.is_empty():
		printerr("FAIL: orientation checks failed")
	else:
		print("FOUNDATION_ORIENTATION_MATH_PASS orientation_version=cube24.v1")
	quit(0 if failures.is_empty() else 1)
