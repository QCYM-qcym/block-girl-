extends SceneTree
## Algorithm tests only: no Explorer, Kernel exploration, or production adapter.
const Analyzer = preload("res://foundation/quality/softlock/softlock_analyzer.gd")
const SoftlockTypes = preload("res://foundation/quality/softlock/softlock_types.gd")
var Fixtures: Script
var ContractDouble: Script
const BUDGET = {"max_nodes": 10000, "max_edges": 100000, "max_runtime_ms": 0}
# Test-only ABI values supplied in place of the absent 3A types owner.
const CODES = {"INVALID_SEARCH_BUDGET": 3003, "GRAPH_INVALID": 3007,
	"VERSION_MISMATCH": 3010, "STATEKEY_ERROR": 3006, "ANALYSIS_INPUT_INVALID": 3016}
var checks := 0
var failures: Array[String] = []
var validation_calls := 0
var validation_result := {"ok": true, "issues": []}
var now := 0
var clock_calls := 0
var expire_at := -1
var graph_double: RefCounted

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	if not ResourceLoader.exists("res://tests/foundation/quality/softlock/softlock_fixtures.gd"):
		check(false, "explicit Graph fixture dependency exists")
		finish()
		return
	Fixtures = load("res://tests/foundation/quality/softlock/softlock_fixtures.gd")
	ContractDouble = load("res://tests/foundation/quality/softlock/graph_contract_double.gd")
	graph_double = ContractDouble.new()
	call_deferred("run")

func finish() -> void:
	print("SOFTLOCK_UNIT checks=", checks, " failures=", failures)
	if failures.is_empty():
		print("FOUNDATION_SOFTLOCK_ANALYSIS_PROVISIONAL_PASS")
	quit(0 if failures.is_empty() else 1)

func clock_value() -> int:
	clock_calls += 1
	if expire_at >= 0 and clock_calls >= expire_at:
		return 10
	return now

func validate_double(level: Dictionary, graph: Dictionary) -> Dictionary:
	validation_calls += 1
	graph_double.response = validation_result
	return graph_double.validate(level, graph)

func analyze_case(fixture: Dictionary, budget: Dictionary = BUDGET) -> Dictionary:
	return Analyzer._analyze_with_dependencies(fixture.level, fixture.graph, budget, validate_double, CODES, clock_value)

func sorted_keys(keys: Array) -> Array:
	var result := keys.duplicate()
	result.sort()
	return result

func run() -> void:
	for name in ["no_softlock", "sink", "cycle", "multiple_goals", "no_goal"]:
		var fixture: Dictionary = Fixtures.make_case(name)
		var result := analyze_case(fixture)
		var expected: Array = []
		match name:
			"sink": expected = [fixture.keys.T]
			"cycle": expected = [fixture.keys.T, fixture.keys.U]
			"no_goal": expected = fixture.graph.nodes.keys()
		check(result.status == 0, name + " complete")
		check(result.softlock_states == sorted_keys(expected), name + " exact softlock set")
		check(result.softlock_count == expected.size(), name + " exact count")
		check(result.unknown_states == [], name + " no unknown states")
		check(result.reachable_states == sorted_keys(fixture.graph.nodes.keys()), name + " forward-discovered nodes retained")
		check(result.metrics.nodes_checked == fixture.graph.nodes.size() and result.metrics.edges_checked == fixture.graph.edges.size(), name + " unique record counts")
		check(result.reset_classification == (1 if name == "no_goal" else 0), name + " Reset classification")
		check(result.reset_recoverable_count == (0 if name == "no_goal" else expected.size()), name + " Reset never removes softlock")
		check_witnesses(fixture, result)
	test_incomplete()
	test_errors()
	test_purity_and_order()
	test_time()
	test_initial_goal_closure()
	test_reporting_timeout()
	finish()

func test_initial_goal_closure() -> void:
	var fixture: Dictionary = Fixtures.make_case("no_softlock")
	var goal: String = fixture.keys.G
	var node: Dictionary = fixture.graph.nodes[goal].duplicate(true)
	node.depth = 0
	node.predecessor_edge = null
	fixture.graph.initial_key = goal
	fixture.graph.nodes = {goal: node}
	fixture.graph.edges = []
	fixture.graph.forward = {goal: []}
	fixture.graph.reverse = {goal: []}
	fixture.graph.policy_descriptor.mode = 0
	fixture.graph.stop_reason = 0 # Official initial-Goal closure is EXHAUSTED.
	validation_calls = 0
	var result := analyze_case(fixture)
	check(validation_calls == 1, "completeness consistency is delegated to Graph owner")
	check(result.status == 0 and result.softlock_states == [] and result.softlock_count == 0, "initial Goal FIRST_SHORTEST can be a complete closure")
	check(result.reset_classification == 2 and result.reset_recoverable_count == null, "zero softlocks do not invent spawn Reset evidence")

