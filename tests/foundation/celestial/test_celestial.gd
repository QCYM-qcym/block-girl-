extends SceneTree

const SET_SLOT := 0
const NEXT_SLOT := 1
const PREVIOUS_SLOT := 2
const TOGGLE_BETWEEN := 3

const INVALID_ENUM := 1003
const INVALID_ID := 1004
const DUPLICATE_ID := 1005
const INVALID_CELESTIAL_REFERENCE := 1300
const SLOT_STEP_UNAVAILABLE := 1301

var failures: Array[String] = []
var checks := 0
var integration_complete := false


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not ResourceLoader.exists("res://foundation/contracts/foundation_types.gd"):
		check(false, "INTEGRATION_DEPENDENCY_MISSING: real DATA foundation_types.gd")
		quit(1)
		return
	if "--lighting-only" in arguments:
		if not ResourceLoader.exists("res://foundation/celestial/logical_lighting.gd"):
			check(false, "logical lighting implementation exists")
			quit(1)
			return
		if not has_method("_test_lighting"):
			check(false, "logical lighting tests are installed")
			quit(1)
			return
		var lighting: Script = load("res://foundation/celestial/logical_lighting.gd")
		if not _script_has_method(lighting, "query"):
			check(false, "logical lighting exposes query")
			quit(1)
			return
		call("_test_lighting", lighting)
		_finish()
		return

	if not ResourceLoader.exists("res://foundation/celestial/celestial_rules.gd"):
		check(false, "celestial slot rules implementation exists")
		quit(1)
		return
	var rules: Script = load("res://foundation/celestial/celestial_rules.gd")
	if not _script_has_method(rules, "resolve_slot_request"):
		check(false, "celestial slot rules expose resolve_slot_request")
		quit(1)
		return
	_test_slots(rules)
	if "--slots-only" not in arguments:
		if not ResourceLoader.exists("res://foundation/celestial/logical_lighting.gd"):
			check(false, "logical lighting implementation exists")
		elif not has_method("_test_lighting"):
			check(false, "logical lighting tests are installed")
		else:
			var lighting: Script = load("res://foundation/celestial/logical_lighting.gd")
			if not _script_has_method(lighting, "query"):
				check(false, "logical lighting exposes query")
			else:
				call("_test_lighting", lighting)
				_test_stable_slot_lighting(rules, lighting)
				if "--unit-only" not in arguments:
					_test_integration(lighting)
	_finish()


func _finish() -> void:
	print("CELESTIAL_TESTS: ", checks, " checks; failures=", failures)
	if failures.is_empty() and integration_complete:
		print("FOUNDATION_CELESTIAL_LIGHTING_PASS")
	quit(0 if failures.is_empty() else 1)


func _script_has_method(script: Script, method_name: String) -> bool:
	if script == null:
		return false
	for method in script.get_script_method_list():
		if method.name == method_name:
			return true
	return false


func _fixture() -> Dictionary:
	return {
		"slots": [
			{"slot_id": &"a", "position2": Vector3i(0, 7, 0)},
			{"slot_id": &"b", "position2": Vector3i(7, 0, 0)},
			{"slot_id": &"c", "position2": Vector3i(0, 0, 7)},
		],
		"slot_order": [&"a", &"b", &"c"],
		"wrap": false,
		"initial_slot_id": &"a",
		"edges": [
			{"from_slot_id": &"a", "to_slot_id": &"b"},
			{"from_slot_id": &"b", "to_slot_id": &"a"},
			{"from_slot_id": &"b", "to_slot_id": &"c"},
			{"from_slot_id": &"c", "to_slot_id": &"b"},
		],
	}


