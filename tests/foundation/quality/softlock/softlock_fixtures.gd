extends RefCounted
## TEST ONLY: literal graph topologies for 3B reverse-reachability tests.
## These records are algorithm fixtures, not claims of Explorer-produced graphs.

const Types = preload("res://foundation/contracts/foundation_types.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const LevelFixture = preload("res://tests/foundation/level/baker_fixture.gd")

const EXHAUSTED := 0
const BUDGET := 2


static func make_authoring(name: String) -> Dictionary:
	var level: Dictionary = LevelFixture.make_golden_level()
	level.erase("content_hash")
	level.level_id = StringName("softlock_" + name)
	for world in level.worlds:
		world.initial_orientation = 0
		world.allowed_states = [0]
		world.allowed_rotation_deltas = []
		world.allowed_rotation_intents = []
	level.groups = []
	level.mechanisms = []
	level.face_transitions = []
	level.shift_compatibilities = [0]
	level.flag_definitions = []
	level.celestial = {
		"slots": [{"slot_id": &"a", "position2": Vector3i(0, -10, 0)}],
		"slot_order": [&"a"],
		"wrap": false,
		"initial_slot_id": &"a",
		"edges": [],
	}
	var cubes: Array[Dictionary] = [LevelFixture.cube(&"floor", Types.WorldLayer.SURFACE, Vector3i.ZERO)]
	var walkable: Array[StringName] = [&"floor/TOP"]
	match name:
		"initial_goal":
			level.goal = {"face_id": &"floor/TOP", "required_flags": []}
		"no_goal":
			cubes.append(LevelFixture.cube(&"exit", Types.WorldLayer.SURFACE, Vector3i(8, 0, 0)))
			walkable.append(&"exit/TOP")
			level.goal = {"face_id": &"exit/TOP", "required_flags": []}
		"corridor":
			cubes.append(LevelFixture.cube(&"step", Types.WorldLayer.SURFACE, Vector3i(2, 0, 0)))
			cubes.append(LevelFixture.cube(&"exit", Types.WorldLayer.INNER, Vector3i(2, 0, 0)))
			walkable.append_array([&"step/TOP", &"exit/TOP"])
			level.goal = {"face_id": &"exit/TOP", "required_flags": []}
		"multiple_goals":
			cubes.append(LevelFixture.cube(&"exit", Types.WorldLayer.SURFACE, Vector3i(2, 0, 0)))
			walkable.append(&"exit/TOP")
			level.goal = {"face_id": &"exit/TOP", "required_flags": []}
			level.celestial.slots.append({"slot_id": &"b", "position2": Vector3i(0, -12, 0)})
			level.celestial.slot_order = [&"a", &"b"]
			level.celestial.edges = [{"from_slot_id": &"a", "to_slot_id": &"b"}, {"from_slot_id": &"b", "to_slot_id": &"a"}]
			level.mechanisms = [{"mechanism_id": &"sky", "face_id": &"floor/TOP", "trigger": &"USE",
				"action": {"kind": 7, "celestial_op": 3, "target_slot_id": &"a", "alternate_slot_id": &"b", "mechanism_id": &"sky"},
				"priority": 0, "initial_state": &"default", "allowed_states": [&"default"]}]
		"sink", "cycle":
			cubes.append(LevelFixture.cube(&"exit", Types.WorldLayer.SURFACE, Vector3i(2, 0, 0)))
			cubes.append(LevelFixture.cube(&"inner_floor", Types.WorldLayer.INNER, Vector3i.ZERO))
			walkable.append(&"exit/TOP")
			walkable.append(&"inner_floor/TOP")
			level.goal = {"face_id": &"exit/TOP", "required_flags": []}
			if name == "cycle":
				cubes.append(LevelFixture.cube(&"inner_next", Types.WorldLayer.INNER, Vector3i(2, 0, 0)))
				walkable.append(&"inner_next/TOP")
		_:
			push_error("Unknown softlock authoring case: " + name)
			return {}
	level.cubes = cubes
	level.faces = _authoring_faces(cubes, walkable, name in ["sink", "cycle"])
	if name == "multiple_goals":
		for face in level.faces:
			if face.face_id == &"floor/TOP":
				face.mechanism_ids.append(&"sky")
	level.spawn = Records.make_player_state(
		Records.make_player_location(Types.WorldLayer.SURFACE, &"floor", Types.FaceDirection.TOP), 0)
	return level


static func make_case(name: String) -> Dictionary:
	var level := _canonical_level()
	if level.is_empty():
		return {}
	var states := _states(level)
	var keys := _keys(level, states)
	if keys.is_empty():
		return {}
	var graph: Dictionary
	match name:
		"no_softlock":
			graph = _graph(level, keys.S, states, keys,
				[["S", 0, null], ["A", 1, 0], ["G", 2, 1]],
				[["S", "A", 0], ["A", "G", 1]], ["G"])
		"sink":
			graph = _graph(level, keys.S, states, keys,
				[["S", 0, null], ["A", 1, 0], ["G", 2, 1], ["T", 1, 2]],
				[["S", "A", 0], ["A", "G", 1], ["S", "T", 2]], ["G"])
		"cycle":
			graph = _graph(level, keys.S, states, keys,
				[["S", 0, null], ["A", 1, 0], ["G", 2, 1], ["T", 1, 2], ["U", 2, 3]],
				[["S", "A", 0], ["A", "G", 1], ["S", "T", 2], ["T", "U", 3], ["U", "T", 0]], ["G"])
		"multiple_goals":
			graph = _graph(level, keys.S, states, keys,
				[["S", 0, null], ["G", 1, 0], ["H", 1, 1]],
				[["S", "G", 0], ["S", "H", 1]], ["G", "H"])
		"no_goal":
			graph = _graph(level, keys.S, states, keys,
				[["S", 0, null], ["T", 1, 0]], [["S", "T", 0]], [])
		"partial":
			graph = _graph(level, keys.S, states, keys,
				[["S", 0, null], ["A", 1, 0], ["G", 2, 1], ["T", 1, 2]],
				[["S", "A", 0], ["A", "G", 1], ["S", "T", 2]], ["G"], false, BUDGET, ["T"])
		"custom_initial":
			graph = _graph(level, keys.A, states, keys,
				[["A", 0, null], ["G", 1, 0]], [["A", "G", 0]], ["G"])
		_:
			push_error("Unknown softlock fixture case: " + name)
			return {}
	return {"level": level, "graph": graph, "keys": keys.duplicate(true)}


static func _canonical_level() -> Dictionary:
	var level: Dictionary = LevelFixture.make_level()
	var identity := Codec.compute_content_hash(level)
	if not identity.ok:
		push_error("Softlock fixture level failed canonical hashing: " + str(identity.issues))
		return {}
	level.content_hash = identity.content_hash
	return level


static func _states(level: Dictionary) -> Dictionary:
	var s: Dictionary = Records.initial_state(level)
	var a := _pose(s, Types.WorldLayer.SURFACE, &"floor", Types.FaceDirection.TOP, 12)
	var g := _pose(s, Types.WorldLayer.SURFACE, &"exit", Types.FaceDirection.TOP, 0)
	var t := _pose(s, Types.WorldLayer.INNER, &"inner_floor", Types.FaceDirection.TOP, 0)
	var u := _pose(s, Types.WorldLayer.INNER, &"inner_floor", Types.FaceDirection.TOP, 1)
	var h := _pose(s, Types.WorldLayer.SURFACE, &"exit", Types.FaceDirection.TOP, 3)
	h.celestial.slot_id = &"b"
	return {"S": s, "A": a, "G": g, "T": t, "U": u, "H": h}


static func _pose(source: Dictionary, layer: int, cube_id: StringName, face: int, orientation: int) -> Dictionary:
	var state := source.duplicate(true)
	state.player = Records.make_player_state(Records.make_player_location(layer, cube_id, face), orientation)
	return state


static func _authoring_faces(cubes: Array[Dictionary], walkable: Array[StringName], block_inner_exit: bool) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	for cube in cubes:
		for face in Geometry.make_face_nodes(cube.cube_id):
			face.walkable = face.face_id in walkable
			if block_inner_exit and cube.layer == Types.WorldLayer.INNER:
				face.shift_exit_blocked = true
			faces.append(face)
	return faces


static func _keys(level: Dictionary, states: Dictionary) -> Dictionary:
	var output := {}
	for label in ["S", "A", "G", "T", "U", "H"]:
		var built := Key.build(level, states[label])
		if not built.ok:
			push_error("Softlock fixture state %s failed StateKey.build: %s" % [label, built.issues])
			return {}
		output[label] = built.key
	return output


static func _graph(level: Dictionary, initial_key: String, states: Dictionary, keys: Dictionary,
		node_specs: Array, topology: Array, goals: Array, complete: bool = true,
		stop_reason: int = EXHAUSTED, unexpanded: Array = []) -> Dictionary:
	var nodes := {}
	var forward := {}
	var reverse := {}
	for node_spec in node_specs:
		var label: String = node_spec[0]
		var state_key: String = keys[label]
		nodes[state_key] = {
			"state_key": state_key,
			"state": states[label].duplicate(true),
			"depth": node_spec[1],
			"is_goal": label in goals,
			"expanded": label not in unexpanded,
			"predecessor_edge": node_spec[2],
		}
		forward[state_key] = []
		reverse[state_key] = []
	var edges: Array = []
	for edge_spec in topology:
		var edge_id := edges.size()
		var from_key: String = keys[edge_spec[0]]
		var to_key: String = keys[edge_spec[1]]
		edges.append({
			"edge_id": edge_id,
			"from_key": from_key,
			"to_key": to_key,
			"action": {"kind": Types.PuzzleActionKind.MOVE, "face_axis": edge_spec[2]},
			"global_kind": Types.GlobalTransitionKind.NONE,
		})
		forward[from_key].append(edge_id)
		reverse[to_key].append(edge_id)
	return {
		"graph_version": "stategraph.v1",
		"level_hash": level.content_hash,
		"rule_version": level.rule_version,
		"initial_key": initial_key,
		"policy_descriptor": _policy_descriptor(),
		"nodes": nodes,
		"edges": edges,
		"forward": forward,
		"reverse": reverse,
		"complete": complete,
		"stop_reason": stop_reason,
	}


static func _policy_descriptor() -> Dictionary:
	return {
		"strategy": &"BFS",
		"mode": 1,
		"validation_options": {"max_configurations": 10000, "max_checks": 100000},
		"filter_descriptor": {"filter_id": &"UNFILTERED", "filter_version": "1", "disabled_mechanics": []},
	}
