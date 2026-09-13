extends SceneTree

const Types = preload("res://foundation/contracts/foundation_types.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")

var failures: Array[String] = []
var checks := 0
var mapper: Script


func _initialize() -> void:
	var path := "res://foundation/runtime/input_mapper.gd"
	check(FileAccess.file_exists(path), "input mapper implementation exists")
	if not failures.is_empty():
		_finish()
		return
	mapper = load(path)
	check(mapper != null and mapper.can_instantiate(), "input mapper loads")
	if not failures.is_empty():
		_finish()
		return
	_test_all_faces()
	_test_projection_and_ties()
	_test_invalid_move()
	_test_rotation_goldens()
	_test_rotation_rejections()
	_finish()


func _test_all_faces() -> void:
	# Face-facing cameras make right/up/left/down match the frame on every face.
	# This catches world-axis assumptions and a reversed screen Y convention.
	var directions := [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]
	var oblique := Basis(Vector3(1, 0, -1).normalized(), Vector3(-1, 2, -1).normalized(), Vector3(1, 1, 1).normalized())
	var oblique_goldens := [[0, 1, 2, 3], [2, 1, 0, 3], [2, 1, 0, 3], [0, 1, 2, 3], [0, 2, 2, 0], [0, 2, 2, 0]]
	for face in range(6):
		var frame := Geometry.face_frame(face)
		var before := frame.duplicate(true)
		var camera := Basis(Vector3(frame.u), Vector3(frame.v), Vector3(frame.normal))
		for axis in range(4):
			var result: Dictionary = mapper.map_move(frame, camera, directions[axis])
			_expect_move(result, axis, "face %s direction %s" % [face, axis])
			var opposite: Dictionary = mapper.map_move(frame, camera, -directions[axis])
			_expect_move(opposite, (axis + 2) % 4, "face %s opposite %s" % [face, axis])
			_expect_move(mapper.map_move(frame, oblique, directions[axis]), oblique_goldens[face][axis], "oblique face %s direction %s" % [face, axis])
		check(frame == before, "move does not mutate frame %s" % face)


func _test_projection_and_ties() -> void:
	var frame := Geometry.face_frame(Types.FaceDirection.FRONT)
	# Halfplane representative for both diagonal pairs starts with positive x.
	for sample in [
		[Vector2(1, -1), 0], [Vector2(-1, 1), 2],
		[Vector2(1, 1), 0], [Vector2(-1, -1), 2],
		[Vector2(1, -2), 1], [Vector2(-1, 2), 3],
		[Vector2(1, 2), 3], [Vector2(-1, -2), 1],
	]:
		_expect_move(mapper.map_move(frame, Basis.IDENTITY, sample[0]), sample[1], "diagonal %s" % sample[0])
	var diagonal_camera := Basis(Vector3(1, 1, 0).normalized(), Vector3(-1, 1, 0).normalized(), Vector3.BACK)
	_expect_move(mapper.map_move(frame, diagonal_camera, Vector2.RIGHT), 0, "continuous camera +u/+v tie")
	_expect_move(mapper.map_move(frame, diagonal_camera, Vector2.LEFT), 2, "continuous camera reverse tie")
	_expect_move(mapper.map_move(frame, diagonal_camera, Vector2.DOWN), 0, "x-zero representative +u/-v tie")
	_expect_move(mapper.map_move(frame, diagonal_camera, Vector2.UP), 2, "x-zero reverse of +u/-v tie")
	# Tangent-plane projection is required, not angle to each projected screen axis.
	var tilted := Basis(Vector3.RIGHT, Vector3(0, 0.6, 0.8), Vector3(0, -0.8, 0.6))
	_expect_move(mapper.map_move(frame, tilted, Vector2(0.8, -1)), 0, "foreshortened up projected to plane")
	_expect_move(mapper.map_move(frame, tilted, Vector2(-0.8, 1)), 2, "foreshortened reverse")
	_expect_move(mapper.map_move(frame, Basis.IDENTITY, Vector2(100, -200)), 1, "magnitude independent direction")


