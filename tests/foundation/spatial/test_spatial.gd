extends SceneTree
## Golden fixtures are deliberately independent of DATA/MATH/SPATIAL.
## --fixtures-only checks fixture consistency, never module acceptance.
## Default execution requires the real modules and exits 1 if any is absent.

const REQUIRED_SCRIPTS := [
	"res://foundation/contracts/foundation_types.gd",
	"res://foundation/contracts/contract_records.gd",
	"res://foundation/contracts/contract_validation.gd",
	"res://foundation/orientation/discrete_orientation.gd",
	"res://foundation/spatial/surface_geometry.gd",
	"res://foundation/spatial/spatial_validation.gd",
]
const FACE_SYMBOLS := ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
# Contract section 3.2: [u, v, normal], with FRONT = +Z.
const FRAMES := [
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
	[Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, -1)],
	[Vector3i(0, 0, 1), Vector3i(0, 1, 0), Vector3i(-1, 0, 0)],
	[Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(1, 0, 0)],
	[Vector3i(1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, 1, 0)],
	[Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, -1, 0)],
]
# Contract section 4: literal right/up/forward columns, not MATH-generated.
const ORIENTATIONS := [
	[Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,0,1)],
	[Vector3i(1,0,0), Vector3i(0,-1,0), Vector3i(0,0,-1)],
	[Vector3i(1,0,0), Vector3i(0,0,1), Vector3i(0,-1,0)],
	[Vector3i(1,0,0), Vector3i(0,0,-1), Vector3i(0,1,0)],
	[Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,0,-1)],
	[Vector3i(-1,0,0), Vector3i(0,-1,0), Vector3i(0,0,1)],
	[Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,1,0)],
	[Vector3i(-1,0,0), Vector3i(0,0,-1), Vector3i(0,-1,0)],
	[Vector3i(0,1,0), Vector3i(1,0,0), Vector3i(0,0,-1)],
	[Vector3i(0,1,0), Vector3i(-1,0,0), Vector3i(0,0,1)],
	[Vector3i(0,1,0), Vector3i(0,0,1), Vector3i(1,0,0)],
	[Vector3i(0,1,0), Vector3i(0,0,-1), Vector3i(-1,0,0)],
	[Vector3i(0,-1,0), Vector3i(1,0,0), Vector3i(0,0,1)],
	[Vector3i(0,-1,0), Vector3i(-1,0,0), Vector3i(0,0,-1)],
	[Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(-1,0,0)],
	[Vector3i(0,-1,0), Vector3i(0,0,-1), Vector3i(1,0,0)],
	[Vector3i(0,0,1), Vector3i(1,0,0), Vector3i(0,1,0)],
	[Vector3i(0,0,1), Vector3i(-1,0,0), Vector3i(0,-1,0)],
	[Vector3i(0,0,1), Vector3i(0,1,0), Vector3i(-1,0,0)],
	[Vector3i(0,0,1), Vector3i(0,-1,0), Vector3i(1,0,0)],
	[Vector3i(0,0,-1), Vector3i(1,0,0), Vector3i(0,-1,0)],
	[Vector3i(0,0,-1), Vector3i(-1,0,0), Vector3i(0,1,0)],
	[Vector3i(0,0,-1), Vector3i(0,1,0), Vector3i(1,0,0)],
	[Vector3i(0,0,-1), Vector3i(0,-1,0), Vector3i(-1,0,0)],
]

var checks := 0
var failures: Array[String] = []
var mapping: Script
var geometry: Script
var validation: Script
var data: Script
var records: Script


func _initialize() -> void:
	_run_test("golden fixtures", _test_golden_fixtures)
	if OS.get_cmdline_user_args().has("--fixtures-only"):
		_finish("SPATIAL_GOLDEN_FIXTURES_ONLY")
		return
	var geometry_only := OS.get_cmdline_user_args().has("--geometry-only")
	for index in REQUIRED_SCRIPTS.size():
		if geometry_only and index in [1,2]:
			continue
		var path: String = REQUIRED_SCRIPTS[index]
		check(FileAccess.file_exists(path), "required real module missing: " + path)
	if not failures.is_empty():
		_finish("SPATIAL_INTEGRATION_NOT_RUN")
		return
	geometry = load(REQUIRED_SCRIPTS[4])
	validation = load(REQUIRED_SCRIPTS[5])
	var loaded: Array = [geometry, validation]
	if not geometry_only:
		data = load(REQUIRED_SCRIPTS[2])
		records = load(REQUIRED_SCRIPTS[1])
		loaded.append_array([data, records])
	for script in loaded:
		check(script != null and script.can_instantiate(), "real script compiles")
	if not failures.is_empty():
		_finish("SPATIAL_INTEGRATION_NOT_RUN")
		return
	_run_test("six FaceNode factory", _test_face_nodes)
	if not geometry_only:
		_run_test("overlap and classification", _test_spatial_predicates)
	_run_test("faces and orientations", _test_faces_and_orientations)
	_run_test("hierarchy", _test_hierarchy)
	if not geometry_only:
		_run_test("real DATA snapshot integration", _test_snapshot)
		_run_test("coordinate range contract", _test_coordinate_range)
	_run_test("overlap and sealing", _test_overlap_and_sealed_faces)
	_run_test("invalid snapshots", _test_invalid_snapshot)
	if not geometry_only:
		if FileAccess.file_exists("res://foundation/spatial/mapping_query.gd"):
			mapping = load("res://foundation/spatial/mapping_query.gd")
		if mapping != null and mapping.can_instantiate():
			_run_test("mapping queries", _test_mapping_queries)
		else:
			check(false, "new canonical mapping_query implementation missing")
	_finish("SPATIAL_GEOMETRY_ONLY" if geometry_only else "FOUNDATION_SPATIAL_MODEL_PASS")


func _run_test(label: String, test: Callable) -> void:
	var before_checks := checks
	var before_failures := failures.size()
	var completed: Variant = test.call()
	check(completed == true, label + " completed without an aborted function")
	print("SECTION: ",label," checks=",checks-before_checks," failures=",failures.size()-before_failures)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)


func _finish(label: String) -> void:
	if failures.is_empty():
		print(label, ": ", checks, " checks; 0 failures")
		quit(0)
	else:
		print("SPATIAL_TEST_FAILED: ", checks, " checks; ", failures.size(), " failures")
		quit(1)


