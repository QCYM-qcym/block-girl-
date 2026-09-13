extends RefCounted
## Test-only five-Cube fixture, never a production level or dependency.
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")


static func make_level() -> Dictionary:
	var cubes: Array[Dictionary] = [
		cube(&"floor", 0, Vector3i.ZERO),
		cube(&"opposite_source", 0, Vector3i(6,0,0)),
		cube(&"blocker", 0, Vector3i(0,4,0)),
		cube(&"mirror", 1, Vector3i.ZERO),
		cube(&"ceiling", 1, Vector3i(6,2,0)),
	]
	cubes[2].group_id = &"alpha"
	cubes[4].group_id = &"beta"
	var faces: Array[Dictionary] = []
	for cell in cubes:
		for face in Geometry.make_face_nodes(cell.cube_id):
			face.walkable = (cell.cube_id in [&"floor", &"opposite_source", &"mirror"] and face.face == Types.FaceDirection.TOP) or (cell.cube_id == &"ceiling" and face.face == Types.FaceDirection.BOTTOM)
			if face.face_id == &"floor/TOP":
				face.mechanism_ids.append(&"plate")
			if face.face_id == &"opposite_source/TOP":
				face.mechanism_ids.append(&"switch")
			faces.append(face)
	var worlds: Array[Dictionary] = []
	for layer in [Types.WorldLayer.SURFACE, Types.WorldLayer.INNER]:
		worlds.append({"layer": layer, "pivot2": Vector3i.ZERO, "initial_orientation": 0,
			"allowed_states": range(24), "allowed_rotation_deltas": [2,3,22,18,9,12], "allowed_rotation_intents": []})
	return {
		"schema_version": 1, "contract_version": "foundation.contract.v1", "orientation_version": "cube24.v1", "rule_version": "foundation.rules.v1",
		"level_id": &"foundation_integration", "content_hash": "1".repeat(64), "cell_size": 1,
		"worlds": worlds, "cubes": cubes, "faces": faces,
		"groups": [group(&"alpha", 0, &"blocker"), group(&"beta", 1, &"ceiling")],
		"celestial": {"slots": [{"slot_id": &"a", "position2": Vector3i(0,10,0)}, {"slot_id": &"b", "position2": Vector3i(0,-10,0)}],
			"slot_order": [&"a", &"b"], "wrap": false, "initial_slot_id": &"a",
			"edges": [{"from_slot_id": &"a", "to_slot_id": &"b"}, {"from_slot_id": &"b", "to_slot_id": &"a"}]},
		"mechanisms": [mechanism(&"plate", &"floor/TOP"), mechanism(&"switch", &"opposite_source/TOP")],
		"face_transitions": [], "shift_compatibilities": [0,1],
		"spawn": Records.make_player_state(Records.make_player_location(0, &"floor", 4), 0),
		"goal": {"face_id": &"opposite_source/TOP", "required_flags": []},
		"flag_definitions": [{"flag_id": &"done", "initial_value": false}, {"flag_id": &"open", "initial_value": true}],
		"build_info": {"purpose": "test fixture; hash is a namespace fixture, not a Bake"},
	}


static func cube(id: StringName, layer: int, center: Vector3i) -> Dictionary:
	return {"cube_id": id, "layer": layer, "center2": center, "orientation": 0, "group_id": &"", "occludes_light": true, "tags": []}


static func group(id: StringName, layer: int, member: StringName) -> Dictionary:
	return {"group_id": id, "layer": layer, "cube_ids": [member], "pivot2": Vector3i.ZERO,
		"initial_orientation": 0, "allowed_states": range(24), "allowed_rotation_deltas": [2,3,22,18,9,12], "edges": []}


static func mechanism(id: StringName, face: StringName) -> Dictionary:
	return {"mechanism_id": id, "face_id": face, "trigger": &"USE", "action": Records.make_action(1, {}),
		"priority": 0, "initial_state": &"off", "allowed_states": [&"off", &"on"]}
