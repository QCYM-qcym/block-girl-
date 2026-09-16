extends SceneTree
## End-to-end consumer of the pinned, unmodified 3A public BFSSolver/Trace APIs.
## No trace builder, search implementation, Runtime override or input simulation.
const Solver = preload("res://foundation/solver/bfs_solver.gd")
const Trace = preload("res://foundation/solver/solution_trace.gd")
const Search = preload("res://foundation/solver/search_records.gd")
const Reader = preload("res://foundation/level/authoring_reader.gd")
const Baker = preload("res://foundation/level/level_baker.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Driver = preload("res://foundation/parity/trace_replayer.gd")
const SOLVER_COMMIT = "f34dd271adabcc4b724eb55b5fff1cb35f532e59"
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var evidence := "res://.godot/foundation-3d/real_trace_manual"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func make_level(name: String) -> Dictionary:
	var authoring_scene: Node3D = load("res://tools/foundation/level/runtime_authoring.tscn").instantiate()
	var read := Reader.read_scene(authoring_scene)
	authoring_scene.free()
	check(read.ok, name + ": real authoring Reader")
	if not read.ok: return {}
	var authoring: Dictionary = read.authoring
	if name == "zero": authoring.goal.face_id = &"s0/TOP"
	if name == "one": authoring.goal.face_id = &"s1/TOP"
	if name == "composite":
		authoring.goal.face_id = &"s1/FRONT"
		authoring.worlds[0].allowed_states = [0]
		authoring.worlds[0].allowed_rotation_deltas = []
		authoring.worlds[0].allowed_rotation_intents = []
		for face in authoring.faces:
			if face.face_id == &"s1/FRONT": face.walkable = true
			if face.face_id == &"s1/TOP": face.mechanism_ids = [&"plate"]
		authoring.mechanisms = [{"mechanism_id": &"plate", "face_id": &"s1/TOP", "trigger": &"ENTER",
			"action": {"kind": 4, "transition_id": &"tip"}, "priority": 0, "initial_state": &"ready", "allowed_states": [&"ready"]}]
		authoring.face_transitions = [{"transition_id": &"tip", "source_face_id": &"s1/TOP", "target_face_id": &"s1/FRONT",
			"entry_axis": 0, "exit_axis": 0, "rotation_steps": [2], "required_flags": []}]
	var baked := Baker.bake(authoring, {"max_configurations":4096,"max_checks":100000})
	check(baked.ok and baked.validation.status == 0, name + ": real Baker / Validator VALID")
	return baked.level if baked.ok else {}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	var graphical := DisplayServer.get_name() != "headless"
	var mode := 1 if graphical else 0
	var stage: Node = load("res://tests/foundation/parity/parity_replay_scene.tscn").instantiate() if graphical else Node.new()
	root.add_child(stage)
	var driver := Driver.new()
	stage.add_child(driver)
	for name in ["zero", "one", "route", "composite"]:
		var level := make_level(name)
		if level.is_empty(): continue
		var policy := Search.default_policy(0)
		var budget := Search.default_budget()
		var solved := Solver.solve(level, Records.initial_state(level), policy, budget)
		check(solved.status == 0 and solved.solution_trace is Dictionary, name + ": formal BFSSolver SOLVED")
		if solved.status != 0:
			cases.append({"name":name,"solver":solved})
			continue
		var trace: Dictionary = solved.solution_trace
		var verified := Trace.validate_semantics(level, trace)
		check(verified.ok and verified.transitions.size() == trace.total_actions, name + ": formal validate_semantics verifies entire trace")
		check(trace.shortest, name + ": actual solver witness, shortest flag supplied by 3A")
		var original := trace.duplicate(true)
		if graphical: stage.show_evidence("Real 3A trace: " + name, {"actions":trace.total_actions,"solver_commit":SOLVER_COMMIT})
		var result: Dictionary = await driver.replay(level, trace, {"mode":mode})
		check(result.status == 0 and result.matched_steps == trace.total_actions, name + ": real Solver to production Runtime MATCH")
		check(result.actual_statekey == trace.goal_statekey and result.expected_statekey == trace.goal_statekey, name + ": canonical full endpoint key")
		check(driver._session.commit_count == trace.total_actions, name + ": exactly one commit per semantic action")
		check(trace == original, name + ": input trace unchanged")
		for step in driver._step_evidence:
			check(step.expected_statekey == step.actual_statekey and step.commit_delta == 1 and step.commit_signals == 1, name + ": step key and authoritative commit parity")
		if name == "zero": check(trace.total_actions == 0, "zero: actual Solver zero-step Goal")
		if name == "one": check(trace.total_actions == 1 and trace.steps[0].action == {"kind":0,"face_axis":0}, "one: literal MOVE witness")
		if name == "route":
			check(trace.total_actions == 3, "route: three-action shortest route")
			check(trace.steps.map(func(s:Dictionary)->int:return s.action.kind) == [0,2,1], "route: MOVE / world rotate / Shadow Shift")
			check(driver._step_evidence.map(func(s:Dictionary)->bool:return s.is_global) == [false,true,true], "route: correct local/global completions")
		if name == "composite":
			check(trace.total_actions == 1 and trace.steps[0].action.kind == 0 and trace.steps[0].global_kind == 5, "composite: real Solver atomic MOVE+ENTER")
			check(not driver._step_evidence[0].is_global, "composite: FaceTransition effect still completes local token")
		cases.append({"name":name,"solver_metrics":solved.metrics,"policy":trace.policy_descriptor,"budget":budget,
			"trace":trace.duplicate(true),"semantics":verified,"result":result,"steps":driver._step_evidence.duplicate(true)})
		if name == "route": await negatives(driver, level, trace, mode)
	stage.free()
	var suffix := "graphical" if graphical else "logical"
	FileAccess.open(evidence.path_join("real_trace_"+suffix+".json"),FileAccess.WRITE).store_string(JSON.stringify({
		"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"solver_commit":SOLVER_COMMIT,
		"trace_source":"formal BFSSolver.solve","trace_semantics":"formal SolutionTrace.validate_semantics","cases":cases},"\t"))
	print("FOUNDATION_PARITY_REAL_TRACE_",suffix.to_upper(),"_","PASS" if failures.is_empty() else "FAIL"," checks=",checks)
	quit(0 if failures.is_empty() else 1)

func negatives(driver: Node, level: Dictionary, trace: Dictionary, mode: int) -> void:
	var wrong := trace.duplicate(true)
	wrong.steps[1].expected_state.player.orientation = 0
	wrong.steps[1].resulting_statekey = Key.build(level,wrong.steps[1].expected_state).key
	check(Trace.validate(level,wrong).ok and not Trace.validate_semantics(level,wrong).ok, "forged intermediate: structure valid, real semantic validator rejects")
	var result: Dictionary = await driver.replay(level,wrong,{"mode":mode})
	check(result.status == 1 and result.divergence_step == 2 and result.matched_steps == 1, "real Trace validator: first divergence at second action")
	check(result.expected_statekey != result.actual_statekey and result.action == wrong.steps[1].action and not result.issues.is_empty(), "real divergence includes exact action, full keys and issues")
	cases.append({"name":"wrong_expected","result":result,"steps":driver._step_evidence.duplicate(true)})
	var tail := trace.duplicate(true)
	tail.initial_state = tail.steps[0].expected_state.duplicate(true)
	tail.initial_statekey = tail.steps[0].resulting_statekey
	tail.steps.pop_front()
	tail.total_actions = tail.steps.size()
	for i in tail.steps.size(): tail.steps[i].index = i+1
	check(Trace.validate_semantics(level,tail).ok, "nonspawn suffix remains real semantic trace")
	result = await driver.replay(level,tail,{"mode":mode})
	check(result.status == 2 and result.issues[0].code == 3013 and driver._session == null, "real nonspawn trace refused before Runtime creation")
	cases.append({"name":"nonspawn","result":result})
