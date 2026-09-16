extends RefCounted
const T = preload("res://foundation/quality/intent/intent_types.gd")
const Intent = preload("res://foundation/quality/intent/intent_validation.gd")
const Mechanics = preload("res://foundation/quality/intent/mechanic_classifier.gd")
const Milestones = preload("res://foundation/quality/intent/milestone_analyzer.gd")

static func analyze(level: Dictionary, initial: Dictionary, intent: Dictionary, policy: Dictionary, budget: Dictionary) -> Dictionary:
	var solver := Callable()
	var semantics := Callable()
	if FileAccess.file_exists("res://foundation/solver/bfs_solver.gd"):
		solver = Callable(load("res://foundation/solver/bfs_solver.gd"),"solve")
	if FileAccess.file_exists("res://foundation/solver/solution_trace.gd"):
		semantics = Callable(load("res://foundation/solver/solution_trace.gd"),"validate_semantics")
	return _analyze_with_ports(level,initial,intent,policy,budget,solver,semantics)

static func _analyze_with_ports(level: Dictionary, initial: Dictionary, intent: Dictionary, policy: Dictionary, budget: Dictionary, solver: Callable, semantics: Callable) -> Dictionary:
	var output := {"status":T.AblationStatus.COMPLETE,"intent":intent.duplicate(true),"baseline":null,"ablations":[],"milestone_analysis":null,"advisories":[],"issues":[]}
	var valid := Intent.validate(level,intent)
	if not valid.ok: return _fail(output,valid.issues)
	if not _unfiltered(policy): return _fail(output,[T._issue(3002,"policy","Analysis requires the closed UNFILTERED baseline SearchPolicy.")])
	if not solver.is_valid() or not semantics.is_valid(): return _fail(output,[T._issue(3016,"dependency","DEPENDENCY_PENDING: REAL_3A_SOLVER solve and validate_semantics are required.")])
	var raw: Variant = solver.call(level.duplicate(true),initial.duplicate(true),policy.duplicate(true),budget.duplicate(true))
	if not _solver_result(raw): return _fail(output,[T._issue(3016,"baseline","Malformed SolverResult.")])
	var baseline: Dictionary = raw.duplicate(true)
	output.baseline = baseline.duplicate(true)
	if baseline.status == 1 and not _graph_scope(baseline.graph,level,initial,policy): return _fail(output,[T._issue(3007,"baseline.graph","Complete graph belongs to a different request.")])
	# SolverStatus's numeric ABI is frozen and owned by 3A, not redefined here.
	if baseline.status == 3: return _fail(output,baseline.issues)
	if baseline.status == 1:
		output.status = T.AblationStatus.BASELINE_UNSOLVABLE
		return output
	if baseline.status == 2:
		output.status = T.AblationStatus.INCOMPLETE
		if baseline.solution_trace is Dictionary:
			var witness := _witness(level,initial,policy,baseline.solution_trace,semantics,[])
			if not witness.ok: return _fail(output,witness.issues)
			output.advisories = _advisories(level,intent,baseline.solution_trace,witness.transitions,true)
		return output
	var checked := _witness(level,initial,policy,baseline.solution_trace,semantics,[])
	if not checked.ok: return _fail(output,checked.issues)
	output.milestone_analysis = Milestones._analyze_with_validator(level,intent,baseline.solution_trace,semantics)
	if output.milestone_analysis.status == T.MilestoneStatus.ERROR: return _fail(output,output.milestone_analysis.issues)
	if output.milestone_analysis.status == T.MilestoneStatus.INCOMPLETE: output.status = T.AblationStatus.INCOMPLETE
	output.advisories = _advisories(level,intent,baseline.solution_trace,checked.transitions,false)
	for request in _requests(intent):
		var filtered := policy.duplicate(true)
		filtered.filter_descriptor = {"filter_id":&"MECHANIC_ABLATION","filter_version":"1","disabled_mechanics":request.disabled.duplicate(true)}
		filtered.transition_filter = _filter.bind(request.disabled.duplicate(true))
		var result: Variant = solver.call(level.duplicate(true),initial.duplicate(true),filtered.duplicate(true),budget.duplicate(true))
		var sub := {"status":T.AblationStatus.COMPLETE,"disabled_mechanics":request.disabled.duplicate(true),"baseline_status":baseline.status,"ablated_status":null,"essential":null,"bypass_detected":null,"findings":[],"solution_trace_if_any":null,"metrics":{"baseline":baseline.metrics.duplicate(true),"ablated":null},"issues":[]}
		if not _solver_result(result) or (result.status == 1 and not _graph_scope(result.graph,level,initial,filtered)):
			sub.status = T.AblationStatus.ERROR
			sub.issues = [T._issue(3016,"ablation","Malformed SolverResult.")]
		else:
			sub.ablated_status = result.status
			sub.metrics.ablated = result.metrics.duplicate(true)
			sub.solution_trace_if_any = result.solution_trace.duplicate(true) if result.solution_trace is Dictionary else null
			sub.issues = result.issues.duplicate(true)
			match result.status:
				0:
					var witness := _witness(level,initial,filtered,result.solution_trace,semantics,request.disabled)
					if not witness.ok:
						sub.status = T.AblationStatus.ERROR
						sub.issues = witness.issues
					else:
						sub.essential = false
						sub.bypass_detected = not request.required.is_empty() or not request.ids.is_empty()
						if sub.bypass_detected:
							var subjects: Array = request.ids.duplicate(true)
							if not request.required.is_empty() and intent.intent_id not in subjects: subjects.append(intent.intent_id)
							subjects.sort()
							sub.findings.append({"code":T.QualityCode.MECHANIC_BYPASS,"severity":0,"subject_ids":subjects,"scope":&"MECHANIC_ABLATION","trace":result.solution_trace.duplicate(true),"details":{"disabled_mechanics":request.disabled.duplicate(true),"required_mechanics":request.required.duplicate(true),"bypass_ids":request.ids.duplicate(true)}})
				1:
					sub.essential = true
					sub.bypass_detected = false
				2:
					sub.status = T.AblationStatus.INCOMPLETE
				3:
					sub.status = T.AblationStatus.ERROR
		output.ablations.append(sub)
		output.issues.append_array(sub.issues.duplicate(true))
		if sub.status == T.AblationStatus.ERROR: output.status = T.AblationStatus.ERROR
		elif sub.status == T.AblationStatus.INCOMPLETE and output.status != T.AblationStatus.ERROR: output.status = T.AblationStatus.INCOMPLETE
	return output

