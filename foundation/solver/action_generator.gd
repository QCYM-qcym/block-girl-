extends RefCounted
## Candidate enumeration only. Runtime permission belongs exclusively to Kernel.
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const Search = preload("res://foundation/solver/search_records.gd")
const Code = preload("res://foundation/solver/solver_types.gd").AnalysisCode
const ORDER = [["face_axis"],[],["rotation_delta"],["rotation_delta"],["transition_id"],["mechanism_id"],
	["group_id","rotation_delta","mechanism_id"],["celestial_op","target_slot_id","alternate_slot_id","mechanism_id"]]

static func generate(level: Dictionary, state: Dictionary) -> Dictionary:
	var issues := Data.validate_level_shape(level)
	if not issues.is_empty():
		return {"ok":false,"actions":[],"issues":[Search._issue(Code.INVALID_LEVEL,"level","Invalid static domain.",issues)]}
	issues = Data.validate_state_shape(level,state)
	if not issues.is_empty():
		return {"ok":false,"actions":[],"issues":[Search._issue(Code.INVALID_INITIAL_STATE,"state","Invalid state shape.",issues)]}
	var actions: Array[Dictionary] = []
	for axis in 4:
		actions.append(Records.make_action(0,{"face_axis":axis}))
	actions.append(Records.make_action(1,{}))
	for world in level.worlds:
		for delta in world.allowed_rotation_deltas:
			actions.append(Records.make_action(2 + world.layer,{"rotation_delta":delta}))
	for transition in level.face_transitions:
		actions.append(Records.make_action(4,{"transition_id":transition.transition_id}))
	for mechanism in level.mechanisms:
		if mechanism.trigger == &"USE":
			actions.append(Records.make_action(5,{"mechanism_id":mechanism.mechanism_id}))
			if mechanism.action.kind in [6,7]:
				actions.append(mechanism.action.duplicate(true))
	actions.sort_custom(_less)
	var unique: Array[Dictionary] = []
	for action in actions:
		if unique.is_empty() or unique[-1] != action:
			unique.append(action)
	return {"ok":true,"actions":unique,"issues":[]}

static func _less(a: Dictionary, b: Dictionary) -> bool:
	if a.kind != b.kind:
		return a.kind < b.kind
	for field in ORDER[a.kind]:
		if a[field] != b[field]:
			return a[field] < b[field] if typeof(a[field]) == TYPE_INT else String(a[field]) < String(b[field])
	return false
