extends SceneTree

var failures: Array[String] = []
var checks := 0
var Types: Script
var Records: Script


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)


func _initialize() -> void:
	for path in ["res://foundation/contracts/foundation_types.gd", "res://foundation/contracts/contract_records.gd"]:
		if not ResourceLoader.exists(path):
			check(false, "required implementation exists: " + path)
			quit(1)
			return
	Types = load("res://foundation/contracts/foundation_types.gd")
	Records = load("res://foundation/contracts/contract_records.gd")
	call_deferred("run")


func run() -> void:
	run_record_tests()
	run_validation_tests()
	run_reconciliation_tests()
	if failures.is_empty():
		print("FOUNDATION_DATA_CONTRACTS_PASS checks=", checks)
		quit(0)
	else:
		printerr("FOUNDATION_DATA_CONTRACTS_FAIL failures=", failures.size(), " checks=", checks)
		quit(1)


func run_record_tests() -> void:
	var enum_goldens: Dictionary = {
		"WorldLayer": {"SURFACE": 0, "INNER": 1},
		"FaceDirection": {"FRONT": 0, "BACK": 1, "LEFT": 2, "RIGHT": 3, "TOP": 4, "BOTTOM": 5},
		"RotationIntent": {"TURN_LEFT": 0, "TURN_RIGHT": 1, "TIP_UP": 2, "TIP_DOWN": 3, "ROLL_CLOCKWISE": 4, "ROLL_COUNTERCLOCKWISE": 5},
		"FaceCompatibility": {"SAME_NORMAL": 0, "OPPOSITE_NORMAL": 1},
		"LightState": {"LIT": 0, "SHADOW": 1},
		"GlobalTransitionState": {"IDLE": 0, "MOVING": 1, "TRANSITION": 2},
		"GlobalTransitionKind": {"NONE": 0, "CELESTIAL": 1, "WORLD_ROTATION": 2, "GROUP_ROTATION": 3, "SHIFT": 4, "FACE_TRANSITION": 5},
		"FaceAxis": {"U_POS": 0, "V_POS": 1, "U_NEG": 2, "V_NEG": 3},
		"PuzzleActionKind": {"MOVE": 0, "SHIFT_WORLD": 1, "ROTATE_SURFACE": 2, "ROTATE_INNER": 3, "USE_FACE_TRANSITION": 4, "TRIGGER_MECHANISM": 5, "LOCAL_GROUP_ROTATE": 6, "MOVE_CELESTIAL": 7},
		"CelestialOp": {"SET_SLOT": 0, "NEXT_SLOT": 1, "PREVIOUS_SLOT": 2, "TOGGLE_BETWEEN": 3},
		"ValidationSeverity": {"ERROR": 0, "WARNING": 1, "INFO": 2},
		"ValidationCode": {
			"INVALID_TYPE": 1000, "UNKNOWN_FIELD": 1001, "MISSING_FIELD": 1002,
			"INVALID_ENUM": 1003, "INVALID_ID": 1004, "DUPLICATE_ID": 1005,
			"INVALID_REFERENCE": 1006, "VERSION_MISMATCH": 1007,
			"OFF_LATTICE": 1100, "INVALID_ORIENTATION": 1101, "INVALID_SURFACE_FRAME": 1102,
			"INVALID_FACE": 1103, "INVALID_ANCHOR": 1104, "ARITHMETIC_OVERFLOW": 1105,
			"SAME_WORLD_CUBE_OVERLAP": 1200, "SEALED_WALKABLE_FACE": 1201,
			"INVALID_GROUP": 1202, "INVALID_ROTATION_EDGE": 1203, "PLAYER_UNSAFE": 1204,
			"INVALID_CELESTIAL_REFERENCE": 1300, "SLOT_STEP_UNAVAILABLE": 1301, "LIGHT_SOURCE_INVALID": 1302,
			"NO_SHIFT_MAPPING": 1400, "AMBIGUOUS_SHIFT_MAPPING": 1401, "FACE_INCOMPATIBLE": 1402,
			"SHIFT_REQUIRES_SHADOW": 1403, "SHIFT_EXIT_BLOCKED": 1404, "SHIFT_ENTRY_BLOCKED": 1405,
			"GLOBAL_TRANSITION_BUSY": 1500, "MULTIPLE_GLOBAL_MUTATIONS": 1501,
			"INVALID_ACTION": 1502, "UNAUTHORIZED_MECHANISM": 1503, "MOVE_NOT_COMMUTATIVE": 1504,
			"VALIDATION_BUDGET_EXCEEDED": 1600, "VALIDATION_INCOMPLETE": 1601,
		},
	}
	for enum_name in enum_goldens:
		var actual: Dictionary = Types.get(enum_name)
		var expected: Dictionary = enum_goldens[enum_name]
		check(actual.size() == expected.size(), enum_name + " has exactly the frozen members")
		for member in expected:
			check(actual.get(member) == expected[member], enum_name + "." + member + " wire ID")

	var location: Dictionary = Records.make_player_location(0, &"floor", 4)
	check(location == {"layer": 0, "cube_id": &"floor", "face": 4}, "location has exact schema and values")
	check(typeof(location.cube_id) == TYPE_STRING_NAME, "location retains StringName ID")
	check(Records.make_player_location(1, &"", 5) == {"layer": 1, "cube_id": &"", "face": 5}, "factory preserves empty ID for validation")
	var player: Dictionary = Records.make_player_state(location, 23)
	check(player == {"location": {"layer": 0, "cube_id": &"floor", "face": 4}, "orientation": 23}, "player has exact schema and values")
	location.cube_id = &"changed"
	check(player.location.cube_id == &"floor", "player owns location deep copy")
	player.location.face = 1
	check(location.face == 4, "editing player does not change source location")
	check(Records.make_action(1, {}) == {"kind": 1}, "Shift action has no target override")
	var payload := {"face_axis": 2}
	check(Records.make_action(0, payload) == {"kind": 0, "face_axis": 2}, "action combines kind and payload")
	check(payload == {"face_axis": 2}, "action construction does not mutate payload")
	var conflict := {"kind": 0, "face_axis": 2}
	check(Records.make_action(1, conflict).is_empty(), "conflicting payload kind returns empty dictionary")
	check(conflict == {"kind": 0, "face_axis": 2}, "conflicting action does not mutate payload")
	check(Records.make_action(0, {"kind": 0}).is_empty(), "matching payload kind is also rejected")
	var nested_payload := {"nested": [{"ids": [&"a", &"b"]}]}
	var copied_action: Dictionary = Records.make_action(0, nested_payload)
	nested_payload.nested[0].ids[0] = &"changed"
	check(copied_action.nested[0].ids == [&"a", &"b"], "action deeply owns nested dictionaries and arrays")
	copied_action.nested[0].ids.append(&"c")
	check(nested_payload.nested[0].ids.size() == 2, "editing action does not change source collections")

	var minimal := minimal_level()
	check(Records.initial_state(minimal) == {
		"player": {"location": {"layer": 0, "cube_id": &"floor", "face": 4}, "orientation": 0},
		"world_orientations": [0, 0], "celestial": {"slot_id": &"a"},
		"group_orientations": {}, "mechanism_states": {}, "level_flags": {},
	}, "minimal initial state has exact stable schema")
	var rich := rich_level()
	var before := rich.duplicate(true)
	var state: Dictionary = Records.initial_state(rich)
	var expected_state := {
		"player": {"location": {"layer": 0, "cube_id": &"floor", "face": 4}, "orientation": 23},
		"world_orientations": [2, 3], "celestial": {"slot_id": &"b"},
		"group_orientations": {&"hinge": 22}, "mechanism_states": {&"switch": &"armed"},
		"level_flags": {&"opened": true, &"finished": false},
	}
	check(state == expected_state, "rich initial state maps worlds by layer and declared initial values")
	check(rich == before, "initial_state does not mutate definition")
	rich.spawn.location.cube_id = &"changed"
	rich.worlds[0].initial_orientation = 0
	rich.celestial.initial_slot_id = &"a"
	rich.groups[0].initial_orientation = 0
	rich.mechanisms[0].initial_state = &"idle"
	rich.flag_definitions[0].initial_value = false
	check(state == expected_state, "initial state owns all definition-derived collections")
	var second: Dictionary = Records.initial_state(before)
	state.player.location.face = 1
	state.world_orientations[0] = 0
	state.celestial.slot_id = &"a"
	state.group_orientations[&"hinge"] = 0
	state.mechanism_states[&"switch"] = &"idle"
	state.level_flags[&"opened"] = false
	check(second == expected_state, "each initial_state call returns independent collections")
	check(before == rich_level(), "editing initial state cannot change definition")