func test_reporting_timeout() -> void:
	var fixture: Dictionary = Fixtures.make_case("no_softlock")
	var report := SoftlockTypes._empty_result()
	report.status = 0
	report.reachable_states = [fixture.keys.G]
	report.softlock_states = []
	report.softlock_count = 0
	# Phase-controlled monotonic clock: report materialization consumes the
	# remaining time. Sampling only before it would incorrectly return COMPLETE.
	var final_clock := func() -> int: return 10 if not report.goal_reachable_states.is_empty() else 0
	var result := Analyzer._finish(report, {fixture.keys.G: true}, 0, final_clock, {"max_nodes": 10, "max_edges": 10, "max_runtime_ms": 1})
	check(result.status == 1 and result.softlock_count == null and result.metrics.elapsed_ms == 10, "report construction time is included before final COMPLETE gate")

func check_witnesses(fixture: Dictionary, result: Dictionary) -> void:
	check(result.witnesses.size() == (result.softlock_count if result.softlock_count != null else 0), "one GraphPath per proven softlock")
	for path in result.witnesses:
		check(path.keys().size() == 2 and path.has("target_key") and path.has("edge_ids"), "GraphPath is not SolutionTrace")
		var current: String = fixture.graph.initial_key
		for edge_id in path.edge_ids:
			var edge: Dictionary = fixture.graph.edges[edge_id]
			check(edge.from_key == current, "witness follows original forward edge")
			current = edge.to_key
		check(current == path.target_key, "witness reaches softlock")

func test_incomplete() -> void:
	var fixture: Dictionary = Fixtures.make_case("sink")
	for reason in [1, 2]:
		fixture.graph.complete = false
		fixture.graph.stop_reason = reason
		var result := analyze_case(fixture)
		check(result.status == 1, "partial or FirstGoal graph INCOMPLETE")
		check(result.softlock_states == null and result.softlock_count == null, "unknown never becomes zero softlock")
		check(result.reset_classification == 2 and result.reset_recoverable_count == null, "partial Reset unknown")
		check(result.goal_reachable_states.has(fixture.keys.G), "positive Goal evidence retained")
		check(result.reachable_states == sorted_keys(fixture.graph.nodes.keys()), "incomplete preserves all validated forward evidence")
		check(result.unknown_states == [fixture.keys.T], "partial unknown only lacks goal proof")
	fixture = Fixtures.make_case("custom_initial")
	var custom := analyze_case(fixture)
	check(custom.status == 0 and custom.reset_classification == 2 and custom.reset_recoverable_count == null, "spawn absent in custom graph Reset UNKNOWN")
	fixture = Fixtures.make_case("sink")
	for budget in [{"max_nodes": 1, "max_edges": 100, "max_runtime_ms": 0}, {"max_nodes": 100, "max_edges": 0, "max_runtime_ms": 0}]:
		validation_calls = 0
		var result := analyze_case(fixture, budget)
		check(result.status == 1 and result.softlock_states == null, "record budget cannot authorize full reverse analysis")
		check(validation_calls == 0 and result.metrics.nodes_checked == 0 and result.metrics.edges_checked == 0, "capacity checked before Graph.validate")
		check(result.goal_reachable_states == [], "unvalidated graph cannot claim Goal proof")
	var exact := analyze_case(fixture, {"max_nodes": fixture.graph.nodes.size(), "max_edges": fixture.graph.edges.size(), "max_runtime_ms": 0})
	check(exact.status == 0, "validation and reverse reuse records without double charging")

