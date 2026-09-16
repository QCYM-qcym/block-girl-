extends SceneTree
## Final four-owner chain. Only public production APIs produce graphs and traces.
const Solver = preload("res://foundation/solver/bfs_solver.gd")
const Search = preload("res://foundation/solver/search_records.gd")
const Graph = preload("res://foundation/solver/state_graph.gd")
const Trace = preload("res://foundation/solver/solution_trace.gd")
const Actions = preload("res://foundation/solver/action_generator.gd")
const Kernel = preload("res://foundation/rules/puzzle_rule_kernel.gd")
const Rules = preload("res://foundation/rules/rule_records.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
const Validator = preload("res://foundation/validation/static_validator.gd")
const Baker = preload("res://foundation/level/level_baker.gd")
const Reader = preload("res://foundation/level/authoring_reader.gd")
const Softlock = preload("res://foundation/quality/softlock/softlock_analyzer.gd")
const Intent = preload("res://foundation/quality/intent/intent_validation.gd")
const Ablation = preload("res://foundation/quality/intent/ablation_analyzer.gd")
const Mechanics = preload("res://foundation/quality/intent/mechanic_classifier.gd")
const Milestones = preload("res://foundation/quality/intent/milestone_analyzer.gd")
const Driver = preload("res://foundation/parity/trace_replayer.gd")
const IntentFixtures = preload("res://tests/foundation/quality/intent/intent_fixtures.gd")
const SoftlockFixtures = preload("res://tests/foundation/quality/softlock/softlock_fixtures.gd")
const VALIDATION = {"max_configurations":4096,"max_checks":100000}
const ANALYSIS = {"max_nodes":10000,"max_edges":100000,"max_runtime_ms":0}
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var evidence := ""
var mode := 0
var driver: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence = arg.trim_prefix("--evidence-dir=")
	mode = 0 if DisplayServer.get_name() == "headless" else 1
	var stage: Node = Node.new() if mode == 0 else load("res://tests/foundation/parity/parity_replay_scene.tscn").instantiate()
	root.add_child(stage)
	driver = Driver.new()
	stage.add_child(driver)
	for name in ["required_shift", "required_enter_celestial", "multiple_celestial_entries", "shift_bypass", "optional_mechanism"]:
		var fixture := IntentFixtures.scenario(name)
		await chain(name, fixture.level, fixture.intent)
	for name in ["initial_goal", "corridor", "sink", "cycle", "multiple_goals", "no_goal"]:
		var baked := Baker.bake(SoftlockFixtures.make_authoring(name), VALIDATION)
		check(baked.ok, name + ": real Bake")
		if not baked.ok: continue
		await chain(name, baked.level, IntentFixtures.empty_intent(baked.level))
	for name in ["route", "composite"]:
		var level := canonical_level(name)
		if level.is_empty(): continue
		var intent := IntentFixtures.empty_intent(level)
		intent.required_mechanics = [0,1,2] if name == "route" else [0,4,7]
		intent.expected_milestones = [IntentFixtures.milestone(&"move", {"kind":3,"mechanic":0}),
			IntentFixtures.milestone(&"optional", {"kind":3,"mechanic":6}, false),
			IntentFixtures.milestone(&"finish", {"kind":4})]
		await chain(name, level, intent)
		if name == "route": budgets_and_errors(level)
	stage.free()
	var report := {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),
		"scope":"Real public Solver -> Graph/Trace -> Softlock/Intent -> RuntimeParity", "cases":cases}
	if not evidence.is_empty():
		DirAccess.make_dir_recursive_absolute(evidence)
		FileAccess.open(evidence.path_join("chain.json"), FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FOUNDATION_3_CHAIN_", "PASS" if failures.is_empty() else "FAIL", " checks=", checks)
	quit(0 if failures.is_empty() else 1)

func canonical_level(name: String) -> Dictionary:
	var scene: Node3D = load("res://tools/foundation/level/runtime_authoring.tscn").instantiate()
	var read := Reader.read_scene(scene)
	scene.free()
	check(read.ok, name + ": real AuthoringReader")
	if not read.ok: return {}
	var authoring: Dictionary = read.authoring
	if name == "composite":
		authoring.goal.face_id = &"s1/FRONT"
		authoring.worlds[0].allowed_states = [0]
		authoring.worlds[0].allowed_rotation_deltas = []
		authoring.worlds[0].allowed_rotation_intents = []
		for face in authoring.faces:
			if face.face_id == &"s1/FRONT": face.walkable = true
			if face.face_id == &"s1/TOP": face.mechanism_ids = [&"plate"]
		authoring.mechanisms = [{"mechanism_id":&"plate","face_id":&"s1/TOP","trigger":&"ENTER",
			"action":{"kind":4,"transition_id":&"tip"},"priority":0,"initial_state":&"ready","allowed_states":[&"ready"]}]
		authoring.face_transitions = [{"transition_id":&"tip","source_face_id":&"s1/TOP","target_face_id":&"s1/FRONT",
			"entry_axis":0,"exit_axis":0,"rotation_steps":[2],"required_flags":[]}]
	var baked := Baker.bake(authoring, VALIDATION)
	check(baked.ok, name + ": real Baker")
	return baked.level if baked.ok else {}

func chain(name: String, level: Dictionary, intent: Dictionary) -> void:
	var before := var_to_bytes([level,intent])
	var initial := Records.initial_state(level)
	check(level.size() == 19 and initial.size() == 6, name + ": unchanged Level/State schema")
	check(Codec.encode(level).ok and Validator.validate(level,VALIDATION).status == 0, name + ": canonical hash and VALID")
	check(Intent.validate(level,intent).ok and intent.intent_version == "puzzleintent.v1", name + ": sidecar accepted")
	var solved := Solver.solve(level,initial,Search.default_policy(1),Search.default_budget())
	check(solved.graph is Dictionary and solved.issues.is_empty(), name + ": real FULL_GRAPH")
	if not solved.graph is Dictionary: return
	var graph: Dictionary = solved.graph
	check(graph.graph_version == "stategraph.v1" and graph.complete and graph.stop_reason == 0, name + ": closed graph")
	check(Graph.validate(level,graph).ok, name + ": public graph validator")
	graph_semantics(name,level,graph,solved.metrics)
	var soft := Softlock.analyze(level,graph,ANALYSIS)
	check(soft.status == 0 and soft.unknown_states == [], name + ": complete reverse analysis")
	var expected_soft: int = {"sink":1,"cycle":2,"no_goal":1}.get(name,0)
	check(soft.softlock_count == expected_soft, name + ": literal softlock count")
	if name in ["sink","cycle"]:
		check(soft.reset_classification == 0 and soft.reset_recoverable_count == expected_soft, name + ": Reset recovery does not erase softlock")
	if name == "multiple_goals":
		check(solved.metrics.goal_states == 2 and soft.goal_reachable_states.size() == 4, "all real Goals seed reverse reachability")
	var analysis := Ablation.analyze(level,initial,intent,Search.default_policy(0),Search.default_budget())
	var expected_sets: Array = {"required_shift":[[1]],"required_enter_celestial":[[6]],
		"multiple_celestial_entries":[[6]],"shift_bypass":[[1]],"optional_mechanism":[[6]],
		"route":[[0],[1],[2]],"composite":[[0],[4],[7]]}.get(name,[])
	check(analysis.ablations.map(func(sub:Dictionary)->Array:return sub.disabled_mechanics) == expected_sets, name + ": every requested ablation is present")
	var record := {"name":name,"budget":Search.default_budget(),"solver":solved,"softlock":soft,"intent":analysis}
	if name == "no_goal":
		check(solved.status == 1 and solved.solution_trace == null and soft.softlock_count == graph.nodes.size(), "closed no-Goal is proven unsolvable and entirely softlocked")
		check(analysis.status == 3 and analysis.ablations.is_empty(), "unsolvable baseline cannot support ablation")
	else:
		check(solved.status == 0 and analysis.status == 0 and analysis.baseline.status == 0, name + ": solved UNFILTERED baseline and completed intent")
		check(analysis.baseline.graph.policy_descriptor.filter_descriptor.filter_id == &"UNFILTERED", name + ": baseline scope")
		var trace: Dictionary = solved.solution_trace
		check(trace.trace_version == "solutiontrace.v1" and trace.total_actions == trace.steps.size(), name + ": formal trace schema/count")
		check(trace.initial_state == initial and trace.initial_statekey == graph.initial_key and trace.policy_descriptor == graph.policy_descriptor, name + ": graph/trace identity")
		var semantics := Trace.validate_semantics(level,trace)
		check(semantics.ok and semantics.transitions.size() == trace.total_actions, name + ": real Kernel semantic replay")
		var milestone := Milestones.analyze_trace(level,intent,trace)
		check(milestone.status == 0 and milestone.scope == "SINGLE_TRACE", name + ": witness-only milestone match")
		if name == "composite":
			check(trace.total_actions == 1 and trace.steps[0].global_kind == 5, "composite is one semantic action with global effect")
			check(Mechanics.classify_transition(level,semantics.transitions[0]).tags == [0,4,7], "Connectivity/Effects classify intermediate ENTER face")
			check(milestone.sample_indices.move == 1 and milestone.sample_indices.finish == 1 and milestone.sample_indices.optional == null, "nondecreasing required indices and independent optional milestone")
		for sub in analysis.ablations:
			if name in ["required_shift","required_enter_celestial","multiple_celestial_entries","route","composite"]:
				check(sub.essential == true and sub.ablated_status == 1 and sub.bypass_detected == false, name + ": disabling required mechanic closes all solutions")
			elif name == "shift_bypass":
				check(sub.essential == false and sub.bypass_detected == true and sub.findings[0].code == 4000, "required violation has verified bypass witness")
			elif name == "optional_mechanism":
				check(sub.essential == false and sub.bypass_detected == false and sub.findings.is_empty(), "unused optional mechanic is not hard bypass")
			if sub.solution_trace_if_any is Dictionary:
				check(Trace.validate_semantics(level,sub.solution_trace_if_any).ok, "ablation witness stays legal under original Kernel")
				var ablated_parity: Dictionary = await driver.replay(level,sub.solution_trace_if_any,{"mode":mode})
				check(ablated_parity.status == 0, "filtered Solver witness also matches original Runtime")
		var parity: Dictionary = await driver.replay(level,trace,{"mode":mode})
		check(parity.status == 0 and parity.matched_steps == trace.total_actions and parity.actual_statekey == trace.goal_statekey, name + ": four-module chain reaches Runtime MATCH")
		check(driver._session.commit_count == trace.total_actions and driver._session.context == Rules.idle_context(), name + ": one authoritative commit per action and IDLE")
		for step in driver._step_evidence:
			check(step.commit_delta == 1 and step.commit_signals == 1 and step.expected_statekey == step.actual_statekey, name + ": each committed full statekey matches")
		if name == "composite": check(not driver._step_evidence[0].is_global, "MOVE+ENTER uses transition_started local token")
		if name == "route": check(driver._step_evidence.map(func(s:Dictionary)->bool:return s.is_global) == [false,true,true], "local/global waits follow Runtime signals")
		record["semantics"] = semantics
		record["parity"] = parity
		record["runtime_steps"] = driver._step_evidence.duplicate(true)
		if trace.total_actions > 0:
			var forged := trace.duplicate(true)
			forged.steps[0].action = {"kind":0,"face_axis":1}
			check(Trace.validate(level,forged).ok and not Trace.validate_semantics(level,forged).ok, name + ": consistent forged keys cannot authorize illegal action")
	check(var_to_bytes([level,intent]) == before, name + ": all consumers preserve source inputs")
	cases.append(record)

func graph_semantics(name: String, level: Dictionary, graph: Dictionary, metrics: Dictionary) -> void:
	var rejected := 0
	var no_op := 0
	var evaluations := 0
	for key in graph.nodes:
		var node: Dictionary = graph.nodes[key]
		check(node.state.size() == 6 and Key.build(level,node.state).key == key and node.state_key == key and key.begins_with("statekey.v1"), name + ": full canonical node identity")
		if node.is_goal: continue
		var generated := Actions.generate(level,node.state)
		check(generated.ok and generated.actions.filter(func(a:Dictionary)->bool:return a.kind == 0).size() == 4, name + ": four static MOVE candidates before legality")
		for action in generated.actions:
			check(action.kind in range(8), name + ": Reset absent from candidate domain")
			var transition := Kernel.evaluate_action(level,node.state,action,Rules.idle_context())
			evaluations += 1
			var edges: Array = graph.forward[key].filter(func(id:int)->bool:return graph.edges[id].action == action)
			check(transition.status != 2, name + ": valid graph candidates have no hidden Kernel ERROR")
			if transition.status == 1:
				rejected += 1
				check(edges.is_empty(), name + ": REJECTED creates no edge")
			elif not transition.changed:
				no_op += 1
				check(edges.is_empty(), name + ": unchanged creates no self-loop")
			else:
				check(edges.size() == 1, name + ": exactly one edge per APPLIED changed candidate")
				if edges.size() != 1: continue
				var edge: Dictionary = graph.edges[edges[0]]
				check(edge.to_key != key and graph.nodes[edge.to_key].state == transition.next_state and edge.global_kind == transition.global_kind, name + ": atomic Kernel next_state owns graph edge")
	check(metrics.rejected_actions == rejected and metrics.no_op_actions == no_op and metrics.action_evaluations == evaluations, name + ": rejected/no-op/evaluation accounting")

func budgets_and_errors(level: Dictionary) -> void:
	var initial := Records.initial_state(level)
	for limit in [["max_states",1,1],["max_edges",0,2],["max_depth",0,3],["max_action_evaluations",1,5]]:
		var budget := Search.default_budget()
		budget[limit[0]] = limit[1]
		var result := Solver.solve(level,initial,Search.default_policy(1),budget)
		check(result.status == 2 and result.budget_reason == limit[2] and not result.graph.complete, "real Solver capacity: " + limit[0])
		var soft := Softlock.analyze(level,result.graph,ANALYSIS)
		check(soft.status == 1 and soft.softlock_states == null and soft.softlock_count == null, "budget cannot become softlock proof: " + limit[0])
		cases.append({"name":limit[0],"budget":budget,"solver":result,"softlock":soft})
	var bad := level.duplicate(true)
	bad.content_hash = "0".repeat(64)
	var invalid := Solver.solve(bad,initial,Search.default_policy(1),Search.default_budget())
	check(invalid.status == 3 and invalid.graph == null and invalid.metrics.action_evaluations == 0, "invalid canonical Level never enters search")
	var policy := Search.default_policy(1)
	policy.validation_options = {"max_configurations":1,"max_checks":1}
	var incomplete := Solver.solve(level,initial,policy,Search.default_budget())
	check(incomplete.status == 3 and incomplete.graph == null and incomplete.metrics.action_evaluations == 0 and incomplete.issues[0].code == 3011, "Validator INCOMPLETE is not search unsolvability")
	var fixture := IntentFixtures.scenario("required_shift")
	var budget := Search.default_budget()
	budget.max_action_evaluations = 6
	var ablated := Ablation.analyze(fixture.level,Records.initial_state(fixture.level),fixture.intent,Search.default_policy(0),budget)
	check(ablated.baseline.status == 0 and ablated.status == 1 and ablated.ablations[0].essential == null and ablated.ablations[0].bypass_detected == null, "solved baseline plus incomplete ablation gives no binary conclusion")
	cases.append({"name":"ablation_budget","budget":budget,"analysis":ablated})