func minimal_level() -> Dictionary:
	var faces: Array[Dictionary] = []
	var symbols := ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	for face in range(6):
		faces.append({"face_id": StringName("floor/" + symbols[face]), "cube_id": &"floor", "face": face,
			"walkable": face == 4, "shift_exit_blocked": false, "shift_entry_blocked": false, "mechanism_ids": []})
	return {
		"schema_version": 1, "contract_version": "foundation.contract.v1", "orientation_version": "cube24.v1",
		"rule_version": "foundation.rules.v1", "level_id": &"fixture", "content_hash": "0".repeat(64), "cell_size": 1,
		"worlds": [
			{"layer": 0, "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0], "allowed_rotation_deltas": [], "allowed_rotation_intents": []},
			{"layer": 1, "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0], "allowed_rotation_deltas": [], "allowed_rotation_intents": []},
		],
		"cubes": [{"cube_id": &"floor", "layer": 0, "center2": Vector3i.ZERO, "orientation": 0,
			"group_id": &"", "occludes_light": true, "tags": []}],
		"faces": faces, "groups": [],
		"celestial": {"slots": [{"slot_id": &"a", "position2": Vector3i(0, 6, 0)}], "slot_order": [&"a"], "wrap": false, "initial_slot_id": &"a", "edges": []},
		"mechanisms": [], "face_transitions": [], "shift_compatibilities": [0],
		"spawn": {"location": {"layer": 0, "cube_id": &"floor", "face": 4}, "orientation": 0},
		"goal": {"face_id": &"floor/TOP", "required_flags": []}, "flag_definitions": [], "build_info": {},
	}


func rich_level() -> Dictionary:
	var level := minimal_level()
	level.worlds.reverse()
	level.worlds[0].initial_orientation = 3
	level.worlds[0].allowed_states = [0, 3]
	level.worlds[1].initial_orientation = 2
	level.worlds[1].allowed_states = [0, 2]
	level.spawn.orientation = 23
	level.cubes[0].group_id = &"hinge"
	level.groups = [{"group_id": &"hinge", "layer": 0, "cube_ids": [&"floor"], "pivot2": Vector3i.ZERO,
		"initial_orientation": 22, "allowed_states": [0, 22], "allowed_rotation_deltas": [], "edges": []}]
	level.celestial.slots.append({"slot_id": &"b", "position2": Vector3i(0, 8, 0)})
	level.celestial.slot_order.append(&"b")
	level.celestial.initial_slot_id = &"b"
	level.faces[4].mechanism_ids = [&"switch"]
	level.mechanisms = [{"mechanism_id": &"switch", "face_id": &"floor/TOP", "trigger": &"USE",
		"action": {"kind": 1}, "priority": 0, "initial_state": &"armed", "allowed_states": [&"idle", &"armed"]}]
	level.flag_definitions = [{"flag_id": &"opened", "initial_value": true}, {"flag_id": &"finished", "initial_value": false}]
	return level

# Validation regression suite, appended to the Task 1 runner.
var Validation: Script

func contract_fixture(rich: bool = false) -> Dictionary:
	var level := {
		"schema_version": 1, "contract_version": "foundation.contract.v1",
		"orientation_version": "cube24.v1", "rule_version": "foundation.rules.v1",
		"level_id": &"fixture", "content_hash": "a".repeat(64), "cell_size": 1,
		"worlds": [], "cubes": [{"cube_id": &"floor", "layer": 0,
			"center2": Vector3i.ZERO, "orientation": 0, "group_id": &"",
			"occludes_light": true, "tags": [&"floor"]}],
		"faces": [], "groups": [],
		"celestial": {"slots": [{"slot_id": &"a", "position2": Vector3i(0,6,0)}],
			"slot_order": [&"a"], "wrap": false, "initial_slot_id": &"a", "edges": []},
		"mechanisms": [], "face_transitions": [], "shift_compatibilities": [0],
		"spawn": {"location": {"layer": 0, "cube_id": &"floor", "face": 4}, "orientation": 0},
		"goal": {"face_id": &"floor/TOP", "required_flags": []},
		"flag_definitions": [], "build_info": {}
	}
	for layer in 2:
		level.worlds.append({"layer": layer, "pivot2": Vector3i.ZERO, "initial_orientation": 0,
			"allowed_states": [0], "allowed_rotation_deltas": [], "allowed_rotation_intents": []})
	var names := ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	for face in 6:
		level.faces.append({"face_id": StringName("floor/" + names[face]), "cube_id": &"floor",
			"face": face, "walkable": face == 4, "shift_exit_blocked": false,
			"shift_entry_blocked": false, "mechanism_ids": []})
	if rich:
		level.cubes[0].group_id = &"g"
		level.groups = [{"group_id": &"g", "layer": 0, "cube_ids": [&"floor"],
			"pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0,2],
			"allowed_rotation_deltas": [2], "edges": [{"from_orientation": 0, "rotation_delta": 2, "to_orientation": 2}]}]
		level.mechanisms = [{"mechanism_id": &"m", "face_id": &"floor/TOP", "trigger": &"USE",
			"action": {"kind": 1}, "priority": 0, "initial_state": &"ready", "allowed_states": [&"ready", &"used"]}]
		level.faces[4].mechanism_ids = [&"m"]
		level.flag_definitions = [{"flag_id": &"done", "initial_value": false}]
		level.face_transitions = [{"transition_id": &"t", "source_face_id": &"floor/TOP",
			"target_face_id": &"floor/FRONT", "entry_axis": 0, "exit_axis": 2,
			"rotation_steps": [2,3], "required_flags": [&"done"]}]
		level.goal.required_flags = [&"done"]
		level.celestial.slots.append({"slot_id": &"b", "position2": Vector3i(4,6,0)})
		level.celestial.slot_order.append(&"b")
		level.celestial.edges = [{"from_slot_id": &"a", "to_slot_id": &"b"}]
	return level

func contract_has(issues: Array, code: int, path: String = "") -> bool:
	for issue in issues:
		if issue.code == code and (path.is_empty() or issue.path == path):
			return true
	return false

func contract_at(value: Variant, path: Array) -> Variant:
	for key in path:
		value = value[key]
	return value

func contract_path(path: Array) -> String:
	var result := ""
	for key in path:
		if key is int:
			result += "[%d]" % key
		else:
			result += ("." if not result.is_empty() else "") + str(key)
	return result

func contract_change(base: Dictionary, path: Array, value: Variant) -> Dictionary:
	var copy := base.duplicate(true)
	var parent: Variant = contract_at(copy, path.slice(0, -1))
	parent[path[-1]] = value
	return copy

func run_validation_tests() -> void:
	if not ResourceLoader.exists("res://foundation/contracts/contract_validation.gd"):
		check(false, "STRUCTURE_CONTRACT validator implementation exists")
		return
	Validation = load("res://foundation/contracts/contract_validation.gd")
	if Validation == null or not Validation.can_instantiate():
		check(false, "validator compiles")
		return
	var minimal := contract_fixture()
	var rich := contract_fixture(true)
	check(Validation.validate_level_shape(minimal).is_empty(), "minimal LevelDefinition shape")
	check(Validation.validate_level_shape(rich).is_empty(), "nonempty declared structure shape")
	# Every record rejects missing and unknown fields, including nested action unions.
	var record_paths := [[], ["worlds",0], ["cubes",0], ["faces",0], ["groups",0],
		["groups",0,"edges",0], ["celestial"], ["celestial","slots",0], ["celestial","edges",0],
		["mechanisms",0], ["mechanisms",0,"action"], ["face_transitions",0],
		["spawn"], ["spawn","location"], ["goal"], ["flag_definitions",0]]
	for path in record_paths:
		var record: Dictionary = contract_at(rich, path)
		for key in record:
			var missing := rich.duplicate(true)
			contract_at(missing, path).erase(key)
			var field_path: Array = path + [key]
			check(contract_has(Validation.validate_level_shape(missing), 1002, contract_path(field_path)),
				"missing required " + contract_path(field_path))
		var unknown := rich.duplicate(true)
		contract_at(unknown, path)["unexpected"] = true
		check(contract_has(Validation.validate_level_shape(unknown), 1001, contract_path(path + ["unexpected"])),
			"unknown field " + contract_path(path))
		for key in record:
			var malformed := contract_change(rich, path + [key], null)
			check(contract_has(Validation.validate_level_shape(malformed), 1000, contract_path(path + [key])),
				"null field type " + contract_path(path + [key]))
	var level_cases := [
		[["schema_version"], 2, 1007], [["contract_version"], "future", 1007],
		[["orientation_version"], "future", 1007], [["rule_version"], "future", 1007],
		[["cell_size"], 2, 1100], [["level_id"], &"", 1004], [["level_id"], &"Upper", 1004],
		[["level_id"], "fixture", 1000], [["content_hash"], "A".repeat(64), 1004],
		[["content_hash"], "abc", 1004], [["cubes",0,"center2"], Vector3(0,0,0), 1000],
		[["cubes",0,"center2"], Vector3i(1,0,0), 1100],
		[["cubes",0,"orientation"], 24, 1101], [["cubes",0,"layer"], 2, 1003],
		[["cubes",0,"group_id"], &"absent", 1006], [["cubes",0,"tags"], ["bad"], 1000],
		[["faces",0,"face_id"], &"floor/TOP", 1103], [["faces",0,"cube_id"], &"absent", 1006],
		[["faces",0,"face"], 6, 1103], [["faces",0,"mechanism_ids"], [&"absent"], 1006],
		[["worlds"], [], 1006], [["worlds",0,"allowed_states"], [], 1101],
		[["worlds",0,"initial_orientation"], 2, 1101], [["worlds",0,"allowed_rotation_deltas"], [1], 1101],
		[["worlds",0,"allowed_rotation_intents"], [6], 1003],
		[["groups",0,"cube_ids"], [&"absent"], 1006], [["groups",0,"layer"], 1, 1202],
		[["groups",0,"cube_ids"], [], 1202], [["groups",0,"initial_orientation"], 3, 1101],
		[["groups",0,"edges",0,"to_orientation"], 3, 1203],
		[["groups",0,"edges",0,"rotation_delta"], 3, 1203],
		[["celestial","initial_slot_id"], &"absent", 1300],
		[["celestial","slot_order"], [&"a"], 1300], [["celestial","slot_order"], [&"a",&"a"], 1005],
		[["celestial","edges",0,"to_slot_id"], &"absent", 1300],
		[["mechanisms",0,"face_id"], &"absent/TOP", 1006],
		[["mechanisms",0,"trigger"], &"BOGUS", 1003], [["mechanisms",0,"initial_state"], &"missing", 1006],
		[["mechanisms",0,"allowed_states"], [], 1006],
		[["face_transitions",0,"source_face_id"], &"absent/TOP", 1006],
		[["face_transitions",0,"target_face_id"], &"absent/TOP", 1006],
		[["face_transitions",0,"rotation_steps"], [1], 1101],
		[["face_transitions",0,"required_flags"], [&"absent"], 1006],
		[["goal","face_id"], &"absent/TOP", 1006], [["goal","required_flags"], [&"absent"], 1006],
		[["spawn","location","layer"], 1, 1006], [["spawn","orientation"], -1, 1101],
		[["shift_compatibilities"], [], 1003], [["shift_compatibilities"], [0,0], 1005],
		[["shift_compatibilities"], [2], 1003], [["build_info"], {"source": 1}, 1000]
	]
	for test in level_cases:
		var changed := contract_change(rich, test[0], test[1])
		check(contract_has(Validation.validate_level_shape(changed), test[2]), "reject " + contract_path(test[0]) + " = " + str(test[1]))
	for collection in ["cubes", "faces", "groups", "mechanisms", "face_transitions", "flag_definitions"]:
		var duplicate := rich.duplicate(true)
		duplicate[collection].append(duplicate[collection][0].duplicate(true))
		check(contract_has(Validation.validate_level_shape(duplicate), 1005), "duplicate " + collection)
	var legacy := minimal.duplicate(true)
	legacy.faces[0]["shift_blocked"] = true
	check(contract_has(Validation.validate_level_shape(legacy), 1001), "legacy Shift flag rejected")
	var restrictions := minimal.duplicate(true)
	restrictions.faces[0].shift_exit_blocked = true
	restrictions.faces[1].shift_entry_blocked = true
	check(Validation.validate_level_shape(restrictions).is_empty(), "independent Shift flags accepted")
	var incomplete := minimal.duplicate(true)
	incomplete.faces.pop_back()
	check(not Validation.validate_level_shape(incomplete).is_empty(), "all six faces required")
	var reverse_group := rich.duplicate(true)
	reverse_group.cubes[0].group_id = &""
	check(contract_has(Validation.validate_level_shape(reverse_group), 1202), "reverse group ownership enforced")
	# Type robustness: bad array entries never trigger script errors.
	for path in [["worlds"],["cubes"],["faces"],["groups"],["mechanisms"],["face_transitions"],
		["flag_definitions"],["celestial","slots"],["celestial","edges"],["groups",0,"edges"]]:
		for bad in [null, 1, "record", [], {}]:
			check(not Validation.validate_level_shape(contract_change(rich,path,[bad])).is_empty(), "malformed collection " + contract_path(path))
	# Boundary tests distinguish strict wire types from values Godot can coerce.
	for entry in [
		[["schema_version"],true], [["schema_version"],1.0],
		[["cubes",0,"orientation"],0.0], [["cubes",0,"orientation"],false],
		[["faces",0,"walkable"],0], [["worlds",0,"allowed_states"],[false]],
		[["worlds",0,"allowed_rotation_deltas"],[2.0]],
		[["celestial","wrap"],0], [["celestial","slots",0,"slot_id"],"a"],
		[["mechanisms",0,"priority"],false], [["flag_definitions",0,"initial_value"],1]]:
		check(contract_has(Validation.validate_level_shape(contract_change(rich,entry[0],entry[1])),1000), "strict wire type " + contract_path(entry[0]))
	for path in [["celestial","slots"],["worlds"]]:
		var duplicate := rich.duplicate(true)
		var entries: Array = contract_at(duplicate,path)
		entries.append(entries[0].duplicate(true))
		check(contract_has(Validation.validate_level_shape(duplicate),1005), "duplicate identity " + contract_path(path))
	var reordered := rich.duplicate(true)
	reordered.worlds.reverse()
	check(Validation.validate_level_shape(reordered).is_empty(), "worlds identified by layer rather than array position")
	check(Validation.validate_state_shape(reordered,Records.initial_state(reordered)).is_empty(), "state layer indices independent of definition order")
	# These are deliberately shape-only: composition and player safety belong to later validators.
	var unproved_edge := rich.duplicate(true)
	unproved_edge.groups[0].edges[0].to_orientation = 0
	check(Validation.validate_level_shape(unproved_edge).is_empty(), "shape does not impersonate rotation composition validation")
	var unproved_spawn := minimal.duplicate(true)
	unproved_spawn.faces[4].walkable = false
	check(Validation.validate_level_shape(unproved_spawn).is_empty(), "shape does not impersonate player safety validation")
	var non_string_key := {}
	for key in minimal:
		non_string_key[StringName(key)] = minimal[key]
	check(contract_has(Validation.validate_level_shape(non_string_key),1000), "record keys must be String")

	var cross_world_duplicate := minimal.duplicate(true)
	var repeated_cube: Dictionary = minimal.cubes[0].duplicate(true)
	repeated_cube.layer = 1
	cross_world_duplicate.cubes.append(repeated_cube)
	check(contract_has(Validation.validate_level_shape(cross_world_duplicate),1005), "Cube ID uniqueness spans both world layers")
	var shared_ids := rich.duplicate(true)
	shared_ids.level_id = &"floor"
	shared_ids.groups[0].group_id = &"floor"
	shared_ids.cubes[0].group_id = &"floor"
	shared_ids.mechanisms[0].mechanism_id = &"floor"
	shared_ids.faces[4].mechanism_ids = [&"floor"]
	shared_ids.flag_definitions[0].flag_id = &"floor"
	shared_ids.face_transitions[0].transition_id = &"floor"
	shared_ids.face_transitions[0].required_flags = [&"floor"]
	shared_ids.goal.required_flags = [&"floor"]
	shared_ids.celestial.slots[0].slot_id = &"floor"
	shared_ids.celestial.slot_order[0] = &"floor"
	shared_ids.celestial.initial_slot_id = &"floor"
	shared_ids.celestial.edges[0].from_slot_id = &"floor"
	check(Validation.validate_level_shape(shared_ids).is_empty(), "same literal ID is legal across distinct identity types")
	check(Validation.validate_state_shape(shared_ids,Records.initial_state(shared_ids)).is_empty(), "typed state ID maps may share literal IDs")

	var tied_diagnostics := rich.duplicate(true)
	tied_diagnostics.celestial.slots.append({"slot_id":&"c","position2":Vector3i(8,6,0)})
	tied_diagnostics.celestial.slots.reverse()
	tied_diagnostics.celestial.slot_order = []
	var tie_ids: Array = []
	for issue in Validation.validate_level_shape(tied_diagnostics):
		if issue.path == "celestial.slot_order" and issue.code == 1300:
			tie_ids.append(issue.entity_ids)
	check(tie_ids == [[&"a"],[&"b"],[&"c"]], "issue entity IDs break tied path/code in byte order")

	contract_test_actions(rich)
	contract_test_states(rich)
	# Validation is pure and diagnostic ordering does not depend on dictionary insertion order.
	var invalid := contract_change(rich, ["cubes",0,"orientation"], 24)
	invalid["zzz"] = 1
	invalid["aaa"] = 2
	var before := invalid.duplicate(true)
	var issues: Array = Validation.validate_level_shape(invalid)
	check(invalid == before, "level validation preserves all inputs")
	var reversed := {}
	var keys := invalid.keys()
	keys.reverse()
	for key in keys:
		reversed[key] = invalid[key]
	check(Validation.validate_level_shape(reversed) == issues, "issues deterministic across key insertion order")
	var previous_path := ""
	var previous_code := -1
	for issue in issues:
		check(issue.keys().size() == 6 and issue.has("code") and issue.has("severity") and issue.has("path") and issue.has("entity_ids") and issue.has("message") and issue.has("details"), "ValidationIssue exact fields")
		check(issue.path >= previous_path and (issue.path != previous_path or issue.code >= previous_code), "issue path/code ordering")
		previous_path = issue.path
		previous_code = issue.code
		check(issue.severity == 0 and issue.message is String and issue.details is Dictionary, "diagnostic value types")
		for entity in issue.entity_ids:
			check(entity is StringName, "diagnostic ID type")
	print("STRUCTURE_CONTRACT fields: LevelDefinition=19 PuzzleState=6; excludes geometry, lighting, permission, solvability")

func contract_test_actions(level: Dictionary) -> void:
	var actions := [{"kind":0,"face_axis":0}, {"kind":1}, {"kind":2,"rotation_delta":2},
		{"kind":3,"rotation_delta":3}, {"kind":4,"transition_id":&"t"},
		{"kind":5,"mechanism_id":&"m"}, {"kind":6,"group_id":&"g","rotation_delta":2,"mechanism_id":&"m"}]
	for op in 4:
		actions.append({"kind":7,"celestial_op":op,"target_slot_id":&"a" if op in [0,3] else &"",
			"alternate_slot_id":&"b" if op == 3 else &"", "mechanism_id":&"m"})
	for action in actions:
		var before: Dictionary = action.duplicate(true)
		var definition_before := level.duplicate(true)
		check(Validation.validate_action_shape(level,action).is_empty(), "action union accepts " + str(action))
		check(action == before and level == definition_before, "action validation immutable")
		for field in action:
			var missing: Dictionary = action.duplicate(true)
			missing.erase(field)
			check(contract_has(Validation.validate_action_shape(level,missing),1002), "action requires " + field)
			var wrong: Dictionary = action.duplicate(true)
			wrong[field] = null
			check(contract_has(Validation.validate_action_shape(level,wrong),1000), "action rejects null " + field)
		var extra: Dictionary = action.duplicate(true)
		extra["unexpected"] = 1
		check(contract_has(Validation.validate_action_shape(level,extra),1001), "action rejects unknown field")
	for action in [{"kind":1,"target_face_id":&"floor/TOP"}, {"kind":0},
		{"kind":2,"rotation_delta":1}, {"kind":2,"rotation_delta":24}, {"kind":8}, {"kind":true},
		{"kind":6,"group_id":&"g","rotation_delta":2}, {"kind":5,"mechanism_id":&"missing"},
		{"kind":4,"transition_id":&"missing"}, {"kind":0,"face_axis":4},
		{"kind":6,"group_id":&"missing","rotation_delta":2,"mechanism_id":&"m"}]:
		check(not Validation.validate_action_shape(level,action).is_empty(), "invalid action " + str(action))
	for delta in [2,3,22,18,9,12]:
		check(Validation.validate_action_shape(level,{"kind":2,"rotation_delta":delta}).is_empty(), "six quarter turns")
	for op in 4:
		for pair in [[&"",&""],[&"a",&""],[&"",&"b"],[&"a",&"b"],[&"a",&"a"],[&"missing",&"b"]]:
			var action := {"kind":7,"celestial_op":op,"target_slot_id":pair[0],"alternate_slot_id":pair[1],"mechanism_id":&"m"}
			var legal: bool = (op == 0 and pair == [&"a",&""]) or (op in [1,2] and pair == [&"",&""]) or (op == 3 and pair == [&"a",&"b"])
			check(Validation.validate_action_shape(level,action).is_empty() == legal, "CelestialOp slots " + str(action))
	check(contract_has(Validation.validate_action_shape(level,Records.make_action(1,{"kind":0})),1002), "factory kind conflict rejected at boundary")

func contract_test_states(level: Dictionary) -> void:
	var state: Dictionary = Records.initial_state(level)
	check(Validation.validate_state_shape(level,state).is_empty(), "factory state matches level domains")
	for field in state:
		var missing := state.duplicate(true)
		missing.erase(field)
		check(contract_has(Validation.validate_state_shape(level,missing),1002), "state requires " + field)
		var wrong := state.duplicate(true)
		wrong[field] = null
		check(contract_has(Validation.validate_state_shape(level,wrong),1000), "state field type " + field)
	for field in ["Frame","LightState","held_keys","global_transition_state","rotate_target","pending_actions"]:
		var extra := state.duplicate(true)
		extra[field] = 0
		check(contract_has(Validation.validate_state_shape(level,extra),1001), "stable state excludes " + field)
	for field in ["group_orientations","mechanism_states","level_flags"]:
		var missing := state.duplicate(true)
		missing[field].clear()
		check(not Validation.validate_state_shape(level,missing).is_empty(), "state exact coverage missing " + field)
		var extra := state.duplicate(true)
		extra[field][&"unknown"] = 0
		check(not Validation.validate_state_shape(level,extra).is_empty(), "state exact coverage extra " + field)
	for entry in [
		[["world_orientations"],[0]], [["world_orientations"],[0,0,0]], [["world_orientations"],[2,0]],
		[["world_orientations"],[0,true]], [["player","location","layer"],1],
		[["player","location","cube_id"],&"unknown"], [["player","orientation"],24],
		[["celestial","slot_id"],&"unknown"], [["group_orientations",&"g"],3],
		[["mechanism_states",&"m"],&"unknown"], [["level_flags",&"done"],1]]:
		var changed := contract_change(state,entry[0],entry[1])
		var before := changed.duplicate(true)
		var level_before := level.duplicate(true)
		check(not Validation.validate_state_shape(level,changed).is_empty(), "invalid state " + contract_path(entry[0]))
		check(changed == before and level == level_before, "invalid state validation immutable")
	for path in [["player"], ["player","location"], ["celestial"]]:
		var record: Dictionary = contract_at(state,path)
		for field in record:
			var missing := state.duplicate(true)
			contract_at(missing,path).erase(field)
			check(contract_has(Validation.validate_state_shape(level,missing),1002), "nested state requires " + contract_path(path + [field]))
			var wrong := contract_change(state,path + [field],null)
			check(contract_has(Validation.validate_state_shape(level,wrong),1000), "nested state type " + contract_path(path + [field]))
		var extra := state.duplicate(true)
		contract_at(extra,path)["unexpected"] = true
		check(contract_has(Validation.validate_state_shape(level,extra),1001), "nested state unknown " + contract_path(path))
	for field in ["group_orientations","mechanism_states","level_flags"]:
		var wrong_keys := state.duplicate(true)
		wrong_keys[field] = {}
		for key in state[field]:
			wrong_keys[field][String(key)] = state[field][key]
		check(contract_has(Validation.validate_state_shape(level,wrong_keys),1000), "state map keys must be StringName " + field)

	for invalid_level in [{}, {"cubes":null}]:
		check(not Validation.validate_state_shape(invalid_level,state).is_empty(), "state handles malformed definition")
		check(not Validation.validate_action_shape(invalid_level,{"kind":1}).is_empty(), "action handles malformed definition")


func run_reconciliation_tests() -> void:
	# Consumers rely on these frozen ABI names; legacy prompts must not create aliases.
	var constants: Dictionary = Types.get_script_constant_map()
	var resolution: Dictionary = constants.get("MappingResolutionStatus", {})
	check(resolution.size() == 4, "MappingResolutionStatus exactly four frozen members")
	for entry in [["NONE",0], ["UNIQUE",1], ["AMBIGUOUS",2], ["ERROR",3]]:
		check(resolution.get(entry[0]) == entry[1], "resolution " + entry[0] + " ABI")
	for alias in ["COORDINATE_OVERFLOW", "DUPLICATE_CUBE_ID", "CUBE_OVERLAP",
		"INVALID_ROTATABLE_GROUP_STATE", "INVALID_MECHANISM_REFERENCE", "INVALID_SPAWN",
		"INVALID_EXIT", "PLAYER_UNSAFE_AFTER_ROTATION"]:
		check(not Types.ValidationCode.has(alias), "no ValidationCode alias " + alias)
	check(Types.ValidationCode.ARITHMETIC_OVERFLOW == 1105, "single canonical overflow code")
	check(Types.ValidationCode.values().count(1105) == 1, "1105 has one canonical name")
	check(Types.PuzzleActionKind.LOCAL_GROUP_ROTATE == 6, "LOCAL_GROUP_ROTATE remains 6")
	check(not Types.PuzzleActionKind.has("ROTATE_LOCAL_GROUP"), "no local group action alias")
	if Validation == null or not Validation.can_instantiate():
		return
	var level := contract_fixture(true)
	# Missing referenced slots and incomplete coverage use 1300 at every DATA boundary.
	for entry in [
		[["celestial","initial_slot_id"], &"missing", "celestial.initial_slot_id"],
		[["celestial","slot_order"], [&"a",&"missing"], "celestial.slot_order[1]"],
		[["celestial","slot_order"], [&"a"], "celestial.slot_order"],
		[["celestial","edges",0,"from_slot_id"], &"missing", "celestial.edges[0].from_slot_id"],
		[["celestial","edges",0,"to_slot_id"], &"missing", "celestial.edges[0].to_slot_id"]]:
		var issues: Array = Validation.validate_level_shape(contract_change(level, entry[0], entry[1]))
		check(contract_has(issues, 1300, entry[2]), "canonical celestial level reference " + entry[2])
		check(not contract_has(issues, 1006), "celestial level reference has no generic duplicate code " + entry[2])
	var state: Dictionary = Records.initial_state(level)
	state.celestial.slot_id = &"missing"
	var state_issues: Array = Validation.validate_state_shape(level, state)
	check(contract_has(state_issues, 1300, "celestial.slot_id"), "canonical celestial state reference")
	check(not contract_has(state_issues, 1006), "celestial state has no generic reference code")
	for entry in [[0,&"missing",&"","target_slot_id"],
		[3,&"missing",&"b","target_slot_id"], [3,&"a",&"missing","alternate_slot_id"]]:
		var action := {"kind":7,"celestial_op":entry[0],"target_slot_id":entry[1],
			"alternate_slot_id":entry[2],"mechanism_id":&"m"}
		var issues: Array = Validation.validate_action_shape(level, action)
		check(contract_has(issues, 1300, entry[3]), "canonical celestial action reference " + str(entry))
		check(not contract_has(issues, 1006), "celestial action has no generic reference code " + str(entry))
		var embedded := level.duplicate(true)
		embedded.mechanisms[0].action = action
		check(contract_has(Validation.validate_level_shape(embedded), 1300, "mechanisms[0].action." + entry[3]),
			"canonical embedded celestial action reference " + str(entry))
	# Shape errors remain distinct from missing references.
	var missing := level.duplicate(true)
	missing.celestial.erase("initial_slot_id")
	check(contract_has(Validation.validate_level_shape(missing), 1002, "celestial.initial_slot_id"), "celestial missing field retains 1002")
	check(contract_has(Validation.validate_level_shape(contract_change(level, ["celestial","initial_slot_id"], "a")),
		1000, "celestial.initial_slot_id"), "celestial reference type retains 1000")
	check(contract_has(Validation.validate_level_shape(contract_change(level, ["celestial","slot_order"], [&"a",&"a",&"b"])),
		1005, "celestial.slot_order[1]"), "celestial duplicate order retains 1005")
	check(contract_has(Validation.validate_action_shape(level, {"kind":5,"mechanism_id":&"missing"}),
		1006, "mechanism_id"), "mechanism reference remains generic 1006")
	check(contract_has(Validation.validate_level_shape(contract_change(level, ["goal","face_id"], &"missing/TOP")),
		1006, "goal.face_id"), "goal reference remains generic 1006")
	# Section 8.1 gives face identity/range failures their specific code, unlike other enums/IDs.
	for bad_face in [-1, 6]:
		for path in [["faces",0,"face"], ["spawn","location","face"]]:
			check(contract_has(Validation.validate_level_shape(contract_change(level, path, bad_face)),
				1103, contract_path(path)), "invalid local face uses 1103 " + contract_path(path) + " " + str(bad_face))
		var bad_state: Dictionary = Records.initial_state(level)
		bad_state.player.location.face = bad_face
		check(contract_has(Validation.validate_state_shape(level, bad_state), 1103, "player.location.face"),
			"invalid player state local face uses 1103 " + str(bad_face))
	for bad_face_id in [&"floor", &"floor/BOGUS", &"/TOP", &"Floor/TOP", &"floor/TOP/FRONT"]:
		for path in [["faces",0,"face_id"], ["goal","face_id"], ["mechanisms",0,"face_id"],
			["face_transitions",0,"source_face_id"], ["face_transitions",0,"target_face_id"]]:
			check(contract_has(Validation.validate_level_shape(contract_change(level, path, bad_face_id)),
				1103, contract_path(path)), "invalid face identity uses 1103 " + contract_path(path) + " " + str(bad_face_id))
	check(contract_has(Validation.validate_level_shape(contract_change(level, ["spawn","location","face"], 4.0)),
		1000, "spawn.location.face"), "local face type error remains 1000")
	check(contract_has(Validation.validate_level_shape(contract_change(level, ["goal","face_id"], "floor/TOP")),
		1000, "goal.face_id"), "face identity type error remains 1000")
	check(contract_has(Validation.validate_level_shape(contract_change(level, ["cubes",0,"cube_id"], &"Floor")),
		1004, "cubes[0].cube_id"), "ordinary cube ID format error remains 1004")
	check(contract_has(Validation.validate_level_shape(contract_change(level, ["worlds",0,"allowed_rotation_intents"], [6])),
		1003, "worlds[0].allowed_rotation_intents[0]"), "non-face enum range error remains 1003")
