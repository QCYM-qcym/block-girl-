extends RefCounted
## Pure structural boundary. No geometry, composition, permissions or solvability.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const Code = Types.ValidationCode
const QUARTER_TURNS = [2, 3, 22, 18, 9, 12]
const FACE_NAMES = ["FRONT", "BACK", "LEFT", "RIGHT", "TOP", "BOTTOM"]
const SCHEMAS = {
	"level": {
		"schema_version": "int", "contract_version": "string", "orientation_version": "string",
		"rule_version": "string", "level_id": "id", "content_hash": "hash", "cell_size": "int",
		"worlds": "array:world", "cubes": "array:cube", "faces": "array:face_record",
		"groups": "array:group", "celestial": "celestial_definition", "mechanisms": "array:mechanism",
		"face_transitions": "array:transition", "shift_compatibilities": "array:compatibility",
		"spawn": "player", "goal": "goal", "flag_definitions": "array:flag", "build_info": "metadata",
	},
	"world": {"layer": "layer", "pivot2": "coordinate", "initial_orientation": "orientation",
		"allowed_states": "array:orientation", "allowed_rotation_deltas": "array:quarter",
		"allowed_rotation_intents": "array:intent"},
	"cube": {"cube_id": "id", "layer": "layer", "center2": "center", "orientation": "orientation",
		"group_id": "optional_id", "occludes_light": "bool", "tags": "array:name"},
	"face_record": {"face_id": "face_id", "cube_id": "id", "face": "face", "walkable": "bool",
		"shift_exit_blocked": "bool", "shift_entry_blocked": "bool", "mechanism_ids": "array:id"},
	"group": {"group_id": "id", "layer": "layer", "cube_ids": "array:id", "pivot2": "coordinate",
		"initial_orientation": "orientation", "allowed_states": "array:orientation",
		"allowed_rotation_deltas": "array:quarter", "edges": "array:rotation_edge"},
	"rotation_edge": {"from_orientation": "orientation", "rotation_delta": "quarter", "to_orientation": "orientation"},
	"celestial_definition": {"slots": "array:slot", "slot_order": "array:id", "wrap": "bool",
		"initial_slot_id": "id", "edges": "array:slot_edge"},
	"slot": {"slot_id": "id", "position2": "coordinate"},
	"slot_edge": {"from_slot_id": "id", "to_slot_id": "id"},
	"mechanism": {"mechanism_id": "id", "face_id": "face_id", "trigger": "trigger", "action": "action",
		"priority": "int", "initial_state": "name", "allowed_states": "array:name"},
	"transition": {"transition_id": "id", "source_face_id": "face_id", "target_face_id": "face_id",
		"entry_axis": "axis", "exit_axis": "axis", "rotation_steps": "array:quarter", "required_flags": "array:id"},
	"location": {"layer": "layer", "cube_id": "id", "face": "face"},
	"player": {"location": "location", "orientation": "orientation"},
	"goal": {"face_id": "face_id", "required_flags": "array:id"},
	"flag": {"flag_id": "id", "initial_value": "bool"},
	"celestial_state": {"slot_id": "id"},
	"state": {"player": "player", "world_orientations": "array:orientation", "celestial": "celestial_state",
		"group_orientations": "map:orientation", "mechanism_states": "map:name", "level_flags": "map:bool"},
}
const ACTION_FIELDS = {
	Types.PuzzleActionKind.MOVE: {"kind": "kind", "face_axis": "axis"},
	Types.PuzzleActionKind.SHIFT_WORLD: {"kind": "kind"},
	Types.PuzzleActionKind.ROTATE_SURFACE: {"kind": "kind", "rotation_delta": "quarter"},
	Types.PuzzleActionKind.ROTATE_INNER: {"kind": "kind", "rotation_delta": "quarter"},
	Types.PuzzleActionKind.USE_FACE_TRANSITION: {"kind": "kind", "transition_id": "id"},
	Types.PuzzleActionKind.TRIGGER_MECHANISM: {"kind": "kind", "mechanism_id": "id"},
	Types.PuzzleActionKind.LOCAL_GROUP_ROTATE: {"kind": "kind", "group_id": "id", "rotation_delta": "quarter", "mechanism_id": "id"},
	Types.PuzzleActionKind.MOVE_CELESTIAL: {"kind": "kind", "celestial_op": "operation", "target_slot_id": "optional_id",
		"alternate_slot_id": "optional_id", "mechanism_id": "id"},
}