func _test_invalid_move() -> void:
	var frame := Geometry.face_frame(Types.FaceDirection.FRONT)
	var edge_camera := Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
	_expect_failure(mapper.map_move(frame, edge_camera, Vector2.RIGHT), "edge-on projection")
	var near_edge := Basis(Vector3(0.00000001, 0, 1).normalized(), Vector3.UP, Vector3(-1, 0, 0.00000001).normalized())
	_expect_failure(mapper.map_move(frame, near_edge, Vector2.RIGHT), "near-zero projection")
	for direction in [Vector2.ZERO, Vector2(0.00000001, 0), Vector2(INF, 0), Vector2(NAN, 1)]:
		_expect_failure(mapper.map_move(frame, Basis.IDENTITY, direction), "invalid direction %s" % direction)
	for camera in [Basis(Vector3.ZERO, Vector3.UP, Vector3.BACK), Basis(Vector3.RIGHT * 2, Vector3.UP, Vector3.BACK), Basis(Vector3.LEFT, Vector3.UP, Vector3.BACK), Basis(Vector3(INF, 0, 0), Vector3.UP, Vector3.BACK)]:
		_expect_failure(mapper.map_move(frame, camera, Vector2.RIGHT), "invalid move camera")
	for bad_frame in [{}, {"u": Vector3.RIGHT, "v": Vector3i.UP, "normal": Vector3i.BACK}, {"u": Vector3i.RIGHT, "v": Vector3i.RIGHT, "normal": Vector3i.BACK}]:
		_expect_failure(mapper.map_move(bad_frame, Basis.IDENTITY, Vector2.RIGHT), "invalid surface frame")


func _test_rotation_goldens() -> void:
	# Literal quarter-turn IDs, ordered LEFT/RIGHT/UP/DOWN/CW/CCW.
	# Signed and permuted camera axes catch incorrect local/world axis and signs.
	var samples := [
		[Basis.IDENTITY, [22, 18, 3, 2, 12, 9]],
		[Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), [22, 18, 2, 3, 9, 12]],
		[Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT), [9, 12, 18, 22, 3, 2]],
		[Basis(Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT), [12, 9, 22, 18, 3, 2]],
	]
	for layer in [Types.WorldLayer.SURFACE, Types.WorldLayer.INNER]:
		var world := _world(layer)
		var before := world.duplicate(true)
		for sample in samples:
			for intent in range(6):
				var result: Dictionary = mapper.map_rotation(intent, sample[0], world)
				check(result.ok and result.issues.is_empty(), "rotation golden accepted %s/%s" % [layer, intent])
				if result.ok:
					check(result.action == {"kind": 2 if layer == 0 else 3, "rotation_delta": sample[1][intent]}, "rotation semantic golden %s/%s" % [layer, intent])
		check(world == before, "rotation does not mutate world")


func _test_rotation_rejections() -> void:
	var world := _world(0)
	_expect_failure(mapper.map_rotation(99, Basis.IDENTITY, world), "unknown intent")
	world.allowed_rotation_intents = [Types.RotationIntent.TURN_RIGHT]
	_expect_failure(mapper.map_rotation(Types.RotationIntent.TURN_LEFT, Basis.IDENTITY, world), "intent authorization required")
	world = _world(0)
	world.allowed_rotation_deltas = [18]
	_expect_failure(mapper.map_rotation(Types.RotationIntent.TURN_LEFT, Basis.IDENTITY, world), "delta authorization required")
	world = _world(0)
	for camera in [
		Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD),
		Basis(Vector3.RIGHT * 2, Vector3.UP, Vector3.BACK),
		Basis(Vector3.RIGHT, Vector3.RIGHT, Vector3.BACK),
		Basis(Vector3(1, 1, 0).normalized(), Vector3(-1, 1, 0).normalized(), Vector3.BACK),
		Basis(Vector3.RIGHT, Vector3(0, 1, 0.0001), Vector3.BACK),
		Basis(Vector3(NAN, 0, 0), Vector3.UP, Vector3.BACK),
	]:
		_expect_failure(mapper.map_rotation(0, camera, world), "non-discrete or non-right-handed camera")
	for malformed in [{}, {"layer": 99, "allowed_rotation_intents": [0], "allowed_rotation_deltas": [22]}, {"layer": 0, "allowed_rotation_intents": "all", "allowed_rotation_deltas": [22]}]:
		_expect_failure(mapper.map_rotation(0, Basis.IDENTITY, malformed), "invalid world input")


func _world(layer: int) -> Dictionary:
	return {"layer": layer, "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0, 2, 3, 9, 12, 18, 22], "allowed_rotation_intents": [0, 1, 2, 3, 4, 5], "allowed_rotation_deltas": [2, 3, 9, 12, 18, 22]}


func _expect_move(result: Dictionary, axis: int, label: String) -> void:
	check(result.ok and result.issues.is_empty(), label + " accepted")
	if result.ok:
		check(result.action == {"kind": Types.PuzzleActionKind.MOVE, "face_axis": axis}, label + " semantic axis")


func _expect_failure(result: Dictionary, label: String) -> void:
	check(not result.ok and result.action == null and not result.issues.is_empty(), label + " rejected atomically")
	if not result.issues.is_empty():
		check(result.issues[0].code == Types.ValidationCode.INVALID_ACTION and result.issues[0].severity == Types.ValidationSeverity.ERROR, label + " adapter diagnostic")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _finish() -> void:
	for failure in failures:
		printerr("FAIL: " + failure)
	print("FOUNDATION_INPUT_MAPPER_%s checks=%s failures=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
