extends RefCounted
## Hand-authored technical fixture, not a Baker output. Hash computed offline
## over canonical rule JSON, excluding content_hash and build_info.
const CONTENT_HASH := "3d6ff71bf204675a105ff77f834064af95f55db20d2a85c04983ecbb810cb032"
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")

static func make_level() -> Dictionary:
	var cubes: Array[Dictionary] = []
	var faces: Array[Dictionary] = []
	for entry in [[&"s0", 0, Vector3i.ZERO], [&"s1", 0, Vector3i(2,0,0)],
		[&"i0", 1, Vector3i.ZERO], [&"i1", 1, Vector3i(0,0,-2)]]:
		cubes.append({"cube_id": entry[0], "layer": entry[1], "center2": entry[2],
			"orientation": 0, "group_id": &"", "occludes_light": true, "tags": []})
		var nodes := Geometry.make_face_nodes(entry[0])
		for face in nodes:
			face.walkable = face.face == 4
			face.shift_exit_blocked = entry[0] == &"s0"
		faces.append_array(nodes)
	return {
		"schema_version": 1, "contract_version": "foundation.contract.v1",
		"orientation_version": "cube24.v1", "rule_version": "foundation.rules.v1",
		"level_id": &"runtime_fixture", "content_hash": CONTENT_HASH, "cell_size": 1,
		"worlds": [
			{"layer": 0, "pivot2": Vector3i.ZERO, "initial_orientation": 0,
			"allowed_states": [0,22], "allowed_rotation_deltas": [22], "allowed_rotation_intents": [0]},
			{"layer": 1, "pivot2": Vector3i.ZERO, "initial_orientation": 0,
			"allowed_states": [0], "allowed_rotation_deltas": [], "allowed_rotation_intents": []}],
		"cubes": cubes, "faces": faces, "groups": [],
		"celestial": {"slots": [{"slot_id": &"a", "position2": Vector3i(0,-8,0)}],
			"slot_order": [&"a"], "wrap": false, "initial_slot_id": &"a", "edges": []},
		"mechanisms": [], "face_transitions": [], "shift_compatibilities": [0],
		"spawn": {"location": {"layer": 0, "cube_id": &"s0", "face": 4}, "orientation": 0},
		"goal": {"face_id": &"i1/TOP", "required_flags": []}, "flag_definitions": [],
		"build_info": {"source": "FOUNDATION-2D hand-authored technical fixture"}}
