extends RefCounted
## Reverse analysis of an immutable, in-process 3A StateGraph.
## No action generation, Kernel calls, Reset edges or forward gameplay search.
const Types = preload("res://foundation/quality/softlock/softlock_types.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const GRAPH_OWNER = "res://foundation/solver/state_graph.gd"
const TYPES_OWNER = "res://foundation/solver/solver_types.gd"


static func analyze(level: Dictionary, graph: Dictionary, budget: Dictionary) -> Dictionary:
	# Only real owner scripts are loaded here. Tests use the private seam below;
	# no production path imports a test fixture or substitutes Graph validation.
	if not ResourceLoader.exists(GRAPH_OWNER) or not ResourceLoader.exists(TYPES_OWNER):
		var pending := Types._empty_result()
		pending.status = Types.SoftlockStatus.ERROR
		# The frozen 3016 wire value is used solely to fail closed when its owner
		# is absent. This is not a second AnalysisCode enum or registry.
		pending.issues = [_issue(3016, "dependency", "DEPENDENCY_PENDING: REAL_3A_STATEGRAPH", {"required": [GRAPH_OWNER, TYPES_OWNER]})]
		return pending
	var owner: Script = load(GRAPH_OWNER)
	var owner_types: Script = load(TYPES_OWNER)
	return _analyze_with_dependencies(level, graph, budget, Callable(owner, "validate"), owner_types.AnalysisCode, Time.get_ticks_msec)


static func _analyze_with_dependencies(level: Dictionary, graph: Dictionary, budget: Dictionary, validate_graph: Callable, codes: Dictionary, clock: Callable) -> Dictionary:
	var started: int = clock.call()
	var result := Types._empty_result()
	var proven := {}
	if not _budget_valid(budget):
		_error(result, codes.INVALID_SEARCH_BUDGET, "budget", "Expected only max_nodes>0, max_edges>=0 and max_runtime_ms>=0 integers.")
		return _finish(result, proven, started, clock, {})
	var admission := _admit(graph, codes)
	if not admission.is_empty():
		result.status = Types.SoftlockStatus.ERROR
		result.issues = admission
		return _finish(result, proven, started, clock, budget)
	result.initial_key = graph.initial_key
	# Capacity bounds apply to different accepted records, never visit count.
	if graph.nodes.size() > budget.max_nodes or graph.edges.size() > budget.max_edges:
		return _finish(result, proven, started, clock, budget)
	if _expired(started, clock, budget):
		return _finish(result, proven, started, clock, budget)
	var validation: Dictionary = validate_graph.call(level, graph)
	# An atomic owner call cannot be interrupted. Its error beats a coincident
	# timeout; only successful full validation establishes record counts.
	if not validation.ok:
		result.status = Types.SoftlockStatus.ERROR
		result.issues = validation.issues.duplicate(true)
		return _finish(result, proven, started, clock, budget)
	result.metrics.nodes_checked = graph.nodes.size()
	result.metrics.edges_checked = graph.edges.size()
	result.reachable_states = graph.nodes.keys()
	result.reachable_states.sort()
	if _expired(started, clock, budget):
		return _finish(result, proven, started, clock, budget)
	var stack: Array[String] = []
	# Canonical keys and edge indices keep disabled-clock runs deterministic.
	for key in result.reachable_states:
		if _expired(started, clock, budget):
			return _finish(result, proven, started, clock, budget)
		if graph.nodes[key].is_goal:
			proven[key] = true
			stack.append(key)
	while not stack.is_empty():
		if _expired(started, clock, budget):
			return _finish(result, proven, started, clock, budget)
		var key: String = stack.pop_back()
		var incoming: Array = graph.reverse[key].duplicate()
		incoming.sort()
		for edge_id in incoming:
			if _expired(started, clock, budget):
				return _finish(result, proven, started, clock, budget)
			var source: String = graph.edges[edge_id].from_key
			if not proven.has(source):
				proven[source] = true
				stack.append(source)
	if not graph.complete:
		return _finish(result, proven, started, clock, budget)
	var softlocks: Array[String] = []
	for key in result.reachable_states:
		if _expired(started, clock, budget):
			return _finish(result, proven, started, clock, budget)
		if not proven.has(key):
			softlocks.append(key)
	# Witnesses are only prefixes in the supplied graph, not SolutionTrace.
	for key in softlocks:
		var edge_ids: Array[int] = []
		var current: String = key
		while current != graph.initial_key:
			if _expired(started, clock, budget):
				return _finish(result, proven, started, clock, budget)
			if edge_ids.size() >= graph.nodes.size() or not graph.nodes.has(current):
				_error(result, codes.GRAPH_INVALID, "nodes", "Invalid predecessor chain while reading a GraphPath.")
				return _finish(result, proven, started, clock, budget)
			var edge_id: Variant = graph.nodes[current].predecessor_edge
			if typeof(edge_id) != TYPE_INT or edge_id < 0 or edge_id >= graph.edges.size() or graph.edges[edge_id].to_key != current:
				_error(result, codes.GRAPH_INVALID, "nodes", "Broken predecessor edge while reading a GraphPath.")
				return _finish(result, proven, started, clock, budget)
			edge_ids.append(edge_id)
			current = graph.edges[edge_id].from_key
		edge_ids.reverse()
		result.witnesses.append({"target_key": key, "edge_ids": edge_ids})
	if _expired(started, clock, budget):
		return _finish(result, proven, started, clock, budget)
	# Respect Records.initial_state's DATA precondition even with a test double.
	var level_issues := Data.validate_level_shape(level)
	if not level_issues.is_empty():
		_error(result, codes.ANALYSIS_INPUT_INVALID, "level", "Cannot construct the canonical Reset spawn.", {}, level_issues)
		return _finish(result, proven, started, clock, budget)
	if _expired(started, clock, budget):
		return _finish(result, proven, started, clock, budget)
	var spawn := Key.build(level, Records.initial_state(level))
	if not spawn.ok:
		_error(result, codes.STATEKEY_ERROR, "spawn", "Reset spawn StateKey failed.", {}, spawn.issues)
		return _finish(result, proven, started, clock, budget)
	if _expired(started, clock, budget):
		return _finish(result, proven, started, clock, budget)
	result.status = Types.SoftlockStatus.COMPLETE
	result.softlock_states = softlocks
	result.softlock_count = softlocks.size()
	if graph.nodes.has(spawn.key):
		result.reset_classification = Types.ResetClassification.RECOVERABLE_BY_RESET if proven.has(spawn.key) else Types.ResetClassification.NOT_RECOVERABLE_BY_RESET
		result.reset_recoverable_count = softlocks.size() if proven.has(spawn.key) else 0
	return _finish(result, proven, started, clock, budget)


static func _budget_valid(budget: Dictionary) -> bool:
	if not _record(budget, {"max_nodes": TYPE_INT, "max_edges": TYPE_INT, "max_runtime_ms": TYPE_INT}):
		return false
	return budget.max_nodes > 0 and budget.max_edges >= 0 and budget.max_runtime_ms >= 0


static func _admit(graph: Dictionary, codes: Dictionary) -> Array[Dictionary]:
	# A bounded top-level admission check, not the 3A node/edge/key validator.
	# Deep consistency and provenance remain the real Graph owner's contract.
	if not _record(graph, {"graph_version": TYPE_STRING, "level_hash": TYPE_STRING, "rule_version": TYPE_STRING,
		"initial_key": TYPE_STRING, "policy_descriptor": TYPE_DICTIONARY, "nodes": TYPE_DICTIONARY,
		"edges": TYPE_ARRAY, "forward": TYPE_DICTIONARY, "reverse": TYPE_DICTIONARY,
		"complete": TYPE_BOOL, "stop_reason": TYPE_INT}):
		return [_issue(codes.GRAPH_INVALID, "graph", "StateGraph admission requires the frozen closed top-level record.")]
	if graph.graph_version != "stategraph.v1":
		return [_issue(codes.VERSION_MISMATCH, "graph.graph_version", "Unsupported StateGraph version.")]
	if graph.stop_reason not in [0, 1, 2]:
		return [_issue(codes.GRAPH_INVALID, "graph.stop_reason", "An invalid or ERROR graph cannot support a softlock conclusion.")]
	var policy: Dictionary = graph.policy_descriptor
	if not _record(policy, {"strategy": TYPE_STRING_NAME, "mode": TYPE_INT, "validation_options": TYPE_DICTIONARY, "filter_descriptor": TYPE_DICTIONARY}):
		return [_issue(codes.GRAPH_INVALID, "graph.policy_descriptor", "Invalid closed PolicyDescriptor.")]
	if policy.strategy != &"BFS" or policy.mode not in [0, 1] or not _record(policy.validation_options, {"max_configurations": TYPE_INT, "max_checks": TYPE_INT}):
		return [_issue(codes.GRAPH_INVALID, "graph.policy_descriptor", "Unsupported policy or validation budget.")]
	if policy.validation_options.max_configurations <= 0 or policy.validation_options.max_checks <= 0:
		return [_issue(codes.GRAPH_INVALID, "graph.policy_descriptor.validation_options", "Validation limits must be positive.")]
	var filter: Dictionary = policy.filter_descriptor
	if not _record(filter, {"filter_id": TYPE_STRING_NAME, "filter_version": TYPE_STRING, "disabled_mechanics": TYPE_ARRAY}):
		return [_issue(codes.GRAPH_INVALID, "graph.policy_descriptor.filter_descriptor", "Invalid closed FilterDescriptor.")]
	if filter.filter_id != &"UNFILTERED" or filter.filter_version != "1" or not filter.disabled_mechanics.is_empty():
		return [_issue(codes.ANALYSIS_INPUT_INVALID, "graph.policy_descriptor.filter_descriptor", "Primary softlock analysis requires the complete UNFILTERED descriptor.")]
	return []


static func _record(value: Dictionary, fields: Dictionary) -> bool:
	if value.size() != fields.size():
		return false
	for field in value:
		if typeof(field) != TYPE_STRING or not fields.has(field) or typeof(value[field]) != fields[field]:
			return false
	return true


static func _expired(started: int, clock: Callable, budget: Dictionary) -> bool:
	return budget.max_runtime_ms > 0 and int(clock.call()) - started >= budget.max_runtime_ms


static func _finish(result: Dictionary, proven: Dictionary, started: int, clock: Callable, budget: Dictionary) -> Dictionary:
	result.goal_reachable_states = proven.keys()
	result.goal_reachable_states.sort()
	if result.status != Types.SoftlockStatus.COMPLETE:
		_clear_conclusions(result, proven)
	# Materializing/sorting the report is work too. Sample after it so a late
	# deadline cannot leak a COMPLETE conclusion. An observed error still wins.
	result.metrics.elapsed_ms = maxi(0, int(clock.call()) - started)
	if result.status != Types.SoftlockStatus.ERROR and budget.get("max_runtime_ms", 0) > 0 and result.metrics.elapsed_ms >= budget.max_runtime_ms:
		if result.status == Types.SoftlockStatus.COMPLETE:
			_clear_conclusions(result, proven)
			result.metrics.elapsed_ms = maxi(0, int(clock.call()) - started)
		result.status = Types.SoftlockStatus.INCOMPLETE
	return result


static func _clear_conclusions(result: Dictionary, proven: Dictionary) -> void:
	result.softlock_states = null
	result.softlock_count = null
	result.witnesses = []
	result.reset_classification = Types.ResetClassification.UNKNOWN
	result.reset_recoverable_count = null
	result.unknown_states = []
	for key in result.reachable_states:
		if not proven.has(key):
			result.unknown_states.append(key)


static func _issue(code: int, path: String, message: String, details: Dictionary = {}, upstream: Array = []) -> Dictionary:
	return {"code": code, "severity": 0, "path": path, "message": message, "details": details.duplicate(true), "upstream": upstream.duplicate(true)}


static func _error(result: Dictionary, code: int, path: String, message: String, details: Dictionary = {}, upstream: Array = []) -> void:
	result.status = Types.SoftlockStatus.ERROR
	result.issues.append(_issue(code, path, message, details, upstream))
