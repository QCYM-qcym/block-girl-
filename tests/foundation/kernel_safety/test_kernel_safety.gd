extends SceneTree
## Real owner integration. No Safety double, source rewriting, or injected results.
## Detects fail-open handling, partial state commits and lost diagnostic domains.
const K = preload("res://foundation/rules/puzzle_rule_kernel.gd")
const RR = preload("res://foundation/rules/rule_records.gd")
const S = preload("res://foundation/validation/safety_queries.gd")
const V = preload("res://foundation/validation/static_validator.gd")
const R = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const G = preload("res://foundation/spatial/surface_geometry.gd")
const F = preload("res://tests/foundation/rules/kernel_fixture.gd")
const VF = preload("res://tests/foundation/validation/validation_fixture.gd")
var checks := 0
var failures: Array[String] = []
var sections: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL: ", label)

func has_code(result: Dictionary, code: int) -> bool:
	for issue in result.issues:
		if issue.code == code: return true
	return false

func action_result(level: Dictionary, state: Dictionary, action: Dictionary, status: int, rejection: int, label: String, context: Dictionary = {}) -> Dictionary:
	var ctx := RR.idle_context() if context.is_empty() else context
	var saved := var_to_bytes([level,state,action,ctx])
	var key := Key.build(level,state)
	var result := K.evaluate_action(level,state,action,ctx)
	check(var_to_bytes([level,state,action,ctx]) == saved, label + " all input bytes unchanged")
	check(Key.build(level,state) == key, label + " StateKey unchanged")
	check(result.status == status, label + " status: " + str(result))
	check(result.rejection_code == rejection, label + " canonical rejection domain")
	check(result.previous_state == state and result.action == action, label + " original records retained")
	if status != 0:
		check(result.next_state == null and not result.changed and result.global_kind == 0, label + " all-or-nothing rejection")
	else:
		check(result.next_state is Dictionary and result.next_state.size() == 6 and Key.build(level,result.next_state).ok, label + " complete six-field next state")
		check(result.issues.is_empty(), label + " clean applied result")
	for issue in result.issues:
		check(issue.code < 2000, label + " ValidationIssue never contains ActionRejectionCode 2000+")
	return result

func preserved(upstream: Dictionary, result: Dictionary, label: String) -> void:
	check(not upstream.issues.is_empty(), label + " meaningful upstream diagnostic")
	for issue in upstream.issues:
		check(result.issues.has(issue), label + " code/severity/path/IDs/details preserved")

func added_cube(level: Dictionary, id: StringName, center: Vector3i) -> void:
	level.cubes.append(F.cube(id,0,center))
	for face in G.make_face_nodes(id):
		face.walkable = false
		level.faces.append(face)

func local_after(before: Dictionary) -> Dictionary:
	var after := before.duplicate(true)
	after.player.location.cube_id = &"step"
	after.player.orientation = 12
	return after

func _initialize() -> void:
	for section in [test_state_and_budget,test_motion,test_rotations,test_face_transition,test_concurrent]:
		var start := checks
		section.call()
		sections[String(section.get_method())] = checks - start
	print("KERNEL_SAFETY_INTEGRATION checks=", checks, " failures=", failures, " sections=", sections)
	if failures.is_empty(): print("KERNEL_SAFETY_REAL_SUITE_PASS")
	quit(0 if failures.is_empty() else 1)

