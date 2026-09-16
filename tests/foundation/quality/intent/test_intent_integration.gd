extends SceneTree
const F = preload("res://tests/foundation/quality/intent/intent_fixtures.gd")
const D = preload("res://tests/foundation/quality/intent/solver_contract_double.gd")
const A = preload("res://foundation/quality/intent/ablation_analyzer.gd")
const C = preload("res://foundation/quality/intent/mechanic_classifier.gd")
const M = preload("res://foundation/quality/intent/milestone_analyzer.gd")
var checks := 0
var failures: Array[String] = []
var evidence := ""
var real := false
var real_searches: Array = []
var real_semantics: Array = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence = argument.trim_prefix("--evidence-dir=")
	real = FileAccess.file_exists("res://foundation/solver/bfs_solver.gd") and FileAccess.file_exists("res://foundation/solver/solution_trace.gd") and FileAccess.file_exists("res://foundation/solver/search_records.gd")
	for name in ["required_shift","shift_bypass","required_enter_celestial","multiple_celestial_entries","optional_mechanism"]:
		var fixture := F.scenario(name)
		var level: Dictionary = fixture.level
		var w := F.witness(level,fixture.actions)
		check(fixture.validation.status == 0,"real Baker and Validator "+name)
		var policy := F.policy()
		var budget := F.budget()
		var result: Dictionary
		var searches: Array = []
		var semantic_checks: Array = []
		if real:
			policy = load("res://foundation/solver/search_records.gd").default_policy(0)
			result = A.analyze(level,w.trace.initial_state,fixture.intent,policy,budget)
			real_searches = []
			real_semantics = []
			var trace_api: Script = load("res://foundation/solver/solution_trace.gd")
			var repeated := A._analyze_with_ports(level,w.trace.initial_state,fixture.intent,policy,budget,_solve_recorded,_semantics_recorded)
			check(repeated.baseline.solution_trace == result.baseline.solution_trace,"real Solver repeatable first trace "+name)
			check(repeated.status == result.status and repeated.ablations[0].ablated_status == result.ablations[0].ablated_status,"real recorded run repeats ablation conclusion "+name)
			searches = real_searches.duplicate(true)
			semantic_checks = real_semantics.duplicate(true)
			check(semantic_checks.size() >= 2,"quality witnesses invoke real semantic verification "+name)
			check(trace_api.validate_semantics(level,result.baseline.solution_trace).ok,"real3A verifies baseline witness "+name)
			var forged: Dictionary = result.baseline.solution_trace.duplicate(true)
			forged.steps[0].action = {"kind":0,"face_axis":1}
			check(trace_api.validate(level,forged).ok,"forged witness retains correct structure/keys/Goal "+name)
			var rejected := M.analyze_trace(level,fixture.intent,forged)
			check(rejected.status == 3 and rejected.findings == [],"real semantic gate rejects unreachable action "+name)
			if name == "shift_bypass":
				var milestones: Dictionary = fixture.intent.duplicate(true)
				milestones.expected_milestones = [F.milestone(&"must_shift",{"kind":3,"mechanic":1})]
				var bypass := M.analyze_trace(level,milestones,result.baseline.solution_trace)
				check(bypass.status == 1 and bypass.findings[0].code == 4001,"real witness gives milestone bypass")
				milestones.expected_milestones[0].required = false
				check(M.analyze_trace(level,milestones,result.baseline.solution_trace).status == 0,"real optional missing milestone is not error")
			if name == "optional_mechanism":
				check(result.advisories.size() == 1 and result.advisories[0].severity == 1 and result.advisories[0].scope == &"RETURNED_SHORTEST_TRACE","unused mechanism is shortest-witness advisory only")
			if name == "required_shift":
				var ablated_budget := budget.duplicate(true)
				ablated_budget.max_action_evaluations = 6
				var bounded := A.analyze(level,w.trace.initial_state,fixture.intent,policy,ablated_budget)
				check(bounded.baseline.status == 0 and bounded.status == 1 and bounded.ablations[0].ablated_status == 2 and bounded.ablations[0].essential == null and bounded.ablations[0].bypass_detected == null,"real ablated budget exhaustion after solved baseline has no binary conclusion")
				_save("required_shift_ablated_budget",{"dependency":"REAL_3A_SOLVER","intent":fixture.intent,"budget":ablated_budget,"analysis":bounded})
		else:
			var double := D.new()
			double.setup(level,w)
			double.outcomes = {"[]":0,str([fixture.tag]):fixture.ablated_status}
			result = A._analyze_with_ports(level,w.trace.initial_state,fixture.intent,policy,budget,double.solve,double.validate_semantics)
			for index in double.calls.size():
				var record: Dictionary = double.calls[index]
				var response: Dictionary = double.responses[index]
				searches.append({"policy_descriptor":F.descriptor(record.policy),"budget":record.budget.duplicate(true),"status":response.status,"metrics":response.metrics,"graph_complete":response.graph.complete if response.graph is Dictionary else null,"stop_reason":response.graph.stop_reason if response.graph is Dictionary else null,"has_trace":response.solution_trace != null,"scope":"TEST_DOUBLE_REGISTERED_WITNESS"})
		check(result.status == 0 and result.ablations.size() == 1,"analysis completes "+name)
		if result.ablations.size() != 1: continue
		var sub: Dictionary = result.ablations[0]
		check(sub.ablated_status == fixture.ablated_status,"expected result contract "+name)
		check(sub.essential == (fixture.ablated_status == 1),"essential conclusion "+name)
		check(sub.bypass_detected == (name == "shift_bypass"),"only required bypass finding "+name)
		check(result.milestone_analysis.status == 0 and result.milestone_analysis.scope == "SINGLE_TRACE","Goal milestone witness scope "+name)
		if name == "multiple_celestial_entries":
			for route in [[{"kind":7,"celestial_op":0,"target_slot_id":&"b","alternate_slot_id":&"","mechanism_id":&"console"},{"kind":1}],[{"kind":5,"mechanism_id":&"console"},{"kind":1}],fixture.actions]:
				var known := F.witness(level,route)
				var tagged := C.classify_transition(level,known.transitions[0])
				check(tagged.ok and 6 in tagged.tags,"same celestial tag across direct/TRIGGER/ENTER")
				var filter := A._filter(level,known.transitions[0],[6])
				check(filter.ok and not filter.allow,"all three celestial entries filtered atomically")
		var limited: Dictionary
		var limited_budget := budget.duplicate(true)
		if real:
			limited_budget.max_states = 1
			limited = A.analyze(level,w.trace.initial_state,fixture.intent,policy,limited_budget)
		else:
			var incomplete := D.new()
			incomplete.setup(level,w)
			incomplete.outcomes = {"[]":0,str([fixture.tag]):2}
			incomplete.preserve_budget_witness = true
			limited = A._analyze_with_ports(level,w.trace.initial_state,fixture.intent,policy,budget,incomplete.solve,incomplete.validate_semantics)
		check(limited.status == 1,"tiny-budget/incomplete port result "+name)
		_save(name,{"dependency":"REAL_3A_SOLVER" if real else "SOLVER_CONTRACT_DOUBLE; semantic gate is registered fixture only","level_hash":level.content_hash,"intent":fixture.intent,"policy_descriptor":F.descriptor(policy),"budget":budget,"search_requests":searches,"semantic_verifications":semantic_checks,"analysis":result,"incomplete_budget":limited_budget,"incomplete_analysis":limited,"baker_validation":fixture.validation})
		if real: print("REAL_INTENT_CASE ",name," baseline=",result.baseline.status," ablated=",sub.ablated_status," essential=",sub.essential," bypass=",sub.bypass_detected," baseline_actions=",result.baseline.metrics.solution_length," evaluations=",sub.metrics.baseline.action_evaluations,"/",sub.metrics.ablated.action_evaluations)
	print("INTENT_INTEGRATION checks=",checks," failures=",failures)
	if not real: print("DEPENDENCY_PENDING: REAL_3A_SOLVER")
	if failures.is_empty(): print("INTENT_INTEGRATION_PASS" if real else "INTENT_INTEGRATION_PROVISIONAL_PASS")
	quit(0 if failures.is_empty() else 1)

