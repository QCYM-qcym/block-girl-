extends RefCounted
## Test authoring profile; content_hash is deliberately a placeholder until baked.
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")

static func make_level() -> Dictionary:
	var cubes := [cube(&"floor", 0, Vector3i.ZERO), cube(&"exit", 0, Vector3i(2,0,0)),
		cube(&"inner_floor", 1, Vector3i.ZERO), cube(&"group_cube", 1, Vector3i(10,0,0))]
	cubes[3].group_id = &"island"
	var faces: Array[Dictionary] = []
	for cell in cubes:
		for face in Geometry.make_face_nodes(cell.cube_id):
			face.walkable = cell.cube_id != &"group_cube" and face.face == 4
			if face.face_id == &"floor/TOP":
				face.mechanism_ids.append(&"toggle_sky")
			faces.append(face)
	var worlds: Array[Dictionary] = []
	for layer in [0, 1]:
		worlds.append({"layer": layer, "pivot2": Vector3i.ZERO, "initial_orientation": 0,
			"allowed_states": [0], "allowed_rotation_deltas": [], "allowed_rotation_intents": []})
	return {
		"schema_version": 1, "contract_version": "foundation.contract.v1", "orientation_version": "cube24.v1",
		"rule_version": "foundation.rules.v1", "level_id": &"minimal_baker", "content_hash": "0".repeat(64), "cell_size": 1,
		"worlds": worlds, "cubes": cubes, "faces": faces,
		"groups": [{"group_id": &"island", "layer": 1, "cube_ids": [&"group_cube"], "pivot2": Vector3i(10,0,0),
			"initial_orientation": 0, "allowed_states": [0,22], "allowed_rotation_deltas": [22,18],
			"edges": [{"from_orientation": 0, "rotation_delta": 22, "to_orientation": 22}, {"from_orientation": 22, "rotation_delta": 18, "to_orientation": 0}]}],
		"celestial": {"slots": [{"slot_id": &"a", "position2": Vector3i(0,10,0)}, {"slot_id": &"b", "position2": Vector3i(0,12,0)}],
			"slot_order": [&"a", &"b"], "wrap": false, "initial_slot_id": &"a",
			"edges": [{"from_slot_id": &"a", "to_slot_id": &"b"}, {"from_slot_id": &"b", "to_slot_id": &"a"}]},
		"mechanisms": [{"mechanism_id": &"toggle_sky", "face_id": &"floor/TOP", "trigger": &"USE",
			"action": {"kind": 7, "celestial_op": 3, "target_slot_id": &"a", "alternate_slot_id": &"b", "mechanism_id": &"toggle_sky"},
			"priority": 0, "initial_state": &"default", "allowed_states": [&"default"]}],
		"face_transitions": [], "shift_compatibilities": [0,1],
		"spawn": Records.make_player_state(Records.make_player_location(0, &"floor", 4), 0),
		"goal": {"face_id": &"exit/TOP", "required_flags": []}, "flag_definitions": [], "build_info": {},
	}

static func make_authoring() -> Dictionary:
	var level := make_level()
	level.erase("content_hash")
	return level

static func cube(id: StringName, layer: int, center: Vector3i) -> Dictionary:
	return {"cube_id": id, "layer": layer, "center2": center, "orientation": 0,
		"group_id": &"", "occludes_light": true, "tags": []}

static func make_golden_level() -> Dictionary:
	var level := make_level()
	level.level_id = &"codec_golden"
	level.cubes = [cube(&"floor", 0, Vector3i.ZERO)]
	level.faces = Geometry.make_face_nodes(&"floor")
	level.faces[4].walkable = true
	level.groups = []
	level.mechanisms = []
	level.goal.face_id = &"floor/TOP"
	level.celestial.slots.resize(1)
	level.celestial.slot_order = [&"a"]
	level.celestial.edges = []
	return level
