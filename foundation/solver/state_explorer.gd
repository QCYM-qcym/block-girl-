extends RefCounted
## The only FIFO search. All gameplay edges come from the formal atomic Kernel.
const Types = preload("res://foundation/solver/solver_types.gd")
const Search = preload("res://foundation/solver/search_records.gd")
const Actions = preload("res://foundation/solver/action_generator.gd")
const Graph = preload("res://foundation/solver/state_graph.gd")
const Trace = preload("res://foundation/solver/solution_trace.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
const Validator = preload("res://foundation/validation/static_validator.gd")
const Kernel = preload("res://foundation/rules/puzzle_rule_kernel.gd")
const Goal = preload("res://foundation/rules/goal_evaluator.gd")
const Rules = preload("res://foundation/rules/rule_records.gd")
const Code = Types.AnalysisCode
const MAX_COUNT = 9223372036854775807

static func explore(level: Dictionary, initial: Dictionary, policy: Dictionary, budget: Dictionary) -> Dictionary:
	return _explore(level,initial,policy,budget,{"kernel":Kernel.evaluate_action,"goal":Goal.is_goal,"clock":Time.get_ticks_usec,"validator":Validator.validate})

static func _explore(level: Dictionary, initial: Dictionary, policy: Dictionary, budget: Dictionary, ports: Dictionary) -> Dictionary:
	# Private dependency seam for controlled algorithm tests; public APIs never accept ports.
	var work := {"ports":ports,"start":ports.clock.call(),"budget":budget.duplicate(true),"status":1,"reason":0,
		"halted":false,"issues":[],"graph":null,"trace":null,"validation":null,"metrics":Search._metrics()}
	if not Search._valid_policy(policy):
		_error(work,Code.INVALID_SEARCH_POLICY,"policy","Invalid closed search policy.")
		return _finish(work,level)
	if not Search._valid_budget(budget):
		_error(work,Code.INVALID_SEARCH_BUDGET,"budget","Invalid closed search budget.")
		return _finish(work,level)
	_call(work,Codec.encode,[level],"encode",Code.INVALID_LEVEL)
	if work.halted:
		return _finish(work,level)
	var validation: Variant = _call(work,ports.validator,[level,policy.validation_options],"validator",Code.INVALID_LEVEL)
	if validation is Dictionary:
		work.validation = validation.duplicate(true)
	if work.halted:
		return _finish(work,level)
	_call(work,Data.validate_state_shape,[level,initial],"data",Code.INVALID_INITIAL_STATE)
	if work.halted:
		return _finish(work,level)
	var terminal: Variant = _call(work,ports.goal,[level,initial],"goal",Code.GOAL_ERROR)
	if work.halted:
		return _finish(work,level)
	var identity: Variant = _call(work,Key.build,[level,initial],"key",Code.STATEKEY_ERROR)
	if work.halted:
		return _finish(work,level)
	var graph := {"graph_version":"stategraph.v1","level_hash":level.content_hash,"rule_version":level.rule_version,
		"initial_key":identity.key,"policy_descriptor":Search._descriptor(policy),"nodes":{},"edges":[],"forward":{},"reverse":{},"complete":false,"stop_reason":2}
	work.graph = graph
	_insert_node(work,identity.key,initial,0,terminal.is_goal,null)
	var queue: Array[String] = []
	if terminal.is_goal:
		_capture_trace(work,level,identity.key)
		if not work.halted:
			work.status = 0
			graph.complete = true
			graph.stop_reason = 0
		return _finish(work,level)
	queue.append(identity.key)
	var cursor := 0
	while cursor < queue.size() and not work.halted:
		var source_key: String = queue[cursor]
		cursor += 1
		var node: Dictionary = graph.nodes[source_key]
		var generated: Variant = _call(work,Actions.generate,[level,node.state],"actions",Code.ANALYSIS_INPUT_INVALID)
		if work.halted:
			break
		for action in generated.actions:
			if _timeout(work):
				break
			if work.metrics.action_evaluations >= budget.max_action_evaluations:
				_stop_budget(work,Types.BudgetReason.MAX_ACTION_EVALUATIONS)
				break
			var result: Variant = _call(work,ports.kernel,[level,node.state,action,Rules.idle_context()],"kernel",Code.KERNEL_ERROR)
			if work.halted:
				break
			if result.status == 1:
				continue
			if not result.changed:
				continue
			_call(work,Data.validate_state_shape,[level,result.next_state],"data",Code.KERNEL_ERROR)
			if work.halted:
				break
			identity = _call(work,Key.build,[level,result.next_state],"key",Code.STATEKEY_ERROR)
			if work.halted:
				break
			terminal = _call(work,ports.goal,[level,result.next_state],"goal",Code.GOAL_ERROR)
			if work.halted:
				break
			if policy.filter_descriptor.filter_id == &"MECHANIC_ABLATION":
				var filtered: Variant = _call(work,policy.transition_filter,[level,result],"filter",Code.FILTER_ERROR)
				if work.halted:
					break
				if not filtered.allow:
					continue
			var known: bool = graph.nodes.has(identity.key)
			if identity.key == source_key:
				_error(work,Code.STATEKEY_ERROR,"next_state","Changed state has identical canonical identity.")
				break
			if not known:
				if node.depth == MAX_COUNT:
					_error(work,Code.ANALYSIS_OVERFLOW,"depth","BFS depth cannot be represented.")
					break
				if budget.max_depth >= 0 and node.depth >= budget.max_depth:
					_stop_budget(work,Types.BudgetReason.MAX_DEPTH)
					break
				if graph.nodes.size() >= budget.max_states:
					_stop_budget(work,Types.BudgetReason.MAX_STATES)
					break
			if graph.edges.size() >= budget.max_edges:
				_stop_budget(work,Types.BudgetReason.MAX_EDGES)
				break
			if _timeout(work):
				break
			# All validation/filter/capacity checks succeeded. Publish both endpoints and indices together.
			var edge_id: int = graph.edges.size()
			if not known:
				_insert_node(work,identity.key,result.next_state,node.depth + 1,terminal.is_goal,edge_id)
				if not terminal.is_goal:
					queue.append(identity.key)
			else:
				_inc(work,"duplicate_states")
			graph.edges.append({"edge_id":edge_id,"from_key":source_key,"to_key":identity.key,"action":action.duplicate(true),"global_kind":result.global_kind})
			graph.forward[source_key].append(edge_id)
			graph.reverse[identity.key].append(edge_id)
			_inc(work,"generated_edges")
			if terminal.is_goal and work.trace == null:
				_capture_trace(work,level,identity.key)
				if work.halted:
					break
				if policy.mode == Types.SearchMode.FIRST_SHORTEST:
					work.status = 0
					graph.stop_reason = 1
					return _finish(work,level)
		if not work.halted:
			node.expanded = true
			_inc(work,"explored_states")
	if not work.halted:
		graph.complete = true
		graph.stop_reason = 0
		work.status = 0 if work.trace != null else 1
	return _finish(work,level)

static func _insert_node(work: Dictionary, key: String, state: Dictionary, depth: int, goal: bool, predecessor: Variant) -> void:
	work.graph.nodes[key] = {"state_key":key,"state":state.duplicate(true),"depth":depth,"is_goal":goal,"expanded":goal,"predecessor_edge":predecessor}
	work.graph.forward[key] = []
	work.graph.reverse[key] = []
	_inc(work,"visited_states")
	work.metrics.max_depth_reached = maxi(work.metrics.max_depth_reached,depth)
	if goal:
		_inc(work,"goal_states")
		_inc(work,"explored_states")

static func _capture_trace(work: Dictionary, level: Dictionary, goal_key: String) -> void:
	var built: Variant = _call(work,Trace._from_graph,[level,work.graph,goal_key,work.ports.goal],"trace",Code.GRAPH_INVALID)
	if built is Dictionary and built.ok:
		work.trace = built.trace.duplicate(true)
		work.metrics.solution_length = built.trace.total_actions

static func _call(work: Dictionary, function: Callable, args: Array, kind: String, code: int) -> Variant:
	if work.halted or _timeout(work):
		return null
	if kind == "kernel":
		_inc(work,"action_evaluations")
		if work.halted:
			return null
	var value: Variant = function.callv(args.duplicate(true))
	# Inspect returned errors before the post-call clock: errors must never be hidden by timeouts.
	if kind == "data":
		if not value is Array or not value.is_empty():
			_error(work,code,kind,"Invalid state data.",value if value is Array else [])
	elif kind == "kernel":
		if not Search._valid_transition(value,args[1],args[2]):
			_error(work,code,kind,"Malformed Kernel result.")
		elif value.status == 2:
			_error(work,code,kind,"Kernel returned ERROR.",value.issues)
		elif value.status == 1:
			_inc(work,"rejected_actions")
			for issue in value.issues:
				if issue.code == 1601:
					_inc(work,"safety_unproven_rejections")
					break
		elif not value.changed:
			_inc(work,"no_op_actions")
	elif kind == "validator":
		if not Search._fields(value,{"status":TYPE_INT,"issues":TYPE_ARRAY,"configurations_checked":TYPE_INT,"checks_performed":TYPE_INT}) or value.status not in [0,1,2] or not Search._valid_upstream(value.issues) or value.configurations_checked < 0 or value.checks_performed < 0:
			_error(work,code,kind,"Malformed StaticValidator result.")
		elif value.status != 0:
			_error(work,Code.LEVEL_VALIDATION_INCOMPLETE if value.status == 2 else Code.INVALID_LEVEL,kind,"Level did not receive VALID.",value.issues)
		elif not value.issues.is_empty():
			_error(work,code,kind,"VALID result contains issues.",value.issues)
	else:
		var schema := {"ok":TYPE_BOOL,"issues":TYPE_ARRAY}
		match kind:
			"encode": schema["text"] = TYPE_STRING
			"key": schema["key"] = TYPE_STRING
			"actions": schema["actions"] = TYPE_ARRAY
			"filter": schema["allow"] = TYPE_BOOL
			"goal": schema["is_goal"] = TYPE_BOOL if value is Dictionary and value.get("ok") == true else TYPE_NIL
			"trace": schema["trace"] = TYPE_DICTIONARY if value is Dictionary and value.get("ok") == true else TYPE_NIL
		if not Search._fields(value,schema):
			_error(work,code,kind,"Malformed dependency result.")
		elif not value.ok:
			if kind in ["filter","actions","trace","graph"]:
				_error(work,code,kind,"Analysis dependency failed.")
				if Search._valid_analysis_issues(value.issues):
					work.issues.append_array(value.issues.duplicate(true))
			else:
				_error(work,code,kind,"Formal dependency failed.",value.issues)
		elif not value.issues.is_empty() or (kind == "key" and value.key.is_empty()):
			_error(work,code,kind,"Successful result has issues or empty identity.")
		elif kind == "filter" and not value.allow:
			_inc(work,"filtered_edges")
	_timeout(work)
	return value

static func _inc(work: Dictionary, field: String) -> void:
	if work.metrics[field] == MAX_COUNT:
		_error(work,Code.ANALYSIS_OVERFLOW,"metrics." + field,"Counter cannot be represented.")
	else:
		work.metrics[field] += 1

static func _error(work: Dictionary, code: int, path: String, message: String, upstream: Array = []) -> void:
	work.halted = true
	work.status = Types.SolverStatus.ERROR
	work.reason = 0
	work.issues.append(Search._issue(code,path,message,upstream))

static func _stop_budget(work: Dictionary, reason: int) -> void:
	work.halted = true
	work.status = Types.SolverStatus.BUDGET_EXCEEDED
	work.reason = reason

static func _timeout(work: Dictionary) -> bool:
	var now: int = work.ports.clock.call()
	work.metrics.elapsed_ms = int((now - work.start) / 1000)
	if work.status == Types.SolverStatus.ERROR:
		return true
	if work.budget.get("max_runtime_ms",0) is int and work.budget.get("max_runtime_ms",0) > 0 and work.metrics.elapsed_ms >= work.budget.max_runtime_ms:
		_stop_budget(work,Types.BudgetReason.MAX_RUNTIME_MS)
		return true
	return work.halted

static func _finish(work: Dictionary, level: Dictionary) -> Dictionary:
	if work.graph != null and not work.halted:
		_call(work,Graph._validate,[level,work.graph,work.ports.goal],"graph",Code.GRAPH_INVALID)
	# Include report copying in elapsed time; perform the last clock check immediately before return.
	var result := {"status":work.status,"graph":work.graph.duplicate(true) if work.graph != null else null,
		"solution_trace":work.trace.duplicate(true) if work.trace != null else null,"metrics":work.metrics.duplicate(true),
		"budget_reason":work.reason,"issues":work.issues.duplicate(true),"validation":work.validation.duplicate(true) if work.validation != null else null}
	_timeout(work)
	result.status = work.status
	result.budget_reason = work.reason
	result.metrics.elapsed_ms = work.metrics.elapsed_ms
	if result.graph != null and work.halted:
		result.graph.complete = false
		result.graph.stop_reason = 3 if work.status == Types.SolverStatus.ERROR else 2
	return result