static func validate_level_shape(level: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	_check_value(level, "level", "", issues)
	# Relationship checks only consume fully typed records, never malformed input.
	if not issues.is_empty():
		return _sorted(issues)
	for field in {"schema_version": 1, "contract_version": "foundation.contract.v1",
		"orientation_version": "cube24.v1", "rule_version": "foundation.rules.v1"}:
		var expected = {"schema_version": 1, "contract_version": "foundation.contract.v1",
			"orientation_version": "cube24.v1", "rule_version": "foundation.rules.v1"}[field]
		if level[field] != expected:
			_issue(issues, Code.VERSION_MISMATCH, field, "Unsupported contract version.")
	if level.cell_size != 1:
		_issue(issues, Code.OFF_LATTICE, "cell_size", "Cell size must be one logical unit.")
	var indexes := _level_indexes(level, issues)
	_validate_worlds(level.worlds, issues)
	_validate_faces(level, indexes, issues)
	_validate_groups(level, indexes, issues)
	_validate_celestial(level.celestial, indexes.slots, issues)
	_validate_mechanisms(level, indexes, issues)
	_validate_transitions(level.face_transitions, indexes, issues)
	_check_player(level.spawn, indexes, "spawn", issues)
	_reference(level.goal.face_id, indexes.faces, "goal.face_id", issues)
	_references(level.goal.required_flags, indexes.flags, "goal.required_flags", issues)
	_unique(level.shift_compatibilities, "shift_compatibilities", issues)
	if level.shift_compatibilities.is_empty():
		_issue(issues, Code.INVALID_ENUM, "shift_compatibilities", "At least one face compatibility is required.")
	return _sorted(issues)


static func validate_state_shape(level: Dictionary, state: Dictionary) -> Array[Dictionary]:
	var issues := validate_level_shape(level)
	if not issues.is_empty():
		return issues
	_check_value(state, "state", "", issues)
	if not issues.is_empty():
		return _sorted(issues)
	var indexes := _level_indexes(level, issues)
	_check_player(state.player, indexes, "player", issues)
	if state.world_orientations.size() != 2:
		_issue(issues, Code.INVALID_REFERENCE, "world_orientations", "Exactly two world orientations are required.")
	else:
		for world in level.worlds:
			_member(state.world_orientations[world.layer], world.allowed_states,
				_index_path("world_orientations", world.layer), Code.INVALID_ORIENTATION, issues)
	_reference(state.celestial.slot_id, indexes.slots, "celestial.slot_id", issues, Code.INVALID_CELESTIAL_REFERENCE)
	_check_map_coverage(state.group_orientations, indexes.groups, "group_orientations", issues)
	for id in state.group_orientations:
		if indexes.groups.has(id):
			_member(state.group_orientations[id], indexes.groups[id].allowed_states,
				_field_path("group_orientations", id), Code.INVALID_ORIENTATION, issues)
	_check_map_coverage(state.mechanism_states, indexes.mechanisms, "mechanism_states", issues)
	for id in state.mechanism_states:
		if indexes.mechanisms.has(id):
			_member(state.mechanism_states[id], indexes.mechanisms[id].allowed_states,
				_field_path("mechanism_states", id), Code.INVALID_REFERENCE, issues)
	_check_map_coverage(state.level_flags, indexes.flags, "level_flags", issues)
	return _sorted(issues)


static func validate_action_shape(level: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var issues := validate_level_shape(level)
	if not issues.is_empty():
		return issues
	_check_action_fields(action, "", issues)
	if issues.is_empty():
		_check_action_references(action, _level_indexes(level, issues), "", issues)
	return _sorted(issues)


static func _check_value(value: Variant, descriptor: String, path: String, issues: Array[Dictionary]) -> void:
	if SCHEMAS.has(descriptor):
		_check_record(value, SCHEMAS[descriptor], path, issues)
		return
	if descriptor == "action":
		_check_action_fields(value, path, issues)
		return
	if descriptor.begins_with("array:"):
		if not _type(value, TYPE_ARRAY, path, issues):
			return
		for i in value.size():
			_check_value(value[i], descriptor.substr(6), _index_path(path, i), issues)
		return
	if descriptor.begins_with("map:") or descriptor == "metadata":
		if not _type(value, TYPE_DICTIONARY, path, issues):
			return
		for key in value:
			var item_path := _field_path(path, key)
			if descriptor == "metadata":
				_type(key, TYPE_STRING, item_path, issues)
				_type(value[key], TYPE_STRING, item_path, issues)
			else:
				_check_value(key, "id", item_path, issues)
				_check_value(value[key], descriptor.substr(4), item_path, issues)
		return
	var expected_type := TYPE_INT
	match descriptor:
		"string", "hash": expected_type = TYPE_STRING
		"id", "optional_id", "face_id", "name", "trigger": expected_type = TYPE_STRING_NAME
		"coordinate", "center": expected_type = TYPE_VECTOR3I
		"bool": expected_type = TYPE_BOOL
	if not _type(value, expected_type, path, issues):
		return
	match descriptor:
		"id", "optional_id":
			if not (descriptor == "optional_id" and value == &"") and not _valid_id(String(value)):
				_issue(issues, Code.INVALID_ID, path, "Expected a lowercase identifier.")
		"face_id":
			var parts := String(value).split("/")
			if parts.size() != 2 or not _valid_id(parts[0]) or not parts[1] in FACE_NAMES:
				_issue(issues, Code.INVALID_FACE, path, "Expected cube_id/FACE_SYMBOL.")
		"hash":
			if value.length() != 64 or not _only_characters(value, "0123456789abcdef"):
				_issue(issues, Code.INVALID_ID, path, "Expected a lowercase SHA-256 digest.")
		"center":
			if value.x % 2 != 0 or value.y % 2 != 0 or value.z % 2 != 0:
				_issue(issues, Code.OFF_LATTICE, path, "Cube center coordinates must all be even.")
		"orientation":
			if value < 0 or value > 23:
				_issue(issues, Code.INVALID_ORIENTATION, path, "Orientation must be in cube24.v1 range 0..23.")
		"quarter":
			_member(value, QUARTER_TURNS, path, Code.INVALID_ORIENTATION, issues)
		"trigger": _member(value, [&"ENTER", &"USE"], path, Code.INVALID_ENUM, issues)
		"layer", "compatibility": _enum_range(value, 2, path, issues)
		"face":
			if value < 0 or value >= 6:
				_issue(issues, Code.INVALID_FACE, path, "Face must be in the local face range 0..5.")
		"intent": _enum_range(value, 6, path, issues)
		"axis", "operation": _enum_range(value, 4, path, issues)
		"kind": _enum_range(value, 8, path, issues)


static func _check_record(value: Variant, fields: Dictionary, path: String, issues: Array[Dictionary]) -> void:
	if not _type(value, TYPE_DICTIONARY, path, issues):
		return
	for key in value:
		var key_path := _field_path(path, key)
		if typeof(key) != TYPE_STRING:
			_issue(issues, Code.INVALID_TYPE, key_path, "Record field keys must be String.")
		elif not fields.has(key):
			_issue(issues, Code.UNKNOWN_FIELD, key_path, "Field is not part of this record.")
	for field in fields:
		var field_path := _field_path(path, field)
		if not value.has(field):
			_issue(issues, Code.MISSING_FIELD, field_path, "Required field is missing.")
		else:
			_check_value(value[field], fields[field], field_path, issues)


static func _check_action_fields(value: Variant, path: String, issues: Array[Dictionary]) -> void:
	if not _type(value, TYPE_DICTIONARY, path, issues):
		return
	if value.has("kind") and typeof(value.kind) == TYPE_INT and ACTION_FIELDS.has(value.kind):
		_check_record(value, ACTION_FIELDS[value.kind], path, issues)
	else:
		_check_record(value, {"kind": "kind"}, path, issues)


static func _level_indexes(level: Dictionary, issues: Array[Dictionary]) -> Dictionary:
	return {
		"cubes": _index_records(level.cubes, "cube_id", "cubes", issues),
		"faces": _index_records(level.faces, "face_id", "faces", issues),
		"groups": _index_records(level.groups, "group_id", "groups", issues),
		"slots": _index_records(level.celestial.slots, "slot_id", "celestial.slots", issues),
		"mechanisms": _index_records(level.mechanisms, "mechanism_id", "mechanisms", issues),
		"transitions": _index_records(level.face_transitions, "transition_id", "face_transitions", issues),
		"flags": _index_records(level.flag_definitions, "flag_id", "flag_definitions", issues),
	}


static func _index_records(records: Array, id_field: String, path: String, issues: Array[Dictionary]) -> Dictionary:
	var result := {}
	for i in records.size():
		var id: StringName = records[i][id_field]
		if result.has(id):
			_issue(issues, Code.DUPLICATE_ID, _field_path(_index_path(path, i), id_field), "Identifier is repeated.", [id])
		else:
			result[id] = records[i]
	return result


static func _validate_worlds(worlds: Array, issues: Array[Dictionary]) -> void:
	var layers := []
	for i in worlds.size():
		var path := _index_path("worlds", i)
		if worlds[i].layer in layers:
			_issue(issues, Code.DUPLICATE_ID, path + ".layer", "World layer is repeated.")
		layers.append(worlds[i].layer)
		_check_orientation_domain(worlds[i], path, issues)
	for layer in [Types.WorldLayer.SURFACE, Types.WorldLayer.INNER]:
		if not layer in layers:
			_issue(issues, Code.INVALID_REFERENCE, "worlds", "Each world layer requires exactly one definition.")


static func _check_orientation_domain(record: Dictionary, path: String, issues: Array[Dictionary]) -> void:
	_member(record.initial_orientation, record.allowed_states, path + ".initial_orientation", Code.INVALID_ORIENTATION, issues)
	_unique(record.allowed_states, path + ".allowed_states", issues)
	_unique(record.allowed_rotation_deltas, path + ".allowed_rotation_deltas", issues)


static func _validate_faces(level: Dictionary, indexes: Dictionary, issues: Array[Dictionary]) -> void:
	var cube_faces := {}
	for i in level.faces.size():
		var face: Dictionary = level.faces[i]
		var path := _index_path("faces", i)
		_reference(face.cube_id, indexes.cubes, path + ".cube_id", issues)
		if face.face_id != StringName(String(face.cube_id) + "/" + FACE_NAMES[face.face]):
			_issue(issues, Code.INVALID_FACE, path + ".face_id", "Face identity must match its cube and local face.", [face.face_id])
		if not cube_faces.has(face.cube_id):
			cube_faces[face.cube_id] = []
		cube_faces[face.cube_id].append(face.face)
		_references(face.mechanism_ids, indexes.mechanisms, path + ".mechanism_ids", issues)
		for j in face.mechanism_ids.size():
			var id: StringName = face.mechanism_ids[j]
			if indexes.mechanisms.has(id) and indexes.mechanisms[id].face_id != face.face_id:
				_issue(issues, Code.INVALID_REFERENCE, _index_path(path + ".mechanism_ids", j), "Mechanism belongs to another face.", [id])
	for i in level.cubes.size():
		var id: StringName = level.cubes[i].cube_id
		var found: Array = cube_faces.get(id, [])
		var complete: bool = found.size() == 6
		for face in 6:
			complete = complete and face in found
		if not complete:
			_issue(issues, Code.INVALID_FACE, _index_path("cubes", i) + ".cube_id", "Cube must have exactly its six local faces.", [id])


static func _validate_groups(level: Dictionary, indexes: Dictionary, issues: Array[Dictionary]) -> void:
	for i in level.cubes.size():
		var cube: Dictionary = level.cubes[i]
		if cube.group_id == &"":
			continue
		var path := _index_path("cubes", i) + ".group_id"
		if _reference(cube.group_id, indexes.groups, path, issues):
			var group: Dictionary = indexes.groups[cube.group_id]
			if cube.layer != group.layer or not cube.cube_id in group.cube_ids:
				_issue(issues, Code.INVALID_GROUP, path, "Cube and group ownership indexes must agree in one layer.", [cube.cube_id, cube.group_id])
	for i in level.groups.size():
		var group: Dictionary = level.groups[i]
		var path := _index_path("groups", i)
		_check_orientation_domain(group, path, issues)
		_references(group.cube_ids, indexes.cubes, path + ".cube_ids", issues)
		for j in group.cube_ids.size():
			var id: StringName = group.cube_ids[j]
			if indexes.cubes.has(id):
				var cube: Dictionary = indexes.cubes[id]
				if cube.layer != group.layer or cube.group_id != group.group_id:
					_issue(issues, Code.INVALID_GROUP, _index_path(path + ".cube_ids", j), "Group and cube ownership indexes must agree in one layer.", [id, group.group_id])
		for j in group.edges.size():
			var edge: Dictionary = group.edges[j]
			var edge_path := _index_path(path + ".edges", j)
			_member(edge.from_orientation, group.allowed_states, edge_path + ".from_orientation", Code.INVALID_ROTATION_EDGE, issues)
			_member(edge.to_orientation, group.allowed_states, edge_path + ".to_orientation", Code.INVALID_ROTATION_EDGE, issues)
			_member(edge.rotation_delta, group.allowed_rotation_deltas, edge_path + ".rotation_delta", Code.INVALID_ROTATION_EDGE, issues)
			# compose(delta, from) belongs to the MATH-backed validation stage.


static func _validate_celestial(definition: Dictionary, slots: Dictionary, issues: Array[Dictionary]) -> void:
	_reference(definition.initial_slot_id, slots, "celestial.initial_slot_id", issues, Code.INVALID_CELESTIAL_REFERENCE)
	_references(definition.slot_order, slots, "celestial.slot_order", issues, Code.INVALID_CELESTIAL_REFERENCE)
	for id in slots:
		if not id in definition.slot_order:
			_issue(issues, Code.INVALID_CELESTIAL_REFERENCE, "celestial.slot_order", "Slot order must cover every defined slot.", [id])
	for i in definition.edges.size():
		var path := _index_path("celestial.edges", i)
		_reference(definition.edges[i].from_slot_id, slots, path + ".from_slot_id", issues, Code.INVALID_CELESTIAL_REFERENCE)
		_reference(definition.edges[i].to_slot_id, slots, path + ".to_slot_id", issues, Code.INVALID_CELESTIAL_REFERENCE)


static func _validate_mechanisms(level: Dictionary, indexes: Dictionary, issues: Array[Dictionary]) -> void:
	for i in level.mechanisms.size():
		var mechanism: Dictionary = level.mechanisms[i]
		var path := _index_path("mechanisms", i)
		if _reference(mechanism.face_id, indexes.faces, path + ".face_id", issues):
			if not mechanism.mechanism_id in indexes.faces[mechanism.face_id].mechanism_ids:
				_issue(issues, Code.INVALID_REFERENCE, path + ".face_id", "Face must list its mechanism.", [mechanism.mechanism_id])
		_member(mechanism.initial_state, mechanism.allowed_states, path + ".initial_state", Code.INVALID_REFERENCE, issues)
		_check_action_references(mechanism.action, indexes, path + ".action", issues)


static func _validate_transitions(transitions: Array, indexes: Dictionary, issues: Array[Dictionary]) -> void:
	for i in transitions.size():
		var path := _index_path("face_transitions", i)
		_reference(transitions[i].source_face_id, indexes.faces, path + ".source_face_id", issues)
		_reference(transitions[i].target_face_id, indexes.faces, path + ".target_face_id", issues)
		_references(transitions[i].required_flags, indexes.flags, path + ".required_flags", issues)


static func _check_player(player: Dictionary, indexes: Dictionary, path: String, issues: Array[Dictionary]) -> void:
	var location: Dictionary = player.location
	if _reference(location.cube_id, indexes.cubes, path + ".location.cube_id", issues):
		if indexes.cubes[location.cube_id].layer != location.layer:
			_issue(issues, Code.INVALID_REFERENCE, path + ".location.layer", "Player location layer must match its cube.", [location.cube_id])
	var face_id := StringName(String(location.cube_id) + "/" + FACE_NAMES[location.face])
	_reference(face_id, indexes.faces, path + ".location.face", issues)


static func _check_action_references(action: Dictionary, indexes: Dictionary, path: String, issues: Array[Dictionary]) -> void:
	for field in {"transition_id": "transitions", "mechanism_id": "mechanisms", "group_id": "groups"}:
		if action.has(field):
			var collection: String = {"transition_id": "transitions", "mechanism_id": "mechanisms", "group_id": "groups"}[field]
			_reference(action[field], indexes[collection], _field_path(path, field), issues)
	if action.kind != Types.PuzzleActionKind.MOVE_CELESTIAL:
		return
	var target: StringName = action.target_slot_id
	var alternate: StringName = action.alternate_slot_id
	var target_path := _field_path(path, "target_slot_id")
	var alternate_path := _field_path(path, "alternate_slot_id")
	match action.celestial_op:
		Types.CelestialOp.SET_SLOT:
			_reference(target, indexes.slots, target_path, issues, Code.INVALID_CELESTIAL_REFERENCE)
			if alternate != &"":
				_issue(issues, Code.INVALID_ACTION, alternate_path, "SET_SLOT requires an empty alternate slot.")
		Types.CelestialOp.NEXT_SLOT, Types.CelestialOp.PREVIOUS_SLOT:
			if target != &"":
				_issue(issues, Code.INVALID_ACTION, target_path, "Slot stepping requires empty explicit slots.")
			if alternate != &"":
				_issue(issues, Code.INVALID_ACTION, alternate_path, "Slot stepping requires empty explicit slots.")
		Types.CelestialOp.TOGGLE_BETWEEN:
			_reference(target, indexes.slots, target_path, issues, Code.INVALID_CELESTIAL_REFERENCE)
			_reference(alternate, indexes.slots, alternate_path, issues, Code.INVALID_CELESTIAL_REFERENCE)
			if target == alternate:
				_issue(issues, Code.INVALID_ACTION, alternate_path, "TOGGLE_BETWEEN requires two different slots.")


static func _check_map_coverage(values: Dictionary, definitions: Dictionary, path: String, issues: Array[Dictionary]) -> void:
	for id in values:
		_reference(id, definitions, _field_path(path, id), issues)
	for id in definitions:
		if not values.has(id):
			_issue(issues, Code.INVALID_REFERENCE, _field_path(path, id), "State must cover every defined identifier.", [id])


static func _reference(id: StringName, definitions: Dictionary, path: String, issues: Array[Dictionary], code: int = Code.INVALID_REFERENCE) -> bool:
	if definitions.has(id):
		return true
	_issue(issues, code, path, "Reference does not identify a defined entity.", [id])
	return false


static func _references(ids: Array, definitions: Dictionary, path: String, issues: Array[Dictionary], code: int = Code.INVALID_REFERENCE) -> void:
	_unique(ids, path, issues)
	for i in ids.size():
		_reference(ids[i], definitions, _index_path(path, i), issues, code)


static func _unique(values: Array, path: String, issues: Array[Dictionary]) -> void:
	var seen := {}
	for i in values.size():
		if seen.has(values[i]):
			_issue(issues, Code.DUPLICATE_ID, _index_path(path, i), "Value is repeated.")
		seen[values[i]] = true


static func _member(value: Variant, domain: Array, path: String, code: int, issues: Array[Dictionary]) -> void:
	if not value in domain:
		_issue(issues, code, path, "Value is outside its declared domain.")


static func _enum_range(value: int, size: int, path: String, issues: Array[Dictionary]) -> void:
	if value < 0 or value >= size:
		_issue(issues, Code.INVALID_ENUM, path, "Value is outside the frozen enumeration.")


static func _type(value: Variant, expected: int, path: String, issues: Array[Dictionary]) -> bool:
	if typeof(value) == expected:
		return true
	_issue(issues, Code.INVALID_TYPE, path, "Expected " + type_string(expected) + ".")
	return false


static func _valid_id(value: String) -> bool:
	return not value.is_empty() and value[0] in "abcdefghijklmnopqrstuvwxyz" and _only_characters(value, "abcdefghijklmnopqrstuvwxyz0123456789_")


static func _only_characters(value: String, characters: String) -> bool:
	for character in value:
		if not character in characters:
			return false
	return true


static func _field_path(parent: String, field: Variant) -> String:
	return (parent + "." if not parent.is_empty() else "") + str(field)


static func _index_path(parent: String, index: int) -> String:
	return parent + "[%d]" % index


static func _issue(issues: Array[Dictionary], code: int, path: String, message: String, entity_ids: Array = []) -> void:
	var ids: Array[StringName] = []
	for id in entity_ids:
		ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	issues.append({"code": code, "severity": Types.ValidationSeverity.ERROR, "path": path,
		"entity_ids": ids, "message": message, "details": {}})


static func _sorted(issues: Array[Dictionary]) -> Array[Dictionary]:
	issues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.path != b.path:
			return a.path < b.path
		if a.code != b.code:
			return a.code < b.code
		for i in mini(a.entity_ids.size(), b.entity_ids.size()):
			if a.entity_ids[i] != b.entity_ids[i]:
				return String(a.entity_ids[i]) < String(b.entity_ids[i])
		if a.entity_ids.size() != b.entity_ids.size():
			return a.entity_ids.size() < b.entity_ids.size()
		return a.message < b.message)
	return issues