func _cross(a: Vector3i, b: Vector3i) -> Vector3i:
	return Vector3i(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)


func _dot(a: Vector3i, b: Vector3i) -> int:
	return a.x * b.x + a.y * b.y + a.z * b.z


func _is_frame(u: Vector3i, v: Vector3i, n: Vector3i) -> bool:
	return _dot(u, u) == 1 and _dot(v, v) == 1 and _dot(n, n) == 1 and _dot(u, v) == 0 and _cross(u, v) == n


func _test_golden_fixtures() -> bool:
	check(FRAMES.size() == 6, "fixture has six local faces")
	for face in 6:
		var frame: Array = FRAMES[face]
		check(_is_frame(frame[0], frame[1], frame[2]), "golden face frame " + FACE_SYMBOLS[face])
	check(ORIENTATIONS.size() == 24, "fixture has all 24 frozen orientations")
	for id in ORIENTATIONS.size():
		var columns: Array = ORIENTATIONS[id]
		check(_is_frame(columns[0], columns[1], columns[2]), "golden proper rotation %s" % id)
		for earlier in id:
			check(columns != ORIENTATIONS[earlier], "unique golden rotations %s/%s" % [earlier, id])
	check(FRAMES[4] == [Vector3i.RIGHT, Vector3i(0,0,-1), Vector3i.UP], "TOP golden basis")
	check(FRAMES[0][2] == Vector3i(0,0,1), "logical FRONT points +Z")
	return true


func _test_faces_and_orientations() -> bool:
	for face in 6:
		var frame: Dictionary = geometry.face_frame(face)
		check(frame == {"u": FRAMES[face][0], "v": FRAMES[face][1], "normal": FRAMES[face][2]}, "six-face golden " + FACE_SYMBOLS[face])
		check(geometry.face_id(&"tile_a", face) == StringName("tile_a/" + FACE_SYMBOLS[face]), "local face identity " + FACE_SYMBOLS[face])
		frame.u = Vector3i.ZERO
		check(geometry.face_frame(face).u == FRAMES[face][0], "face_frame owns a fresh record")
	for id in 24:
		var columns: Array = ORIENTATIONS[id]
		# Each local face normal/tangent is a signed column; this oracle never
		# calls MATH.apply or the production geometry when deriving expectations.
		var expected: Array = [
			[columns[0], columns[1], columns[2]],
			[-columns[0], columns[1], -columns[2]],
			[columns[2], columns[1], -columns[0]],
			[-columns[2], columns[1], columns[0]],
			[columns[0], -columns[2], columns[1]],
			[columns[0], columns[2], -columns[1]],
		]
		var cube := _resolved(&"tile_a", 0, Vector3i(2,4,-6), id)
		var before := cube.duplicate(true)
		for face in 6:
			var anchor: Dictionary = _resolve_anchor(cube, face)
			var want: Array = expected[face]
			check(anchor.position2 == Vector3i(2,4,-6) + want[2], "anchor normal offset %s/%s" % [id, face])
			check(anchor.frame == {"u": want[0], "v": want[1], "normal": want[2]}, "rotated complete frame %s/%s" % [id, face])
			check(_is_frame(anchor.frame.u, anchor.frame.v, anchor.frame.normal), "proper frame %s/%s" % [id, face])
			check(anchor.face_id == StringName("tile_a/" + FACE_SYMBOLS[face]) and anchor.layer == 0, "rotation preserves local identity %s/%s" % [id, face])
		check(cube == before, "resolve_anchor does not mutate input")
	return true


func _test_hierarchy() -> bool:
	var cube := _cube(&"tile_a", 0, Vector3i(2,0,0))
	var identity := _transform(0)
	var world := _transform(2)
	var group := _transform(22)
	var original := [cube.duplicate(true), world.duplicate(true), group.duplicate(true)]
	var resolved: Dictionary = _resolve_cube(cube, identity, identity)
	check(resolved == _resolved(&"tile_a", 0, Vector3i(2,0,0), 0), "identity resolved record")
	check(_resolve_anchor(resolved, 4).position2 == Vector3i(2,1,0), "half-grid TOP anchor")
	resolved = _resolve_cube(cube, world, group)
	check(resolved.center2 == Vector3i(0,2,0) and resolved.orientation == 10, "noncommuting W*G*C golden")
	check(_resolve_anchor(resolved, 4).position2 == Vector3i(0,2,1), "X+ world / Y+ group TOP golden")
	var reversed: Dictionary = _resolve_cube(cube, group, world)
	check(reversed.center2 == Vector3i(0,0,-2) and reversed.orientation == 20, "swapping W and G changes golden")
	check([cube, world, group] == original, "resolve_cube preserves all inputs")
	cube.orientation = 9
	resolved = _resolve_cube(cube, world, group)
	check(resolved.center2 == Vector3i(0,2,0) and resolved.orientation == 19, "static C rotates basis but not cube center")
	resolved = _resolve_cube(_cube(&"tile_a", 0, Vector3i(2,0,0)), _transform(2, Vector3i(0,2,0)), _transform(22, Vector3i(2,0,2)))
	check(resolved.center2 == Vector3i(0,0,-2), "distinct world and group pivot spaces")
	resolved = _resolve_cube(_cube(&"tile_a", 0, Vector3i(2,0,0)), identity, _transform(22, Vector3i(1,0,0)))
	check(resolved.center2 == Vector3i(1,0,-1), "odd pivot stays exact; no rounding")
	var odd_snapshot := {"cubes": [resolved], "anchors": []}
	for face in 6:
		odd_snapshot.anchors.append(_resolve_anchor(resolved, face))
	check(_has_code(_validate(odd_snapshot, _faces(&"tile_a")), 1100), "odd center is OFF_LATTICE at validation boundary")
	return true


