extends SceneTree

var failures: Array[String] = []
var checks := 0
var reader: Script

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func has_code(issues: Array, code: int) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false

func _initialize() -> void:
	if not ResourceLoader.exists("res://foundation/level/authoring_reader.gd"):
		check(false, "authoring reader implementation exists")
		quit(1)
		return
	reader = load("res://foundation/level/authoring_reader.gd")
	if reader == null or not reader.can_instantiate():
		check(false, "authoring reader compiles")
		quit(1)
		return
	_test_reader()
	if "--reader-only" not in OS.get_cmdline_user_args():
		if has_method("_test_baker"):
			call("_test_baker")
		else:
			check(false, "real Baker integration installed")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact="):
			_test_artifact(argument.substr(11))
	print("LEVEL_BAKER_TESTS checks=%d failures=%s" % [checks, failures])
	if failures.is_empty():
		if "--reader-only" in OS.get_cmdline_user_args():
			print("FOUNDATION_AUTHORING_READER_PASS")
		elif "--baker-unit-only" in OS.get_cmdline_user_args():
			print("FOUNDATION_LEVEL_BAKER_UNIT_PASS")
		else:
			print("FOUNDATION_LEVEL_BAKER_TEST_PASS")
	quit(0 if failures.is_empty() else 1)

func _scene() -> Node3D:
	var packed: PackedScene = load("res://tools/foundation/level/minimal_authoring.tscn")
	if packed == null:
		check(false, "minimal authoring scene loads")
		return null
	return packed.instantiate() as Node3D

func _test_reader() -> void:
	var root := _scene()
	if root == null:
		return
	var first: Dictionary = reader.read_scene(root)
	check(first.ok, "real scene reads: " + str(first.issues))
	if not first.ok:
		root.free()
		return
	check(first.authoring.size() == 18 and not first.authoring.has("content_hash"), "authoring has eighteen fields without authored hash")
	check(first.authoring.cubes.size() == 4 and first.authoring.faces.size() == 24, "two independent worlds with two cubes and six faces each")
	var walkable: Array[StringName] = []
	for face in first.authoring.faces:
		if face.walkable:
			walkable.append(face.face_id)
	check(walkable == [&"exit/TOP", &"floor/TOP", &"inner_floor/TOP"], "explicit walkable face configuration survives with stable local face IDs")
	check(first.authoring.cubes[0].layer == 0 and first.authoring.cubes[1].layer == 0 and first.authoring.cubes[2].layer == 1 and first.authoring.cubes[3].layer == 1, "Surface and Inner layer ownership remains independent")
	check(first.authoring.cubes[0].cube_id == &"exit" and first.authoring.cubes[0].center2 == Vector3i(2,0,0), "canonical ID sorting and half-grid center")
	check(first.authoring.celestial.slots[0].position2 == Vector3i(0,10,0) and first.authoring.celestial.slots[1].slot_id == &"b", "two slots use Shared Space integer points")
	check(first.authoring.spawn.location.cube_id == &"floor" and first.authoring.goal.face_id == &"exit/TOP", "spawn and exit survive reader")
	check(first.authoring.groups[0].cube_ids == [&"group_cube"] and first.authoring.mechanisms[0].mechanism_id == &"toggle_sky", "minimal group and mechanism survive reader")
	check(reader.read_scene(root) == first, "repeated reads identical")
	var reloaded := _scene()
	check(reader.read_scene(reloaded) == first, "reloaded scene reads identical")
	reloaded.free()
	root.transform = Transform3D(Basis(Vector3.UP, 0.31), Vector3(13,7,-9))
	check(reader.read_scene(root) == first, "root rigid placement normalized away")
	root.get_node("Cubes/Floor").name = "RenamedForEditor"
	root.get_node("Cubes").move_child(root.get_node("Cubes").get_child(0), 3)
	check(reader.read_scene(root) == first, "display names and sibling ordering do not define IDs")
	var visual := Camera3D.new()
	visual.name = "PreviewCamera"
	root.add_child(visual)
	check(reader.read_scene(root) == first, "visual Camera does not enter definition")
	var leaked: Dictionary = first.authoring
	leaked.cubes[0].tags.append(&"changed")
	check(reader.read_scene(root).authoring.cubes[0].tags == [], "read result owns nested metadata copies")
	root.free()
	for problem in ["off_lattice", "odd_center", "scale", "mirror", "shear", "overflow", "missing_face", "duplicate_id", "container_transform", "root_scale", "slot_basis", "visual_payload", "invalid_id", "newline_id", "top_level"]:
		root = _scene()
		var cube: Node3D = root.get_node("Cubes/Floor")
		var expected := 1000
		match problem:
			"off_lattice":
				cube.position.x = 0.00001
				expected = 1100
			"odd_center":
				cube.position.x = 0.5
				expected = 1100
			"scale":
				cube.scale = Vector3(2,1,1)
				expected = 1101
			"mirror":
				cube.scale = Vector3(-1,1,1)
				expected = 1101
			"shear":
				cube.basis = Basis(Vector3(1,0,0), Vector3(0.2,1,0), Vector3(0,0,1))
				expected = 1101
			"overflow":
				cube.position.x = 2147483648.0
				expected = 1105
			"missing_face":
				var config: Array = cube.get_meta("foundation_faces").duplicate(true)
				config.pop_back()
				cube.set_meta("foundation_faces", config)
				expected = 1103
			"duplicate_id":
				var meta: Dictionary = cube.get_meta("foundation_cube").duplicate(true)
				meta.cube_id = &"exit"
				cube.set_meta("foundation_cube", meta)
				expected = 1005
			"container_transform":
				root.get_node("Cubes").position.x = 1
				expected = 1101
			"root_scale":
				root.scale = Vector3(2,2,2)
				expected = 1101
			"slot_basis":
				root.get_node("Slots/A").scale = Vector3(2,1,1)
				expected = 1101
			"visual_payload":
				var meta: Dictionary = root.get_meta("foundation_authoring").duplicate(true)
				meta.build_info["camera"] = root
				root.set_meta("foundation_authoring", meta)
			"invalid_id":
				var meta: Dictionary = cube.get_meta("foundation_cube").duplicate(true)
				meta.cube_id = &"Bad ID"
				cube.set_meta("foundation_cube", meta)
				expected = 1004
			"newline_id":
				var meta: Dictionary = cube.get_meta("foundation_cube").duplicate(true)
				meta.cube_id = StringName("floor\n")
				cube.set_meta("foundation_cube", meta)
				expected = 1004
			"top_level":
				cube.top_level = true
				expected = 1101
		var rejected: Dictionary = reader.read_scene(root)
		check(rejected.get("ok") == false and rejected.get("authoring") == null and has_code(rejected.get("issues", []), expected), "reader rejects %s atomically: %s" % [problem, rejected.get("issues", [])])
		root.free()

	root = _scene()
	var template: Dictionary = root.get_meta("foundation_authoring").duplicate(true)
	template.worlds[0].initial_orientation = 22
	template.worlds[0].allowed_states = [0, 22]
	root.set_meta("foundation_authoring", template)
	root.get_node("Cubes/Exit").basis = Basis(Vector3.UP, Vector3.LEFT, Vector3.BACK)
	var binding: Dictionary = reader.read_scene(root)
	check(binding.ok and binding.authoring.cubes[0].center2 == Vector3i(2,0,0) and binding.authoring.cubes[0].orientation == 9, "reader retains bind-space center and formal local orientation without baking initial World twice")
	root.free()
	root = _scene()
	root.get_node("Cubes/Floor").position.x = 0.0000001
	root.get_node("Slots/A").position.x = -0.5
	binding = reader.read_scene(root)
	check(binding.ok and binding.authoring.celestial.slots[0].position2.x == -1, "within-tolerance Cube and negative half-grid Slot quantize canonically")
	root.free()