func _test_slots(rules: Script) -> void:
	var definition := _fixture()
	var original := definition.duplicate(true)

	var set_forward: Dictionary = rules.resolve_slot_request(
		definition, &"a", SET_SLOT, &"b", StringName()
	)
	check(set_forward == {
		"ok": true,
		"changed": true,
		"next_slot_id": &"b",
		"issues": [],
	}, "SET follows an allowed directed edge")

	var set_current: Dictionary = rules.resolve_slot_request(
		definition, &"b", SET_SLOT, &"b", StringName()
	)
	check(set_current == {
		"ok": true,
		"changed": false,
		"next_slot_id": &"b",
		"issues": [],
	}, "SET current slot succeeds without requiring a self edge")

	var next_middle: Dictionary = rules.resolve_slot_request(
		definition, &"b", NEXT_SLOT, StringName(), StringName()
	)
	check(next_middle.ok and next_middle.changed and next_middle.next_slot_id == &"c",
		"NEXT uses author slot order")
	var previous_middle: Dictionary = rules.resolve_slot_request(
		definition, &"b", PREVIOUS_SLOT, StringName(), StringName()
	)
	check(previous_middle.ok and previous_middle.next_slot_id == &"a",
		"PREVIOUS uses author slot order")

	var no_wrap: Dictionary = rules.resolve_slot_request(
		definition, &"c", NEXT_SLOT, StringName(), StringName()
	)
	_check_rejection(no_wrap, SLOT_STEP_UNAVAILABLE, "NEXT rejects a non-wrapping boundary")

	var toggle: Dictionary = rules.resolve_slot_request(
		definition, &"a", TOGGLE_BETWEEN, &"a", &"b"
	)
	check(toggle.ok and toggle.changed and toggle.next_slot_id == &"b",
		"TOGGLE selects its explicit other endpoint")
	var toggle_reverse: Dictionary = rules.resolve_slot_request(
		definition, &"b", TOGGLE_BETWEEN, &"a", &"b"
	)
	check(toggle_reverse.ok and toggle_reverse.next_slot_id == &"a",
		"TOGGLE works from either explicit endpoint")
	var toggle_outside: Dictionary = rules.resolve_slot_request(
		definition, &"c", TOGGLE_BETWEEN, &"a", &"b"
	)
	_check_rejection(toggle_outside, INVALID_CELESTIAL_REFERENCE,
		"TOGGLE rejects a current slot outside its endpoints")

	var missing_target: Dictionary = rules.resolve_slot_request(
		definition, &"a", SET_SLOT, &"missing", StringName()
	)
	_check_rejection(missing_target, INVALID_CELESTIAL_REFERENCE,
		"SET rejects an unknown slot reference")
	var missing_current: Dictionary = rules.resolve_slot_request(
		definition, &"missing", NEXT_SLOT, StringName(), StringName()
	)
	_check_rejection(missing_current, INVALID_CELESTIAL_REFERENCE,
		"requests reject an unknown current slot")
	var forbidden_edge: Dictionary = rules.resolve_slot_request(
		definition, &"a", SET_SLOT, &"c", StringName()
	)
	_check_rejection(forbidden_edge, SLOT_STEP_UNAVAILABLE,
		"SET rejects a destination without a directed edge")

	var wrapping := _fixture()
	wrapping.wrap = true
	wrapping.edges.append({"from_slot_id": &"c", "to_slot_id": &"a"})
	wrapping.edges.append({"from_slot_id": &"a", "to_slot_id": &"c"})
	var wrapped_next: Dictionary = rules.resolve_slot_request(
		wrapping, &"c", NEXT_SLOT, StringName(), StringName()
	)
	check(wrapped_next.ok and wrapped_next.next_slot_id == &"a",
		"NEXT follows the configured wrap edge")
	var wrapped_previous: Dictionary = rules.resolve_slot_request(
		wrapping, &"a", PREVIOUS_SLOT, StringName(), StringName()
	)
	check(wrapped_previous.ok and wrapped_previous.next_slot_id == &"c",
		"PREVIOUS follows the configured wrap edge")

	var reordered := _fixture()
	reordered.slot_order = [&"c", &"b", &"a"]
	var reordered_next: Dictionary = rules.resolve_slot_request(
		reordered, &"c", NEXT_SLOT, StringName(), StringName()
	)
	check(reordered_next.ok and reordered_next.next_slot_id == &"b",
		"NEXT honors a changed author order")

	var no_slots := _fixture()
	no_slots.slots = []
	no_slots.slot_order = []
	no_slots.initial_slot_id = StringName()
	no_slots.edges = []
	var empty_result: Dictionary = rules.resolve_slot_request(
		no_slots, &"a", NEXT_SLOT, StringName(), StringName()
	)
	_check_rejection(empty_result, INVALID_CELESTIAL_REFERENCE,
		"empty slot definitions cannot resolve a current slot")

	var duplicate_slots := _fixture()
	duplicate_slots.slots.append({"slot_id": &"a", "position2": Vector3i(2, 2, 2)})
	var duplicate_slot_result: Dictionary = rules.resolve_slot_request(
		duplicate_slots, &"a", NEXT_SLOT, StringName(), StringName()
	)
	_check_rejection(duplicate_slot_result, DUPLICATE_ID,
		"duplicate slot IDs reject the full definition")

	var duplicate_order := _fixture()
	duplicate_order.slot_order = [&"a", &"b", &"b"]
	var duplicate_order_result: Dictionary = rules.resolve_slot_request(
		duplicate_order, &"a", NEXT_SLOT, StringName(), StringName()
	)
	_check_rejection(duplicate_order_result, DUPLICATE_ID,
		"duplicate slot order entries reject the full definition")

	var duplicate_edge := _fixture()
	duplicate_edge.edges.append({"from_slot_id": &"a", "to_slot_id": &"b"})
	var duplicate_edge_result: Dictionary = rules.resolve_slot_request(
		duplicate_edge, &"a", NEXT_SLOT, StringName(), StringName()
	)
	_check_rejection(duplicate_edge_result, DUPLICATE_ID,
		"duplicate directed edges reject the full definition")

	var missing_order_reference := _fixture()
	missing_order_reference.slot_order[2] = &"missing"
	var missing_order_result: Dictionary = rules.resolve_slot_request(
		missing_order_reference, &"a", NEXT_SLOT, StringName(), StringName()
	)
	_check_rejection(missing_order_result, INVALID_CELESTIAL_REFERENCE,
		"slot order rejects unknown references")

	var missing_edge_reference := _fixture()
	missing_edge_reference.edges.append({"from_slot_id": &"a", "to_slot_id": &"missing"})
	var missing_edge_result: Dictionary = rules.resolve_slot_request(
		missing_edge_reference, &"a", NEXT_SLOT, StringName(), StringName()
	)
	_check_rejection(missing_edge_result, INVALID_CELESTIAL_REFERENCE,
		"edges reject unknown references")

	var invalid_shape := _fixture()
	invalid_shape.slots[0].slot_id = "a"
	invalid_shape.slots[1].slot_id = &"Bad-ID"
	var invalid_shape_first: Dictionary = rules.resolve_slot_request(
		invalid_shape, &"a", NEXT_SLOT, StringName(), StringName()
	)
	var invalid_shape_second: Dictionary = rules.resolve_slot_request(
		invalid_shape, &"a", NEXT_SLOT, StringName(), StringName()
	)
	check(not invalid_shape_first.ok
		and _issue_codes(invalid_shape_first.issues).has(INVALID_ID)
		and _issue_codes(invalid_shape_first.issues).has(INVALID_CELESTIAL_REFERENCE),
		"definition validation returns all independent shape and reference issues")
	check(invalid_shape_first.issues == invalid_shape_second.issues,
		"definition issues are deterministic and fully ordered")
	_check_issue_shape(invalid_shape_first.issues)

	var independently_malformed := _fixture()
	independently_malformed.erase("slots")
	independently_malformed.wrap = "false"
	independently_malformed.edges.append({"from_slot_id": &"a"})
	var malformed_result: Dictionary = rules.resolve_slot_request(
		independently_malformed, &"a", NEXT_SLOT, StringName(), StringName()
	)
	var malformed_paths := _issue_paths(malformed_result.issues)
	check(malformed_paths.has("slots")
		and malformed_paths.has("wrap")
		and malformed_paths.has("edges[4].to_slot_id")
		and malformed_paths.has("current_slot_id"),
		"definition validation accumulates independent shape errors")
	check(_issues_are_sorted(malformed_result.issues),
		"accumulated issues follow path, code, and entity ID order")

	var bad_slot_record := _fixture()
	bad_slot_record.slots[0].erase("position2")
	bad_slot_record.slots[0]["unexpected"] = true
	var bad_slot_record_result: Dictionary = rules.resolve_slot_request(
		bad_slot_record, &"a", NEXT_SLOT, StringName(), StringName()
	)
	var bad_slot_paths := _issue_paths(bad_slot_record_result.issues)
	check(bad_slot_paths.has("slots[0].position2")
		and bad_slot_paths.has("slots[0].unexpected"),
		"slot records reject missing and unknown fields")

	var malformed_root_keys := _fixture()
	malformed_root_keys[123] = true
	malformed_root_keys[&"unexpected_name"] = false
	var malformed_root_key_result: Dictionary = rules.resolve_slot_request(
		malformed_root_keys, &"a", SET_SLOT, &"a", StringName()
	)
	_check_rejection(malformed_root_key_result, 1000,
		"root records reject non-String field keys without accepting the request")
	var malformed_root_key_details: Array[Dictionary] = []
	for issue in malformed_root_key_result.issues:
		if issue.code == 1000 and issue.path == "<invalid_field_key>":
			malformed_root_key_details.append(issue.details)
	check(malformed_root_key_details == [
		{"key_type": TYPE_INT, "key": 123},
		{"key_type": TYPE_STRING_NAME, "key": "unexpected_name"},
	], "invalid root keys have deterministic contract-safe details")

	var reversed_root_keys := _fixture()
	reversed_root_keys[&"unexpected_name"] = false
	reversed_root_keys[123] = true
	var reversed_root_key_result: Dictionary = rules.resolve_slot_request(
		reversed_root_keys, &"a", SET_SLOT, &"a", StringName()
	)
	check(malformed_root_key_result.issues == reversed_root_key_result.issues,
		"invalid field-key issues do not depend on Dictionary insertion order")

	var malformed_nested_keys := _fixture()
	malformed_nested_keys.slots[0][17] = true
	malformed_nested_keys.slots[0][&"slot_note"] = true
	malformed_nested_keys.edges[0][29] = true
	malformed_nested_keys.edges[0][&"edge_note"] = true
	var malformed_nested_key_result: Dictionary = rules.resolve_slot_request(
		malformed_nested_keys, &"a", SET_SLOT, &"a", StringName()
	)
	_check_rejection(malformed_nested_key_result, 1000,
		"slot and edge records reject non-String field keys")
	var malformed_nested_paths := _issue_paths(malformed_nested_key_result.issues)
	check(malformed_nested_paths.has("slots[0].<invalid_field_key>")
		and malformed_nested_paths.has("edges[0].<invalid_field_key>"),
		"nested invalid field keys report stable schema paths")

	var invalid_toggle: Dictionary = rules.resolve_slot_request(
		definition, &"a", TOGGLE_BETWEEN, &"a", &"a"
	)
	_check_rejection(invalid_toggle, INVALID_CELESTIAL_REFERENCE,
		"TOGGLE rejects identical endpoints")
	var polluted_next: Dictionary = rules.resolve_slot_request(
		definition, &"a", NEXT_SLOT, &"b", StringName()
	)
	_check_rejection(polluted_next, INVALID_CELESTIAL_REFERENCE,
		"NEXT rejects a target field")

	var invalid_operation: Dictionary = rules.resolve_slot_request(
		definition, &"a", 99, StringName(), StringName()
	)
	_check_rejection(invalid_operation, INVALID_ENUM, "unknown celestial operations reject")

	var first_world: Dictionary = rules.resolve_slot_request(
		definition, &"a", NEXT_SLOT, StringName(), StringName()
	)
	var second_world: Dictionary = rules.resolve_slot_request(
		definition, &"a", NEXT_SLOT, StringName(), StringName()
	)
	check(first_world == second_world,
		"identical requests from either world resolve the same shared slot result")
	check(definition == original, "slot resolution leaves the definition input unchanged")