static func _witness(level: Dictionary, initial: Dictionary, policy: Dictionary, trace: Dictionary, validator: Callable, disabled: Array) -> Dictionary:
	# 3A owns the complete trace schema/replay; we check request binding and
	# our filter semantics in addition to its mandatory semantic verification.
	var checked := Milestones._checked_trace(level,trace,validator)
	if not checked.ok: return checked
	var descriptor := policy.duplicate(true)
	descriptor.erase("transition_filter")
	if trace.initial_state != initial or trace.get("policy_descriptor") != descriptor:
		return {"ok":false,"transitions":[],"issues":[T._issue(3008,"trace","Witness belongs to a different initial state or policy.")]}
	for transition in checked.transitions:
		var classification := Mechanics.classify_transition(level,transition)
		if not classification.ok: return {"ok":false,"transitions":[],"issues":classification.issues}
		for tag in disabled:
			if tag in classification.tags: return {"ok":false,"transitions":[],"issues":[T._issue(3009,"trace","Ablated witness contains a disabled mechanic.")]}
	return checked

static func _filter(level: Dictionary, transition: Dictionary, disabled: Array) -> Dictionary:
	var classification := Mechanics.classify_transition(level,transition)
	if not classification.ok: return {"ok":false,"allow":false,"issues":classification.issues.duplicate(true)}
	for tag in disabled:
		if tag in classification.tags: return {"ok":true,"allow":false,"issues":[]}
	return {"ok":true,"allow":true,"issues":[]}

static func _requests(intent: Dictionary) -> Array:
	var requests: Array = []
	var by_set: Dictionary = {}
	for tag in intent.required_mechanics + intent.optional_mechanics:
		var record := {"disabled":[tag],"required":[tag] if tag in intent.required_mechanics else [],"ids":[]}
		by_set[str([tag])] = requests.size()
		requests.append(record)
	for forbidden in intent.forbidden_bypasses:
		var key := str(forbidden.disabled_mechanics)
		if not by_set.has(key):
			by_set[key] = requests.size()
			requests.append({"disabled":forbidden.disabled_mechanics.duplicate(true),"required":[],"ids":[]})
		requests[by_set[key]].ids.append(forbidden.bypass_id)
	return requests

