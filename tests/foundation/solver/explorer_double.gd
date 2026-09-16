extends RefCounted
## Tests-only controlled topology and monotonic clock. No movement/lighting math.
const Rules = preload("res://foundation/rules/rule_records.gd")
const Key = preload("res://foundation/contracts/state_key.gd")
var links: Dictionary = {0:{0:1,1:2,2:1},1:{0:3,1:0},2:{0:4},4:{0:3}}
var goals: Array = [3]
var calls := 0
var fault := false
var unproven := false
var no_op := false
var now := 0
var advance_on_kernel := 0
var clock_calls := 0
var clock_jump_at := -1
var validation_status := 0
var goal_error := false
var malformed_kernel := false
var malformed_next := false

func ports() -> Dictionary:
	return {"kernel":evaluate,"goal":goal,"clock":clock,"validator":validate}

func evaluate(_level: Dictionary, state: Dictionary, action: Dictionary, context: Dictionary) -> Dictionary:
	assert(context == Rules.idle_context())
	calls += 1
	now += advance_on_kernel
	if malformed_kernel:
		return {}
	if fault:
		return Rules.error(state,action,[Rules.issue(1105,"double.overflow","Controlled lower-layer overflow.")])
	if no_op:
		return Rules.applied(state,state,action)
	if action.kind == 0 and links.get(state.player.orientation,{}).has(action.face_axis):
		var target := state.duplicate(true)
		target.player.orientation = links[state.player.orientation][action.face_axis]
		if malformed_next:
			target["camera"] = 0
		return Rules.applied(state,target,action)
	return Rules.rejected(state,action,2000,[Rules.issue(1601,"double.safety","Controlled UNPROVEN.")] if unproven else [])

func goal(_level: Dictionary, state: Dictionary) -> Dictionary:
	if goal_error:
		return {"ok":false,"is_goal":null,"issues":[Rules.issue(1105,"double.goal","Controlled Goal failure.")]}
	return {"ok":true,"is_goal":state.player.orientation in goals,"issues":[]}

func clock() -> int:
	clock_calls += 1
	if clock_calls == clock_jump_at:
		now += 100000
	return now

func validate(_level: Dictionary, _options: Dictionary) -> Dictionary:
	return {"status":validation_status,"issues":[] if validation_status == 0 else [Rules.issue(1601,"double.validator","Controlled incomplete validation.")],"configurations_checked":1,"checks_performed":1}
