extends RefCounted
const T = preload("res://foundation/quality/intent/intent_types.gd")
const Intent = preload("res://foundation/quality/intent/intent_validation.gd")
const Mechanics = preload("res://foundation/quality/intent/mechanic_classifier.gd")
const Geometry = preload("res://foundation/spatial/surface_geometry.gd")
const Derived = preload("res://foundation/rules/derived_state_resolver.gd")
const Goal = preload("res://foundation/rules/goal_evaluator.gd")

static func analyze_trace(level: Dictionary, intent: Dictionary, trace: Dictionary) -> Dictionary:
	var path := "res://foundation/solver/solution_trace.gd"
	var validator := Callable()
	if FileAccess.file_exists(path):
		var script: Script = load(path)
		validator = Callable(script,"validate_semantics")
	return _analyze_with_validator(level,intent,trace,validator)

static func _analyze_with_validator(level: Dictionary, intent: Dictionary, trace: Dictionary, validator: Callable) -> Dictionary:
	var valid := Intent.validate(level,intent)
	if not valid.ok: return _error(valid.issues)
	var checked := _checked_trace(level,trace,validator)
	if not checked.ok: return _error(checked.issues)
	var samples: Array = [{"state":trace.initial_state.duplicate(true),"tags":[]}]
	for transition in checked.transitions:
		var classification := Mechanics.classify_transition(level,transition)
		if not classification.ok: return _error(classification.issues)
		samples.append({"state":transition.next_state.duplicate(true),"tags":classification.tags})
	var matched: Array = []
	var missing: Array = []
	var indices: Dictionary = {}
	var cursor := 0
	for milestone in intent.expected_milestones:
		var found: Variant = null
		for index in range(cursor if milestone.required else 0,samples.size()):
			var result := _matches(level,milestone.predicate,samples[index])
			if not result.ok: return _error(result.issues)
			if result.matches:
				found = index
				break
		indices[milestone.milestone_id] = found
		if found != null:
			matched.append(milestone.milestone_id)
			if milestone.required: cursor = found
		elif milestone.required:
			missing.append(milestone.milestone_id)
	var findings: Array = []
	if not missing.is_empty():
		findings.append({"code":T.QualityCode.MILESTONE_BYPASS,"severity":0,"subject_ids":missing.duplicate(true),"scope":&"SINGLE_TRACE","trace":trace.duplicate(true),"details":{"sample_indices":indices.duplicate(true)}})
	return {"status":T.MilestoneStatus.TRACE_MATCH if missing.is_empty() else T.MilestoneStatus.TRACE_BYPASS,"scope":"SINGLE_TRACE","matched_milestones":matched,"missing_required":missing,"sample_indices":indices,"findings":findings,"issues":[]}

static func _checked_trace(level: Dictionary, trace: Dictionary, validator: Callable) -> Dictionary:
	if not validator.is_valid():
		return {"ok":false,"transitions":[],"issues":[T._issue(3016,"dependency","DEPENDENCY_PENDING: REAL_3A_SOLVER validate_semantics is required.")]}
	var checked: Variant = validator.call(level.duplicate(true),trace.duplicate(true))
	if not checked is Dictionary or checked.size() != 3 or not checked.has_all(["ok","transitions","issues"]) or typeof(checked.ok) != TYPE_BOOL or not checked.transitions is Array or not checked.issues is Array:
		return {"ok":false,"transitions":[],"issues":[T._issue(3008,"trace","Malformed semantic-validation result.")]}
	if not checked.ok:
		return {"ok":false,"transitions":[],"issues":checked.issues.duplicate(true) if not checked.issues.is_empty() else [T._issue(3008,"trace","Semantic validation failed.")]}
	if not checked.issues.is_empty() or not trace.get("initial_state") is Dictionary or not trace.get("steps") is Array or checked.transitions.size() != trace.steps.size():
		return {"ok":false,"transitions":[],"issues":[T._issue(3008,"trace","Semantic result contradicts the witness.")]}
	for transition in checked.transitions:
		if not transition is Dictionary: return {"ok":false,"transitions":[],"issues":[T._issue(3008,"trace","Expected validated transitions.")]}
	return checked.duplicate(true)

static func _matches(level: Dictionary, predicate: Dictionary, sample: Dictionary) -> Dictionary:
	var state: Dictionary = sample.state
	var location: Dictionary = state.player.location
	var value := false
	match predicate.kind:
		T.PredicateKind.AT_FACE:
			value = Geometry.face_id(location.cube_id,location.face) == predicate.face_id
		T.PredicateKind.IN_LAYER:
			value = location.layer == predicate.layer
		T.PredicateKind.MECHANIC_USED:
			value = predicate.mechanic in sample.tags
		T.PredicateKind.FACE_LIGHT:
			var light := Derived.light(level,state,Geometry.face_id(location.cube_id,location.face))
			if not light.ok: return {"ok":false,"matches":false,"issues":[T._issue(3016,"milestone.light","Derived light query failed.",light.issues)]}
			value = light.light_state == predicate.light_state
		T.PredicateKind.GOAL:
			var goal := Goal.is_goal(level,state)
			if not goal.ok: return {"ok":false,"matches":false,"issues":[T._issue(3005,"milestone.goal","Goal query failed.",goal.issues)]}
			value = goal.is_goal
	return {"ok":true,"matches":value,"issues":[]}

static func _error(issues: Array) -> Dictionary:
	return {"status":T.MilestoneStatus.ERROR,"scope":"SINGLE_TRACE","matched_milestones":[],"missing_required":[],"sample_indices":{},"findings":[],"issues":issues.duplicate(true)}
