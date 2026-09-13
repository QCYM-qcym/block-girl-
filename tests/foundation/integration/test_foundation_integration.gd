extends SceneTree
## Real production modules only. No rotation, mapping or lighting test doubles.
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const StateKey = preload("res://foundation/contracts/state_key.gd")
const Orientation = preload("res://foundation/orientation/discrete_orientation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const SpatialValidation = preload("res://foundation/spatial/spatial_validation.gd")
const Mapping = preload("res://foundation/spatial/mapping_query.gd")
const Celestial = preload("res://foundation/celestial/celestial_rules.gd")
const Lighting = preload("res://foundation/celestial/logical_lighting.gd")
const Fixture = preload("res://tests/foundation/integration/foundation_fixture.gd")

var checks := 0
var failures: Array[String] = []
var light_calls := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


func _initialize() -> void:
	var level := Fixture.make_level()
	var issues := Data.validate_level_shape(level)
	check(issues.is_empty(), "real DATA validates five-Cube fixture: " + str(issues))
	if not issues.is_empty():
		_finish()
		return
	var state := Records.initial_state(level)
	check(Data.validate_state_shape(level,state).is_empty(), "real initial state")
	var before_level := level.duplicate(true)
	var before_state := state.duplicate(true)
	_test_orientation(level,state)
	_test_mapping(level,state)
	_test_lighting_and_slots(level,state)
	_test_state_key(level,state)
	_test_overflow(level,state)
	check(level == before_level and state == before_state, "all integration queries preserve inputs")
	_finish()


func _finish() -> void:
	print("FOUNDATION_INTEGRATION: ", checks, " checks; failures=", failures)
	if failures.is_empty():
		print("FOUNDATION_INTEGRATION_TEST_PASS")
	quit(0 if failures.is_empty() else 1)


func _snapshot(level: Dictionary, state: Dictionary) -> Dictionary:
	var result := Geometry.snapshot(level,state)
	check(result.ok, "real checked Spatial snapshot: " + str(result.issues))
	var faces: Array[Dictionary] = []
	faces.assign(level.faces)
	check(SpatialValidation.validate_snapshot(result,faces).is_empty(), "real structural snapshot validation")
	return result


func _anchor(snapshot: Dictionary, id: StringName) -> Dictionary:
	if snapshot.ok:
		for anchor in snapshot.value.anchors:
			if anchor.face_id == id:
				return anchor
	check(false, "missing real anchor " + String(id))
	return {}


func _mapping(snapshot: Dictionary, level: Dictionary, source: StringName) -> Dictionary:
	var faces: Array[Dictionary] = []
	faces.assign(level.faces)
	var enabled: Array[int] = []
	enabled.assign(level.shift_compatibilities)
	return Mapping.resolve_mapping(Mapping.collect_mapping_candidates(snapshot,faces,source,1,enabled))


func _light(snapshot: Dictionary, id: StringName, slot: Dictionary) -> Dictionary:
	# Test consumer boundary, not a production wrapper or alternate light solver.
	if not snapshot.ok:
		return {"ok": false, "light_state": null, "reason": &"INVALID", "occluder_id": &"", "issues": snapshot.issues.duplicate(true)}
	var cubes: Array[Dictionary] = []
	cubes.assign(snapshot.value.cubes)
	light_calls += 1
	return Lighting.query(_anchor(snapshot,id),slot,cubes)


func _test_orientation(level: Dictionary, state: Dictionary) -> void:
	# Independent fixed normal goldens; expected frames use the sole math API.
	var normals := [Vector3i(0,0,1), Vector3i(0,0,-1), Vector3i.UP, Vector3i.UP, Vector3i.LEFT, Vector3i.RIGHT]
	var deltas := [2,3,22,18,9,12]
	var local := Geometry.face_frame(Types.FaceDirection.TOP)
	for index in deltas.size():
		var delta: int = Orientation.quarter_turn(index / 2, 1 if index % 2 == 0 else -1)
		check(delta == deltas[index], "canonical quarter-turn ID")
		var rotated := state.duplicate(true)
		rotated.world_orientations[0] = delta
		var snapshot := _snapshot(level,rotated)
		if not snapshot.ok:
			continue
		var anchor := _anchor(snapshot,&"floor/TOP")
		check(anchor.position2 == normals[index] and anchor.frame.normal == normals[index], "world quarter-turn fixed Anchor/Normal golden")
		check(anchor.frame.u == Orientation.apply(delta,local.u) and anchor.frame.v == Orientation.apply(delta,local.v), "Spatial frame consumes formal math")
		check(Orientation.from_columns(anchor.frame.u,anchor.frame.v,anchor.frame.normal) == Orientation.compose(delta,3), "Frame cube24 identity agreement")
		rotated.world_orientations[0] = Orientation.compose(Orientation.inverse(delta),delta)
		check(Geometry.snapshot(level,rotated) == Geometry.snapshot(level,state), "inverse restores complete geometry")


func _test_mapping(level: Dictionary, state: Dictionary) -> void:
	var snapshot := _snapshot(level,state)
	if not snapshot.ok:
		return
	var same := _mapping(snapshot,level,&"floor/TOP")
	check(same.status == Types.MappingResolutionStatus.UNIQUE and same.mapping.compatibility == Types.FaceCompatibility.SAME_NORMAL, "real SAME_NORMAL UNIQUE")
	var opposite := _mapping(snapshot,level,&"opposite_source/TOP")
	check(opposite.status == Types.MappingResolutionStatus.UNIQUE and opposite.mapping.compatibility == Types.FaceCompatibility.OPPOSITE_NORMAL, "real OPPOSITE_NORMAL UNIQUE")
	var shifted := level.duplicate(true)
	shifted.cubes[3].center2 = Vector3i(2,0,0)
	check(_mapping(_snapshot(shifted,state),shifted,&"floor/TOP").status == Types.MappingResolutionStatus.NONE, "real no-overlap NONE")
	var source := _anchor(snapshot,&"floor/TOP")
	var target := _anchor(snapshot,&"mirror/TOP").duplicate(true)
	target.position2.x += 1
	check(not Geometry.anchor_overlap(source,target).overlaps, "one half-unit difference is never approximate overlap")
	check(Geometry.classify_face_compatibility(source,target).compatibility == 0, "classification independent of overlap")
	var reordered := level.duplicate(true)
	reordered.cubes.reverse()
	reordered.faces.reverse()
	reordered.worlds.reverse()
	reordered.groups.reverse()
	reordered.shift_compatibilities.reverse()
	check(_mapping(_snapshot(reordered,state),reordered,&"floor/TOP") == same, "real mapping order deterministic")
	for face in reordered.faces:
		face.shift_exit_blocked = true
		face.shift_entry_blocked = true
	check(_mapping(Geometry.snapshot(reordered,state),reordered,&"floor/TOP") == same, "geometry does not implement ShiftPermission")
	# Contract permits synthetic complete collections to test resolution. These
	# candidates come from separate valid snapshots, NOT one valid ambiguous map.
	var alternate := level.duplicate(true)
	alternate.cubes[3].center2 = Vector3i(0,2,0)
	for face in alternate.faces:
		if face.cube_id == &"mirror":
			face.walkable = face.face == Types.FaceDirection.BOTTOM
	var other := _mapping(_snapshot(alternate,state),alternate,&"floor/TOP")
	check(other.status == Types.MappingResolutionStatus.UNIQUE, "independent second target fixture")
	var pair: Array[Dictionary] = [same.mapping,other.mapping]
	var ambiguous := Mapping.resolve_mapping({"ok": true,"candidates": pair,"issues": []})
	pair.reverse()
	check(ambiguous == Mapping.resolve_mapping({"ok": true,"candidates": pair,"issues": []}), "ambiguous canonical order")
	check(ambiguous.status == Types.MappingResolutionStatus.AMBIGUOUS and ambiguous.mapping == null and ambiguous.candidates.size() == 2, "multiple targets never pick first")
	check(ambiguous.issues[0].code == Types.ValidationCode.AMBIGUOUS_SHIFT_MAPPING, "ambiguity uses canonical issue")
	# A real shared Anchor with two internal walkable targets is invalid first.
	var sealed := level.duplicate(true)
	sealed.cubes.append(Fixture.cube(&"sealed_target",1,Vector3i(0,2,0)))
	for face in Geometry.make_face_nodes(&"sealed_target"):
		face.walkable = face.face == Types.FaceDirection.BOTTOM
		sealed.faces.append(face)
	var invalid := _mapping(Geometry.snapshot(sealed,state),sealed,&"floor/TOP")
	check(invalid.status == Types.MappingResolutionStatus.ERROR and _has_code(invalid.issues,1201), "real sealed multiple targets ERROR before resolution")


func _test_lighting_and_slots(level: Dictionary, state: Dictionary) -> void:
	var snapshot := _snapshot(level,state)
	var a := _slot(level,state)
	var blocked := _light(snapshot,&"floor/TOP",a)
	check(blocked.ok and blocked.light_state == Types.LightState.SHADOW and blocked.occluder_id == &"blocker", "real Cube volume occludes")
	var clear := level.duplicate(true)
	clear.cubes[2].center2 = Vector3i(4,4,0)
	var clear_snapshot := _snapshot(clear,state)
	var front := _light(clear_snapshot,&"floor/TOP",a)
	check(front.ok and front.light_state == Types.LightState.LIT, "removing real blocker from ray restores LIT")
	var shared := state.duplicate(true)
	var request := Celestial.resolve_slot_request(level.celestial,shared.celestial.slot_id,Types.CelestialOp.SET_SLOT,&"b",&"")
	check(request.ok and request.changed and shared.celestial.slot_id == &"a", "formal Slot request does not prematurely commit")
	for id in [&"floor/TOP",&"mirror/TOP"]:
		check(_light(clear_snapshot,id,_slot(level,shared)).light_state == Types.LightState.LIT, "both worlds read committed Slot A")
	shared.celestial.slot_id = request.next_slot_id
	check(Data.validate_state_shape(level,shared).is_empty(), "single shared Slot B is valid state")
	for id in [&"floor/TOP",&"mirror/TOP"]:
		var back := _light(clear_snapshot,id,_slot(level,shared))
		check(back.ok and back.light_state == Types.LightState.SHADOW and back.reason == &"BACK_OR_TANGENT", "same Face at Slot B is back-facing SHADOW")
	check(shared.celestial.size() == 1 and shared.celestial.slot_id == &"b", "no separate sun/moon states")
	check(_mapping(clear_snapshot,clear,&"floor/TOP") == _mapping(snapshot,level,&"floor/TOP"), "light change does not change mapping")


func _slot(level: Dictionary, state: Dictionary) -> Dictionary:
	for slot in level.celestial.slots:
		if slot.slot_id == state.celestial.slot_id:
			return slot
	check(false, "committed shared Slot must resolve through formal IDs")
	return {}


func _test_state_key(level: Dictionary, state: Dictionary) -> void:
	var key := StateKey.build(level,state)
	check(key.ok and key.key.begins_with("statekey.v1:"), "real IDs build canonical statekey.v1")
	var permuted := state.duplicate(true)
	for field in ["group_orientations","mechanism_states","level_flags"]:
		var ids: Array = permuted[field].keys()
		ids.reverse()
		var values := {}
		for id in ids:
			values[id] = permuted[field][id]
		permuted[field] = values
	check(StateKey.build(level,permuted) == key, "all nonempty maps ignore insertion order")
	var decoded: Dictionary = JSON.parse_string(key.key.trim_prefix("statekey.v1:"))
	check(decoded.state.size() == 6 and decoded.state.player.location.cube_id == "floor" and decoded.state.player.location.face == "TOP", "key has exact six fields and real face identity")
	var changed := state.duplicate(true)
	changed.player.orientation = Orientation.quarter_turn(0,1)
	check(StateKey.build(level,changed).key != key.key, "formal orientation ID changes key")
	changed = state.duplicate(true)
	changed.celestial.slot_id = &"b"
	check(StateKey.build(level,changed).key != key.key, "formal Slot ID changes key")
	for field in ["RotateTarget","Camera","FaceLightState","AnchorOverlap","ShiftMapping","Connectivity","debug_state","animation_progress"]:
		var invalid := state.duplicate(true)
		invalid[field] = 0
		var result := StateKey.build(level,invalid)
		check(not result.ok and result.key == "" and _has_code(result.issues,1001), "UI/derived state rejected: " + field)
	var visited := {key.key: true}
	visited[StateKey.build(level,permuted).key] = true
	check(visited.size() == 1, "complete String visited identity")


func _test_overflow(level: Dictionary, state: Dictionary) -> void:
	for mode in ["anchor","world","group"]:
		var extreme := level.duplicate(true)
		var rotated := state.duplicate(true)
		if mode == "anchor":
			extreme.cubes[0].center2 = Vector3i(-2147483648,0,0)
		elif mode == "world":
			extreme.worlds[0].pivot2 = Vector3i(2147483646,0,0)
			rotated.world_orientations[0] = 4
		else:
			extreme.groups[0].pivot2 = Vector3i(2147483646,0,0)
			rotated.group_orientations[&"alpha"] = 4
		check(Data.validate_state_shape(extreme,rotated).is_empty(), "extreme coordinates are valid DATA input: " + mode)
		var result := Geometry.snapshot(extreme,rotated)
		check(not result.ok and result.value == null and _has_code(result.issues,1105), "real Spatial atomic overflow: " + mode)
		var mapping := _mapping(result,extreme,&"floor/TOP")
		check(mapping.status == Types.MappingResolutionStatus.ERROR and mapping.mapping == null and mapping.candidates.is_empty() and mapping.issues == result.issues, "Mapping preserves exact upstream1105: " + mode)
		var before := light_calls
		var light := _light(result,&"floor/TOP",level.celestial.slots[0])
		check(not light.ok and light.light_state == null and light.issues == result.issues and light_calls == before, "failed snapshot never calls production Lighting: " + mode)


func _has_code(issues: Array, code: int) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false