func _solve_recorded(level: Dictionary, initial: Dictionary, policy: Dictionary, budget: Dictionary) -> Dictionary:
	# Tests-only observation adapter: every call goes to the formal 3A Solver.
	var response: Dictionary = load("res://foundation/solver/bfs_solver.gd").solve(level,initial,policy,budget)
	real_searches.append({"policy_descriptor":F.descriptor(policy),"budget":budget.duplicate(true),"status":response.status,"metrics":response.metrics.duplicate(true),"graph_complete":response.graph.complete if response.graph is Dictionary else null,"stop_reason":response.graph.stop_reason if response.graph is Dictionary else null,"has_trace":response.solution_trace != null,"solution_trace":response.solution_trace.duplicate(true) if response.solution_trace is Dictionary else null,"scope":"REAL_3A_SEARCH","issues":response.issues.duplicate(true)})
	return response

func _semantics_recorded(level: Dictionary, trace: Dictionary) -> Dictionary:
	var response: Dictionary = load("res://foundation/solver/solution_trace.gd").validate_semantics(level,trace)
	real_semantics.append({"ok":response.ok,"total_actions":trace.total_actions,"policy_descriptor":trace.policy_descriptor.duplicate(true),"issues":response.issues.duplicate(true)})
	return response

func _save(name: String, record: Dictionary) -> void:
	if evidence.is_empty(): return
	# Diagnostic evidence only, no imported trace format or serializer API.
	var path := evidence.path_join(name+".txt")
	var file := FileAccess.open(path,FileAccess.WRITE)
	check(file != null,"evidence output "+name)
	if file != null: file.store_string(var_to_str(record))
