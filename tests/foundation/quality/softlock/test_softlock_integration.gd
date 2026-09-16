extends SceneTree
## Positive evidence comes only from live official Explorer / BFSSolver output.
## Literal graphs and the validator double are confined to the separate unit suite.
const Fixtures = preload("res://tests/foundation/quality/softlock/softlock_fixtures.gd")
const Baker = preload("res://foundation/level/level_baker.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Analyzer = preload("res://foundation/quality/softlock/softlock_analyzer.gd")
const VALIDATION_BUDGET = {"max_configurations": 4096, "max_checks": 100000}
const ANALYSIS_BUDGET = {"max_nodes": 10000, "max_edges": 100000, "max_runtime_ms": 0}
const OWNERS = ["res://foundation/solver/state_graph.gd", "res://foundation/solver/solver_types.gd",
	"res://foundation/solver/state_explorer.gd", "res://foundation/solver/search_records.gd",
	"res://foundation/solver/action_generator.gd", "res://foundation/solver/solution_trace.gd",
	"res://foundation/solver/bfs_solver.gd"]
const CASES = ["initial_goal", "no_goal", "corridor", "sink", "cycle", "multiple_goals"]
var checks := 0
var failures: Array[String] = []
var evidence: Array[Dictionary] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var levels := {}
	for name in CASES:
		var baked := Baker.bake(Fixtures.make_authoring(name), VALIDATION_BUDGET)
		check(baked.ok and baked.validation.status == 0, "real Baker and Validator accept: " + name)
		if baked.ok:
			levels[name] = baked.level
		else:
			print("BAKER DIAGNOSTIC ", baked)
	var bad: Dictionary = Fixtures.make_authoring("sink")
	bad.cubes[1].center2 = bad.cubes[0].center2
	var rejected := Baker.bake(bad, VALIDATION_BUDGET)
	check(not rejected.ok and rejected.level == null, "invalid authoring cannot supply a Graph input")
	var missing: Array[String] = []
	for path in OWNERS:
		if not ResourceLoader.exists(path):
			missing.append(path)
	if not missing.is_empty():
		check(not missing.is_empty(), "real 3A presence checked without test fallback")
		print("SOFTLOCK_INTEGRATION checks=", checks, " failures=", failures, " source=DEPENDENCY_PENDING")
		print("DEPENDENCY_PENDING: REAL_3A_STATEGRAPH missing=", missing)
		quit(0 if failures.is_empty() else 1)
		return
	if levels.size() != CASES.size():
		finish()
		return
	var Explorer: Script = load(OWNERS[2])
	var SearchRecords: Script = load(OWNERS[3])
	var SolverTypes: Script = load(OWNERS[1])
	var BFS: Script = load(OWNERS[6])
	var policy: Dictionary = SearchRecords.default_policy(SolverTypes.SearchMode.FULL_GRAPH)
	check(not Types.PuzzleActionKind.has("RESET"), "Reset is absent from the formal action enum")
	var cycle_graph := {}
	for name in CASES + ["partial", "custom_initial"]:
		var level: Dictionary = levels["cycle" if name in ["partial", "custom_initial"] else name]
		var budget: Dictionary = SearchRecords.default_budget()
		var initial := Records.initial_state(level)
		if name == "partial":
			budget.max_states = 3
		if name == "custom_initial":
			for node in cycle_graph.nodes.values():
				if node.state.player.location.cube_id == &"inner_floor":
					initial = node.state.duplicate(true)
		# Both public 3A facades are exercised; neither is replicated here.
		var solved: Dictionary = BFS.solve(level, initial, policy, budget) if name == "corridor" else Explorer.explore(level, initial, policy, budget)
		check(solved.graph != null and solved.issues.is_empty(), name + " produces a real in-process Graph")
		if solved.graph == null:
			continue
		var graph: Dictionary = solved.graph
		if name == "cycle":
			cycle_graph = graph
		var snapshot := var_to_bytes([level, graph])
		var result := Analyzer.analyze(level, graph, ANALYSIS_BUDGET)
		check(snapshot == var_to_bytes([level, graph]), name + " analysis does not mutate its inputs")
		check(result.issues.is_empty(), name + " public analyzer accepts official Graph.validate")
		check(result.metrics.nodes_checked == graph.nodes.size() and result.metrics.edges_checked == graph.edges.size(), name + " counts validated unique records")
		var repeated := Analyzer.analyze(level, graph, ANALYSIS_BUDGET)
		check(logical(result) == logical(repeated), name + " deterministic repeat excluding elapsed time")
		check(sorted_sets(result), name + " canonical result ordering")
		check_no_reset(level, graph, name)
		var goals: Array = graph.nodes.values().filter(func(node: Dictionary) -> bool: return node.is_goal)
		if name == "partial":
			check(solved.status == SolverTypes.SolverStatus.BUDGET_EXCEEDED and solved.budget_reason == SolverTypes.BudgetReason.MAX_STATES and not graph.complete, "official SearchBudget stops real expansion")
			check(result.status == 1 and result.softlock_count == null and result.softlock_states == null, "partial cannot certify absence of softlock")
			check(result.reachable_states.size() == 3 and result.goal_reachable_states.size() == 2 and result.unknown_states.size() == 1, "partial retains discovered, positive and unknown evidence")
			check(result.reset_classification == 2 and result.reset_recoverable_count == null and result.witnesses.is_empty(), "partial Reset stays UNKNOWN without negative witnesses")
			check(solved.solution_trace != null and graph.nodes[result.unknown_states[0]].state.player.location.cube_id == &"inner_floor", "partial keeps found Goal trace and unknown inner trap")
		else:
			check(graph.complete and graph.stop_reason == SolverTypes.GraphStopReason.EXHAUSTED and result.status == 0, name + " full graph and reverse analysis complete")
			match name:
				"initial_goal":
					check(graph.nodes.size() == 1 and result.softlock_count == 0, "initial Goal is singleton closure")
				"corridor":
					check(graph.nodes.size() == 3 and graph.edges.size() == 3 and result.softlock_count == 0, "MOVE-then-SHIFT corridor has no softlock")
					check(solved.solution_trace != null and solved.solution_trace.total_actions == 2 and solved.solution_trace.steps[0].expected_state.player.location.cube_id == &"step", "nontrivial solution passes through middle cube")
				"no_goal":
					check(solved.status == SolverTypes.SolverStatus.PROVEN_UNSOLVABLE and goals.is_empty() and result.softlock_count == 1, "complete no-Goal graph is entirely softlocked")
					check(result.reset_classification == 1 and result.reset_recoverable_count == 0, "unsolvable spawn cannot recover via Reset")
				"sink":
					check(graph.nodes.size() == 3 and graph.edges.size() == 2 and result.softlock_count == 1, "one-way Shift produces exactly one sink")
					if result.softlock_count == 1:
						var key: String = result.softlock_states[0]
						check(graph.nodes[key].state.player.location == {"layer": 1, "cube_id": &"inner_floor", "face": 4} and graph.forward[key].is_empty(), "literal Inner sink has no outgoing edges")
						check(result.witnesses[0].edge_ids.size() == 1 and graph.edges[result.witnesses[0].edge_ids[0]].action == {"kind": 1}, "sink witness is one real Shift")
					check(result.reset_classification == 0 and result.reset_recoverable_count == 1, "Reset recovery preserves the sink identity")
				"cycle":
					check(graph.nodes.size() == 4 and graph.edges.size() == 4 and result.softlock_count == 2, "two-state trapped cycle with Goal alternative")
					var locations: Array = []
					for key in result.softlock_states:
						locations.append(String(graph.nodes[key].state.player.location.cube_id))
						check(graph.forward[key].size() == 1 and graph.edges[graph.forward[key][0]].to_key in result.softlock_states and graph.edges[graph.forward[key][0]].to_key != key, "cycle edge reaches the other trapped state")
					locations.sort()
					check(locations == ["inner_floor", "inner_next"], "cycle occupies the two declared Inner cubes")
					check(result.reset_classification == 0 and result.reset_recoverable_count == 2 and goals.size() == 1, "both cycle states stay softlocked but Reset recovers")
				"multiple_goals":
					var slots: Array = []
					for node in goals:
						slots.append(String(node.state.celestial.slot_id))
					slots.sort()
					check(graph.nodes.size() == 4 and graph.edges.size() == 6 and slots == ["a", "b"], "two celestial slots produce distinct real Goal states")
					check(result.softlock_count == 0 and result.goal_reachable_states.size() == 4, "reverse seeds every Goal including both branches")
				"custom_initial":
					check(graph.nodes.size() == 2 and graph.edges.size() == 2 and result.softlock_count == 2, "real custom initial closes only the trapped cycle")
					check(result.reset_classification == 2 and result.reset_recoverable_count == null, "absent spawn produces Reset UNKNOWN")
		if solved.solution_trace != null:
			var Trace: Script = load(OWNERS[5])
			check(Trace.validate_semantics(level, solved.solution_trace).ok, name + " retained Goal trace replays through real Kernel")
		check_witnesses(graph, result)
		evidence.append({"case": name, "source": "REAL_3A_EXPLORER", "level_hash": level.content_hash,
			"search_budget": budget, "policy_descriptor": graph.policy_descriptor, "solver_status": solved.status,
			"budget_reason": solved.budget_reason, "complete": graph.complete, "stop_reason": graph.stop_reason,
			"nodes": graph.nodes.size(), "edges": graph.edges.size(), "goals": goals.size(),
			"analysis": result, "trace_actions": solved.solution_trace.total_actions if solved.solution_trace != null else null})
	var first_policy: Dictionary = SearchRecords.default_policy(SolverTypes.SearchMode.FIRST_SHORTEST)
	var first: Dictionary = Explorer.explore(levels.initial_goal, Records.initial_state(levels.initial_goal), first_policy, SearchRecords.default_budget())
	check(first.graph != null and first.graph.complete and first.graph.stop_reason == SolverTypes.GraphStopReason.EXHAUSTED, "real FIRST_SHORTEST initial Goal uses EXHAUSTED closure")
	if first.graph != null:
		var closure := Analyzer.analyze(levels.initial_goal, first.graph, ANALYSIS_BUDGET)
		check(closure.status == 0 and closure.softlock_count == 0, "public analyzer accepts real initial-Goal FIRST_SHORTEST closure")
	check_owner_rejection(levels.cycle, cycle_graph)
	var limited := Analyzer.analyze(levels.cycle, cycle_graph, {"max_nodes": 1, "max_edges": 100, "max_runtime_ms": 0})
	check(limited.status == 1 and limited.softlock_count == null and limited.metrics.nodes_checked == 0, "real graph over analysis capacity fails closed")
	finish()

func logical(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true)
	copy.metrics.erase("elapsed_ms")
	return copy

func sorted_sets(result: Dictionary) -> bool:
	for field in ["reachable_states", "goal_reachable_states", "softlock_states", "unknown_states"]:
		if result[field] == null:
			continue
		var sorted: Array = result[field].duplicate()
		sorted.sort()
		if result[field] != sorted:
			return false
	return true

func check_no_reset(level: Dictionary, graph: Dictionary, name: String) -> void:
	var Actions: Script = load(OWNERS[4])
	var valid := true
	for node in graph.nodes.values():
		var generated: Dictionary = Actions.generate(level, node.state)
		valid = valid and generated.ok
		for action in generated.actions:
			# Only declared gameplay kinds; Reset is not an action or edge.
			valid = valid and action.kind in [0, 1, 5, 7]
	for edge in graph.edges:
		valid = valid and edge.action.kind in [0, 1, 5, 7]
	check(valid, name + " official actions and Graph edges exclude Reset")

func check_witnesses(graph: Dictionary, result: Dictionary) -> void:
	for path in result.witnesses:
		var current: String = graph.initial_key
		for edge_id in path.edge_ids:
			check(graph.edges[edge_id].from_key == current, "witness follows original graph")
			current = graph.edges[edge_id].to_key
		check(current == path.target_key, "witness reaches its target")

func check_owner_rejection(level: Dictionary, graph: Dictionary) -> void:
	var Graph: Script = load(OWNERS[0])
	# Copies are intentionally corrupted only for ERROR-boundary tests.
	for defect in ["reverse", "key", "predecessor"]:
		var bad := graph.duplicate(true)
		var target: String = bad.edges[0].to_key
		match defect:
			"reverse": bad.reverse[target].append(0)
			"key": bad.nodes[target].state_key = "invalid"
			"predecessor": bad.nodes[target].predecessor_edge = 999
		var rejected: Dictionary = Graph.validate(level, bad)
		var result := Analyzer.analyze(level, bad, ANALYSIS_BUDGET)
		check(not rejected.ok and result.status == 2 and result.issues == rejected.issues and result.softlock_count == null, "public analyzer preserves real owner rejection: " + defect)

func finish() -> void:
	print("SOFTLOCK_REAL_EVIDENCE ", JSON.stringify(evidence))
	print("SOFTLOCK_INTEGRATION checks=", checks, " failures=", failures, " source=REAL_3A_EXPLORER")
	if failures.is_empty():
		print("FOUNDATION_SOFTLOCK_ANALYSIS_PASS")
	quit(0 if failures.is_empty() else 1)
