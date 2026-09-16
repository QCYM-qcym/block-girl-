extends RefCounted
const Search = preload("res://foundation/solver/search_records.gd")
const Graph = preload("res://foundation/solver/state_graph.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
const Goal = preload("res://foundation/rules/goal_evaluator.gd")
const Kernel = preload("res://foundation/rules/puzzle_rule_kernel.gd")
const Rules = preload("res://foundation/rules/rule_records.gd")
const Code = preload("res://foundation/solver/solver_types.gd").AnalysisCode

static func from_graph(level: Dictionary, graph: Dictionary, goal_key: String) -> Dictionary:
	return _from_graph(level,graph,goal_key,Goal.is_goal)

static func _from_graph(level: Dictionary, graph: Dictionary, goal_key: String, goal: Callable) -> Dictionary:
	var checked := Graph._validate(level,graph,goal)
	if not checked.ok:
		return {"ok":false,"trace":null,"issues":checked.issues}
	if not graph.nodes.has(goal_key) or not graph.nodes[goal_key].is_goal:
		return {"ok":false,"trace":null,"issues":[Search._issue(Code.GRAPH_INVALID,"goal_key","Requested node is not a Goal.")]}
	var steps: Array[Dictionary] = []
	var cursor := goal_key
	var seen := {}
	while cursor != graph.initial_key:
		if seen.has(cursor):
			return {"ok":false,"trace":null,"issues":[Search._issue(Code.GRAPH_INVALID,"predecessor","Cyclic predecessor.")]}
		seen[cursor] = true
		var node: Dictionary = graph.nodes[cursor]
		var edge: Dictionary = graph.edges[node.predecessor_edge]
		steps.append({"index":node.depth,"action":edge.action.duplicate(true),"expected_state":node.state.duplicate(true),"resulting_statekey":cursor,"global_kind":edge.global_kind})
		cursor = edge.from_key
	steps.reverse()
	# Only live Explorer graphs are supported; schema validation cannot certify provenance.
	var shortest := true
	for node in graph.nodes.values():
		if node.is_goal and node.depth < steps.size():
			shortest = false
	var trace := {"trace_version":"solutiontrace.v1","level_hash":graph.level_hash,"rule_version":graph.rule_version,
		"policy_descriptor":graph.policy_descriptor.duplicate(true),"initial_state":graph.nodes[graph.initial_key].state.duplicate(true),
		"initial_statekey":graph.initial_key,"steps":steps,"goal_statekey":goal_key,"total_actions":steps.size(),"shortest":shortest}
	return {"ok":true,"trace":trace,"issues":[]}

static func validate(level: Dictionary, trace: Dictionary) -> Dictionary:
	var encoded := Codec.encode(level)
	if not encoded.ok:
		return _bad("level","Invalid content identity.",encoded.issues)
	if not Search._fields(trace,{"trace_version":TYPE_STRING,"level_hash":TYPE_STRING,"rule_version":TYPE_STRING,"policy_descriptor":TYPE_DICTIONARY,
		"initial_state":TYPE_DICTIONARY,"initial_statekey":TYPE_STRING,"steps":TYPE_ARRAY,"goal_statekey":TYPE_STRING,"total_actions":TYPE_INT,"shortest":TYPE_BOOL}):
		return _bad("trace","Invalid trace schema.")
	if trace.trace_version != "solutiontrace.v1" or trace.level_hash != level.content_hash or trace.rule_version != level.rule_version:
		return _bad("trace","Trace version/level mismatch.")
	if not Search._valid_descriptor(trace.policy_descriptor) or trace.total_actions != trace.steps.size():
		return _bad("trace","Invalid descriptor or total actions.")
	var identity := Key.build(level,trace.initial_state)
	if not identity.ok or identity.key != trace.initial_statekey:
		return _bad("initial_statekey","Invalid initial state/key.",identity.issues)
	var state: Dictionary = trace.initial_state
	var statekey: String = trace.initial_statekey
	for index in trace.steps.size():
		var step: Variant = trace.steps[index]
		if not Search._fields(step,{"index":TYPE_INT,"action":TYPE_DICTIONARY,"expected_state":TYPE_DICTIONARY,"resulting_statekey":TYPE_STRING,"global_kind":TYPE_INT}):
			return _bad("steps[%d]" % index,"Invalid step schema.")
		if step.index != index + 1 or step.global_kind not in range(6):
			return _bad("steps[%d]" % index,"Invalid step index/global kind.")
		var issues := Data.validate_action_shape(level,step.action)
		if not issues.is_empty():
			return _bad("steps[%d].action" % index,"Invalid action.",issues)
		identity = Key.build(level,step.expected_state)
		if not identity.ok or identity.key != step.resulting_statekey:
			return _bad("steps[%d].resulting_statekey" % index,"Expected state/key mismatch.",identity.issues)
		state = step.expected_state
		statekey = step.resulting_statekey
	if statekey != trace.goal_statekey:
		return _bad("goal_statekey","Final key mismatch.")
	var terminal := Goal.is_goal(level,state)
	if not terminal.ok or not terminal.is_goal:
		return _bad("goal_statekey","Trace must terminate at a formal Goal.",terminal.issues)
	return {"ok":true,"issues":[]}

static func validate_semantics(level: Dictionary, trace: Dictionary) -> Dictionary:
	var checked := validate(level,trace)
	if not checked.ok:
		return {"ok":false,"transitions":[],"issues":checked.issues}
	var state: Dictionary = trace.initial_state.duplicate(true)
	var transitions: Array[Dictionary] = []
	for step in trace.steps:
		var result := Kernel.evaluate_action(level,state,step.action,Rules.idle_context())
		if not Search._valid_transition(result,state,step.action) or result.status != 0 or not result.changed:
			return _semantic_bad("steps[%d]" % step.index,"Kernel did not apply a changed transition.",result.issues)
		var identity := Key.build(level,result.next_state)
		if not identity.ok or result.next_state != step.expected_state or identity.key != step.resulting_statekey or result.global_kind != step.global_kind:
			return _semantic_bad("steps[%d]" % step.index,"Full state, key or global kind diverged.",identity.issues)
		transitions.append(result.duplicate(true))
		state = result.next_state.duplicate(true)
	var terminal := Goal.is_goal(level,state)
	if not terminal.ok or not terminal.is_goal:
		return _semantic_bad("goal_statekey","Replay did not end at Goal.",terminal.issues)
	return {"ok":true,"transitions":transitions,"issues":[]}

static func _bad(path: String, message: String, upstream: Array = []) -> Dictionary:
	return {"ok":false,"issues":[Search._issue(Code.TRACE_INVALID,path,message,upstream)]}

static func _semantic_bad(path: String, message: String, upstream: Array = []) -> Dictionary:
	return {"ok":false,"transitions":[],"issues":[Search._issue(Code.TRACE_INVALID,path,message,upstream)]}