func _check_rejection(result: Dictionary, expected_code: int, label: String) -> void:
	check(result.has("ok")
		and result.has("changed")
		and result.has("next_slot_id")
		and result.has("issues")
		and not result.ok
		and not result.changed
		and result.next_slot_id == StringName()
		and _issue_codes(result.issues).has(expected_code), label)


func _issue_codes(issues: Array) -> Array[int]:
	var codes: Array[int] = []
	for issue in issues:
		if issue is Dictionary and issue.has("code") and issue.code is int:
			codes.append(issue.code)
	return codes


func _issue_paths(issues: Array) -> Array[String]:
	var paths: Array[String] = []
	for issue in issues:
		if issue is Dictionary and issue.has("path") and issue.path is String:
			paths.append(issue.path)
	return paths


func _issues_are_sorted(issues: Array) -> bool:
	for index in range(1, issues.size()):
		var previous: Dictionary = issues[index - 1]
		var current: Dictionary = issues[index]
		var previous_key := "%s\u001f%08d\u001f%s" % [
			previous.path,
			previous.code,
			_string_ids(previous.entity_ids),
		]
		var current_key := "%s\u001f%08d\u001f%s" % [
			current.path,
			current.code,
			_string_ids(current.entity_ids),
		]
		if previous_key > current_key:
			return false
	return true