func _test_snapshot() -> bool:
	var level := _level()
	if not _valid_level(level):
		return false
	var state: Dictionary = records.initial_state(level)
	if not _valid_state(level, state):
		return false
	var before_level := level.duplicate(true)
	var before_state := state.duplicate(true)
	var snapshot: Dictionary = _snapshot(level, state)
	check(snapshot.cubes.size() == 1 and snapshot.anchors.size() == 6, "snapshot contains every cube and its six faces")
	check(_find_anchor(snapshot, &"tile_a/TOP").position2 == Vector3i(0,1,0), "identity snapshot golden anchor")
	check(_validate(snapshot, _typed_faces(level.faces)).is_empty(), "initial stable snapshot validates")
	check(level == before_level and state == before_state, "snapshot preserves level/state")
	check(snapshot == _snapshot(level, state), "repeat snapshot is deterministic")
	snapshot.anchors[0].frame.u = Vector3i.ZERO
	check(_snapshot(level, state) != snapshot, "returned nested frames do not alias future snapshots")
	level.cubes.append(_cube(&"cube_b", 1, Vector3i(8,0,0)))
	level.faces.append_array(_faces(&"cube_b"))
	level.cubes[0].center2 = Vector3i(2,0,0)
	level.cubes[0].group_id = &"group_a"
	level.groups = [{"group_id": &"group_a", "layer": 0, "cube_ids": [&"tile_a"], "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0,22], "allowed_rotation_deltas": [22], "edges": [{"from_orientation": 0, "rotation_delta": 22, "to_orientation": 22}]}]
	level.worlds[0].allowed_states = [0,2]
	level.worlds[0].allowed_rotation_deltas = [2]
	if not _valid_level(level):
		return false
	state = records.initial_state(level)
	state.world_orientations[0] = 2
	state.group_orientations[&"group_a"] = 22
	if not _valid_state(level, state):
		return false
	before_level = level.duplicate(true)
	before_state = state.duplicate(true)
	snapshot = _snapshot(level, state)
	check(snapshot.cubes[0].cube_id == &"cube_b" and snapshot.cubes[1].cube_id == &"tile_a", "cube byte-order sort")
	check(snapshot.cubes[1].center2 == Vector3i(0,2,0) and snapshot.cubes[1].orientation == 10, "snapshot uses committed world/group states")
	var top := _find_anchor(snapshot, &"tile_a/TOP")
	check(top.position2 == Vector3i(0,2,1) and top.frame.normal == Vector3i(0,0,1), "snapshot rotates TOP geometry without renaming")
	var actual_ids: Array = []
	for anchor in snapshot.anchors:
		actual_ids.append(anchor.face_id)
	var expected_ids: Array = []
	for cube_id in ["cube_b", "tile_a"]:
		for symbol in ["BACK", "BOTTOM", "FRONT", "LEFT", "RIGHT", "TOP"]:
			expected_ids.append(StringName(cube_id + "/" + symbol))
	check(actual_ids == expected_ids, "all anchors sorted by immutable face_id")
	check(_validate(snapshot, _typed_faces(level.faces)).is_empty(), "rotated stable configuration validates")
	check(level == before_level and state == before_state, "rotated snapshot preserves inputs")
	level.cubes.reverse()
	level.faces.reverse()
	level.worlds.reverse()
	check(snapshot == _snapshot(level, state), "permuted definition arrays give identical sorted snapshot")
	check(snapshot == _snapshot(level, state), "repeated transformed snapshot does not accumulate transforms")
	return true


func _test_overlap_and_sealed_faces() -> bool:
	var snapshot := _pair_snapshot(Vector3i.ZERO, 0)
	var faces := _faces(&"tile_a")
	faces.append_array(_faces(&"tile_b"))
	check(_has_code(_validate(snapshot, faces), 1200), "same-world volume overlap rejected")
	snapshot = _pair_snapshot(Vector3i.ZERO, 1)
	check(_validate(snapshot, faces).is_empty(), "cross-world overlap is legal geometry")
	snapshot = _pair_snapshot(Vector3i(2,0,0), 0)
	check(_validate(snapshot, faces).is_empty(), "same-world shared boundary is not volume overlap")
	faces[3].walkable = true
	faces[6 + 2].walkable = true
	var issues: Array[Dictionary] = _validate(snapshot, faces)
	check(_has_code(issues, 1201), "internal opposing walkable faces rejected")
	check(not _has_code(issues, 1200), "sealed faces do not imply volume overlap")
	faces[3].walkable = false
	faces[6 + 2].walkable = false
	faces[2].walkable = true
	faces[6 + 3].walkable = true
	check(_validate(snapshot, faces).is_empty(), "outer walkable faces are not sealed")
	for offset in [Vector3i(2,2,0), Vector3i(2,2,2)]:
		check(_validate(_pair_snapshot(offset, 0), faces).is_empty(), "edge/corner contact leaves faces exposed %s" % offset)
	# Rotate a cube's local RIGHT to world +Y: sealing must use resolved normal.
	snapshot = _pair_snapshot(Vector3i(0,2,0), 0)
	snapshot.cubes[0].orientation = 9
	snapshot.anchors.clear()
	for cube in snapshot.cubes:
		for face in 6:
			snapshot.anchors.append(_resolve_anchor(cube, face))
	faces = _faces(&"tile_a")
	faces.append_array(_faces(&"tile_b"))
	faces[3].walkable = true
	check(_has_code(_validate(snapshot, faces), 1201), "sealed test follows rotated local RIGHT")
	return true


func _test_coordinate_range() -> bool:
	var identity := _transform(0)
	var edge_cube := _cube(&"tile_a", 0, Vector3i(-2147483648,0,0))
	var resolved: Dictionary = geometry.resolve_cube(edge_cube, identity, identity)
	check(resolved.ok, "extreme representable cube center is accepted")
	if not resolved.ok:
		return false
	var overflow: Dictionary = geometry.resolve_anchor(resolved.value, 2)
	_check_overflow(overflow, "ANCHOR_DERIVATION", "position2")
	var level := _level()
	level.cubes[0].center2 = edge_cube.center2
	if not _valid_level(level):
		return false
	var state: Dictionary = records.initial_state(level)
	overflow = geometry.snapshot(level, state)
	_check_overflow(overflow, "ANCHOR_DERIVATION", "anchors[3].position2")
	check(validation.validate_snapshot(overflow, _typed_faces(level.faces)) == overflow.issues, "LEFT overflow propagates unchanged through validation")
	level = _level()
	level.worlds[0].pivot2 = Vector3i(2147483646,0,0)
	level.worlds[0].initial_orientation = 4
	level.worlds[0].allowed_states = [4]
	if not _valid_level(level):
		return false
	state = records.initial_state(level)
	overflow = geometry.snapshot(level, state)
	_check_overflow(overflow, "WORLD_TRANSFORM", "cubes[0].center2")
	check(validation.validate_snapshot(overflow, _typed_faces(level.faces)) == overflow.issues, "world overflow propagates unchanged through validation")
	var cube := _cube(&"tile_a", 0, Vector3i.ZERO)
	var huge := _transform(4, Vector3i(2147483646,0,0))
	_check_overflow(geometry.resolve_cube(cube, huge, identity), "WORLD_TRANSFORM", "center2")
	_check_overflow(geometry.resolve_cube(cube, huge, huge), "GROUP_TRANSFORM", "center2")
	var large_identity := _transform(0, Vector3i(2147483647,-2147483648,2147483647))
	var safe: Dictionary = geometry.resolve_cube(edge_cube, large_identity, large_identity)
	check(safe.ok and safe.value.center2 == edge_cube.center2, "wide temporary differences with representable endpoint succeed")
	for axis in 3:
		var center := Vector3i.ZERO
		center[axis] = -2147483648
		var face: int = [2,5,1][axis]
		var boundary := _resolved(&"tile_a",0,center,0)
		var result: Dictionary = geometry.resolve_anchor(boundary, face)
		check(not result.ok and result.value == null and result.issues[0].details.component == ["x","y","z"][axis], "overflow component %s" % axis)
	var bad := cube.duplicate(true)
	bad.orientation = 24
	var rejected: Dictionary = geometry.resolve_cube(bad, identity, identity)
	check(not rejected.ok and _has_code(rejected.issues,1101), "checked cube rejects invalid orientation without assertions")
	bad = cube.duplicate(true)
	bad.center2 = Vector3.ZERO
	rejected = geometry.resolve_cube(bad, identity, identity)
	check(not rejected.ok and _has_code(rejected.issues,1000), "checked cube refuses floating coordinates")
	rejected = geometry.resolve_anchor(_resolved(&"tile_a",0,Vector3i.ZERO,0), 6)
	check(not rejected.ok and _has_code(rejected.issues,1103), "checked anchor rejects invalid face")
	var wrong_level := _level()
	wrong_level["extra"] = true
	rejected = geometry.snapshot(wrong_level, state)
	check(not rejected.ok and rejected.value == null and _has_code(rejected.issues,1001), "snapshot validates DATA before derivation: %s" % [rejected])
	var malformed := {"ok": false, "value": null, "issues": []}
	check(not validation.validate_snapshot(malformed,_faces(&"tile_a")).is_empty(), "empty failure is not accepted")
	malformed = {"ok": true, "value": {}, "issues": overflow.issues}
	check(not validation.validate_snapshot(malformed,_faces(&"tile_a")).is_empty(), "success with issues rejected")
	var upstream := overflow.duplicate(true)
	var propagated: Array[Dictionary] = validation.validate_snapshot(upstream,_faces(&"tile_a"))
	propagated[0].details.component = "changed"
	check(upstream == overflow, "propagated failure owns deep copy")
	print("OVERFLOW_REGRESSIONS: previous LEFT and WORLD failures now reject atomically with 1105")
	return true


func _check_overflow(result: Dictionary, operation: String, path: String) -> void:
	check(not result.ok and result.value == null and not result.issues.is_empty(), "atomic failure " + operation)
	var issue: Dictionary = result.issues[0]
	check(issue.code == 1105 and issue.severity == 0 and issue.path == path, "canonical overflow path/code " + path)
	check(issue.details.has_all(["operation","component","representation","operands","minimum","maximum"]), "complete overflow details")
	check(issue.details.operation == operation and issue.details.representation == "int32" and issue.details.minimum == -2147483648 and issue.details.maximum == 2147483647, "overflow representation " + operation)


func _test_face_nodes() -> bool:
	var faces: Array[Dictionary] = geometry.make_face_nodes(&"tile_a")
	check(faces.size() == 6, "Cube generates exactly six FaceNodes")
	for face in 6:
		check(faces[face] == _faces(&"tile_a")[face], "canonical default FaceNode %s" % face)
	faces[0].mechanism_ids.append(&"test")
	faces[0].walkable = true
	check(faces[1].mechanism_ids.is_empty(), "Face mechanism arrays independent")
	check(geometry.make_face_nodes(&"tile_a") == _faces(&"tile_a"), "new factory call owns fresh records")
	return true


func _success(value: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	return {"ok": true, "value": value, "issues": issues}


func _value(result: Dictionary) -> Dictionary:
	check(result.has_all(["ok","value","issues"]), "checked result has canonical fields")
	check(result.ok and result.issues.is_empty() and result.value != null, "expected successful checked geometry")
	return result.value if result.ok else {}


func _resolve_cube(cube: Dictionary, world: Dictionary, group: Dictionary) -> Dictionary:
	return _value(geometry.resolve_cube(cube,world,group))


func _resolve_anchor(cube: Dictionary, face: int) -> Dictionary:
	return _value(geometry.resolve_anchor(cube,face))


func _snapshot(level: Dictionary, state: Dictionary) -> Dictionary:
	return _value(geometry.snapshot(level,state))


func _validate(snapshot: Dictionary, faces: Array[Dictionary]) -> Array[Dictionary]:
	return validation.validate_snapshot(_success(snapshot),faces)


func _test_invalid_snapshot() -> bool:
	var snapshot := _pair_snapshot(Vector3i(4,0,0), 0)
	var faces := _faces(&"tile_a")
	faces.append_array(_faces(&"tile_b"))
	var bad := snapshot.duplicate(true)
	bad.anchors[0].position2 += Vector3i(1,0,0)
	check(_has_code(_validate(bad, faces), 1104), "incorrect normal-offset anchor rejected")
	bad = snapshot.duplicate(true)
	bad.anchors[0].frame.v *= -1
	check(_has_code(_validate(bad, faces), 1102), "mirrored frame rejected")
	bad = snapshot.duplicate(true)
	bad.anchors[0].frame.u = Vector3i.ZERO
	check(_has_code(_validate(bad, faces), 1102), "non-unit frame rejected")
	bad = snapshot.duplicate(true)
	bad.anchors[0].frame = {"u": Vector3i(0,1,0), "v": Vector3i(-1,0,0), "normal": Vector3i(0,0,1)}
	check(_has_code(_validate(bad, faces), 1102), "valid basis with incorrect local tangents rejected")
	bad = snapshot.duplicate(true)
	bad.anchors.append(bad.anchors[0].duplicate(true))
	check(_has_code(_validate(bad, faces), 1005), "duplicate derived face identity rejected")
	bad = snapshot.duplicate(true)
	bad.cubes[0].center2 = Vector3i(1,0,0)
	var before := bad.duplicate(true)
	var before_faces := faces.duplicate(true)
	var issues: Array[Dictionary] = _validate(bad, faces)
	check(_has_code(issues, 1100), "odd snapshot center rejected")
	check(bad == before and faces == before_faces, "validation preserves snapshot/face definitions")
	check(issues == _validate(bad, faces), "validation issues deterministic")
	for issue in issues:
		check(issue.has_all(["code", "severity", "path", "entity_ids", "message", "details"]), "ValidationIssue complete record")
		check(typeof(issue.code) == TYPE_INT and issue.severity == 0, "numeric frozen ValidationCode and ERROR severity")
	bad = snapshot.duplicate(true)
	bad.anchors = []
	var no_faces: Array[Dictionary] = []
	issues = _validate(bad, no_faces)
	var actual_keys: Array = []
	for issue in issues:
		actual_keys.append([issue.path, issue.code, issue.entity_ids])
	var expected_keys: Array = []
	for index in 2:
		for code in [1103,1104]:
			for symbol in ["BACK", "BOTTOM", "FRONT", "LEFT", "RIGHT", "TOP"]:
				expected_keys.append(["cubes[%s]" % index, code, [StringName(("tile_a/" if index == 0 else "tile_b/") + symbol)]])
	check(actual_keys == expected_keys, "issues sort by path, numeric code, then entity IDs")
	bad = snapshot.duplicate(true)
	bad.cubes[0].orientation = 24
	check(_has_code(_validate(bad, faces), 1101), "invalid orientation rejected before MATH precondition")
	bad = snapshot.duplicate(true)
	bad.cubes.append(bad.cubes[0].duplicate(true))
	check(_has_code(_validate(bad, faces), 1005), "duplicate cube identity rejected")
	bad = snapshot.duplicate(true)
	bad.anchors[0].layer = 1
	check(_has_code(_validate(bad, faces), 1104), "anchor cannot silently switch worlds")
	bad = snapshot.duplicate(true)
	bad.anchors.pop_back()
	check(_has_code(_validate(bad, faces), 1104), "missing sixth anchor rejected")
	bad = snapshot.duplicate(true)
	bad.cubes[0].center2 = Vector3i(-1,0,0)
	check(_has_code(_validate(bad, faces), 1100), "negative odd center rejected")
	check(_has_code(_validate({"cubes": []}, no_faces), 1002), "missing snapshot collection rejected without crash")
	check(_has_code(_validate({"cubes": [false], "anchors": []}, no_faces), 1000), "non-record cube rejected without crash")
	return true


func _has_code(issues: Array[Dictionary], code: int) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false


func _valid_level(level: Dictionary) -> bool:
	var issues: Array[Dictionary] = data.validate_level_shape(level)
	check(issues.is_empty(), "real DATA accepts LevelDefinition fixture: %s" % [issues])
	return issues.is_empty()


func _valid_state(level: Dictionary, state: Dictionary) -> bool:
	var issues: Array[Dictionary] = data.validate_state_shape(level, state)
	check(issues.is_empty(), "real DATA accepts PuzzleState fixture: %s" % [issues])
	return issues.is_empty()


func _transform(rotation: int, pivot2 := Vector3i.ZERO) -> Dictionary:
	return {"rotation": rotation, "pivot2": pivot2}


func _cube(id: StringName, layer: int, center2: Vector3i) -> Dictionary:
	return {"cube_id": id, "layer": layer, "center2": center2, "orientation": 0, "group_id": &"", "occludes_light": true, "tags": []}


func _resolved(id: StringName, layer: int, center2: Vector3i, orientation: int) -> Dictionary:
	return {"cube_id": id, "layer": layer, "center2": center2, "orientation": orientation, "occludes_light": true}


func _faces(id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for face in 6:
		result.append({"face_id": StringName(String(id) + "/" + FACE_SYMBOLS[face]), "cube_id": id, "face": face, "walkable": false, "shift_exit_blocked": false, "shift_entry_blocked": false, "mechanism_ids": []})
	return result


func _typed_faces(input: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(input)
	return result


func _pair_snapshot(offset: Vector3i, other_layer: int) -> Dictionary:
	var snapshot := {"cubes": [_resolved(&"tile_a", 0, Vector3i.ZERO, 0), _resolved(&"tile_b", other_layer, offset, 0)], "anchors": []}
	# Handwritten identity frames keep validator fixtures independent of resolve_anchor.
	for cube in snapshot.cubes:
		for face in 6:
			var axes: Array = FRAMES[face]
			snapshot.anchors.append({"face_id": StringName(String(cube.cube_id) + "/" + FACE_SYMBOLS[face]), "layer": cube.layer, "position2": cube.center2 + axes[2], "frame": {"u": axes[0], "v": axes[1], "normal": axes[2]}})
	return snapshot


func _find_anchor(snapshot: Dictionary, id: StringName) -> Dictionary:
	for anchor in snapshot.anchors:
		if anchor.face_id == id:
			return anchor
	check(false, "snapshot missing anchor " + String(id))
	return {"position2": Vector3i.ZERO, "frame": {"normal": Vector3i.ZERO}}


func _level() -> Dictionary:
	var faces := _faces(&"tile_a")
	faces[4].walkable = true
	return {
		"schema_version": 1, "contract_version": "foundation.contract.v1", "orientation_version": "cube24.v1", "rule_version": "foundation.rules.v1",
		"level_id": &"spatial_fixture", "content_hash": "0".repeat(64), "cell_size": 1,
		"worlds": [
			{"layer": 0, "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0], "allowed_rotation_deltas": [], "allowed_rotation_intents": []},
			{"layer": 1, "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0], "allowed_rotation_deltas": [], "allowed_rotation_intents": []},
		],
		"cubes": [_cube(&"tile_a", 0, Vector3i.ZERO)], "faces": faces, "groups": [],
		"celestial": {"slots": [{"slot_id": &"a", "position2": Vector3i(0,6,0)}], "slot_order": [&"a"], "wrap": false, "initial_slot_id": &"a", "edges": []},
		"mechanisms": [], "face_transitions": [], "shift_compatibilities": [0],
		"spawn": {"location": {"layer": 0, "cube_id": &"tile_a", "face": 4}, "orientation": 0},
		"goal": {"face_id": &"tile_a/TOP", "required_flags": []}, "flag_definitions": [], "build_info": {},
	}


func _test_mapping_queries() -> bool:
	var both: Array[int] = [0,1]
	var reversed_both: Array[int] = [1,0]
	var same: Array[int] = [0]
	var opposite: Array[int] = [1]
	# These cases catch permission filtering, invalid snapshot filtering,
	# first-candidate selection, partial failures and output/input aliasing.
	if mapping == null or not mapping.can_instantiate():
		check(false, "mapping query implementation required")
		return true
	var level := _level()
	level.cubes.append(_cube(&"tile_b", 1, Vector3i.ZERO))
	level.faces.append_array(_faces(&"tile_b"))
	level.faces[10].walkable = true
	if not _valid_level(level):
		return false
	var state: Dictionary = records.initial_state(level)
	if not _valid_state(level, state):
		return false
	var snapshot: Dictionary = geometry.snapshot(level, state)
	check(snapshot.ok, "mapping uses real DATA/MATH checked snapshot")
	if not snapshot.ok:
		return false
	var faces := _typed_faces(level.faces)
	var originals := [snapshot.duplicate(true), faces.duplicate(true)]
	var discovery: Dictionary = mapping.discover_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1)
	check(discovery == {"ok": true, "pairs": [{"source_face": &"tile_a/TOP", "target_face": &"tile_b/TOP"}], "issues": []}, "discovery real SAME pair")
	for malformed_ids in [[123],[&"bad id"]]:
		var bad_faces: Array[Dictionary] = faces.duplicate(true)
		bad_faces[0].mechanism_ids = malformed_ids
		var bad_discovery: Dictionary = mapping.discover_mapping_candidates(snapshot,bad_faces,&"tile_a/TOP",1)
		check(not bad_discovery.ok and bad_discovery.pairs.is_empty(), "discovery validates nested mechanism IDs even on filtered nonwalkable source-layer face")
		var bad_collection: Dictionary = mapping.collect_mapping_candidates(snapshot,bad_faces,&"tile_a/TOP",1,both)
		check(not bad_collection.ok and bad_collection.candidates.is_empty() and bad_collection.issues == bad_discovery.issues, "nested FaceNode errors propagate through collection")
		var bad_resolution: Dictionary = mapping.resolve_mapping(bad_collection)
		check(bad_resolution.status == 3 and bad_resolution.mapping == null and bad_resolution.issues == bad_discovery.issues, "nested FaceNode errors resolve ERROR")


	var collection: Dictionary = mapping.collect_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1, reversed_both)
	var expected := {"ok": true, "candidates": [{"source_face": &"tile_a/TOP", "target_face": &"tile_b/TOP", "compatibility": 0}], "issues": []}
	check(collection == expected, "collect real SAME candidate")
	var resolution: Dictionary = mapping.resolve_mapping(collection)
	check(resolution.status == 1 and resolution.mapping == expected.candidates[0] and resolution.issues.is_empty(), "one real candidate is UNIQUE")
	resolution.mapping.target_face = &"changed/TOP"
	check(resolution.candidates == expected.candidates and collection == expected, "mapping owns separate deep copy")
	resolution.candidates[0].target_face = &"changed/TOP"
	check(collection == expected, "resolution candidates do not alias collection")
	check([snapshot, faces] == originals, "mapping queries preserve full inputs")
	for face in faces:
		face.shift_exit_blocked = true
		face.shift_entry_blocked = true
	check(mapping.collect_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1, both) == expected, "blocked flags never filter geometry")
	snapshot.value.cubes.reverse()
	snapshot.value.anchors.reverse()
	faces.reverse()
	check(mapping.collect_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1, both) == expected, "all input permutations preserve mapping")
	faces = _typed_faces(level.faces)
	faces[10].walkable = false
	faces[11].walkable = true
	collection = mapping.collect_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1, both)
	check(collection.ok and collection.candidates.is_empty(), "nonoverlapping BOTTOM gives successful empty collection")
	resolution = mapping.resolve_mapping(collection)
	check(resolution.status == 0 and resolution.mapping == null and resolution.candidates.is_empty() and _has_code(resolution.issues, 1400), "zero candidates is NONE with 1400")
	check(resolution.issues[0].path == "mapping" and resolution.issues[0].severity == 0, "NONE canonical issue")
	level.cubes[1].center2 = Vector3i(0,2,0)
	snapshot = geometry.snapshot(level, state)
	collection = mapping.collect_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1, opposite)
	check(collection.ok and collection.candidates == [{"source_face": &"tile_a/TOP", "target_face": &"tile_b/BOTTOM", "compatibility": 1}], "real opposite anchors classify OPPOSITE")
	collection = mapping.collect_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1, same)
	check(collection.ok and collection.candidates.is_empty(), "disabled OPPOSITE is normally filtered")
	level.cubes.append(_cube(&"tile_c", 1, Vector3i.ZERO))
	level.faces = faces.duplicate(true)
	level.faces.append_array(_faces(&"tile_c"))
	level.faces[16].walkable = true
	snapshot = geometry.snapshot(level, state)
	faces = _typed_faces(level.faces)
	discovery = mapping.discover_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1)
	check(not discovery.ok and discovery.pairs.is_empty() and _has_code(discovery.issues, 1201), "sealed multi-target geometry fails before discovery")
	collection = mapping.collect_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1, same)
	check(not collection.ok and collection.candidates.is_empty() and _has_code(collection.issues, 1201), "compatibility filtering cannot hide invalid target geometry")
	resolution = mapping.resolve_mapping(collection)
	check(resolution.status == 3 and resolution.mapping == null and resolution.candidates.is_empty(), "invalid geometry resolves ERROR")
	level = _level()
	snapshot = geometry.snapshot(level, records.initial_state(level))
	faces = _typed_faces(level.faces)
	for request in [[&"missing/TOP", 1, 1006], [&"tile_a/BOTTOM", 1, 1103], [&"tile_a/TOP", 0, 1006], [&"tile_a/TOP", 2, 1003], [&"bad face", 1, 1004]]:
		discovery = mapping.discover_mapping_candidates(snapshot, faces, request[0], request[1])
		check(not discovery.ok and discovery.pairs.is_empty() and _has_code(discovery.issues, request[2]), "invalid mapping source/layer request rejected %s" % [request])
	for enabled in [[], [0,0], [2]]:
		var typed_enabled: Array[int] = []
		typed_enabled.assign(enabled)
		collection = mapping.collect_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1, typed_enabled)
		var code: int = 1006 if enabled.is_empty() else (1005 if enabled == [0,0] else 1003)
		check(not collection.ok and collection.candidates.is_empty() and _has_code(collection.issues, code), "invalid enabled compatibility collection rejected %s" % [enabled])
	level.cubes[0].center2 = Vector3i(-2147483648,0,0)
	snapshot = geometry.snapshot(level, records.initial_state(level))
	check(not snapshot.ok and _has_code(snapshot.issues, 1105), "mapping fixture upstream overflow fails")
	collection = mapping.collect_mapping_candidates(snapshot, faces, &"tile_a/TOP", 1, same)
	check(not collection.ok and collection.issues == snapshot.issues and collection.candidates.is_empty(), "mapping preserves original overflow issues")
	resolution = mapping.resolve_mapping(collection)
	check(resolution.status == 3 and resolution.issues == snapshot.issues, "overflow is ERROR never NONE")
	resolution.issues[0].details.operation = "changed"
	check(collection.issues == snapshot.issues, "propagated issues are deep copies")
	var world_overflow_level := _level()
	world_overflow_level.worlds[0].pivot2 = Vector3i(2147483646,0,0)
	world_overflow_level.worlds[0].initial_orientation = 4
	world_overflow_level.worlds[0].allowed_states = [4]
	var world_failure: Dictionary = geometry.snapshot(world_overflow_level,records.initial_state(world_overflow_level))
	check(not world_failure.ok and world_failure.value == null and _has_code(world_failure.issues,1105), "old WORLD regression fails before mapping")
	var world_collection: Dictionary = mapping.collect_mapping_candidates(world_failure,_typed_faces(world_overflow_level.faces),&"tile_a/TOP",1,same)
	check(not world_collection.ok and world_collection.candidates.is_empty() and world_collection.issues == world_failure.issues, "WORLD overflow cannot participate in overlap")
	var world_resolution: Dictionary = mapping.resolve_mapping(world_collection)
	check(world_resolution.status == 3 and world_resolution.mapping == null and world_resolution.issues == world_failure.issues, "old WORLD overflow reaches canonical ERROR unchanged")

	# Independent resolution fixture: intentionally not a spatial integration claim.
	var synthetic := {"ok": true, "candidates": [
		{"source_face": &"source/TOP", "target_face": &"target_b/BOTTOM", "compatibility": 1},
		{"source_face": &"source/TOP", "target_face": &"target_a/TOP", "compatibility": 0},
	], "issues": []}
	var before := synthetic.duplicate(true)
	resolution = mapping.resolve_mapping(synthetic)
	check(resolution.status == 2 and resolution.mapping == null and _has_code(resolution.issues, 1401), "independent multiple candidate fixture is AMBIGUOUS")
	check(resolution.candidates[0].target_face == &"target_a/TOP", "candidate canonical full face ID order")
	check(resolution.issues[0].entity_ids == [&"source/TOP", &"target_a/TOP", &"target_b/BOTTOM"], "ambiguity IDs canonical sorted unique")
	check(resolution.issues[0].details.candidates == [
		{"source_face": "source/TOP", "target_face": "target_a/TOP", "compatibility": "SAME_NORMAL"},
		{"source_face": "source/TOP", "target_face": "target_b/BOTTOM", "compatibility": "OPPOSITE_NORMAL"},
	], "ambiguity evidence uses canonical serialized fields")
	check(synthetic == before, "resolution does not sort input in place")
	synthetic.candidates.reverse()
	check(mapping.resolve_mapping(synthetic) == resolution, "synthetic permutation invariant")
	var duplicate := before.duplicate(true)
	duplicate.candidates.append(duplicate.candidates[0].duplicate(true))
	var mixed := before.duplicate(true)
	mixed.candidates[0].source_face = &"other/TOP"
	var invalid_enum := before.duplicate(true)
	invalid_enum.candidates[0].compatibility = 2
	var invalid_id := before.duplicate(true)
	invalid_id.candidates[0].target_face = &"invalid"
	var unknown_candidate := before.duplicate(true)
	unknown_candidate.candidates[0].extra = 0
	var missing_candidate := before.duplicate(true)
	missing_candidate.candidates[0].erase("target_face")
	for invalid in [duplicate, mixed, invalid_enum, invalid_id, unknown_candidate, missing_candidate,
		{}, {"ok": true, "candidates": [], "issues": [], "extra": 1},
		{"ok": false, "candidates": [], "issues": []},
		{"ok": true, "candidates": [false], "issues": []},
		{"ok": true, "candidates": [], "issues": [false]},
		{"ok": false, "candidates": before.candidates, "issues": collection.issues},
		{"ok": true, "candidates": [], "issues": collection.issues}]:
		resolution = mapping.resolve_mapping(invalid)
		check(resolution.status == 3 and resolution.mapping == null and resolution.candidates.is_empty() and not resolution.issues.is_empty(), "malformed collection fails atomically")
	check(_has_code(mapping.resolve_mapping(duplicate).issues, 1005), "duplicate pair is not deduplicated to unique")
	check(_has_code(mapping.resolve_mapping(mixed).issues, 1006), "mixed sources are invalid reference")
	# A genuine multi-height mapping: Inner +Y height rotates to Shared +Z;
	# its local BACK rotates to +Y and aligns with the unchanged Surface TOP.
	level = _level()
	level.cubes[0].center2 = Vector3i(0,0,2)
	level.cubes.append(_cube(&"tile_b",1,Vector3i(0,2,0)))
	level.cubes.append(_cube(&"tile_c",1,Vector3i(4,0,0)))
	level.cubes.append(_cube(&"tile_d",0,Vector3i(-4,0,0)))
	for cube_id in [&"tile_b",&"tile_c",&"tile_d"]:
		level.faces.append_array(_faces(cube_id))
	level.faces[7].walkable = true
	level.faces[16].walkable = true
	level.faces[22].walkable = true
	level.worlds[1].initial_orientation = 2
	level.worlds[1].allowed_states = [2]
	if not _valid_level(level):
		return false
	state = records.initial_state(level)
	if not _valid_state(level,state):
		return false
	snapshot = geometry.snapshot(level,state)
	check(snapshot.ok, "multi-height real snapshot succeeds")
	faces = _typed_faces(level.faces)
	collection = mapping.collect_mapping_candidates(snapshot,faces,&"tile_a/TOP",1,both)
	check(collection == {"ok":true,"candidates":[{"source_face":&"tile_a/TOP","target_face":&"tile_b/BACK","compatibility":0}],"issues":[]}, "multi-height transform yields unique exact candidate without unrelated cubes")
	check(_find_anchor(snapshot.value,&"tile_a/TOP").position2 == Vector3i(0,1,2) and _find_anchor(snapshot.value,&"tile_b/BACK").position2 == Vector3i(0,1,2), "independent transformed anchors match golden shared coordinate")
	var permuted_level := level.duplicate(true)
	permuted_level.cubes.reverse()
	permuted_level.worlds.reverse()
	permuted_level.faces.reverse()
	var permuted_snapshot: Dictionary = geometry.snapshot(permuted_level,state)
	check(mapping.collect_mapping_candidates(permuted_snapshot,_typed_faces(permuted_level.faces),&"tile_a/TOP",1,reversed_both) == collection, "mapping canonical under all definition insertion orders")
	# Whole FaceNodeId lexical order, rather than enum order FRONT=0/BACK=1.
	synthetic.candidates = [
		{"source_face":&"source/TOP","target_face":&"target/FRONT","compatibility":0},
		{"source_face":&"source/TOP","target_face":&"target/BACK","compatibility":1}]
	resolution = mapping.resolve_mapping(synthetic)
	check(resolution.status == 2 and resolution.candidates[0].target_face == &"target/BACK", "ambiguity preserves full face-ID ordering rather than enum ordering")
	# Valid failure wrappers with warning-only issues are malformed failures.
	var upstream_issue := {"code":1105,"severity":0,"path":"position2","entity_ids":[&"tile_a/LEFT"],"message":"range","details":{}}
	for mutation in ["severity","code","path","entity_ids","details"]:
		var bad_issue := upstream_issue.duplicate(true)
		match mutation:
			"severity": bad_issue.severity = 1
			"code": bad_issue.code = 9999
			"path": bad_issue.path = 0
			"entity_ids": bad_issue.entity_ids = ["tile_a/LEFT"]
			"details": bad_issue.details = {"float":0.5}
		resolution = mapping.resolve_mapping({"ok":false,"candidates":[],"issues":[bad_issue]})
		check(resolution.status == 3 and resolution.mapping == null and resolution.candidates.is_empty() and not resolution.issues.is_empty(), "malformed failure issue rejected " + mutation)
		check(resolution.issues != [bad_issue], "malformed issue cannot masquerade as upstream error " + mutation)

	return true


