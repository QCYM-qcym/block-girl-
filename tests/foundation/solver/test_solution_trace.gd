extends SceneTree
const Fixtures = preload("res://tests/foundation/solver/solver_fixtures.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Search = preload("res://foundation/solver/search_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL: ",label)

func _initialize() -> void:
	if not FileAccess.file_exists("res://foundation/solver/solution_trace.gd"):
		check(false,"SolutionTrace entry missing")
		finish()
		return
	var solver = load("res://foundation/solver/bfs_solver.gd")
	var trace_type = load("res://foundation/solver/solution_trace.gd")
	var graph_type = load("res://foundation/solver/state_graph.gd")
	var level := Fixtures.corridor()
	var initial := Records.initial_state(level)
	var result: Dictionary = solver.solve(level,initial,Search.default_policy(0),Search.default_budget())
	check(result.status == 0,"fixture solved")
	if result.status != 0:
		finish()
		return
	var trace: Dictionary = result.solution_trace
	check(trace_type.validate(level,trace).ok,"structural trace")
	var evidence: Dictionary = trace_type.validate_semantics(level,trace)
	check(evidence.ok and evidence.transitions.size() == 2,"two complete semantic transition records")
	check(evidence.transitions[0].size() == 8 and evidence.transitions[0].next_state == trace.steps[0].expected_state,"full transition evidence")
	var before := var_to_bytes([result.graph,trace,level])
	var reconstructed: Dictionary = trace_type.from_graph(level,result.graph,trace.goal_statekey)
	check(reconstructed.ok and reconstructed.trace == trace,"first predecessor reconstruction")
	check(var_to_bytes([result.graph,trace,level]) == before,"validators and reconstruction preserve inputs")
	reconstructed.trace.steps[0].expected_state.player.orientation = 23
	check(trace.steps[0].expected_state.player.orientation != 23,"reconstructed nested state owned")
	var forged := trace.duplicate(true)
	forged.steps[0].action = {"kind":1}
	check(trace_type.validate(level,forged).ok,"structure does not claim reachability")
	var rejected: Dictionary = trace_type.validate_semantics(level,forged)
	check(not rejected.ok and rejected.transitions.is_empty(),"forged legal key path rejected by Kernel replay")
	forged = trace.duplicate(true)
	forged.steps[1].action = {"kind":0,"face_axis":2}
	rejected = trace_type.validate_semantics(level,forged)
	check(not rejected.ok and rejected.transitions.is_empty(),"late divergence does not leak prefix evidence")
	forged = trace.duplicate(true)
	forged.steps[0].global_kind = 1
	check(trace_type.validate(level,forged).ok and not trace_type.validate_semantics(level,forged).ok,"semantic global kind checked")
	for field in ["trace_version","level_hash","rule_version","initial_statekey","goal_statekey"]:
		forged = trace.duplicate(true)
		forged[field] = "wrong"
		check(not trace_type.validate(level,forged).ok,"bad trace " + field)
	for change in [0,1,2,3,4,5,6]:
		forged = trace.duplicate(true)
		match change:
			0: forged.extra = true
			1: forged.steps[0].extra = true
			2: forged.steps[0].index = 2
			3: forged.steps[0].resulting_statekey = "forged"
			4: forged.total_actions = 1
			5: forged.steps[0].expected_state["camera"] = 0
			6: forged.policy_descriptor["budget"] = {}
		check(not trace_type.validate(level,forged).ok,"closed trace invariant %d" % change)
	for change in range(13):
		var graph: Dictionary = result.graph.duplicate(true)
		var first: String = graph.edges[0].to_key
		match change:
			0: graph.extra = true
			1: graph.nodes[first].depth = 7
			2: graph.nodes[first].predecessor_edge = null
			3: graph.nodes[first].predecessor_edge = 999
			4: graph.edges[0].to_key = graph.initial_key
			5: graph.forward[graph.initial_key].append(0)
			6: graph.reverse[first].clear()
			7: graph.nodes[first].state.player.orientation = 23
			8: graph.complete = true
			9: graph.nodes[trace.goal_statekey].is_goal = false
			10: graph.edges[0].edge_id = 99
			11: graph.nodes[graph.initial_key].predecessor_edge = 0
			12: graph.edges[0].action["reset"] = true
		check(not graph_type.validate(level,graph).ok,"graph invariant %d" % change)
		check(not trace_type.from_graph(level,graph,trace.goal_statekey).ok,"bad graph cannot produce trace %d" % change)
	var zero := Fixtures.corridor(1)
	var solved: Dictionary = solver.solve(zero,Records.initial_state(zero),Search.default_policy(0),Search.default_budget())
	var zero_check: Dictionary = trace_type.validate_semantics(zero,solved.solution_trace)
	check(zero_check.ok and zero_check.transitions.is_empty(),"zero-step Goal semantic success")
	finish()

func finish() -> void:
	print("SOLUTION_TRACE_PASS checks=%d" % checks if failures.is_empty() else "SOLUTION_TRACE_FAIL checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)
