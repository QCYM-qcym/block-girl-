extends RefCounted
## Explicit result table and registered fixture gate. No search, graph build,
## or implementation of 3A Trace.validate_semantics. Never production evidence.
const F = preload("res://tests/foundation/quality/intent/intent_fixtures.gd")
var level: Dictionary
var witness: Dictionary
var outcomes: Dictionary = {"[]":0}
var calls: Array = []
var semantic_calls: Array = []
var responses: Array = []
var reject_semantics := false
var corrupt_witness := false
var preserve_budget_witness := false

func setup(definition: Dictionary, known: Dictionary) -> void:
	level = definition.duplicate(true)
	witness = known.duplicate(true)

func solve(definition: Dictionary, initial: Dictionary, policy: Dictionary, budget: Dictionary) -> Dictionary:
	calls.append({"level":definition.duplicate(true),"initial":initial.duplicate(true),"policy":policy.duplicate(true),"budget":budget.duplicate(true)})
	var disabled: Array = policy.filter_descriptor.disabled_mechanics
	var status: int = outcomes.get(str(disabled),3)
	if definition != level or initial != witness.trace.initial_state: status = 3
	var trace: Variant = witness.trace.duplicate(true) if status == 0 or (status == 2 and preserve_budget_witness) else null
	if trace != null:
		trace.policy_descriptor = F.descriptor(policy)
		if corrupt_witness: trace.steps[0].action.face_axis = 2
	var metrics := {"explored_states":1,"visited_states":1,"generated_edges":0,"duplicate_states":0,"goal_states":0,"max_depth_reached":0,"solution_length":null if trace == null else trace.total_actions,"action_evaluations":0,"rejected_actions":0,"no_op_actions":0,"filtered_edges":0,"safety_unproven_rejections":0,"elapsed_ms":0,"shortest_solution_count":null,"shortest_solution_count_complete":false}
	# A literal one-node closed graph represents the table's unsolvable case.
	# It is not explored or claimed to be the real Level's reachable graph.
	var initial_key: String = witness.trace.initial_statekey
	var graph: Variant = null
	if status == 1:
		graph = {"graph_version":"stategraph.v1","level_hash":level.content_hash,"rule_version":level.rule_version,"initial_key":initial_key,"policy_descriptor":F.descriptor(policy),"nodes":{initial_key:{"state_key":initial_key,"state":initial.duplicate(true),"depth":0,"is_goal":false,"expanded":true,"predecessor_edge":null}},"edges":[],"forward":{initial_key:[]},"reverse":{initial_key:[]},"complete":true,"stop_reason":0}
	var response := {"status":status,"graph":graph,"solution_trace":trace,"metrics":metrics,"budget_reason":1 if status == 2 else 0,"issues":[{"code":3004,"severity":0,"path":"double","message":"explicit table ERROR","details":{},"upstream":[]}] if status == 3 else [],"validation":{"status":0,"issues":[],"configurations_checked":1,"checks_performed":1}}
	responses.append(response.duplicate(true))
	return response

func validate_semantics(definition: Dictionary, trace: Dictionary) -> Dictionary:
	semantic_calls.append(trace.duplicate(true))
	var candidate := trace.duplicate(true)
	# The consumer separately checks the returned policy against its request.
	candidate.policy_descriptor = witness.trace.policy_descriptor.duplicate(true)
	if reject_semantics or definition != level or candidate != witness.trace:
		return {"ok":false,"transitions":[],"issues":[{"code":3008,"severity":0,"path":"trace","message":"Not the explicitly registered witness fixture.","details":{},"upstream":[]}]}
	return {"ok":true,"transitions":witness.transitions.duplicate(true),"issues":[]}