func _string_ids(ids: Array) -> String:
	var parts: Array[String] = []
	for id in ids:
		parts.append(String(id))
	return "\u001f".join(parts)


func _check_issue_shape(issues: Array) -> void:
	for issue in issues:
		check(issue is Dictionary
			and issue.keys().size() == 6
			and issue.has_all(["code", "severity", "path", "entity_ids", "message", "details"])
			and issue.severity == 0
			and issue.path is String
			and issue.entity_ids is Array
			and issue.message is String
			and issue.details is Dictionary,
			"validation issues use the complete contract shape")

func _light_anchor() -> Dictionary:
	return {"face_id": &"floor/TOP", "layer": 0, "position2": Vector3i(0, 1, 0), "frame": {"u": Vector3i.RIGHT, "v": Vector3i(0, 0, -1), "normal": Vector3i.UP}}

func _light_cube(id: StringName, center: Vector3i, layer: int = 0, occludes: bool = true) -> Dictionary:
	return {"cube_id": id, "layer": layer, "center2": center, "orientation": 0, "occludes_light": occludes}

func _light_expect(result: Dictionary, state: int, reason: StringName, id: StringName, label: String) -> void:
	check(result.get("ok") == true and result.get("light_state") == state and result.get("reason") == reason and result.get("occluder_id") == id and result.get("issues") == [], label)

func _light_error(result: Dictionary, code: int, label: String) -> void:
	var issues: Array = result.get("issues", [])
	check(result.get("ok") == false and result.get("light_state") == null and result.get("reason") == &"INVALID" and result.get("occluder_id") == &"" and not issues.is_empty() and issues[0].get("code") == code, label)
	if not issues.is_empty():
		check(issues[0].has_all(["code", "severity", "path", "entity_ids", "message", "details"]) and issues[0].severity == 0, label + " issue contract")

