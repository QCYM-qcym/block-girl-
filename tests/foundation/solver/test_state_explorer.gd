extends SceneTree
const Fixtures = preload("res://tests/foundation/solver/solver_fixtures.gd")
const Double = preload("res://tests/foundation/solver/explorer_double.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Search = preload("res://foundation/solver/search_records.gd")
var checks := 0
var failures: Array[String] = []
var explorer
var solver
var graph_type
var trace_type
var level: Dictionary
var initial: Dictionary
var real_reports: Array = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL: ",label)

func _initialize() -> void:
	if not FileAccess.file_exists("res://foundation/solver/state_explorer.gd"):
		check(false,"StateExplorer entry missing")
		finish()
		return
	explorer = load("res://foundation/solver/state_explorer.gd")
	solver = load("res://foundation/solver/bfs_solver.gd")
	graph_type = load("res://foundation/solver/state_graph.gd")
	trace_type = load("res://foundation/solver/solution_trace.gd")
	level = Fixtures.corridor()
	initial = Records.initial_state(level)
	test_topology()
	test_budgets()
	test_errors_filters()
	test_real()
	test_real_mechanisms()
	test_strict_boundaries()
	finish()

func run_double(double: RefCounted, mode: int = 0, limits: Dictionary = {}, policy_override: Dictionary = {}) -> Dictionary:
	var budget := Search.default_budget()
	budget.merge(limits,true)
	var policy := Search.default_policy(mode)
	policy.merge(policy_override,true)
	return explorer._explore(level,initial,policy,budget,double.ports())

func test_topology() -> void:
	var double := Double.new()
	var first := run_double(double)
	check(first.status == 0 and first.solution_trace.total_actions == 2,"FIFO returns shorter route")
	check(not first.graph.complete and first.graph.stop_reason == 1,"first Goal stops before closure")
	check(first.solution_trace.steps[0].action == {"kind":0,"face_axis":0},"first equal-length route deterministic")
	check(first.metrics.shortest_solution_count == null and not first.metrics.shortest_solution_count_complete,"no invented solution count")
	var full := run_double(Double.new(),1)
	check(full.status == 0 and full.graph.complete and full.graph.stop_reason == 0,"full graph solved after closure")
	check(full.metrics.visited_states == 5 and full.metrics.explored_states == 5,"unique nodes and goal expansion")
	check(full.metrics.generated_edges == 7 and full.metrics.duplicate_states == 3,"parallel edges and cycle retained")
	check(full.metrics.action_evaluations == 20 and full.metrics.rejected_actions == 13,"each ordinary node expanded once")
	var start: String = full.graph.initial_key
	check(full.graph.forward[start] == [0,1,2],"stable parallel adjacency")
	check(full.graph.edges[0].to_key == full.graph.edges[2].to_key,"different semantic action same target")
	check(full.graph.nodes[full.graph.edges[0].to_key].predecessor_edge == 0,"first predecessor never overwritten")
	for edge in full.graph.edges:
		check(full.graph.forward[edge.from_key].count(edge.edge_id) == 1 and full.graph.reverse[edge.to_key].count(edge.edge_id) == 1,"bidirectional index")
	var repeat := run_double(Double.new(),1)
	check(repeat.graph == full.graph and repeat.solution_trace == full.solution_trace,"count-budget determinism")
	var multi := Double.new()
	multi.goals = [3,5]
	multi.links[4] = {0:5}
	var multiple := run_double(multi,1)
	var deeper := initial.duplicate(true)
	deeper.player.orientation = 5
	var longer: Dictionary = trace_type._from_graph(level,multiple.graph,Key.build(level,deeper).key,multi.goal)
	check(longer.ok and longer.trace.total_actions == 3 and not longer.trace.shortest,"deeper Goal witness must not claim globally shortest solution")
	check(multiple.solution_trace.shortest and multiple.solution_trace.total_actions == 2,"first Goal remains shortest across all Goals")
	for node in full.graph.nodes.values():
		check(Key.build(level,node.state).key == node.state_key,"full canonical statekey identity")
	double = Double.new()
	double.goals = []
	var unsolved := run_double(double,1)
	check(unsolved.status == 1 and unsolved.graph.complete and unsolved.solution_trace == null,"complete no-goal graph is proven unsolvable")
	double = Double.new()
	double.goals = [0]
	var zero := run_double(double,0,{"max_edges":0,"max_states":1,"max_depth":0})
	check(zero.status == 0 and zero.graph.complete and zero.solution_trace.total_actions == 0 and double.calls == 0,"initial Goal zero budget edges")
	double = Double.new()
	double.links = {}
	double.no_op = true
	var idle := run_double(double,1,{"max_states":1,"max_edges":0,"max_action_evaluations":5})
	check(idle.status == 1 and idle.graph.edges.is_empty() and idle.metrics.no_op_actions == 5,"no-op omitted and exact attempt cap closes")

func test_budgets() -> void:
	for item in [["max_states",1,1],["max_edges",0,2],["max_depth",0,3],["max_action_evaluations",1,5]]:
		var result := run_double(Double.new(),1,{item[0]:item[1]})
		check(result.status == 2 and result.budget_reason == item[2] and not result.graph.complete,"budget " + item[0])
		check(not result.graph.nodes[result.graph.initial_key].expanded,"interrupted source remains unexpanded")
		check(result.metrics.visited_states == result.graph.nodes.size() and result.metrics.generated_edges == result.graph.edges.size(),"atomic capacity insert " + item[0])
	var double := Double.new()
	double.links = {0:{0:1},1:{0:0}}
	double.goals = []
	var exact := run_double(double,1,{"max_states":2,"max_edges":2,"max_depth":1,"max_action_evaluations":10})
	check(exact.status == 1 and exact.graph.complete and exact.metrics.max_depth_reached == 1,"depth boundary may point to visited; all caps exactly full")
	var goal_prefix := run_double(Double.new(),1,{"max_states":4})
	check(goal_prefix.status == 2 and goal_prefix.solution_trace.total_actions == 2,"FULL_GRAPH found goal still budget-exceeded")
	double = Double.new()
	double.advance_on_kernel = 2000
	var timed := run_double(double,0,{"max_runtime_ms":1})
	check(timed.status == 2 and timed.budget_reason == 4 and timed.metrics.action_evaluations == 1 and timed.graph.edges.is_empty(),"runtime after external call prevents late solved")
	double = Double.new()
	double.clock_jump_at = 3
	var preflight := run_double(double,0,{"max_runtime_ms":1})
	check(preflight.status == 2 and preflight.budget_reason == 4 and preflight.graph == null and double.calls == 0,"preflight time included")
	double = Double.new()
	double.fault = true
	double.advance_on_kernel = 2000
	var error := run_double(double,0,{"max_runtime_ms":1})
	check(error.status == 3 and error.issues[0].upstream[0].code == 1105,"Kernel error outranks concurrent timeout")
	for field in Search.default_budget():
		var limits := {field:-2}
		var invalid := run_double(Double.new(),0,limits)
		check(invalid.status == 3 and invalid.graph == null and invalid.issues[0].code == 3003,"invalid budget " + field)

func test_errors_filters() -> void:
	var double := Double.new()
	double.unproven = true
	var unsafe := run_double(double,1)
	check(unsafe.metrics.safety_unproven_rejections == 13,"1601 rejection counted per action")
	double = Double.new()
	double.validation_status = 2
	var incomplete := run_double(double)
	check(incomplete.status == 3 and incomplete.graph == null and incomplete.issues[0].code == 3011 and double.calls == 0,"Validator incomplete is not search closure")
	var descriptor := {"filter_id":&"MECHANIC_ABLATION","filter_version":"1","disabled_mechanics":[0]}
	var filtered := run_double(Double.new(),1,{}, {"filter_descriptor":descriptor,"transition_filter":func(_l,_r):return {"ok":true,"allow":false,"issues":[]}})
	check(filtered.status == 1 and filtered.metrics.filtered_edges == 3 and filtered.metrics.generated_edges == 0,"filter removes entire successful edge")
	check(filtered.graph.policy_descriptor.filter_descriptor == descriptor and not filtered.graph.policy_descriptor.has("transition_filter"),"descriptor exact projection")
	var failed := run_double(Double.new(),0,{}, {"filter_descriptor":descriptor,"transition_filter":func(_l,_r):return {"ok":false,"allow":false,"issues":[Search._issue(3009,"filter","Controlled failure.")]}})
	check(failed.status == 3 and failed.issues[0].code == 3009,"filter failure terminates")
	var bad := run_double(Double.new(),0,{}, {"filter_descriptor":descriptor})
	check(bad.status == 3 and bad.graph == null,"missing callback cannot become unfiltered")
	var immutable := var_to_bytes([level,initial])
	var mutation := run_double(Double.new(),0,{}, {"filter_descriptor":descriptor,"transition_filter":func(l,r):
		l.level_id = &"mutated"
		r.next_state.player.orientation = 23
		return {"ok":true,"allow":true,"issues":[]}})
	check(mutation.status == 0 and var_to_bytes([level,initial]) == immutable and mutation.solution_trace.steps[0].expected_state.player.orientation == 1,"filter cannot mutate accepted state")

func test_real() -> void:
	var policy := Search.default_policy(0)
	var budget := Search.default_budget()
	var before := var_to_bytes([level,initial,policy,budget])
	var result: Dictionary = solver.solve(level,initial,policy,budget)
	record_real("two_step_move_shift",result,policy,budget)
	check(result.status == 0,"real Baker Validator Kernel solved: " + str([result.status,result.metrics,result.issues]))
	if result.status == 0:
		check(result.solution_trace.total_actions == 2,"real literal two-step shortest")
		check(result.solution_trace.steps.map(func(s):return s.action) == [{"kind":0,"face_axis":0},{"kind":1}],"real literal MOVE then SHIFT sequence")
		check(result.solution_trace.steps[-1].expected_state.player == {"location":{"layer":1,"cube_id":&"cell2","face":4},"orientation":12},"real literal final pose")
		check(graph_type.validate(level,result.graph).ok,"real graph validation")
		check(trace_type.validate_semantics(level,result.solution_trace).ok,"real trace semantic replay")
	check(var_to_bytes([level,initial,policy,budget]) == before,"all public inputs immutable")
	var bad := level.duplicate(true)
	bad.content_hash = "f".repeat(64)
	var invalid: Dictionary = solver.solve(bad,initial,policy,budget)
	check(invalid.status == 3 and invalid.graph == null and invalid.validation == null and invalid.metrics.action_evaluations == 0,"fake hash fails before Validator/search")
	var low := policy.duplicate(true)
	low.validation_options.max_checks = 1
	invalid = solver.solve(level,initial,low,budget)
	check(invalid.status == 3 and invalid.graph == null and invalid.issues[0].code == 3011,"real Validator budget incomplete")
	var zero := Fixtures.corridor(1)
	var solved: Dictionary = solver.solve(zero,Records.initial_state(zero),policy,budget)
	record_real("zero_step_goal",solved,policy,budget)
	check(solved.status == 0 and solved.graph.complete and solved.solution_trace.total_actions == 0,"real zero-step Goal")
	var source := Fixtures.authoring()
	source.flag_definitions = [{"flag_id":&"never","initial_value":false}]
	source.goal.required_flags = [&"never"]
	var baked := Fixtures.bake(source)
	check(baked.ok,"real unreachable-goal fixture valid")
	if baked.ok:
		var closed: Dictionary = solver.solve(baked.level,Records.initial_state(baked.level),Search.default_policy(1),budget)
		record_real("required_flag_unsolvable",closed,Search.default_policy(1),budget)
		check(closed.status == 1 and closed.graph.complete,"real complete unsolvable")
		check(graph_type.validate(baked.level,closed.graph).ok,"real closed graph validates")
	# The conservative production Safety model may reject this physically plausible roll.
	source = Fixtures.authoring()
	source.cubes[2].layer = 0
	source.cubes[2].center2 = Vector3i(4,0,0)
	baked = Fixtures.bake(source)
	check(baked.ok,"real Safety rejection fixture passes static validation")
	if baked.ok:
		var safe_closed: Dictionary = solver.solve(baked.level,Records.initial_state(baked.level),Search.default_policy(1),budget)
		record_real("safety_unproven_closed",safe_closed,Search.default_policy(1),budget)
		check(safe_closed.status == 1 and safe_closed.metrics.safety_unproven_rejections == 1 and safe_closed.graph.edges.is_empty(),"real UNPROVEN stays rejected; no solver safety bypass")
	bad = level.duplicate(true)
	bad.cubes[1].center2 = Vector3i.ZERO
	bad.content_hash = load("res://foundation/level/level_codec.gd").compute_content_hash(bad).content_hash
	invalid = solver.solve(bad,initial,policy,budget)
	check(invalid.status == 3 and invalid.graph == null and invalid.validation.status == 1 and invalid.metrics.action_evaluations == 0,"true hash with invalid geometry fails before search")

func test_real_mechanisms() -> void:
	var source := Fixtures.authoring(2)
	Fixtures.add_celestial_mechanism(source,&"USE",&"cell0/TOP")
	var baked := Fixtures.bake(source)
	check(baked.ok,"real USE mechanism fixture bakes")
	if baked.ok:
		var result: Dictionary = solver.solve(baked.level,Records.initial_state(baked.level),Search.default_policy(1),Search.default_budget())
		record_real("use_parallel_full",result,Search.default_policy(1),Search.default_budget())
		check(result.status == 0 and result.graph.complete and result.solution_trace.total_actions == 1,"real USE full graph with one-step shortest")
		var outgoing: Array = result.graph.forward[result.graph.initial_key]
		check(outgoing.size() == 3,"real MOVE plus wrapper and direct edges")
		var wrapper: Dictionary = result.graph.edges[outgoing[1]]
		var direct: Dictionary = result.graph.edges[outgoing[2]]
		check(wrapper.action.kind == 5 and direct.action.kind == 7 and wrapper.to_key == direct.to_key and wrapper.global_kind == 1,"real semantic parallel edges")
		check(graph_type.validate(baked.level,result.graph).ok,"real parallel graph validation")
		var reordered: Dictionary = baked.level.duplicate(true)
		for field in ["faces","cubes","worlds","mechanisms"]:
			reordered[field].reverse()
		var again: Dictionary = solver.solve(reordered,Records.initial_state(reordered),Search.default_policy(1),Search.default_budget())
		check(again.graph == result.graph and again.solution_trace == result.solution_trace,"real declaration order independent graph")
	source = Fixtures.authoring(2)
	Fixtures.add_celestial_mechanism(source,&"ENTER",&"cell1/TOP")
	baked = Fixtures.bake(source)
	check(baked.ok,"real ENTER fixture bakes")
	if baked.ok:
		var enter: Dictionary = solver.solve(baked.level,Records.initial_state(baked.level),Search.default_policy(0),Search.default_budget())
		record_real("move_enter_atomic",enter,Search.default_policy(0),Search.default_budget())
		check(enter.status == 0 and enter.solution_trace.total_actions == 1,"MOVE plus ENTER costs one semantic action")
		check(enter.solution_trace.steps[0].global_kind == 1 and enter.solution_trace.steps[0].expected_state.celestial.slot_id == &"b","atomic ENTER state and global kind retained")
		check(trace_type.validate_semantics(baked.level,enter.solution_trace).ok,"real compound trace semantic validation")

func test_strict_boundaries() -> void:
	for field in ["strategy","mode","validation_options","filter_descriptor","transition_filter","unknown"]:
		var policy := Search.default_policy(0)
		policy[field] = "invalid"
		var result: Dictionary = explorer.explore(level,initial,policy,Search.default_budget())
		check(result.status == 3 and result.graph == null and result.issues[0].code == 3002,"policy rejects " + field)
	for property in ["goal_error","malformed_kernel","malformed_next"]:
		var double := Double.new()
		double.set(property,true)
		var result := run_double(double)
		check(result.status == 3 and not result.issues.is_empty(),"dependency fails closed: " + property)
	var bad := initial.duplicate(true)
	bad["debug"] = true
	var invalid: Dictionary = solver.solve(level,bad,Search.default_policy(0),Search.default_budget())
	check(invalid.status == 3 and invalid.graph == null and invalid.issues[0].code == 3001,"initial state closed schema")
	var descriptor := {"filter_id":&"MECHANIC_ABLATION","filter_version":"1","disabled_mechanics":[0]}
	var calls := [0]
	var failed_kernel := Double.new()
	failed_kernel.fault = true
	var rejected := run_double(failed_kernel,0,{}, {"filter_descriptor":descriptor,"transition_filter":func(_l,_r):
		calls[0] += 1
		return {"ok":true,"allow":false,"issues":[]}})
	check(rejected.status == 3 and calls[0] == 0,"filter never consumes Kernel ERROR")
	var malformed := run_double(Double.new(),0,{}, {"filter_descriptor":descriptor,"transition_filter":func(_l,_r):return {"ok":true,"allow":false,"issues":[],"extra":0}})
	check(malformed.status == 3 and malformed.issues[0].code == 3009,"filter closed schema")
	var rejected_double := Double.new()
	rejected_double.links = {}
	rejected_double.advance_on_kernel = 2000
	var timed_rejection := run_double(rejected_double,0,{"max_runtime_ms":1})
	check(timed_rejection.status == 2 and timed_rejection.metrics.rejected_actions == 1,"timed returned rejection still counted")
	var noop_double := Double.new()
	noop_double.no_op = true
	noop_double.advance_on_kernel = 2000
	var timed_noop := run_double(noop_double,0,{"max_runtime_ms":1})
	check(timed_noop.status == 2 and timed_noop.metrics.no_op_actions == 1,"timed returned no-op still counted")
	rejected_double = Double.new()
	rejected_double.links = {}
	rejected_double.unproven = true
	rejected_double.advance_on_kernel = 2000
	var timed_safety := run_double(rejected_double,0,{"max_runtime_ms":1})
	check(timed_safety.metrics.safety_unproven_rejections == 1,"timed 1601 returned result counted")
	var filter_clock := Double.new()
	var timed_filter := run_double(filter_clock,0,{"max_runtime_ms":1},{"filter_descriptor":descriptor,"transition_filter":func(_l,_r):
		filter_clock.now += 2000
		return {"ok":true,"allow":false,"issues":[]}})
	check(timed_filter.status == 2 and timed_filter.metrics.filtered_edges == 1,"timed filter deletion counted")
	var at_goal := Double.new()
	at_goal.goals = [1]
	at_goal.advance_on_kernel = 2000
	var late_goal := run_double(at_goal,0,{"max_runtime_ms":1})
	check(late_goal.status == 2 and late_goal.graph.nodes.size() == 1 and late_goal.solution_trace == null,"goal candidate arriving after deadline is not inserted or solved")
	var final_clock := Double.new()
	final_clock.goals = [0]
	var zero_baseline := run_double(final_clock)
	check(zero_baseline.status == 0,"controlled zero Goal for final return timing")
	var last_call: int = final_clock.clock_calls
	final_clock = Double.new()
	final_clock.goals = [0]
	final_clock.clock_jump_at = last_call
	var late_report := run_double(final_clock,0,{"max_runtime_ms":1})
	check(late_report.status == 2 and not late_report.graph.complete and late_report.solution_trace != null,"last return clock prevents late SOLVED report")

func record_real(label: String, result: Dictionary, policy: Dictionary, budget: Dictionary) -> void:
	real_reports.append({"fixture":label,"status":result.status,"policy_descriptor":Search._descriptor(policy),"budget":budget,
		"complete":result.graph.complete if result.graph != null else null,"stop_reason":result.graph.stop_reason if result.graph != null else null,
		"budget_reason":result.budget_reason,"metrics":result.metrics,"trace":result.solution_trace,"issues":result.issues,"validation":result.validation})

func finish() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			var directory := argument.trim_prefix("--evidence-dir=")
			FileAccess.open(directory.path_join("real-fixtures.json"),FileAccess.WRITE).store_string(JSON.stringify(real_reports,"\t"))
	print("STATE_EXPLORER_PASS checks=%d" % checks if failures.is_empty() else "STATE_EXPLORER_FAIL checks=%d" % checks)
	quit(0 if failures.is_empty() else 1)
