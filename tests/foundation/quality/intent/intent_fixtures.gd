extends RefCounted
## Reuses the real rules fixture; no Solver implementation or search double.
const KernelFixture = preload("res://tests/foundation/rules/kernel_fixture.gd")


static func make_level() -> Dictionary:
	return KernelFixture.make_level(true)


static func make_intent(level: Dictionary) -> Dictionary:
	return {
		"intent_version": "puzzleintent.v1", "intent_id": &"teaching_route",
		"level_hash": level.content_hash, "rule_version": level.rule_version,
		"required_mechanics": [1, 6], "optional_mechanics": [4],
		"expected_milestones": [milestone(&"start", {"kind": 0, "face_id": &"floor/TOP"}),
			milestone(&"finish", {"kind": 4})],
		"forbidden_bypasses": [{"bypass_id": &"skip_shift", "disabled_mechanics": [1]},
			{"bypass_id": &"skip_both", "disabled_mechanics": [1, 6]}],
	}


static func milestone(id: StringName, predicate: Dictionary, required: bool = true) -> Dictionary:
	return {"milestone_id": id, "required": required, "predicate": predicate.duplicate(true)}

static func baked_level(enter: bool = false) -> Dictionary:
	var authoring: Dictionary = load("res://tests/foundation/level/baker_fixture.gd").make_authoring()
	if enter:
		KernelFixture.add_mechanism(authoring,&"plate",&"exit/TOP",KernelFixture.celestial_action(&"plate",0,&"b"),&"ENTER")
	var baked: Dictionary = load("res://foundation/level/level_baker.gd").bake(authoring,{"max_configurations":4096,"max_checks":100000})
	assert(baked.ok, str(baked.issues))
	return baked.level

static func scenario(name: String) -> Dictionary:
	var authoring: Dictionary = load("res://tests/foundation/level/baker_fixture.gd").make_authoring()
	var actions: Array = [{"kind":0,"face_axis":0}]
	var tag := 1
	var ablated_status := 0
	if name == "required_shift":
		authoring.celestial.slots[0].position2 = Vector3i(0,-10,0)
		authoring.celestial.slots[1].position2 = Vector3i(0,-12,0)
		authoring.goal.face_id = &"inner_floor/TOP"
		actions = [{"kind":1}]
		ablated_status = 1
	elif name in ["required_enter_celestial","multiple_celestial_entries"]:
		authoring.celestial.slots[1].position2 = Vector3i(0,-10,0)
		authoring.goal.face_id = &"inner_floor/TOP"
		authoring.mechanisms = []
		for face in authoring.faces: face.mechanism_ids = []
		KernelFixture.add_mechanism(authoring,&"plate",&"exit/TOP",KernelFixture.celestial_action(&"plate",0,&"b"),&"ENTER")
		if name == "multiple_celestial_entries":
			KernelFixture.add_mechanism(authoring,&"console",&"floor/TOP",KernelFixture.celestial_action(&"console",0,&"b"))
		actions = [{"kind":0,"face_axis":0},{"kind":0,"face_axis":2},{"kind":1}]
		tag = 6
		ablated_status = 1
	elif name == "optional_mechanism":
		tag = 6
	var baked: Dictionary = load("res://foundation/level/level_baker.gd").bake(authoring,{"max_configurations":4096,"max_checks":100000})
	assert(baked.ok,str(baked.issues))
	var intent := empty_intent(baked.level)
	if name == "optional_mechanism": intent.optional_mechanics = [tag]
	else: intent.required_mechanics = [tag]
	intent.expected_milestones = [milestone(&"goal",{"kind":4})]
	return {"level":baked.level,"intent":intent,"actions":actions,"tag":tag,"ablated_status":ablated_status,"validation":baked.validation}

static func empty_intent(level: Dictionary) -> Dictionary:
	var intent := make_intent(level)
	intent.required_mechanics = []
	intent.optional_mechanics = []
	intent.expected_milestones = []
	intent.forbidden_bypasses = []
	return intent

static func policy() -> Dictionary:
	return {"strategy":&"BFS","mode":0,"validation_options":{"max_configurations":4096,"max_checks":100000},"filter_descriptor":{"filter_id":&"UNFILTERED","filter_version":"1","disabled_mechanics":[]},"transition_filter":Callable()}

static func budget() -> Dictionary:
	return {"max_states":10000,"max_edges":100000,"max_depth":-1,"max_runtime_ms":0,"max_action_evaluations":200000}

static func descriptor(policy_value: Dictionary) -> Dictionary:
	var value := policy_value.duplicate(true)
	value.erase("transition_filter")
	return value

static func witness(level: Dictionary, actions: Array) -> Dictionary:
	# Known scripted fixture route, never an explorer or a shortestness proof.
	var records: Script = load("res://foundation/contracts/contract_records.gd")
	var key: Script = load("res://foundation/contracts/state_key.gd")
	var kernel: Script = load("res://foundation/rules/puzzle_rule_kernel.gd")
	var rules: Script = load("res://foundation/rules/rule_records.gd")
	var initial: Dictionary = records.initial_state(level)
	var state := initial.duplicate(true)
	var steps: Array = []
	var transitions: Array = []
	for action in actions:
		var result: Dictionary = kernel.evaluate_action(level,state,action,rules.idle_context())
		assert(result.status == 0 and result.changed,str(result))
		transitions.append(result)
		state = result.next_state.duplicate(true)
		steps.append({"index":steps.size()+1,"action":action.duplicate(true),"expected_state":state.duplicate(true),"resulting_statekey":key.build(level,state).key,"global_kind":result.global_kind})
	assert(load("res://foundation/rules/goal_evaluator.gd").is_goal(level,state).is_goal,"scripted witness reaches Goal")
	return {"trace":{"trace_version":"solutiontrace.v1","level_hash":level.content_hash,"rule_version":level.rule_version,"policy_descriptor":descriptor(policy()),"initial_state":initial,"initial_statekey":key.build(level,initial).key,"steps":steps,"goal_statekey":key.build(level,state).key,"total_actions":steps.size(),"shortest":false},"transitions":transitions}