func _test_lighting(lighting) -> void:
	var anchor := _light_anchor()
	var slot := {"slot_id": &"a", "position2": Vector3i(0, 7, 0)}
	var cubes: Array[Dictionary] = []
	_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "front clear")
	cubes.append(_light_cube(&"blocker", Vector3i(0, 4, 0)))
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"OCCLUDED", &"blocker", "same world blocks")
	cubes[0].layer = 1
	_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "other world ignored")
	anchor.layer = 1
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"OCCLUDED", &"blocker", "inner world blocks itself")
	anchor.layer = 0
	cubes[0].layer = 0
	cubes[0].occludes_light = false
	_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "transparent cube ignored")
	cubes.clear()
	slot.position2 = Vector3i(4, 1, 0)
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"BACK_OR_TANGENT", &"", "tangent is shadow")
	slot.position2 = Vector3i(0, -7, 0)
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"BACK_OR_TANGENT", &"", "back is shadow")
	slot.position2 = anchor.position2
	_light_error(lighting.query(anchor, slot, cubes), 1302, "coincident source invalid")
	slot.position2 = Vector3i(0, 7, 0)
	cubes.append(_light_cube(&"floor", Vector3i.ZERO))
	_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "receiver endpoint t=1 excluded")
	cubes.append(_light_cube(&"beyond", Vector3i(0, -4, 0)))
	cubes.append(_light_cube(&"behind_source", Vector3i(0, 10, 0)))
	_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "segment does not extend past endpoints")
	cubes = [_light_cube(&"near", Vector3i(0, 6, 0))]
	_light_error(lighting.query(anchor, slot, cubes), 1302, "source on closed boundary invalid")
	slot.position2 = Vector3i(0, 6, 0)
	_light_error(lighting.query(anchor, slot, cubes), 1302, "source inside invalid")
	cubes[0].layer = 1
	_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "source inside foreign cube allowed")
	cubes[0].layer = 0
	cubes[0].occludes_light = false
	_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "source inside transparent cube allowed")
	# The diagonal touches only (1,3,0) of [-1,1]x[3,5]x[-1,1], at t=1/2.
	slot.position2 = Vector3i(2, 5, 0)
	cubes = [_light_cube(&"corner", Vector3i(0, 4, 0))]
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"OCCLUDED", &"corner", "single point grazing counts")
	slot.position2 = Vector3i(1, 7, 0)
	anchor.position2 = Vector3i(1, 1, 0)
	cubes = [_light_cube(&"edge", Vector3i(2, 4, 0))]
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"OCCLUDED", &"edge", "parallel ray along closed face blocks")
	anchor = _light_anchor()
	slot.position2 = Vector3i(0, 11, 0)
	cubes = [_light_cube(&"a_far", Vector3i(0, 4, 0)), _light_cube(&"z_near", Vector3i(0, 8, 0))]
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"OCCLUDED", &"z_near", "nearest is measured from source")
	var saved_cubes := cubes.duplicate(true)
	var saved_anchor := anchor.duplicate(true)
	var saved_slot := slot.duplicate(true)
	var first: Dictionary = lighting.query(anchor, slot, cubes)
	check(cubes == saved_cubes and anchor == saved_anchor and slot == saved_slot, "query preserves all input values")
	cubes.reverse()
	check(lighting.query(anchor, slot, cubes) == first, "permutation preserves nearest result")
	# Two legal nonoverlapping cubes touch the x=1 ray at the same t.
	anchor.position2 = Vector3i(1, 1, 0)
	slot.position2 = Vector3i(1, 7, 0)
	cubes = [_light_cube(&"z_tie", Vector3i(0, 4, 0)), _light_cube(&"a_tie", Vector3i(2, 4, 0))]
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"OCCLUDED", &"a_tie", "exact tie breaks by cube ID")
	cubes.reverse()
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"OCCLUDED", &"a_tie", "tie independent of order")
	# Differences must use int64 components, not overflowing Vector3i subtraction.
	anchor = _light_anchor()
	anchor.position2 = Vector3i(0, -2147483647, 0)
	slot.position2 = Vector3i(0, 2147483647, 0)
	cubes.clear()
	_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "32-bit coordinate difference remains exact")
	cubes = [_light_cube(&"wide", Vector3i.ZERO)]
	_light_expect(lighting.query(anchor, slot, cubes), 1, &"OCCLUDED", &"wide", "large parallel interval remains exact")
	anchor.position2 = Vector3i(-2147483646, -2147483647, 0)
	slot.position2 = Vector3i(2147483647, 2147483647, 0)
	cubes = [_light_cube(&"extreme", Vector3i(-2147483646, -2147483644, 0))]
	_light_error(lighting.query(anchor, slot, cubes), 1105, "rational cross product overflow is explicit")
	anchor = _light_anchor()
	slot.position2 = Vector3i(0, 7, 0)
	cubes.clear()
	anchor.frame.normal = Vector3i(0, 2, 0)
	_light_error(lighting.query(anchor, slot, cubes), 1102, "nonunit frame rejected")
	anchor = _light_anchor()
	anchor.erase("position2")
	_light_error(lighting.query(anchor, slot, cubes), 1104, "malformed anchor rejected without crash")
	anchor = _light_anchor()
	slot.position2 = Vector3(0, 7, 0)
	_light_error(lighting.query(anchor, slot, cubes), 1302, "floating source rejected")
	_test_lighting_axes(lighting)