func _test_spatial_predicates() -> bool:
	var cube := _resolved(&"tile_a",0,Vector3i.ZERO,0)
	var source := _resolve_anchor(cube,4)
	var target := source.duplicate(true)
	target.face_id = &"tile_b/TOP"
	target.layer = 1
	var before := [source.duplicate(true),target.duplicate(true)]
	check(geometry.anchor_overlap(source,target) == {"ok":true,"overlaps":true,"issues":[]}, "exact cross-world integer overlap")
	check(geometry.classify_face_compatibility(source,target) == {"ok":true,"compatibility":0,"issues":[]}, "SAME classification")
	for axis in 3:
		for offset in [-1,1]:
			var near := target.duplicate(true)
			near.position2[axis] += offset
			check(geometry.anchor_overlap(source,near) == {"ok":true,"overlaps":false,"issues":[]}, "one half-grid unit is not overlap %s/%s" % [axis,offset])
			check(geometry.classify_face_compatibility(source,near).compatibility == 0, "classification independent of position")
	target = _resolve_anchor(_resolved(&"tile_b",1,Vector3i(0,2,0),0),5)
	check(geometry.anchor_overlap(source,target).overlaps and geometry.classify_face_compatibility(source,target).compatibility == 1, "exact OPPOSITE overlap")
	target = _resolve_anchor(_resolved(&"tile_b",1,Vector3i.ZERO,0),3)
	check(geometry.classify_face_compatibility(source,target) == {"ok":true,"compatibility":null,"issues":[]}, "perpendicular normals are normal incompatibility")
	target.position2 = source.position2
	check(geometry.anchor_overlap(source,target).overlaps, "overlap ignores normal compatibility")
	target.layer = 0
	check(geometry.anchor_overlap(source,target).overlaps, "base overlap does not filter same layer")
	target = before[1].duplicate(true)
	check(source == before[0], "query preserves source record")
	for malformed in [{},_success(source),{"face_id":&"tile_b/TOP","layer":1,"position2":Vector3.ZERO,"frame":source.frame}]:
		var overlap: Dictionary = geometry.anchor_overlap(source,malformed)
		var classification: Dictionary = geometry.classify_face_compatibility(source,malformed)
		check(not overlap.ok and overlap.overlaps == null and not overlap.issues.is_empty(), "malformed anchor cannot be compared")
		check(not classification.ok and classification.compatibility == null and not classification.issues.is_empty(), "malformed anchor cannot be classified")
	for axes in [
		{"u":Vector3i.ZERO,"v":Vector3i(0,0,-1),"normal":Vector3i.UP},
		{"u":Vector3i.RIGHT,"v":Vector3i(0,0,1),"normal":Vector3i.UP},
		{"u":Vector3i.RIGHT,"v":Vector3i(0,0,-1),"normal":Vector3i(1,1,0)},
	]:
		target.frame = axes
		check(_has_code(geometry.anchor_overlap(source,target).issues,1102), "overlap refuses malformed frame")
		check(_has_code(geometry.classify_face_compatibility(source,target).issues,1102), "classification refuses malformed frame")
	var layer_level := _level()
	layer_level.cubes.append(_cube(&"tile_b",1,Vector3i(0,2,0)))
	layer_level.faces.append_array(_faces(&"tile_b"))
	layer_level.faces[8].walkable = true
	layer_level.worlds[1].initial_orientation = 2
	layer_level.worlds[1].allowed_states = [2]
	var state: Dictionary = records.initial_state(layer_level)
	if not _valid_level(layer_level) or not _valid_state(layer_level,state):
		return false
	var rotated := _snapshot(layer_level,state)
	check(_find_anchor(rotated,&"tile_a/TOP").position2 == Vector3i(0,1,0), "Inner rotation leaves Surface anchor unchanged")
	check(_find_anchor(rotated,&"tile_b/TOP").position2 == Vector3i(0,0,3), "Inner independently rotates its height")
	return true