func _test_baker() -> void:
	if not ResourceLoader.exists("res://foundation/level/level_baker.gd"):
		check(false, "Baker implementation exists")
		return
	if not ResourceLoader.exists("res://foundation/validation/static_validator.gd"):
		check(false, "real 2B dependency required for full Baker acceptance")
		return
	var baker: Script = load("res://foundation/level/level_baker.gd")
	var codec: Script = load("res://foundation/level/level_codec.gd")
	var double: Script = load("res://tests/foundation/level/validator_double.gd")
	if baker == null or not baker.can_instantiate():
		check(false, "Baker compiles")
		return
	var root := _scene()
	var read: Dictionary = reader.read_scene(root)
	root.free()
	if not read.ok:
		check(false, "Baker reader precondition")
		return
	var authoring: Dictionary = read.authoring
	var original := authoring.duplicate(true)
	var options := {"max_configurations": 4096, "max_checks": 100000}
	for case in [[double.reject_invalid, 1006, 1], [double.reject_incomplete, 1600, 2], [double.malformed_result, 1000, -1]]:
		var result: Dictionary = baker._bake_with_validator(authoring, options, case[0])
		check(not result.ok and result.level == null and not result.issues.is_empty(), "test double cannot publish failed/incomplete/malformed validation")
		check(result.issues[0].code == case[1], "Baker preserves failure code across Validator boundary")
		if case[2] >= 0:
			check(result.validation.status == case[2] and result.issues[0].details.get("source") == "failure-only-test-double", "Baker preserves validation status and nested issue details")
		else:
			check(result.validation == null, "malformed result cannot masquerade as StaticValidationResult")
	check(authoring == original, "double failure preserves authoring input")
	var bad := authoring.duplicate(true)
	bad["content_hash"] = "0".repeat(64)
	var result: Dictionary = baker.bake(bad, options)
	check(not result.ok and result.level == null and result.validation == null, "author supplied hash rejected before Validator")
	for bad_options in [{}, {"max_configurations": 0, "max_checks": 100}, {"max_configurations": 1, "max_checks": 1, "skip_validation": true}]:
		result = baker.bake(authoring, bad_options)
		check(not result.ok and result.level == null, "invalid budget or skip_validation never bypasses gate")
	if "--baker-unit-only" in OS.get_cmdline_user_args():
		return
	var data: Script = load("res://foundation/contracts/contract_validation.gd")
	var validator: Script = load("res://foundation/validation/static_validator.gd")
	var records: Script = load("res://foundation/contracts/contract_records.gd")
	var state_key: Script = load("res://foundation/contracts/state_key.gd")
	var baked: Dictionary = baker.bake(authoring, options)
	check(baked.ok and baked.validation != null and baked.validation.get("status") == 0, "real Validator accepts minimal authoring: " + str(baked.issues))
	if not baked.ok:
		return
	check(data.validate_level_shape(baked.level).is_empty(), "Baker produces canonical DATA record")
	check(codec.compute_content_hash(baked.level).content_hash == baked.level.content_hash, "Baker output has true canonical identity")
	var encoded: Dictionary = codec.encode(baked.level)
	var decoded: Dictionary = codec.decode(encoded.text)
	check(decoded.ok and validator.validate(decoded.level, options).status == 0, "real encoded artifact decodes and validates")
	check(state_key.build(decoded.level, records.initial_state(decoded.level)).ok, "real StateKey consumes baked initial state")
	check(baker.bake(authoring, options) == baked, "same authoring bakes repeatedly with identical validation/output")
	root = _scene()
	var reread: Dictionary = reader.read_scene(root)
	root.free()
	check(baker.bake(reread.authoring, options) == baked, "reloaded scene produces identical Bake")
	root = _scene()
	root.get_node("Cubes").move_child(root.get_node("Cubes/Floor"), 3)
	root.get_node("Cubes/Floor").name = "VisualNameOnly"
	reread = reader.read_scene(root)
	root.free()
	check(codec.encode(baker.bake(reread.authoring, options).level).text == encoded.text, "node reorder/rename keeps canonical bytes and stable IDs")
	for problem in ["bad_spawn", "bad_goal", "bad_reference", "illegal_source", "mechanism_profile", "budget"]:
		bad = authoring.duplicate(true)
		var budget := options.duplicate(true)
		match problem:
			"bad_spawn": bad.spawn.location.cube_id = &"missing"
			"bad_goal": bad.goal.face_id = &"floor/LEFT"
			"bad_reference": bad.celestial.edges[0].to_slot_id = &"missing"
			"illegal_source": bad.celestial.slots[0].position2 = Vector3i.ZERO
			"mechanism_profile": bad.mechanisms[0].allowed_states.append(&"second")
			"budget": budget.max_configurations = 1
		result = baker.bake(bad, budget)
		check(not result.ok and result.level == null and not result.issues.is_empty(), "real boundary rejects " + problem)
		if problem in ["bad_goal", "illegal_source", "mechanism_profile", "budget"]:
			check(result.validation != null and result.validation.status in [1, 2], "real Validator owns " + problem)
	check(authoring == original and options == {"max_configurations": 4096, "max_checks": 100000}, "Baker and Validator preserve all caller input")
	print("BAKED_CONTENT_HASH=" + baked.level.content_hash)
	print("REAL_VALIDATOR_RESULT=" + str(baked.validation))


func _test_artifact(path: String) -> void:
	if not FileAccess.file_exists(path):
		check(false, "CLI artifact exists")
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	check(not bytes.is_empty() and bytes[0] != 239 and bytes[-1] != 10, "CLI artifact uses UTF-8 without BOM or trailing newline")
	var text := bytes.get_string_from_utf8()
	var codec: Script = load("res://foundation/level/level_codec.gd")
	var decoded: Dictionary = codec.decode(text)
	check(decoded.ok, "actual CLI artifact decodes with authentic content hash")
	if not decoded.ok:
		return
	check(codec.encode(decoded.level).text == text, "actual CLI artifact is canonical byte-for-byte")
	var validator: Script = load("res://foundation/validation/static_validator.gd")
	var validation: Dictionary = validator.validate(decoded.level, {"max_configurations": 4096, "max_checks": 100000})
	check(validation.status == 0 and validation.issues.is_empty(), "actual CLI artifact passes real Static Validator")
	var records: Script = load("res://foundation/contracts/contract_records.gd")
	var state_key: Script = load("res://foundation/contracts/state_key.gd")
	check(state_key.build(decoded.level, records.initial_state(decoded.level)).ok, "actual CLI artifact supports formal StateKey")