func _test_lighting_axes(lighting: Script) -> void:
	# Explicit contract frames exercise positive/negative rays on all three axes.
	var frames := [
		[Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,0,1)],
		[Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,0,-1)],
		[Vector3i(0,0,1), Vector3i(0,1,0), Vector3i(-1,0,0)],
		[Vector3i(0,0,-1), Vector3i(0,1,0), Vector3i(1,0,0)],
		[Vector3i(1,0,0), Vector3i(0,0,-1), Vector3i(0,1,0)],
		[Vector3i(1,0,0), Vector3i(0,0,1), Vector3i(0,-1,0)]]
	var symbols := ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	for index in range(6):
		var normal: Vector3i = frames[index][2]
		var anchor := {"face_id": StringName("floor/" + symbols[index]), "layer": 0, "position2": normal, "frame": {"u": frames[index][0], "v": frames[index][1], "normal": normal}}
		var slot := {"slot_id": &"a", "position2": normal * 7}
		var cubes: Array[Dictionary] = [_light_cube(&"floor", Vector3i.ZERO)]
		_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "all-axis receiver endpoint " + symbols[index])
		cubes.append(_light_cube(&"blocker", normal * 4))
		_light_expect(lighting.query(anchor, slot, cubes), 1, &"OCCLUDED", &"blocker", "all-axis blocker " + symbols[index])
	var anchor := _light_anchor()
	anchor.position2 = Vector3i(0, -2147483647, 0)
	var slot := {"slot_id": &"a", "position2": Vector3i(0, 2147483647, 0)}
	var cubes: Array[Dictionary] = [_light_cube(&"floor", Vector3i(0, -2147483648, 0))]
	_light_expect(lighting.query(anchor, slot, cubes), 0, &"FRONT_CLEAR", &"", "AABB lower bound below int32 remains exact")


func _test_stable_slot_lighting(rules: Script, lighting: Script) -> void:
	var definition := _fixture()
	var slots: Dictionary = {}
	for slot in definition.slots:
		slots[slot.slot_id] = slot
	# One committed record is consumed by both worlds; no Sun/Moon state copies.
	var celestial_state := {"slot_id": &"a"}
	var state_before := celestial_state.duplicate(true)
	var cubes: Array[Dictionary] = []
	for layer in [0, 1]:
		var anchor := _light_anchor()
		anchor.layer = layer
		_light_expect(lighting.query(anchor, slots[celestial_state.slot_id], cubes), 0, &"FRONT_CLEAR", &"", "shared committed A lights world %d" % layer)
	var request: Dictionary = rules.resolve_slot_request(definition, celestial_state.slot_id, SET_SLOT, &"b", &"")
	check(request.ok and request.changed and request.next_slot_id == &"b", "Slot request produces B candidate")
	check(celestial_state == state_before, "request resolution leaves committed A unchanged")
	# This fixture selects the next stable input. It does not emulate a scheduler.
	celestial_state = {"slot_id": request.next_slot_id}
	for layer in [0, 1]:
		var anchor := _light_anchor()
		anchor.layer = layer
		_light_expect(lighting.query(anchor, slots[celestial_state.slot_id], cubes), 1, &"BACK_OR_TANGENT", &"", "shared committed B updates world %d" % layer)
		check(celestial_state == {"slot_id": &"b"}, "world query preserves the same single committed Slot")
	request = rules.resolve_slot_request(definition, celestial_state.slot_id, PREVIOUS_SLOT, &"", &"")
	check(request.ok and request.next_slot_id == &"a", "previous request returns A candidate")
	celestial_state = {"slot_id": request.next_slot_id}
	var anchor := _light_anchor()
	_light_expect(lighting.query(anchor, slots[celestial_state.slot_id], cubes), 0, &"FRONT_CLEAR", &"", "return to A recomputes LIT without stale B result")
	cubes = [_light_cube(&"moving_blocker", Vector3i(0, 4, 0))]
	var blocked: Dictionary = lighting.query(anchor, slots[celestial_state.slot_id], cubes)
	_light_expect(blocked, 1, &"OCCLUDED", &"moving_blocker", "stable blocker snapshot is SHADOW")
	var moved_cubes: Array[Dictionary] = cubes.duplicate(true)
	moved_cubes[0].center2 = Vector3i(4, 4, 0)
	var clear: Dictionary = lighting.query(anchor, slots[celestial_state.slot_id], moved_cubes)
	_light_expect(clear, 0, &"FRONT_CLEAR", &"", "moving blocker off the finite ray recomputes LIT")
	check(cubes[0].center2 == Vector3i(0, 4, 0), "old stable blocker snapshot is preserved")
	check(lighting.query(anchor, slots[celestial_state.slot_id], cubes) == blocked, "old stable input remains reproducible after new snapshot query")
	check(lighting.query(anchor, slots[celestial_state.slot_id], moved_cubes) == clear, "new stable input repeats exactly")
	# At t=1/2 the ray touches (1,3,0). Some face points are clear,
	# but the sole FaceAnchor sample is blocked, so the result is SHADOW.
	var grazing_slot := {"slot_id": &"sample", "position2": Vector3i(2, 5, 0)}
	cubes = [_light_cube(&"sample_blocker", Vector3i(0, 4, 0))]
	var sampled: Dictionary = lighting.query(anchor, grazing_slot, cubes)
	_light_expect(sampled, 1, &"OCCLUDED", &"sample_blocker", "only FaceAnchor decides lighting, never a face-area percentage")
	for result in [blocked, clear, sampled]:
		check(result.ok and typeof(result.light_state) == TYPE_INT and result.light_state in [0, 1], "successful lighting has only LIT or SHADOW, never PARTIAL")