func test_errors() -> void:
	var fixture: Dictionary = Fixtures.make_case("sink")
	for bad_budget in [{}, {"max_nodes": 0, "max_edges": 1, "max_runtime_ms": 0}, {"max_nodes": 10, "max_edges": -1, "max_runtime_ms": 0}, {"max_nodes": 10, "max_edges": 10, "max_runtime_ms": -1}, {"max_nodes": 10.0, "max_edges": 10, "max_runtime_ms": 0}, {"max_nodes": 10, "max_edges": 10, "max_runtime_ms": 0, "extra": 0}]:
		var result := analyze_case(fixture, bad_budget)
		check(result.status == 2 and result.issues.any(func(issue: Dictionary) -> bool: return issue.code == 3003), "invalid AnalysisBudget is ERROR3003")
	for mode in ["filtered", "stop_error", "version", "unknown_field", "unknown_complete"]:
		var bad := fixture.duplicate(true)
		match mode:
			"filtered": bad.graph.policy_descriptor.filter_descriptor = {"filter_id": &"MECHANIC_ABLATION", "filter_version": "1", "disabled_mechanics": [0]}
			"stop_error": bad.graph.stop_reason = 3
			"version": bad.graph.graph_version = "stategraph.future"
			"unknown_field": bad.graph["extra"] = true
			"unknown_complete": bad.graph.erase("complete")
		check(analyze_case(bad).status == 2, "coarse graph admission rejects " + mode)
	# A narrow response double tests rejection propagation, not Graph validation.
	var upstream := {"code": 1105, "severity": 0, "path": "position2", "entity_ids": [&"floor"], "message": "overflow", "details": {"operation": "TEST"}}
	validation_result = {"ok": false, "issues": [{"code": 3007, "severity": 0, "path": "reverse", "message": "controlled owner rejection", "details": {"reason": "duplicate edge / bad key / broken predecessor"}, "upstream": [upstream]}]}
	var result := analyze_case(fixture)
	check(result.status == 2 and result.issues == validation_result.issues, "Graph owner rejection including1105 preserved exactly")
	check(result.metrics.nodes_checked == 0 and result.softlock_count == null, "failed graph has no complete-record claim")
	for corruption in ["duplicate_reverse", "wrong_key", "broken_predecessor"]:
		var rejected := fixture.duplicate(true)
		match corruption:
			"duplicate_reverse": rejected.graph.reverse[fixture.keys.G].append(1)
			"wrong_key": rejected.graph.nodes[fixture.keys.G].state_key = "not-a-statekey"
			"broken_predecessor": rejected.graph.nodes[fixture.keys.T].predecessor_edge = null
		validation_result.issues[0].details.reason = corruption
		validation_calls = 0
		var refused := analyze_case(rejected)
		check(refused.status == 2 and validation_calls == 1 and refused.issues == validation_result.issues, "controlled Graph owner rejects " + corruption + " before traversal")
		check(refused.goal_reachable_states == [] and refused.witnesses == [], "invalid graph never supplies partial proof")
	validation_result = {"ok": true, "issues": []}
	if not ResourceLoader.exists("res://foundation/solver/state_graph.gd"):
		var pending := Analyzer.analyze(fixture.level, fixture.graph, BUDGET)
		check(pending.status == 2 and pending.softlock_count == null, "public API has no tests-only fallback")

func test_purity_and_order() -> void:
	var fixture: Dictionary = Fixtures.make_case("cycle")
	var saved := fixture.duplicate(true)
	var first := analyze_case(fixture)
	check(fixture == saved, "input graph and level never mutated")
	var reorder := fixture.duplicate(true)
	for field in ["nodes", "forward", "reverse"]:
		var keys: Array = reorder.graph[field].keys()
		keys.reverse()
		var rebuilt := {}
		for key in keys:
			rebuilt[key] = reorder.graph[field][key]
			if field != "nodes": rebuilt[key].reverse()
		reorder.graph[field] = rebuilt
	check(analyze_case(reorder) == first, "deterministic results independent of map and reverse insertion order")
	if not first.witnesses.is_empty():
		first.witnesses[0].edge_ids.append(999)
	check(fixture == saved, "returned witness owns its arrays")

func test_time() -> void:
	var fixture: Dictionary = Fixtures.make_case("sink")
	var budget := {"max_nodes": 100, "max_edges": 100, "max_runtime_ms": 1}
	clock_calls = 0
	expire_at = 3
	var result := analyze_case(fixture, budget)
	check(result.status == 1 and result.softlock_count == null, "clock cutoff prevents COMPLETE")
	check(result.metrics.nodes_checked == fixture.graph.nodes.size() and result.metrics.edges_checked == fixture.graph.edges.size(), "post-validation timeout retains validated unique record counts")
	check(result.reachable_states == sorted_keys(fixture.graph.nodes.keys()), "post-validation timeout retains forward evidence before reverse begins")
	# Locate a deterministic interruption *inside* reverse traversal. This scans
	# test clock cutoffs, not graph reachability; expected proof subset is literal.
	var found := false
	for cutoff in range(4, 40):
		clock_calls = 0
		expire_at = cutoff
		result = analyze_case(fixture, budget)
		if result.status == 1 and result.goal_reachable_states.has(fixture.keys.G) and not result.goal_reachable_states.has(fixture.keys.S):
			found = true
			check(result.reachable_states == sorted_keys(fixture.graph.nodes.keys()), "reverse cutoff retains validated forward evidence")
			check(result.softlock_states == null and result.reset_classification == 2, "reverse cutoff no negative/Reset proof")
			break
	check(found, "controlled reverse time budget interrupted real reverse work")
	validation_result = {"ok": false, "issues": [{"code": 3007, "severity": 0, "path": "nodes", "message": "owner error", "details": {}, "upstream": []}]}
	clock_calls = 0
	expire_at = 3
	result = analyze_case(fixture, budget)
	check(result.status == 2, "Graph validation error beats simultaneous timeout")
	validation_result = {"ok": true, "issues": []}
	expire_at = -1
	clock_calls = 0
	result = analyze_case(fixture, budget)
	var final_clock_call := clock_calls
	check(result.status == 0, "unlimited controlled time completes timed analysis")
	clock_calls = 0
	expire_at = final_clock_call
	result = analyze_case(fixture, budget)
	check(result.status == 1 and result.softlock_count == null and result.witnesses == [], "return-boundary timeout cannot leak complete softlock conclusions")
	expire_at = -1
