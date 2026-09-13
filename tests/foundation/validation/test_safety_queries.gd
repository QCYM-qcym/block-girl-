extends SceneTree
const Safety = preload("res://foundation/validation/safety_queries.gd")
const Fixture = preload("res://tests/foundation/validation/validation_fixture.gd")
const Orientation = preload("res://foundation/orientation/discrete_orientation.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL: " + label)
func has_code(result: Dictionary, code: int) -> bool:
	for issue in result.issues:
		if issue.code == code:
			return true
	return false
func _initialize() -> void:
	var level := Fixture.make_level()
	var state := Records.initial_state(level)
	check(Safety.validate_state(level,state).status == 0, "support contact safe")
	var saved := level.duplicate(true)
	var saved_state := state.duplicate(true)
	Safety.validate_state(level,state)
	check(level == saved and state == saved_state, "state query immutable")
	var cross := level.duplicate(true)
	cross.cubes.append(Fixture.cube(&"other",1,Vector3i(0,2,0)))
	Fixture.rebuild_faces(cross)
	check(Safety.validate_state(cross,state).status == 0, "cross-world body ignored")
	var blocked := level.duplicate(true)
	blocked.cubes.append(Fixture.cube(&"block",0,Vector3i(0,2,0)))
	Fixture.rebuild_faces(blocked)
	check(Safety.validate_state(blocked,state).status == 1, "sealed support unsafe")
	check(has_code(Safety.validate_state(blocked,state),1204), "sealed support preserves player penetration diagnostic")
	var nonwalkable := level.duplicate(true)
	Fixture.rebuild_faces(nonwalkable,[])
	check(has_code(Safety.validate_state(nonwalkable,state),1204), "nonwalkable unsafe")
	var bad := state.duplicate(true)
	bad.player.location.cube_id = &"missing"
	check(has_code(Safety.validate_state(level,bad),1006), "bad reference preserved")
	var extreme := level.duplicate(true)
	extreme.cubes[0].center2 = Vector3i(0,2147483646,0)
	check(has_code(Safety.validate_state(extreme,state),1105), "player anchor plus normal overflow")
	test_motion()
	test_defensive_queries()
	test_review_regressions()
	print("SAFETY CHECKS: %s; FAILURES: %s" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func state_for(level: Dictionary, cube: StringName = &"floor", face: int = 4, orientation: int = 0) -> Dictionary:
	var state := Records.initial_state(level)
	state.player = Records.make_player_state(Records.make_player_location(0,cube,face),orientation)
	return state
func rotated(before: Dictionary, delta: int, layer: int = 0, group: StringName = &"") -> Dictionary:
	var after := before.duplicate(true)
	if group == &"":
		after.world_orientations[layer] = Orientation.compose(delta,before.world_orientations[layer])
	else:
		after.group_orientations[group] = Orientation.compose(delta,before.group_orientations[group])
	after.player.orientation = Orientation.compose(delta,before.player.orientation)
	return after
func rotate_action(delta: int, layer: int = 0, group: StringName = &"") -> Dictionary:
	return Records.make_action(2 if layer == 0 else 3,{"rotation_delta":delta}) if group == &"" else Records.make_action(6,{"group_id":group,"rotation_delta":delta,"mechanism_id":&"probe"})
func roll_level(offset: int = 0) -> Dictionary:
	var level := Fixture.make_level()
	level.cubes[0].center2 = Vector3i(offset,0,0)
	level.cubes.append(Fixture.cube(&"next",0,Vector3i(offset+2,0,0)))
	Fixture.rebuild_faces(level,[&"floor/TOP",&"next/TOP"])
	return level
func grouped(level: Dictionary, members: Array) -> void:
	level.groups = [Fixture.group(&"carrier",0,members)]
	for cube in level.cubes:
		if cube.cube_id in members:
			cube.group_id = &"carrier"
func test_motion() -> void:
	var level := Fixture.make_level()
	level.worlds[0].allowed_states = range(24)
	var before := state_for(level)
	for delta in [2,3,22,18,9,12]:
		for pose in range(24):
			before.player.orientation = pose
			check(Safety.validate_motion(level,before,rotated(before,delta),rotate_action(delta)).status == 0,"all signed World quarter-turns and poses safe")
	before.player.orientation = 0
	var malformed := rotate_action(2)
	malformed["extra"] = true
	check(has_code(Safety.validate_motion(level,before,rotated(before,2),malformed),1001),"unknown motion field rejected")
	var altered := rotated(before,2)
	altered.player.orientation = 0
	check(has_code(Safety.validate_motion(level,before,altered,rotate_action(2)),1502),"rotation cannot claim incorrect carried pose")
	var far := level.duplicate(true)
	far.worlds[0].pivot2 = Vector3i(1073741824,0,0)
	far.cubes[0].center2 = Vector3i(2,0,0)
	check(has_code(Safety.validate_motion(far,before,rotated(before,22),rotate_action(22)),1105),"checked conservative sweep range overflow")
	var roll := roll_level()
	before = state_for(roll)
	var after := state_for(roll,&"next",4,12)
	var move := Records.make_action(0,{"face_axis":0})
	check(Safety.validate_motion(roll,before,after,move).status == 0,"real support-edge roll safe")
	var wrong := after.duplicate(true)
	wrong.player.orientation = 9
	check(has_code(Safety.validate_motion(roll,before,wrong,move),1502),"wrong roll pose rejected")
	var high := roll.duplicate(true)
	high.cubes.append(Fixture.cube(&"obstacle",0,Vector3i(0,4,0)))
	Fixture.rebuild_faces(high,[&"floor/TOP",&"next/TOP"])
	var uncertain := Safety.validate_motion(high,before,after,move)
	check(uncertain.status == 2 and has_code(uncertain,1601),"endpoint-safe roll enclosure unresolved")
	var saved := roll.duplicate(true)
	var saved_before := before.duplicate(true)
	var saved_after := after.duplicate(true)
	Safety.validate_motion(roll,before,after,move)
	check(roll == saved and before == saved_before and after == saved_after,"motion query immutable")
	var carrier := roll.duplicate(true)
	grouped(carrier,[&"floor",&"next"])
	before = state_for(carrier)
	after = state_for(carrier,&"next",4,12)
	var global := rotated(before,22,0,&"carrier")
	var action := rotate_action(22,0,&"carrier")
	check(Safety.validate_motion(carrier,before,global,action).status == 0,"rigid Group player carried")
	check(Safety.validate_concurrent_motion(carrier,before,after,global,move,action).status == 0,"carried concurrent roll positively proven")
	var combined := roll_level(4)
	grouped(combined,[&"floor",&"next"])
	combined.cubes.append(Fixture.cube(&"obstacle",0,Vector3i(4,4,4)))
	Fixture.rebuild_faces(combined,[&"floor/TOP",&"next/TOP"])
	before = state_for(combined)
	after = state_for(combined,&"next",4,12)
	global = rotated(before,22,0,&"carrier")
	check(Safety.validate_motion(combined,before,after,move).status == 0,"serial local example safe")
	check(Safety.validate_motion(combined,before,global,action).status == 0,"serial global example safe")
	check(Safety.validate_concurrent_motion(combined,before,after,global,move,action).status == 2,"(4,4,4) concurrent obstruction cannot pass")
	var outside := roll_level()
	outside.cubes.append(Fixture.cube(&"moving",0,Vector3i(12,0,0)))
	grouped(outside,[&"moving"])
	Fixture.rebuild_faces(outside,[&"floor/TOP",&"next/TOP"])
	before = state_for(outside)
	after = state_for(outside,&"next",4,12)
	global = rotated(before,22,0,&"carrier")
	global.player = before.player.duplicate(true)
	outside.groups[0].pivot2 = Vector3i(12,0,0)
	check(Safety.validate_concurrent_motion(outside,before,after,global,move,action).status == 0,"outside Group player roll stays Shared Space")
	outside.groups[0].pivot2 = Vector3i.ZERO
	check(Safety.validate_motion(outside,before,global,action).status == 2,"noncarried player obstructs Group enclosure")
	var other := roll_level()
	other.cubes.append(Fixture.cube(&"inner",1,Vector3i.ZERO))
	other.worlds[1].allowed_states = range(24)
	Fixture.rebuild_faces(other,[&"floor/TOP",&"next/TOP"])
	before = state_for(other)
	after = state_for(other,&"next",4,12)
	global = rotated(before,22,1)
	global.player = before.player.duplicate(true)
	check(Safety.validate_concurrent_motion(other,before,after,global,move,rotate_action(22,1)).status == 0,"other-world rotation reduces to ordinary roll")

	# A canonical celestial action is geometric no-op irrespective of provenance.
	var celestial := Records.make_action(7,{"celestial_op":0,"target_slot_id":&"a","alternate_slot_id":&"","mechanism_id":&"probe"})
	check(Safety.validate_concurrent_motion(other,before,after,before,move,celestial).status == 0,"celestial concurrent effect reduces to roll")
	# Shared-space conjugation belongs to real Orientation, never an alternate table.
	var reframed := Fixture.make_level()
	grouped(reframed,[&"floor"])
	reframed.worlds[0].allowed_states = range(24)
	before = state_for(reframed)
	before.world_orientations[0] = 9
	global = before.duplicate(true)
	global.group_orientations[&"carrier"] = 2
	var shared_delta := Orientation.compose(9,Orientation.compose(2,Orientation.inverse(9)))
	global.player.orientation = shared_delta
	check(Safety.validate_motion(reframed,before,global,rotate_action(2,0,&"carrier")).status == 0,"Group delta conjugated through World")
	var crossing := roll_level()
	grouped(crossing,[&"floor"])
	before = state_for(crossing)
	after = state_for(crossing,&"next",4,12)
	global = rotated(before,22,0,&"carrier")
	# Endpoints are safe, but the roll leaves its moving support carrier.
	check(Safety.validate_concurrent_motion(crossing,before,after,global,move,rotate_action(22,0,&"carrier")).status != 0,"cannot certify roll leaving concurrent carrier")
	for step in [2,3]:
		var transport := Fixture.make_level()
		var target_face := 0 if step == 2 else 1
		var target_id := Geometry.face_id(&"floor",target_face)
		Fixture.rebuild_faces(transport,[&"floor/TOP",target_id])
		transport.face_transitions = [{"transition_id":&"around","source_face_id":&"floor/TOP","target_face_id":target_id,"entry_axis":0,"exit_axis":0 if step == 2 else 2,"rotation_steps":[step],"required_flags":[]}]
		check(Data.validate_level_shape(transport).is_empty(),"transport fixture is canonical real DATA")
		before = state_for(transport)
		after = state_for(transport,&"floor",target_face,step)
		var transition_action := Records.make_action(4,{"transition_id":&"around"})
		check(Safety.validate_motion(transport,before,after,transition_action).status == 0,"outward/radius4/inward transport safe signed path")
		transport.cubes.append(Fixture.cube(&"obstacle",0,Vector3i(0,6,0)))
		Fixture.rebuild_faces(transport,[&"floor/TOP",target_id])
		check(Safety.validate_motion(transport,before,after,transition_action).status == 2,"transport sweep cannot exempt unrelated Cube")

func test_defensive_queries() -> void:
	var level := Fixture.make_level()
	var before := state_for(level)
	var bad := before.duplicate(true)
	bad.erase("celestial")
	check(has_code(Safety.validate_state(level,bad),1002),"malformed state missing field preserved")
	bad = before.duplicate(true)
	bad.player.orientation = 24
	check(has_code(Safety.validate_state(level,bad),1101),"malformed pose preserved")
	var action := Records.make_action(0,{"face_axis":4})
	check(has_code(Safety.validate_motion(level,before,before,action),1003),"malformed face axis rejected")
	action = Records.make_action(6,{"group_id":&"missing","rotation_delta":2,"mechanism_id":&"probe"})
	check(has_code(Safety.validate_motion(level,before,before,action),1006),"unknown geometric group ref retained")
	action = Records.make_action(6,{"group_id":&"missing","rotation_delta":2,"mechanism_id":&""})
	check(has_code(Safety.validate_motion(level,before,before,action),1004),"missing provenance ID cannot masquerade as canonical action")
	var blocked := Fixture.make_level()
	blocked.cubes.append(Fixture.cube(&"block",0,Vector3i(0,0,2)))
	grouped(blocked,[&"block"])
	Fixture.rebuild_faces(blocked)
	before = state_for(blocked)
	var after := before.duplicate(true)
	after.group_orientations[&"carrier"] = 3
	var hit := Safety.validate_motion(blocked,before,after,rotate_action(3,0,&"carrier"))
	check(hit.status == 1 and has_code(hit,1201) and has_code(hit,1204),"rotation endpoint retains sealed and actual player penetration")
	var saved_before := before.duplicate(true)
	var saved_after := after.duplicate(true)
	var second := Safety.validate_motion(blocked,before,after,rotate_action(3,0,&"carrier"))
	hit.issues[0].details["edited"] = true
	hit.issues[0].entity_ids.clear()
	check(second == Safety.validate_motion(blocked,before,after,rotate_action(3,0,&"carrier")),"returned issues have independent ownership")
	check(before == saved_before and after == saved_after,"unsafe queries preserve both input states")
	var transport := Fixture.make_level()
	Fixture.rebuild_faces(transport,[&"floor/TOP",&"floor/BOTTOM"])
	transport.face_transitions = [{"transition_id":&"around","source_face_id":&"floor/TOP","target_face_id":&"floor/BOTTOM","entry_axis":0,"exit_axis":0,"rotation_steps":[2,2],"required_flags":[]}]
	before = state_for(transport)
	after = state_for(transport,&"floor",5,1)
	action = Records.make_action(4,{"transition_id":&"around"})
	check(Safety.validate_motion(transport,before,after,action).status == 0,"multistep transport across nonwalkable intermediate face")
	transport.face_transitions[0].exit_axis = 2
	check(has_code(Safety.validate_motion(transport,before,after,action),1203),"transport cumulative entry exit axes enforced")
	transport.face_transitions[0].rotation_steps = [22]
	check(has_code(Safety.validate_motion(transport,before,after,action),1203),"transport spin on normal is not face crossing")
	for extreme in [2147483646,-2147483646]:
		var near_limit := Fixture.make_level()
		near_limit.cubes[0].center2 = Vector3i(0,extreme,0)
		Fixture.rebuild_faces(near_limit,[&"floor/TOP",&"floor/BOTTOM"])
		before = state_for(near_limit,&"floor",4 if extreme > 0 else 5)
		var failure := Safety.validate_state(near_limit,before)
		check(failure.status == 3 and has_code(failure,1105),"signed player volume overflow is ERROR")
	var far_pivot := Fixture.make_level()
	far_pivot.worlds[0].allowed_states = range(24)
	for coordinate in [2147483647,-2147483648]:
		far_pivot.worlds[0].pivot2 = Vector3i(coordinate,0,0)
		before = state_for(far_pivot)
		for delta in [2,3]:
			check(Safety.validate_motion(far_pivot,before,rotated(before,delta),rotate_action(delta)).status == 0,"extreme pivot along axis cancels exactly for both signs")

func test_review_regressions() -> void:
	var level := Fixture.make_level()
	grouped(level,[&"floor"])
	level.cubes.append(Fixture.cube(&"inner",1,Vector3i.ZERO))
	Fixture.rebuild_faces(level,[&"floor/TOP",&"inner/TOP"])
	var before := state_for(level)
	var after := before.duplicate(true)
	after.player.location = Records.make_player_location(1,&"inner",4)
	var shift := Records.make_action(1,{})
	check(Safety.validate_motion(level,before,after,shift).status == 0,"fixed physical geometry allows cross-layer exchange")
	after.group_orientations[&"carrier"] = 22
	check(has_code(Safety.validate_motion(level,before,after,shift),1502),"SHIFT cannot conceal a Group geometry change")
	check(has_code(Safety.validate_motion(level,before,before,shift),1502),"SHIFT requires an actual layer exchange")
	var extreme := Fixture.make_level()
	extreme.cubes[0].center2 = Vector3i(0,2147483646,0)
	extreme.cubes.append(Fixture.cube(&"a",0,Vector3i.ZERO))
	extreme.cubes.append(Fixture.cube(&"b",0,Vector3i.ZERO))
	Fixture.rebuild_faces(extreme)
	var overflow := Safety.validate_state(extreme,state_for(extreme))
	check(overflow.status == 3 and has_code(overflow,1105) and has_code(overflow,1200),"player overflow retains independent structural issue")
	var transport := Fixture.make_level()
	transport.cubes.append(Fixture.cube(&"obstacle",0,Vector3i(0,6,0)))
	Fixture.rebuild_faces(transport,[&"floor/TOP",&"floor/FRONT"])
	transport.face_transitions = [{"transition_id":&"around","source_face_id":&"floor/TOP","target_face_id":&"floor/FRONT","entry_axis":0,"exit_axis":0,"rotation_steps":[2],"required_flags":[]}]
	before = state_for(transport)
	after = state_for(transport,&"floor",0,0)
	var action := Records.make_action(4,{"transition_id":&"around"})
	var wrong := Safety.validate_motion(transport,before,after,action)
	check(wrong.status == 3 and has_code(wrong,1203),"obstacle uncertainty cannot hide wrong transport endpoint pose")
	transport.face_transitions[0].rotation_steps = [2,9]
	after.player.orientation = Orientation.compose(9,2)
	wrong = Safety.validate_motion(transport,before,after,action)
	check(wrong.status == 3 and has_code(wrong,1203),"early obstacle uncertainty cannot hide later step spinning on normal")