func _integration_level() -> Dictionary:
	var faces: Array[Dictionary] = []
	var symbols := ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
	for cube_id in [&"floor", &"foreign_blocker"]:
		for face in range(6):
			faces.append({"face_id": StringName(String(cube_id) + "/" + symbols[face]), "cube_id": cube_id, "face": face, "walkable": cube_id == &"floor" and face == 4, "shift_exit_blocked": false, "shift_entry_blocked": false, "mechanism_ids": []})
	return {
		"schema_version": 1, "contract_version": "foundation.contract.v1", "orientation_version": "cube24.v1", "rule_version": "foundation.rules.v1",
		"level_id": &"celestial_integration", "content_hash": "0".repeat(64), "cell_size": 1,
		"worlds": [
			{"layer": 0, "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0, 9], "allowed_rotation_deltas": [9, 12], "allowed_rotation_intents": []},
			{"layer": 1, "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0], "allowed_rotation_deltas": [], "allowed_rotation_intents": []}],
		"cubes": [
			{"cube_id": &"floor", "layer": 0, "center2": Vector3i(2, 0, 0), "orientation": 0, "group_id": &"", "occludes_light": true, "tags": []},
			{"cube_id": &"foreign_blocker", "layer": 1, "center2": Vector3i(2, 4, 0), "orientation": 0, "group_id": &"", "occludes_light": true, "tags": []}],
		"faces": faces, "groups": [],
		"celestial": {"slots": [{"slot_id": &"a", "position2": Vector3i(2, 7, 0)}], "slot_order": [&"a"], "wrap": false, "initial_slot_id": &"a", "edges": []},
		"mechanisms": [], "face_transitions": [], "shift_compatibilities": [0],
		"spawn": {"location": {"layer": 0, "cube_id": &"floor", "face": 4}, "orientation": 0},
		"goal": {"face_id": &"floor/TOP", "required_flags": []}, "flag_definitions": [], "build_info": {}}

func _integration_anchor(snapshot: Dictionary) -> Dictionary:
	if not snapshot.ok:
		check(false, "Spatial failed before anchor consumption: " + str(snapshot.issues))
		return {}
	for anchor in snapshot.value.anchors:
		if anchor.face_id == &"floor/TOP":
			return anchor
	check(false, "real snapshot provides floor/TOP")
	return {}

func _integration_query(lighting: Script, snapshot: Dictionary, slot: Dictionary) -> Dictionary:
	# Test adapter only: a failed Spatial result never reaches the light query.
	if not snapshot.ok:
		check(false, "Spatial failed before lighting consumption: " + str(snapshot.issues))
		return {"ok": false, "light_state": null, "reason": &"INVALID", "occluder_id": &"", "issues": snapshot.issues.duplicate(true)}
	var cubes: Array[Dictionary] = []
	cubes.assign(snapshot.value.cubes)
	return lighting.query(_integration_anchor(snapshot), slot, cubes)

func _test_integration(lighting: Script) -> void:
	var paths := ["res://foundation/contracts/contract_records.gd", "res://foundation/contracts/contract_validation.gd", "res://foundation/orientation/discrete_orientation.gd", "res://foundation/spatial/surface_geometry.gd", "res://foundation/spatial/spatial_validation.gd"]
	var modules: Array[Script] = []
	for path in paths:
		if not ResourceLoader.exists(path):
			check(false, "INTEGRATION_DEPENDENCY_MISSING: " + path)
			return
		var module: Script = load(path)
		if module == null or not module.can_instantiate():
			check(false, "INTEGRATION_DEPENDENCY_INVALID: " + path)
			return
		modules.append(module)
	var records: Script = modules[0]
	var data: Script = modules[1]
	var spatial: Script = modules[3]
	var spatial_validation: Script = modules[4]
	var level := _integration_level()
	var shape_issues: Array = data.validate_level_shape(level)
	check(shape_issues.is_empty(), "real DATA accepts integration level: " + str(shape_issues))
	if not shape_issues.is_empty():
		return
	var state: Dictionary = records.initial_state(level)
	shape_issues = data.validate_state_shape(level, state)
	check(shape_issues.is_empty(), "real DATA accepts integration initial state: " + str(shape_issues))
	if not shape_issues.is_empty():
		return
	var original_level := level.duplicate(true)
	var original_state := state.duplicate(true)
	var slot: Dictionary = level.celestial.slots[0]
	var snapshot: Dictionary = spatial.snapshot(level, state)
	var faces: Array[Dictionary] = []
	faces.assign(level.faces)
	check(spatial_validation.validate_snapshot(snapshot, faces).is_empty(), "real snapshot is a valid stable geometry")
	var anchor := _integration_anchor(snapshot)
	check(anchor.get("position2") == Vector3i(2, 1, 0) and anchor.get("frame", {}).get("normal") == Vector3i.UP, "initial real TOP anchor golden")
	_light_expect(_integration_query(lighting, snapshot, slot), 0, &"FRONT_CLEAR", &"", "real snapshot foreign blocker ignored")
	check(level == original_level and state == original_state, "real snapshot and lighting leave definition/state unchanged")
	var changed_level := level.duplicate(true)
	changed_level.cubes[1].layer = 0
	check(data.validate_level_shape(changed_level).is_empty(), "same-world fixture passes DATA")
	var blocked: Dictionary = spatial.snapshot(changed_level, state)
	_light_expect(_integration_query(lighting, blocked, slot), 1, &"OCCLUDED", &"foreign_blocker", "real snapshot same-world blocker occludes")
	changed_level = level.duplicate(true)
	changed_level.cubes[0].orientation = 9
	check(data.validate_level_shape(changed_level).is_empty(), "rotated local cube fixture passes DATA")
	var cube_rotated: Dictionary = spatial.snapshot(changed_level, state)
	anchor = _integration_anchor(cube_rotated)
	check(anchor.get("position2") == Vector3i(1, 0, 0) and anchor.get("frame", {}).get("normal") == Vector3i.LEFT, "local cube Z+ rotates TOP frame at fixed center")
	_light_expect(_integration_query(lighting, cube_rotated, slot), 1, &"BACK_OR_TANGENT", &"", "local cube rotation changes incidence")
	var rotated_state := state.duplicate(true)
	rotated_state.world_orientations[0] = 9
	check(data.validate_state_shape(level, rotated_state).is_empty(), "world-rotated state passes DATA")
	var world_rotated: Dictionary = spatial.snapshot(level, rotated_state)
	anchor = _integration_anchor(world_rotated)
	check(anchor.get("position2") == Vector3i(-1, 2, 0) and anchor.get("frame", {}).get("normal") == Vector3i.LEFT, "world Z+ rotates center and TOP frame")
	_light_expect(_integration_query(lighting, world_rotated, slot), 1, &"BACK_OR_TANGENT", &"", "fixed celestial source does not follow rotating world")
	check(slot.position2 == Vector3i(2, 7, 0) and rotated_state.celestial.slot_id == &"a", "source position and single Slot unchanged after rotations")
	check(spatial_validation.validate_snapshot(cube_rotated, faces).is_empty() and spatial_validation.validate_snapshot(world_rotated, faces).is_empty(), "rotated real snapshots validate")
	var reversed_level := original_level.duplicate(true)
	reversed_level.cubes.reverse()
	reversed_level.faces.reverse()
	reversed_level.worlds.reverse()
	check(spatial.snapshot(reversed_level, state) == snapshot, "real snapshot independent of definition array order")
	var snapshot_before := snapshot.duplicate(true)
	var reversed_snapshot := snapshot.duplicate(true)
	reversed_snapshot.value.cubes.reverse()
	check(_integration_query(lighting, reversed_snapshot, slot) == _integration_query(lighting, snapshot, slot), "real lighting independent of snapshot array order")
	check(snapshot == snapshot_before and level == original_level and state == original_state, "integration queries preserve nested snapshot and inputs")
	integration_complete = true