func test_state_and_budget() -> void:
	var level := F.make_level(true)
	var state := R.initial_state(level)
	check(S.validate_state(level,state).status == 0, "real stable state SAFE")
	action_result(level,state,{"kind":2,"rotation_delta":2},0,0,"SAFE state continues World rotate")
	F.face(level,&"floor/TOP").walkable = false
	var unsafe := S.validate_state(level,state)
	check(unsafe.status == 1 and has_code(unsafe,1204), "nonwalkable current support UNSAFE1204")
	var failed := action_result(level,state,{"kind":2,"rotation_delta":2},2,0,"unsafe current state blocks dangerous World rotate")
	preserved(unsafe,failed,"state Safety propagation")
	level = VF.make_level()
	var valid := V.validate(level,{"max_configurations":4096,"max_checks":100000})
	check(valid.status == 0 and valid.issues.is_empty(), "Static VALID on minimal canonical fixture")
	var incomplete := V.validate(level,{"max_configurations":1,"max_checks":1})
	check(incomplete.status == 2 and has_code(incomplete,1600), "Static budget yields INCOMPLETE1600, never VALID")
	VF.rebuild_faces(level,[])
	var invalid := V.validate(level,{"max_configurations":4096,"max_checks":100000})
	check(invalid.status == 1 and has_code(invalid,1204), "Static INVALID is distinct from Safety UNSAFE")
	# validate_state is exhaustive for one stable configuration and has no
	# budget/UNPROVEN branch. Its defensive UNPROVEN consumer test lives in
	# the explicitly marked Kernel -UnitDouble suite, never this real suite.

func test_motion() -> void:
	var level := F.make_level(true)
	var before := R.initial_state(level)
	var after := local_after(before)
	var move := {"kind":0,"face_axis":0}
	var original := var_to_bytes([level,before,after,move])
	check(S.validate_motion(level,before,after,move).status == 0, "real two-support roll SAFE")
	check(var_to_bytes([level,before,after,move]) == original, "Safety motion inputs immutable")
	var applied := action_result(level,before,move,0,0,"SAFE motion applies MOVE")
	check(applied.next_state == after, "MOVE exact player pose12 and complete state")
	var returned := action_result(level,after,{"kind":0,"face_axis":2},0,0,"real reverse MOVE")
	check(returned.next_state == before, "real round trip restores full PuzzleState")
	level = F.make_level()
	var uncertain := S.validate_motion(level,before,after,move)
	check(uncertain.status == 2 and has_code(uncertain,1601), "third support produces real UNPROVEN")
	var rejected := action_result(level,before,move,1,2000,"UNPROVEN motion blocks MOVE")
	preserved(uncertain,rejected,"motion uncertainty propagation")
	level = F.make_level(true)
	F.face(level,&"step/TOP").walkable = false
	var unsafe := S.validate_motion(level,before,after,move)
	check(unsafe.status == 1 and has_code(unsafe,1204), "unsafe motion endpoint returns UNSAFE")
	action_result(level,before,move,1,2000,"nonwalkable target cannot become a transaction")
	level = F.make_level(true)
	after.player.orientation = 9
	var bad := S.validate_motion(level,before,after,move)
	check(bad.status == 3 and has_code(bad,1502), "wrong endpoint pose is Safety ERROR")

func test_rotations() -> void:
	var level := F.group_level(true)
	var before := R.initial_state(level)
	var action: Dictionary = level.mechanisms[1].action
	var after := before.duplicate(true)
	after.group_orientations.bridge = 2
	after.player.orientation = 2
	check(S.validate_motion(level,before,after,action).status == 0, "real carried Group rotation SAFE")
	var applied := action_result(level,before,action,0,0,"Group and player rotate atomically")
	check(applied.next_state == after, "Group result exact full state")
	added_cube(level,&"overhead",Vector3i(0,4,0))
	check(S.validate_state(level,before).status == 0 and S.validate_state(level,after).status == 0, "Group sweep uncertainty has safe endpoints")
	var unproven := S.validate_motion(level,before,after,action)
	check(unproven.status == 2 and has_code(unproven,1601), "real Group sweep UNPROVEN")
	var rejected := action_result(level,before,action,1,2002,"unproven Group changes neither Group nor player")
	preserved(unproven,rejected,"Group Safety propagation")
	level = F.make_level(true)
	before = R.initial_state(level)
	level.worlds[0].pivot2 = Vector3i(1073741824,0,0)
	action = {"kind":2,"rotation_delta":22}
	after = before.duplicate(true)
	after.world_orientations[0] = 22
	after.player.orientation = 22
	var overflow := S.validate_motion(level,before,after,action)
	check(overflow.status == 3 and has_code(overflow,1105), "real World swept arithmetic overflow ERROR1105")
	var failed := action_result(level,before,action,2,0,"World motion overflow rolls back orientation and player")
	preserved(overflow,failed,"World1105 propagation")

