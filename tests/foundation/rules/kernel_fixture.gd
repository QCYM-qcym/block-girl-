extends RefCounted
## Business-profile fixture owned by rules tests, not an authored level/Bake.
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Math = preload("res://foundation/orientation/discrete_orientation.gd")
const RealDerived = preload("res://foundation/rules/derived_state_resolver.gd")
## Unit-only query seam; real acceptance always preloads production Derived.
static var mapping_override: Variant = null
static var fail_snapshot_at_slot: StringName = &""
static var snapshot_failure: Dictionary = {}
static var light_calls := 0


static func snapshot(level: Dictionary, state: Dictionary) -> Dictionary:
	if not snapshot_failure.is_empty() and state.get("celestial", {}).get("slot_id", &"") == fail_snapshot_at_slot:
		return snapshot_failure.duplicate(true)
	return RealDerived.snapshot(level, state)


static func shift_mapping(level: Dictionary, state: Dictionary) -> Dictionary:
	return mapping_override.duplicate(true) if mapping_override != null else RealDerived.shift_mapping(level, state)


static func light(level: Dictionary, state: Dictionary, face_id: StringName) -> Dictionary:
	light_calls += 1
	return RealDerived.light(level, state, face_id)


static func make_level(real_clearance: bool = false) -> Dictionary:
	var cubes: Array[Dictionary] = []
	for item in [[&"floor", 0, Vector3i.ZERO], [&"step", 0, Vector3i(2,0,0)], [&"end", 0, Vector3i(4,0,0)], [&"goal", 0, Vector3i(10,0,0)], [&"mirror", 1, Vector3i.ZERO]]:
		cubes.append(cube(item[0], item[1], item[2]))
	# The frozen conservative roll only exempts its two support Cubes.
	# Keep the original three-support unit fixture; real positive cases need
	# the unrelated third Cube outside the swept enclosure.
	if real_clearance:
		cubes[2].center2 = Vector3i(20,0,0)
	var faces: Array[Dictionary] = []
	for cell in cubes:
		for record in Geometry.make_face_nodes(cell.cube_id):
			record.walkable = record.face == Types.FaceDirection.TOP or (cell.cube_id == &"floor" and record.face == Types.FaceDirection.FRONT)
			faces.append(record)
	var worlds: Array[Dictionary] = []
	for layer in range(2):
		worlds.append({"layer": layer, "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": range(24), "allowed_rotation_deltas": [2,3,22,18,9,12], "allowed_rotation_intents": range(6)})
	var level := {
		"schema_version": 1, "contract_version": "foundation.contract.v1", "orientation_version": "cube24.v1", "rule_version": "foundation.rules.v1",
		"level_id": &"kernel_fixture", "content_hash": "a".repeat(64), "cell_size": 1,
		"worlds": worlds, "cubes": cubes, "faces": faces, "groups": [],
		"celestial": {"slots": [{"slot_id": &"a", "position2": Vector3i(0,-10,0)}, {"slot_id": &"b", "position2": Vector3i(0,10,0)}], "slot_order": [&"a", &"b"], "wrap": false, "initial_slot_id": &"a", "edges": [{"from_slot_id": &"a", "to_slot_id": &"b"}, {"from_slot_id": &"b", "to_slot_id": &"a"}]},
		"mechanisms": [],
		"face_transitions": [{"transition_id": &"tip", "source_face_id": &"floor/TOP", "target_face_id": &"floor/FRONT", "entry_axis": 0, "exit_axis": 0, "rotation_steps": [2], "required_flags": []}, {"transition_id": &"untip", "source_face_id": &"floor/FRONT", "target_face_id": &"floor/TOP", "entry_axis": 0, "exit_axis": 0, "rotation_steps": [3], "required_flags": []}],
		"shift_compatibilities": [0,1], "spawn": Records.make_player_state(Records.make_player_location(0, &"floor", 4), 0),
		"goal": {"face_id": &"goal/TOP", "required_flags": [&"open"]}, "flag_definitions": [{"flag_id": &"open", "initial_value": true}], "build_info": {"purpose": "rules fixture; hash is a test namespace"},
	}
	add_mechanism(level, &"console", &"floor/TOP", celestial_action())
	return level


static func cube(id: StringName, layer: int, center2: Vector3i) -> Dictionary:
	return {"cube_id": id, "layer": layer, "center2": center2, "orientation": 0, "group_id": &"", "occludes_light": true, "tags": []}


static func face(level: Dictionary, id: StringName) -> Dictionary:
	for record in level.faces:
		if record.face_id == id:
			return record
	return {}


static func celestial_action(id: StringName = &"console", operation: int = 0, target: StringName = &"b", alternate: StringName = &"") -> Dictionary:
	return Records.make_action(7, {"celestial_op": operation, "target_slot_id": target, "alternate_slot_id": alternate, "mechanism_id": id})


static func add_mechanism(level: Dictionary, id: StringName, face_id: StringName, action: Dictionary, trigger: StringName = &"USE") -> void:
	level.mechanisms.append({"mechanism_id": id, "face_id": face_id, "trigger": trigger, "action": action.duplicate(true), "priority": 0, "initial_state": &"ready", "allowed_states": [&"ready"]})
	face(level, face_id).mechanism_ids.append(id)


static func group_level(real_clearance: bool = false) -> Dictionary:
	var level := make_level(real_clearance)
	var edges: Array[Dictionary] = []
	for pose in range(24):
		for delta in [2,3,22,18,9,12]:
			edges.append({"from_orientation": pose, "rotation_delta": delta, "to_orientation": Math.compose(delta, pose)})
	level.groups.append({"group_id": &"bridge", "layer": 0, "cube_ids": [&"floor", &"step", &"end"], "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": range(24), "allowed_rotation_deltas": [2,3,22,18,9,12], "edges": edges})
	if real_clearance:
		level.groups[0].cube_ids = [&"floor", &"step"]
	for cell in level.cubes:
		if cell.cube_id in level.groups[0].cube_ids:
			cell.group_id = &"bridge"
	add_mechanism(level, &"rotator", &"floor/TOP", Records.make_action(6, {"group_id": &"bridge", "rotation_delta": 2, "mechanism_id": &"rotator"}))
	return level


static func opposite_level(twisted: bool = false) -> Dictionary:
	var level := make_level()
	for cell in level.cubes:
		if cell.cube_id == &"mirror":
			cell.center2 = Vector3i(0,2,0)
			# TOP frame 3 left multiplied by ID 1 -> BOTTOM frame 2.
			# ID 19 left multiplied by TOP frame 3 -> target frame 17.
			cell.orientation = 19 if twisted else 1
	return level
