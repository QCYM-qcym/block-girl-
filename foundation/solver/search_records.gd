extends RefCounted
const Types = preload("res://foundation/solver/solver_types.gd")

static func default_policy(mode: int) -> Dictionary:
	return {"strategy": &"BFS", "mode": mode,
		"validation_options": {"max_configurations":4096,"max_checks":100000},
		"filter_descriptor": {"filter_id":&"UNFILTERED","filter_version":"1","disabled_mechanics":[]},
		"transition_filter": Callable()}

static func default_budget() -> Dictionary:
	return {"max_states":10000,"max_edges":100000,"max_depth":-1,"max_runtime_ms":0,"max_action_evaluations":200000}

static func _issue(code: int, path: String, message: String, upstream: Array = [], details: Dictionary = {}) -> Dictionary:
	return {"code":code,"severity":0,"path":path,"message":message,"details":details.duplicate(true),"upstream":upstream.duplicate(true)}

static func _fields(value: Variant, schema: Dictionary) -> bool:
	if not value is Dictionary or value.size() != schema.size():
		return false
	for field in value:
		if typeof(field) != TYPE_STRING or not schema.has(field) or typeof(value[field]) != schema[field]:
			return false
	return true

static func _descriptor(policy: Dictionary) -> Dictionary:
	var descriptor := policy.duplicate(true)
	descriptor.erase("transition_filter")
	return descriptor

static func _valid_descriptor(value: Variant) -> bool:
	if not _fields(value, {"strategy":TYPE_STRING_NAME,"mode":TYPE_INT,"validation_options":TYPE_DICTIONARY,"filter_descriptor":TYPE_DICTIONARY}):
		return false
	if value.strategy != &"BFS" or value.mode not in [0,1]:
		return false
	if not _fields(value.validation_options, {"max_configurations":TYPE_INT,"max_checks":TYPE_INT}):
		return false
	if value.validation_options.max_configurations <= 0 or value.validation_options.max_checks <= 0:
		return false
	var descriptor: Dictionary = value.filter_descriptor
	if not _fields(descriptor, {"filter_id":TYPE_STRING_NAME,"filter_version":TYPE_STRING,"disabled_mechanics":TYPE_ARRAY}):
		return false
	if descriptor.filter_version != "1":
		return false
	if descriptor.filter_id == &"UNFILTERED":
		return descriptor.disabled_mechanics.is_empty()
	if descriptor.filter_id != &"MECHANIC_ABLATION" or descriptor.disabled_mechanics.is_empty():
		return false
	for index in descriptor.disabled_mechanics.size():
		if typeof(descriptor.disabled_mechanics[index]) != TYPE_INT:
			return false
		if index > 0 and descriptor.disabled_mechanics[index] <= descriptor.disabled_mechanics[index - 1]:
			return false
	return true

static func _valid_policy(policy: Dictionary) -> bool:
	if not policy.has("transition_filter") or typeof(policy.transition_filter) != TYPE_CALLABLE or not _valid_descriptor(_descriptor(policy)):
		return false
	return policy.transition_filter.is_valid() if policy.filter_descriptor.filter_id == &"MECHANIC_ABLATION" else policy.transition_filter.is_null()

static func _valid_budget(budget: Dictionary) -> bool:
	if not _fields(budget, {"max_states":TYPE_INT,"max_edges":TYPE_INT,"max_depth":TYPE_INT,"max_runtime_ms":TYPE_INT,"max_action_evaluations":TYPE_INT}):
		return false
	return budget.max_states > 0 and budget.max_edges >= 0 and budget.max_depth >= -1 and budget.max_runtime_ms >= 0 and budget.max_action_evaluations > 0

static func _metrics() -> Dictionary:
	return {"explored_states":0,"visited_states":0,"generated_edges":0,"duplicate_states":0,"goal_states":0,
		"max_depth_reached":0,"solution_length":null,"action_evaluations":0,"rejected_actions":0,
		"no_op_actions":0,"filtered_edges":0,"safety_unproven_rejections":0,"elapsed_ms":0,
		"shortest_solution_count":null,"shortest_solution_count_complete":false}

static func _valid_analysis_issues(issues: Array) -> bool:
	for issue in issues:
		if not _fields(issue, {"code":TYPE_INT,"severity":TYPE_INT,"path":TYPE_STRING,"message":TYPE_STRING,"details":TYPE_DICTIONARY,"upstream":TYPE_ARRAY}):
			return false
		if issue.code not in Types.AnalysisCode.values() or issue.severity not in [0,1,2] or not _valid_upstream(issue.upstream):
			return false
	return true

static func _valid_upstream(issues: Array) -> bool:
	for issue in issues:
		if not _fields(issue, {"code":TYPE_INT,"severity":TYPE_INT,"path":TYPE_STRING,"message":TYPE_STRING,"details":TYPE_DICTIONARY,"entity_ids":TYPE_ARRAY}):
			return false
		if issue.severity not in [0,1,2]:
			return false
		for id in issue.entity_ids:
			if typeof(id) != TYPE_STRING_NAME:
				return false
	return true

static func _valid_transition(result: Variant, state: Dictionary, action: Dictionary) -> bool:
	if not result is Dictionary or result.size() != 8 or not result.has_all(["status","previous_state","next_state","action","changed","rejection_code","issues","global_kind"]):
		return false
	if typeof(result.status) != TYPE_INT or result.status not in [0,1,2] or typeof(result.changed) != TYPE_BOOL or typeof(result.global_kind) != TYPE_INT or result.global_kind not in range(6):
		return false
	if typeof(result.rejection_code) != TYPE_INT or not result.issues is Array or not _valid_upstream(result.issues):
		return false
	if result.previous_state != state or result.action != action:
		return false
	if result.status == 0:
		return result.next_state is Dictionary and result.changed == (state != result.next_state) and result.rejection_code == 0 and result.issues.is_empty() and (result.changed or result.global_kind == 0)
	return result.next_state == null and not result.changed and result.global_kind == 0 and (result.rejection_code > 0 if result.status == 1 else result.rejection_code == 0 and not result.issues.is_empty())