static func _advisories(level: Dictionary, intent: Dictionary, trace: Dictionary, transitions: Array, budget_witness: bool) -> Array:
	var used: Array = []
	for transition in transitions:
		var classified := Mechanics.classify_transition(level,transition)
		for id in classified.mechanism_ids:
			if id not in used: used.append(id)
	var output: Array = []
	var mechanisms: Array = level.mechanisms.duplicate(true)
	mechanisms.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return String(a.mechanism_id) < String(b.mechanism_id))
	for mechanism in mechanisms:
		if mechanism.mechanism_id in used: continue
		var potential := [T.MechanicTag.MECHANISM_TRIGGER,Mechanics._effect_tag(mechanism.action.kind)]
		var required: Array = []
		var optional: Array = []
		for tag in intent.required_mechanics:
			if tag in potential: required.append(tag)
		for tag in intent.optional_mechanics:
			if tag in potential: optional.append(tag)
		output.append({"code":T.QualityCode.UNUSED_MECHANISM,"severity":1,"subject_ids":[mechanism.mechanism_id],"scope":&"DISCOVERED_WITNESS" if budget_witness or not trace.get("shortest",false) else &"RETURNED_SHORTEST_TRACE","trace":trace.duplicate(true),"details":{"mechanism_id":mechanism.mechanism_id,"required_mechanics":required,"optional_mechanics":optional,"observed_used":false}})
	return output

static func _unfiltered(policy: Dictionary) -> bool:
	if not Intent._record(policy,["strategy","mode","validation_options","filter_descriptor","transition_filter"],"policy").ok: return false
	if typeof(policy.strategy) != TYPE_STRING_NAME or policy.strategy != &"BFS" or typeof(policy.mode) != TYPE_INT or policy.mode not in [0,1]: return false
	if typeof(policy.transition_filter) != TYPE_CALLABLE or not policy.transition_filter.is_null(): return false
	if not Intent._record(policy.validation_options,["max_configurations","max_checks"],"policy").ok: return false
	for value in policy.validation_options.values():
		if typeof(value) != TYPE_INT or value <= 0: return false
	if not Intent._record(policy.filter_descriptor,["filter_id","filter_version","disabled_mechanics"],"policy").ok: return false
	var filter: Dictionary = policy.filter_descriptor
	return typeof(filter.filter_id) == TYPE_STRING_NAME and filter.filter_id == &"UNFILTERED" and typeof(filter.filter_version) == TYPE_STRING and filter.filter_version == "1" and filter.disabled_mechanics is Array and filter.disabled_mechanics.is_empty()

static func _solver_result(value: Variant) -> bool:
	if not Intent._record(value,["status","graph","solution_trace","metrics","budget_reason","issues","validation"],"solver").ok: return false
	if typeof(value.status) != TYPE_INT or value.status not in [0,1,2,3] or not value.metrics is Dictionary or not value.issues is Array or typeof(value.budget_reason) != TYPE_INT: return false
	if value.status == 0 and not value.solution_trace is Dictionary: return false
	if value.solution_trace != null and not value.solution_trace is Dictionary: return false
	if value.status == 3 and value.issues.is_empty(): return false
	if value.status in [0,1] and not value.issues.is_empty(): return false
	if value.status == 1 and (value.solution_trace != null or not value.graph is Dictionary or value.graph.get("complete") != true or value.graph.get("stop_reason") != 0): return false
	if value.status == 2 and value.budget_reason not in [1,2,3,4,5]: return false
	if value.status != 2 and value.budget_reason != 0: return false
	return true

static func _graph_scope(graph: Dictionary, level: Dictionary, initial: Dictionary, policy: Dictionary) -> bool:
	var descriptor := policy.duplicate(true)
	descriptor.erase("transition_filter")
	if graph.get("level_hash") != level.content_hash or graph.get("rule_version") != level.rule_version or graph.get("policy_descriptor") != descriptor: return false
	var nodes: Variant = graph.get("nodes")
	if not nodes is Dictionary or not nodes.get(graph.get("initial_key")) is Dictionary: return false
	return nodes[graph.initial_key].get("state") == initial

static func _fail(output: Dictionary, issues: Array) -> Dictionary:
	output.status = T.AblationStatus.ERROR
	output.issues.append_array(issues.duplicate(true))
	return output
