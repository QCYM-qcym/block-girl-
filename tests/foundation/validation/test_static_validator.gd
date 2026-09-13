extends SceneTree
## Integration tests use the real FOUNDATION owners; no production substitutes.

const Data = preload("res://foundation/contracts/contract_validation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Mapping = preload("res://foundation/spatial/mapping_query.gd")
var Validator: Script
var Fixture: Script
var checks := 0
var failures: Array[String] = []
var covered: Dictionary = {}
const BUDGET = {"max_configurations": 4096, "max_checks": 100000}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	if not ResourceLoader.exists("res://foundation/validation/static_validator.gd"):
		check(false, "StaticValidator implementation exists")
		finish()
		return
	Validator = load("res://foundation/validation/static_validator.gd")
	Fixture = load("res://tests/foundation/validation/validation_fixture.gd")
	call_deferred("run")

func finish() -> void:
	var codes := covered.keys()
	codes.sort()
	print("STATIC_VALIDATOR checks=", checks, " failures=", failures, " codes=", codes)
	quit(0 if failures.is_empty() else 1)

func expect_code(level: Dictionary, code: int, label: String) -> Dictionary:
	var result: Dictionary = Validator.validate(level, BUDGET)
	check(result.status == 1, label + " is INVALID")
	var found := false
	for issue in result.issues:
		check(issue.code < 2000, "ValidationIssue never carries ActionRejectionCode")
		found = found or issue.code == code
	check(found, label + " code " + str(code))
	if not found:
		print("DIAGNOSTIC ", label, " ", result)
	if found:
		covered[code] = true
	return result

func run() -> void:
	var level: Dictionary = Fixture.make_level()
	check(Data.validate_level_shape(level).is_empty(), "minimal fixture meets frozen DATA")
	var saved := level.duplicate(true)
	var valid: Dictionary = Validator.validate(level, BUDGET)
	check(valid.status == 0 and valid.issues.is_empty(), "minimal complete level VALID")
	check(valid.configurations_checked == 1 and valid.checks_performed > 0, "complete finite domain counted")
	check(level == saved, "validator input immutable")
	var bad := level.duplicate(true)
	bad.cubes.append(bad.cubes[0].duplicate(true))
	expect_code(bad, 1005, "duplicate cube")
	bad = level.duplicate(true)
	bad.spawn.location.cube_id = &"missing"
	expect_code(bad, 1006, "invalid spawn reference")
	bad = level.duplicate(true)
	bad.goal.face_id = &"missing/TOP"
	expect_code(bad, 1006, "invalid goal reference")
	bad = level.duplicate(true)
	bad.spawn.orientation = 24
	expect_code(bad, 1101, "invalid orientation")
	bad = level.duplicate(true)
	bad.faces[0].face = 8
	expect_code(bad, 1103, "invalid face")
	bad = level.duplicate(true)
	bad.celestial.initial_slot_id = &"missing"
	expect_code(bad, 1300, "invalid celestial reference")
	bad = level.duplicate(true)
	bad.faces[0].mechanism_ids = [&"missing"]
	expect_code(bad, 1006, "invalid mechanism reference")
	bad = level.duplicate(true)
	bad.erase("spawn")
	expect_code(bad, 1002, "missing spawn")
	bad = level.duplicate(true)
	bad.cell_size = 1.0
	expect_code(bad, 1000, "invalid field type")
	bad = level.duplicate(true)
	bad["exit"] = {}
	expect_code(bad, 1001, "unknown exit alias")
	bad = level.duplicate(true)
	bad.shift_compatibilities = [8]
	expect_code(bad, 1003, "invalid compatibility enum")
	bad = level.duplicate(true)
	bad.level_id = &"Bad ID"
	expect_code(bad, 1004, "invalid ID")
	bad = level.duplicate(true)
	bad.schema_version = 2
	expect_code(bad, 1007, "unsupported version")
	bad = level.duplicate(true)
	bad.cubes[0].center2 = Vector3i(1, 0, 0)
	expect_code(bad, 1100, "off lattice")
	run_geometry(level)
	run_profiles(level)
	run_budgets(level)
	run_declared_motions(level)
	run_complete_domain(level)
	finish()

func run_geometry(level: Dictionary) -> void:
	var bad := level.duplicate(true)
	bad.cubes.append(Fixture.cube(&"other", 0, Vector3i.ZERO))
	Fixture.rebuild_faces(bad)
	expect_code(bad, 1200, "same world overlap")
	bad.cubes[1].layer = 1
	check(Validator.validate(bad, BUDGET).status == 0, "cross world overlap allowed")
	bad.cubes[1].layer = 0
	bad.cubes[1].center2 = Vector3i(0, 2, 0)
	expect_code(bad, 1201, "sealed walkable face")
	bad = level.duplicate(true)
	Fixture.rebuild_faces(bad, [])
	expect_code(bad, 1204, "nonwalkable spawn and goal")
	bad = level.duplicate(true)
	bad.cubes[0].center2 = Vector3i(2147483646, 0, 0)
	Fixture.rebuild_faces(bad, [&"floor/RIGHT"])
	bad.spawn.location.face = 3
	bad.goal.face_id = &"floor/RIGHT"
	expect_code(bad, 1105, "player center overflow")
	bad = level.duplicate(true)
	bad.celestial.slots.append({"slot_id": &"b", "position2": Vector3i.ZERO})
	bad.celestial.slot_order.append(&"b")
	var result := expect_code(bad, 1302, "noninitial invalid light source")
	check(result.configurations_checked == 2, "every slot examined")
	bad = level.duplicate(true)
	bad.cubes[0].center2 = Vector3i(2, 0, 0)
	bad.cubes[0].group_id = &"turn"
	bad.cubes.append(Fixture.cube(&"other", 0, Vector3i(0, 0, -2)))
	bad.groups = [Fixture.group(&"turn", 0, [&"floor"])]
	bad.groups[0].allowed_states = [0, 22]
	Fixture.rebuild_faces(bad)
	result = expect_code(bad, 1200, "noninitial group overlap")
	check(result.configurations_checked == 2, "every group state examined")
	bad.cubes[1].center2 = Vector3i(0, 2, -2)
	expect_code(bad, 1201, "noninitial sealed face")
	bad = level.duplicate(true)
	bad.worlds[0].allowed_states = [0, 9]
	bad.worlds[0].pivot2 = Vector3i(2147483646, 2147483646, 0)
	expect_code(bad, 1105, "noninitial world overflow")
	# Independent complete collection exercises the official resolution boundary.
	# It is synthetic test data: valid grid cubes cannot expose two walkable
	# coincident target faces without an earlier overlap/sealed-face failure.
	var collection := {"ok": true, "issues": [], "candidates": [
		{"source_face": &"floor/TOP", "target_face": &"a/TOP", "compatibility": 0},
		{"source_face": &"floor/TOP", "target_face": &"b/BOTTOM", "compatibility": 1}]}
	var ambiguous := Mapping.resolve_mapping(collection)
	check(ambiguous.status == 2 and ambiguous.mapping == null, "real Mapping rejects all-candidate ambiguity")
	check(ambiguous.issues[0].code == 1401 and ambiguous.issues[0].entity_ids.size() == 3, "canonical ambiguity preserves all IDs")
	covered[1401] = true

func add_mechanism(level: Dictionary, id: StringName, trigger: StringName = &"USE") -> void:
	level.mechanisms.append({"mechanism_id": id, "face_id": &"floor/TOP", "trigger": trigger,
		"action": {"kind": 7, "celestial_op": 0, "target_slot_id": &"a", "alternate_slot_id": &"", "mechanism_id": id},
		"priority": 0, "initial_state": &"on", "allowed_states": [&"on"]})
	for face in level.faces:
		if face.face_id == &"floor/TOP":
			face.mechanism_ids.append(id)

func run_profiles(level: Dictionary) -> void:
	var bad := level.duplicate(true)
	bad.cubes[0].group_id = &"turn"
	bad.groups = [Fixture.group(&"turn", 1, [&"floor"])]
	expect_code(bad, 1202, "cross layer group ownership")
	bad.groups[0].layer = 0
	bad.groups[0].allowed_states = [0, 22]
	bad.groups[0].allowed_rotation_deltas = [22]
	bad.groups[0].edges = [{"from_orientation": 0, "rotation_delta": 22, "to_orientation": 0}]
	expect_code(bad, 1203, "edge composition mismatch")
	bad = level.duplicate(true)
	bad.worlds[0].allowed_rotation_deltas = [22]
	expect_code(bad, 1502, "world intents and deltas paired")
	bad = level.duplicate(true)
	add_mechanism(bad, &"first")
	check(Validator.validate(bad, BUDGET).status == 0, "single-state celestial mechanism valid")
	bad.mechanisms[0].allowed_states.append(&"off")
	expect_code(bad, 1502, "multi-state mechanism profile")
	bad.mechanisms[0].allowed_states = [&"on"]
	add_mechanism(bad, &"second")
	bad.mechanisms[0].action.mechanism_id = &"second"
	expect_code(bad, 1006, "mechanism self authorization reference mismatch")
	bad = level.duplicate(true)
	add_mechanism(bad, &"first", &"ENTER")
	add_mechanism(bad, &"second", &"ENTER")
	expect_code(bad, 1501, "multiple ENTER effects")
	bad = level.duplicate(true)
	add_mechanism(bad, &"first")
	bad.mechanisms[0].action = {"kind": 1}
	expect_code(bad, 1502, "unsupported bound action")
	bad = level.duplicate(true)
	bad.cubes.append(Fixture.cube(&"other", 0, Vector3i(8, 0, 0)))
	Fixture.rebuild_faces(bad, [&"floor/TOP", &"other/FRONT"])
	bad.face_transitions = [{"transition_id": &"path", "source_face_id": &"floor/TOP", "target_face_id": &"other/FRONT", "entry_axis": 0, "exit_axis": 0, "rotation_steps": [2], "required_flags": []}]
	expect_code(bad, 1006, "cross cube FaceTransition forbidden")
	bad.face_transitions[0].target_face_id = &"floor/FRONT"
	Fixture.rebuild_faces(bad, [&"floor/TOP", &"floor/FRONT"])
	check(Validator.validate(bad, BUDGET).status == 0, "real same-cube three-segment transition valid")
	bad.face_transitions[0].rotation_steps = [22]
	expect_code(bad, 1203, "transition spin cannot change supporting normal")
	bad = level.duplicate(true)
	bad.cubes.append(Fixture.cube(&"inner", 1, Vector3i.ZERO))
	Fixture.rebuild_faces(bad, [&"floor/TOP", &"inner/TOP"])
	add_mechanism(bad, &"enter", &"ENTER")
	expect_code(bad, 1502, "Shift target ENTER rejected regardless of lighting")

func run_budgets(level: Dictionary) -> void:
	var short: Dictionary = Validator.validate(level, {"max_configurations": 1, "max_checks": 1})
	check(short.status == 2 and short.checks_performed <= 1 and short.configurations_checked <= 1, "query budget returns bounded INCOMPLETE")
	check(short.issues.any(func(issue: Dictionary) -> bool: return issue.code == 1600), "budget canonical 1600")
	covered[1600] = true
	for options in [{}, {"max_configurations": 0, "max_checks": 1}, {"max_configurations": 1, "max_checks": 1.0}, {"max_configurations": 1, "max_checks": 1, "time": 1}]:
		check(Validator.validate(level, options).status == 1, "invalid budgets are INVALID")
	var many := level.duplicate(true)
	many.worlds[0].allowed_states = [0, 22]
	many.worlds[1].allowed_states = [0, 22]
	var limited: Dictionary = Validator.validate(many, {"max_configurations": 1, "max_checks": 100000})
	check(limited.status == 2 and limited.configurations_checked == 1, "configuration budget cannot imply VALID")
	many.worlds[0].allowed_rotation_deltas = [22]
	limited = Validator.validate(many, {"max_configurations": 1, "max_checks": 100000})
	check(limited.status == 1 and limited.issues.any(func(issue: Dictionary) -> bool: return issue.code == 1600), "INVALID wins and retains incomplete diagnostics")
	var reordered := many.duplicate(true)
	reordered.worlds.reverse()
	reordered.faces.reverse()
	for world in reordered.worlds:
		world.allowed_states.reverse()
	check(Validator.validate(reordered, BUDGET) == Validator.validate(many, BUDGET), "canonical full results independent of declaration order")
	var multi := level.duplicate(true)
	multi.spawn.orientation = 99
	multi.goal.face_id = &"malformed_face"
	var result := expect_code(multi, 1101, "multiple independent issues")
	check(result.issues.size() >= 2, "multiple errors reported together")

func run_declared_motions(level: Dictionary) -> void:
	var rotating := level.duplicate(true)
	rotating.worlds[0].allowed_states = [0, 22]
	rotating.worlds[0].allowed_rotation_deltas = [22]
	rotating.worlds[0].allowed_rotation_intents = [0]
	check(Validator.validate(rotating, BUDGET).status == 0, "declared world edge uses real Safety")
	rotating = level.duplicate(true)
	rotating.cubes[0].center2 = Vector3i(4, 0, 0)
	rotating.cubes[0].group_id = &"turn"
	rotating.groups = [Fixture.group(&"turn", 0, [&"floor"])]
	rotating.groups[0].allowed_states = [0, 22]
	rotating.groups[0].edges = [{"from_orientation": 0, "rotation_delta": 22, "to_orientation": 22}]
	check(Validator.validate(rotating, BUDGET).status == 0, "unbound declared Group edge still geometrically validated")
	rotating.cubes.append(Fixture.cube(&"obstacle", 0, Vector3i(4, 0, 4)))
	Fixture.rebuild_faces(rotating)
	var result: Dictionary = Validator.validate(rotating, BUDGET)
	check(result.status == 2 and result.issues.any(func(issue: Dictionary) -> bool: return issue.code == 1601), "endpoint valid uncertain declared sweep is INCOMPLETE1601")
	covered[1601] = true
	rotating.cubes[1].center2 = Vector3i(0, 2, -4)
	result = expect_code(rotating, 1204, "player unsafe after declared rotation")
	check(result.issues.any(func(issue: Dictionary) -> bool: return issue.code == 1201), "unsafe player preserves original sealed-face issue")

func run_complete_domain(level: Dictionary) -> void:
	var duplicate_edges := level.duplicate(true)
	duplicate_edges.celestial.edges = [{"from_slot_id": &"a", "to_slot_id": &"a"}, {"from_slot_id": &"a", "to_slot_id": &"a"}]
	expect_code(duplicate_edges, 1005, "duplicate Celestial directed edges")
	var dark_layer := level.duplicate(true)
	dark_layer.cubes.append(Fixture.cube(&"inner", 1, Vector3i(0, 10, 0)))
	Fixture.rebuild_faces(dark_layer)
	expect_code(dark_layer, 1302, "Lighting computable on nonwalkable world")
	var enormous := level.duplicate(true)
	for index in 20:
		var id := StringName("g_%02d" % index)
		enormous.groups.append(Fixture.group(id, 1, []))
	var result: Dictionary = Validator.validate(enormous, {"max_configurations": 1, "max_checks": 1000})
	check(result.status == 2 and result.configurations_checked == 1, "24^20 domains stay lazy and bounded")
	# Validate the Static owner propagation boundary with a full official
	# Mapping resolution from synthetic candidates, never a Mapping double.
	var collection := {"ok": true, "issues": [], "candidates": [
		{"source_face": &"floor/TOP", "target_face": &"b/TOP", "compatibility": 0},
		{"source_face": &"floor/TOP", "target_face": &"a/BOTTOM", "compatibility": 1}]}
	var resolution := Mapping.resolve_mapping(collection)
	var sink := {"issues": []}
	Validator._consume_mapping(sink, resolution, level, {"probe": "floor/TOP"})
	check(sink.issues.size() == 1 and sink.issues[0].code == 1401, "Static owner propagates official AMBIGUOUS")
	for field in ["code", "severity", "path", "entity_ids", "message"]:
		check(sink.issues[0][field] == resolution.issues[0][field], "Mapping original " + field + " preserved")
	check(sink.issues[0].details.candidates == resolution.issues[0].details.candidates, "ambiguity details never replaced by config context")
	check(not resolution.issues[0].details.has("static_configuration"), "upstream issue not mutated")
	var shuffled := enormous.duplicate(true)
	shuffled.groups.reverse()
	shuffled.faces.reverse()
	shuffled.worlds.reverse()
	for group in shuffled.groups:
		group.allowed_states.reverse()
		group.allowed_rotation_deltas.reverse()
	check(Validator.validate(shuffled, {"max_configurations": 1, "max_checks": 1000}) == result, "bounded result identical after domains and collections reordered")
	var edge_order := level.duplicate(true)
	edge_order.cubes[0].group_id = &"turn"
	edge_order.cubes.append(Fixture.cube(&"obstacle", 0, Vector3i(0, 4, 0)))
	edge_order.groups = [Fixture.group(&"turn", 0, [&"floor"])]
	edge_order.groups[0].allowed_states = [0, 2, 12]
	edge_order.groups[0].edges = [{"from_orientation": 0, "rotation_delta": 12, "to_orientation": 12}, {"from_orientation": 0, "rotation_delta": 2, "to_orientation": 2}]
	Fixture.rebuild_faces(edge_order)
	result = Validator.validate(edge_order, BUDGET)
	var motions: Array = []
	for issue in result.issues:
		if issue.code == 1601 and issue.details.static_configuration.group_orientations.turn == 0:
			motions.append(issue.details.static_configuration.motion)
	check(motions == ["group:turn:2", "group:turn:12"], "canonical edge issue ties use numeric from/delta/to ordering")
	var malformed := level.duplicate(true)
	malformed.worlds[0].allowed_states = [0, 2, 12, 15.0, &"bad", {}, null]
	var malformed_reversed := malformed.duplicate(true)
	malformed_reversed.worlds[0].allowed_states.reverse()
	check(Validator.validate(malformed, BUDGET) == Validator.validate(malformed_reversed, BUDGET), "malformed mixed-type arrays also have deterministic diagnostic paths")
	var cyclic := level.duplicate(true)
	cyclic.build_info["cycle"] = cyclic.build_info
	expect_code(cyclic, 1000, "recursive invalid metadata terminates at DATA boundary")
	cyclic.build_info.clear() # Release the deliberately cyclic invalid test input.
