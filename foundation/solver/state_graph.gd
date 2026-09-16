extends RefCounted
## Structural consistency only: completeness provenance belongs to the live Explorer.
const Search = preload("res://foundation/solver/search_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Goal = preload("res://foundation/rules/goal_evaluator.gd")
const Code = preload("res://foundation/solver/solver_types.gd").AnalysisCode

static func validate(level: Dictionary, graph: Dictionary) -> Dictionary:
	return _validate(level,graph,Goal.is_goal)

static func _validate(level: Dictionary, graph: Dictionary, goal: Callable) -> Dictionary:
	var level_issues := Data.validate_level_shape(level)
	if not level_issues.is_empty():
		return _bad("level","Invalid level shape.",level_issues)
	if not Search._fields(graph,{"graph_version":TYPE_STRING,"level_hash":TYPE_STRING,"rule_version":TYPE_STRING,"initial_key":TYPE_STRING,
		"policy_descriptor":TYPE_DICTIONARY,"nodes":TYPE_DICTIONARY,"edges":TYPE_ARRAY,"forward":TYPE_DICTIONARY,"reverse":TYPE_DICTIONARY,"complete":TYPE_BOOL,"stop_reason":TYPE_INT}):
		return _bad("graph","Invalid graph schema.")
	if graph.graph_version != "stategraph.v1" or graph.level_hash != level.content_hash or graph.rule_version != level.rule_version:
		return _bad("graph","Graph version or level identity mismatch.")
	if not Search._valid_descriptor(graph.policy_descriptor) or graph.stop_reason not in range(4):
		return _bad("graph","Invalid descriptor or stop reason.")
	if not graph.nodes.has(graph.initial_key) or graph.nodes.is_empty() or graph.forward.size() != graph.nodes.size() or graph.reverse.size() != graph.nodes.size():
		return _bad("graph.nodes","Missing initial node or adjacency entries.")
	var expected_forward := {}
	var expected_reverse := {}
	var all_expanded := true
	var goals := 0
	for key in graph.nodes:
		if typeof(key) != TYPE_STRING or key.is_empty():
			return _bad("graph.nodes","Node identity must be a full String.")
		var node: Variant = graph.nodes[key]
		if not node is Dictionary or node.size() != 6 or not node.has_all(["state_key","state","depth","is_goal","expanded","predecessor_edge"]):
			return _bad("graph.nodes","Invalid node schema.")
		if typeof(node.state_key) != TYPE_STRING or node.state_key != key or not node.state is Dictionary or typeof(node.depth) != TYPE_INT or node.depth < 0 or typeof(node.is_goal) != TYPE_BOOL or typeof(node.expanded) != TYPE_BOOL:
			return _bad("graph.nodes","Invalid node fields.")
		if not graph.forward.has(key) or not graph.reverse.has(key) or not graph.forward[key] is Array or not graph.reverse[key] is Array:
			return _bad("graph","Missing adjacency array.")
		var identity := Key.build(level,node.state)
		if not identity.ok or identity.key != key:
			return _bad("graph.nodes.state","StateKey mismatch.",identity.issues)
		var terminal: Dictionary = goal.call(level.duplicate(true),node.state.duplicate(true))
		if not terminal.ok or terminal.is_goal != node.is_goal:
			return _bad("graph.nodes.is_goal","Goal marker mismatch.",terminal.issues)
		if node.is_goal:
			goals += 1
			if not node.expanded or not graph.forward[key].is_empty():
				return _bad("graph.nodes","Goal must be an expanded terminal.")
		all_expanded = all_expanded and node.expanded
		if key == graph.initial_key:
			if node.depth != 0 or node.predecessor_edge != null:
				return _bad("graph.nodes","Initial predecessor/depth invalid.")
		elif node.depth == 0 or typeof(node.predecessor_edge) != TYPE_INT or node.predecessor_edge < 0 or node.predecessor_edge >= graph.edges.size():
			return _bad("graph.nodes","Missing predecessor or invalid depth.")
		expected_forward[key] = []
		expected_reverse[key] = []
	for index in graph.edges.size():
		var edge: Variant = graph.edges[index]
		if not Search._fields(edge,{"edge_id":TYPE_INT,"from_key":TYPE_STRING,"to_key":TYPE_STRING,"action":TYPE_DICTIONARY,"global_kind":TYPE_INT}):
			return _bad("graph.edges","Invalid edge schema.")
		if edge.edge_id != index or not graph.nodes.has(edge.from_key) or not graph.nodes.has(edge.to_key) or edge.from_key == edge.to_key or edge.global_kind not in range(6):
			return _bad("graph.edges","Invalid edge identity/reference or self-loop.")
		var issues := Data.validate_action_shape(level,edge.action)
		if not issues.is_empty():
			return _bad("graph.edges.action","Invalid semantic action.",issues)
		if graph.nodes[edge.to_key].depth > graph.nodes[edge.from_key].depth + 1:
			return _bad("graph.edges","Edge contradicts BFS shortest depth.")
		for previous in expected_forward[edge.from_key]:
			if graph.edges[previous].action == edge.action:
				return _bad("graph.edges","Same source/action recorded twice.")
		expected_forward[edge.from_key].append(index)
		expected_reverse[edge.to_key].append(index)
	if expected_forward != graph.forward or expected_reverse != graph.reverse:
		return _bad("graph","Forward/reverse adjacency differs from ordered edge references.")
	for key in graph.nodes:
		if key == graph.initial_key:
			continue
		var node: Dictionary = graph.nodes[key]
		var predecessor: Dictionary = graph.edges[node.predecessor_edge]
		if predecessor.to_key != key or node.depth != graph.nodes[predecessor.from_key].depth + 1 or graph.reverse[key].is_empty() or graph.reverse[key][0] != node.predecessor_edge:
			return _bad("graph.nodes.predecessor_edge","First predecessor/depth chain is invalid.")
	if graph.complete != (graph.stop_reason == 0) or (graph.complete and not all_expanded):
		return _bad("graph.complete","Closure/stop/expanded flags disagree.")
	if graph.stop_reason == 1 and (goals == 0 or graph.policy_descriptor.mode != 0):
		return _bad("graph.stop_reason","FIRST_GOAL requires a goal and FIRST_SHORTEST policy.")
	return {"ok":true,"issues":[]}

static func _bad(path: String, message: String, upstream: Array = []) -> Dictionary:
	return {"ok":false,"issues":[Search._issue(Code.GRAPH_INVALID,path,message,upstream)]}
