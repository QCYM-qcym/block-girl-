extends RefCounted
## Test fixture only. These factories are never production dependencies.
const Records = preload("res://foundation/contracts/contract_records.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
static func make_level() -> Dictionary:
	var level := {
		"schema_version": 1, "contract_version": "foundation.contract.v1", "orientation_version": "cube24.v1", "rule_version": "foundation.rules.v1",
		"level_id": &"validation_fixture", "content_hash": "0".repeat(64), "cell_size": 1,
		"worlds": [world(0), world(1)], "cubes": [cube(&"floor", 0, Vector3i.ZERO)], "faces": [], "groups": [],
		"celestial": {"slots": [{"slot_id": &"a", "position2": Vector3i(0,10,0)}], "slot_order": [&"a"], "wrap": false, "initial_slot_id": &"a", "edges": []},
		"mechanisms": [], "face_transitions": [], "shift_compatibilities": [0,1],
		"spawn": Records.make_player_state(Records.make_player_location(0, &"floor", 4), 0),
		"goal": {"face_id": &"floor/TOP", "required_flags": []}, "flag_definitions": [], "build_info": {},
	}
	rebuild_faces(level, [&"floor/TOP"])
	return level
static func cube(id: StringName, layer: int, center: Vector3i) -> Dictionary:
	return {"cube_id": id, "layer": layer, "center2": center, "orientation": 0, "group_id": &"", "occludes_light": true, "tags": []}
static func world(layer: int) -> Dictionary:
	return {"layer": layer, "pivot2": Vector3i.ZERO, "initial_orientation": 0, "allowed_states": [0], "allowed_rotation_deltas": [], "allowed_rotation_intents": []}
static func group(id: StringName, layer: int, members: Array, pivot: Vector3i = Vector3i.ZERO) -> Dictionary:
	return {"group_id": id, "layer": layer, "cube_ids": members.duplicate(), "pivot2": pivot, "initial_orientation": 0, "allowed_states": range(24), "allowed_rotation_deltas": [2,3,22,18,9,12], "edges": []}
static func rebuild_faces(level: Dictionary, walkable: Array = [&"floor/TOP"]) -> void:
	var faces: Array[Dictionary] = []
	for cell in level.cubes:
		for face in Geometry.make_face_nodes(cell.cube_id):
			face.walkable = face.face_id in walkable
			faces.append(face)
	level.faces = faces