func test_face_transition() -> void:
	var level := F.make_level(true)
	var before := R.initial_state(level)
	var after := before.duplicate(true)
	after.player.location.face = 0
	after.player.orientation = 2
	var action := {"kind":4,"transition_id":&"tip"}
	check(S.validate_motion(level,before,after,action).status == 0, "real three-segment FaceTransition SAFE")
	var applied := action_result(level,before,action,0,0,"real FaceTransition success")
	check(applied.next_state == after, "FaceTransition exact endpoint and pose")
	added_cube(level,&"transport_obstacle",Vector3i(0,6,0))
	var uncertain := S.validate_motion(level,before,after,action)
	check(uncertain.status == 2 and has_code(uncertain,1601), "real FaceTransition swept path UNPROVEN")
	var rejected := action_result(level,before,action,1,2003,"unproven FaceTransition has no player half-update")
	preserved(uncertain,rejected,"FaceTransition issue propagation")

func test_concurrent() -> void:
	var level := F.group_level(true)
	var before := R.initial_state(level)
	var move := {"kind":0,"face_axis":0}
	var global_action: Dictionary = level.mechanisms[1].action
	global_action.rotation_delta = 22
	var local := local_after(before)
	var global := before.duplicate(true)
	global.group_orientations.bridge = 22
	global.player.orientation = 22
	check(S.validate_concurrent_motion(level,before,local,global,move,global_action).status == 0, "real concurrent Group roll SAFE")
	var prepared := action_result(level,before,global_action,0,0,"prepare real concurrent Group")
	var opened := RR.begin_global(level,prepared)
	check(opened.ok, "open only accepted transaction")
	if opened.ok:
		action_result(level,before,move,0,0,"real concurrent SAFE permits local MOVE",opened.context)
	# Frozen §16.1 counterexample: single motions are safe; their combined
	# envelope meets (4,4,4), so serial checks alone cannot authorize busy MOVE.
	for cube in level.cubes:
		if cube.cube_id == &"floor": cube.center2 = Vector3i(4,0,0)
		if cube.cube_id == &"step": cube.center2 = Vector3i(6,0,0)
		if cube.cube_id == &"goal": cube.center2 = Vector3i(30,0,0)
	added_cube(level,&"concurrent_obstacle",Vector3i(4,4,4))
	check(S.validate_motion(level,before,local,move).status == 0, "counterexample local motion SAFE")
	check(S.validate_motion(level,before,global,global_action).status == 0, "counterexample global motion SAFE")
	var inputs := var_to_bytes([level,before,local,global,move,global_action])
	var uncertain := S.validate_concurrent_motion(level,before,local,global,move,global_action)
	check(var_to_bytes([level,before,local,global,move,global_action]) == inputs, "concurrent query all inputs immutable")
	check(uncertain.status == 2 and has_code(uncertain,1601), "real concurrent combination UNPROVEN")
	prepared = action_result(level,before,global_action,0,0,"independent global still admissible")
	opened = RR.begin_global(level,prepared)
	if opened.ok:
		var rejected := action_result(level,before,move,1,1504,"concurrent UNPROVEN fail-safe",opened.context)
		preserved(uncertain,rejected,"concurrent Safety issue propagation")
		check(opened.context.local_moves.is_empty(), "rejected busy MOVE creates no trace or queue")
	else:
		check(false,"counterexample requires valid accepted global ticket")
	# Unsafe local endpoints short-circuit the real concurrent query. The
	# Kernel likewise refuses to create that local transaction before proof.
	level = F.group_level(true)
	global_action = level.mechanisms[1].action
	global.group_orientations.bridge = 2
	global.player.orientation = 2
	F.face(level,&"step/TOP").walkable = false
	var unsafe := S.validate_concurrent_motion(level,before,local,global,move,global_action)
	check(unsafe.status == 1 and has_code(unsafe,1204), "real concurrent unsafe endpoint returns UNSAFE")
	prepared = action_result(level,before,global_action,0,0,"prepare global with nonwalkable local destination")
	opened = RR.begin_global(level,prepared)
	if opened.ok:
		action_result(level,before,move,1,2000,"unsafe local target creates no busy mutation",opened.context)
