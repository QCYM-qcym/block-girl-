extends SceneTree
const F = preload("res://tests/foundation/quality/intent/intent_fixtures.gd")
const D = preload("res://tests/foundation/quality/intent/solver_contract_double.gd")
var A
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run_case(level: Dictionary, w: Dictionary, intent: Dictionary, outcomes: Dictionary) -> Dictionary:
	var double := D.new()
	double.setup(level,w)
	double.outcomes = outcomes.duplicate(true)
	var policy := F.policy()
	var budget := F.budget()
	var initial: Dictionary = w.trace.initial_state.duplicate(true)
	var saved := [level.duplicate(true),initial.duplicate(true),intent.duplicate(true),policy.duplicate(true),budget.duplicate(true)]
	var result: Dictionary = A._analyze_with_ports(level,initial,intent,policy,budget,double.solve,double.validate_semantics)
	check([level,initial,intent,policy,budget] == saved,"all caller inputs unchanged")
	for call_record in double.calls:
		check(call_record.budget == budget and call_record.level == level and call_record.initial == initial,"same Solver inputs and independent budgets")
	return {"result":result,"double":double}

func _initialize() -> void:
	var path := "res://foundation/quality/intent/ablation_analyzer.gd"
	if not FileAccess.file_exists(path):
		check(false,"ablation implementation missing")
		finish()
		return
	A = load(path)
	if not A.can_instantiate():
		check(false,"ablation compiles")
		finish()
		return
	var level := F.baked_level()
	var w := F.witness(level,[{"kind":0,"face_axis":0}])
	var intent := F.empty_intent(level)
	intent.required_mechanics = [1]
	intent.optional_mechanics = [6]
	intent.forbidden_bypasses = [{"bypass_id":&"no_shift", "disabled_mechanics":[1]},{"bypass_id":&"also_no_shift", "disabled_mechanics":[1]},{"bypass_id":&"pair", "disabled_mechanics":[1,6]}]
	var run := run_case(level,w,intent,{"[]":0,"[1]":0,"[6]":0,"[1, 6]":1})
	var result: Dictionary = run.result
	check(result.status == 0 and result.ablations.size() == 3 and run.double.calls.size() == 4,"deduplicate same disabled set")
	var required: Dictionary = result.ablations[0]
	check(required.essential == false and required.bypass_detected == true and required.findings[0].code == 4000,"required bypass hard finding")
	check(&"no_shift" in required.findings[0].subject_ids and &"also_no_shift" in required.findings[0].subject_ids,"shared run retains every forbidden declaration")
	check(result.ablations[1].essential == false and result.ablations[1].bypass_detected == false and result.ablations[1].findings.is_empty(),"optional solvable ablation not error")
	check(result.ablations[2].essential == true and result.ablations[2].bypass_detected == false,"unsolvable disabled collection essential as a whole")
	check(not result.advisories.is_empty() and result.advisories[0].code == 4002 and result.advisories[0].severity == 1 and result.advisories[0].details.observed_used == false,"unused console only warning")
	check(run.double.semantic_calls.size() >= 3,"solved witnesses semantically gated")
	var forbidden_only := F.empty_intent(level)
	forbidden_only.forbidden_bypasses = [{"bypass_id":&"declared_pair","disabled_mechanics":[1,6]}]
	var forbidden_run := run_case(level,w,forbidden_only,{"[]":0,"[1, 6]":0})
	check(forbidden_run.result.ablations[0].essential == false and forbidden_run.result.ablations[0].bypass_detected == true and forbidden_run.result.ablations[0].findings[0].subject_ids == [&"declared_pair"],"forbidden collection alone produces a bypass without required tags")
	# Contradictory status/result metadata cannot be interpreted as proof.
	var invalid_result: Dictionary = run.double.solve(level,w.trace.initial_state,F.policy(),F.budget())
	invalid_result.status = 1
	invalid_result.solution_trace = null
	invalid_result.graph = null
	check(not A._solver_result(invalid_result),"PROVEN_UNSOLVABLE requires the Solver's complete graph")
	for baseline_status in [1,2,3]:
		run = run_case(level,w,intent,{"[]":baseline_status})
		check(run.result.status == {1:3,2:1,3:2}[baseline_status] and run.result.ablations.is_empty() and run.double.calls.size() == 1,"baseline gates later runs "+str(baseline_status))
	intent = F.empty_intent(level)
	intent.required_mechanics = [1]
	var mixed := intent.duplicate(true)
	mixed.optional_mechanics = [6]
	run = run_case(level,w,mixed,{"[]":0,"[1]":2,"[6]":3})
	check(run.result.status == 2 and run.result.ablations.size() == 2,"ERROR outranks INCOMPLETE without discarding per-run outcomes")
	for status in [2,3]:
		run = run_case(level,w,intent,{"[]":0,"[1]":status})
		var sub: Dictionary = run.result.ablations[0]
		check(run.result.status == (1 if status == 2 else 2) and sub.essential == null and sub.bypass_detected == null and sub.findings == [],"budget/error never assert essential/bypass")
	var double := D.new()
	double.setup(level,w)
	double.outcomes = {"[]":0,"[1]":2}
	double.preserve_budget_witness = true
	result = A._analyze_with_ports(level,w.trace.initial_state,intent,F.policy(),F.budget(),double.solve,double.validate_semantics)
	check(result.status == 1 and result.ablations[0].essential == null and result.ablations[0].bypass_detected == null and result.ablations[0].solution_trace_if_any != null,"budget witness is attachment only")
	double.outcomes = {"[]":0,"[1]":0}
	double.reject_semantics = true
	result = A._analyze_with_ports(level,w.trace.initial_state,intent,F.policy(),F.budget(),double.solve,double.validate_semantics)
	check(result.status == 2 and result.ablations.is_empty() and result.advisories == [],"forged baseline gate blocks quality conclusions")
	double.reject_semantics = false
	double.corrupt_witness = true
	result = A._analyze_with_ports(level,w.trace.initial_state,intent,F.policy(),F.budget(),double.solve,double.validate_semantics)
	check(result.status == 2 and result.ablations.is_empty(),"forged action with unchanged endpoint rejected")
	double.corrupt_witness = false
	var policy := F.policy()
	policy.filter_descriptor = {"filter_id":&"MECHANIC_ABLATION","filter_version":"1","disabled_mechanics":[1]}
	var old_count := double.calls.size()
	result = A._analyze_with_ports(level,w.trace.initial_state,intent,policy,F.budget(),double.solve,double.validate_semantics)
	check(result.status == 2 and result.issues[0].code == 3002 and double.calls.size() == old_count,"filtered policy cannot be baseline")
	intent.optional_mechanics = [1]
	result = A._analyze_with_ports(level,w.trace.initial_state,intent,F.policy(),F.budget(),double.solve,double.validate_semantics)
	check(result.status == 2 and double.calls.size() == old_count,"invalid intent invokes no Solver")
	# A Solver returning a witness that used a disabled tag must be rejected,
	# even if semantic validation says the route itself is a legal one.
	level = F.baked_level(true)
	w = F.witness(level,[{"kind":0,"face_axis":0}])
	intent = F.empty_intent(level)
	intent.required_mechanics = [6]
	run = run_case(level,w,intent,{"[]":0,"[6]":0})
	check(run.result.status == 2 and run.result.ablations[0].essential == null and run.result.ablations[0].findings == [],"disabled-tag witness is filter error, not bypass")
	var filter: Callable = run.double.calls[1].policy.transition_filter
	var transition: Dictionary = w.transitions[0].duplicate(true)
	var saved := transition.duplicate(true)
	var filtered: Dictionary = filter.call(level,transition)
	check(filtered.ok and not filtered.allow and filtered.size() == 3 and transition == saved,"MOVE plus ENTER removed atomically, no fabricated state")
	transition.status = 2
	filtered = filter.call(level,transition)
	check(not filtered.ok and not filtered.allow and not filtered.issues.is_empty(),"callback error cannot masquerade as a banned edge")
	if not FileAccess.file_exists("res://foundation/solver/bfs_solver.gd"):
		result = A.analyze(level,w.trace.initial_state,intent,F.policy(),F.budget())
		check(result.status == 2 and result.baseline == null,"public entry has no Solver double fallback")
	finish()

func finish() -> void:
	print("ABLATION_ANALYZER checks=",checks," failures=",failures)
	if failures.is_empty(): print("ABLATION_ANALYZER_PROVISIONAL_PASS")
	quit(0 if failures.is_empty() else 1)
