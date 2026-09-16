extends RefCounted
## Tests only: authored fixtures go through the real Baker; no game rules here.
const Base = preload("res://tests/foundation/level/baker_fixture.gd")
const Baker = preload("res://foundation/level/level_baker.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")

static func authoring(length: int = 3) -> Dictionary:
	var level := Base.make_golden_level()
	level.erase("content_hash")
	level.level_id = &"solver_corridor"
	level.cubes = []
	level.faces = []
	for index in length:
		var id := StringName("cell%d" % index)
		# Two Surface supports followed by a co-located Inner exit: MOVE, SHIFT.
		level.cubes.append(Base.cube(id, 1 if index == 2 else 0, Vector3i(2 if index == 2 else index * 2, 0, 0)))
		for face in Geometry.make_face_nodes(id):
			face.walkable = face.face == 4
			level.faces.append(face)
	level.spawn = Records.make_player_state(Records.make_player_location(0, &"cell0", 4), 0)
	level.goal.face_id = StringName("cell%d/TOP" % (length - 1))
	level.celestial.slots[0].position2 = Vector3i(0,-10,0)
	return level

static func bake(source: Dictionary) -> Dictionary:
	return Baker.bake(source, {"max_configurations": 4096, "max_checks": 100000})

static func corridor(length: int = 3) -> Dictionary:
	var baked := bake(authoring(length))
	assert(baked.ok, str(baked.issues))
	return baked.level

static func add_celestial_mechanism(source: Dictionary, trigger: StringName, face_id: StringName, id: StringName = &"sky") -> void:
	source.celestial.slots.append({"slot_id":&"b","position2":Vector3i(0,-12,0)})
	source.celestial.slot_order = [&"a",&"b"]
	source.celestial.edges = [{"from_slot_id":&"a","to_slot_id":&"b"},{"from_slot_id":&"b","to_slot_id":&"a"}]
	source.mechanisms.append({"mechanism_id":id,"face_id":face_id,"trigger":trigger,
		"action":{"kind":7,"celestial_op":3,"target_slot_id":&"a","alternate_slot_id":&"b","mechanism_id":id},
		"priority":0,"initial_state":&"default","allowed_states":[&"default"]})
	for face in source.faces:
		if face.face_id == face_id:
			face.mechanism_ids.append(id)

static func static_domain() -> Dictionary:
	var level := Base.make_level()
	for world in level.worlds:
		world.allowed_states = range(24)
		world.allowed_rotation_deltas = [22, 3, 2]
		world.allowed_rotation_intents = [0, 1, 2, 3, 4, 5]
	level.mechanisms.append({"mechanism_id": &"group_use", "face_id": &"floor/TOP", "trigger": &"USE",
		"action": {"kind": 6, "group_id": &"island", "rotation_delta": 22, "mechanism_id": &"group_use"},
		"priority": 1, "initial_state": &"default", "allowed_states": [&"default"]})
	var enter: Dictionary = level.mechanisms[0].duplicate(true)
	enter.mechanism_id = &"enter_plate"
	enter.trigger = &"ENTER"
	enter.action.mechanism_id = &"enter_plate"
	level.mechanisms.append(enter)
	for face in level.faces:
		if face.face_id == &"floor/TOP":
			face.mechanism_ids.append_array([&"group_use", &"enter_plate"])
	level.face_transitions = [{"transition_id": &"turn", "source_face_id": &"floor/TOP", "target_face_id": &"floor/FRONT",
		"entry_axis": 1, "exit_axis": 1, "rotation_steps": [2], "required_flags": []}]
	return level
