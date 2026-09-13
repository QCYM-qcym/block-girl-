extends SceneTree

const Validation = preload("res://foundation/contracts/contract_validation.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
# Copied verbatim from FOUNDATION-0.1 §6.2, not produced by the encoder under test.
const GOLDEN_A = 'statekey.v1:{"level_hash":"0000000000000000000000000000000000000000000000000000000000000000","rule_version":"foundation.rules.v1","state":{"celestial":{"slot_id":"a"},"group_orientations":{},"level_flags":{},"mechanism_states":{},"player":{"location":{"cube_id":"floor","face":"TOP","layer":"SURFACE"},"orientation":0},"world_orientations":[0,0]}}'
const GOLDEN_B = 'statekey.v1:{"level_hash":"0000000000000000000000000000000000000000000000000000000000000000","rule_version":"foundation.rules.v1","state":{"celestial":{"slot_id":"b"},"group_orientations":{"alpha":2,"beta":22},"level_flags":{"done":false,"open":true},"mechanism_states":{"plate":"down","z_gate":"open"},"player":{"location":{"cube_id":"inner_floor","face":"BOTTOM","layer":"INNER"},"orientation":19},"world_orientations":[9,0]}}'
var Key: Script
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	if not ResourceLoader.exists("res://foundation/contracts/state_key.gd"):
		check(false,"StateKey implementation exists")
		quit(1)
		return
	Key = load("res://foundation/contracts/state_key.gd")
	if Key == null or not Key.can_instantiate():
		check(false,"StateKey compiles")
		quit(1)
		return
	call_deferred("run")

func fixture(rich: bool = false) -> Dictionary:
	var level := {
		"schema_version":1,"contract_version":"foundation.contract.v1","orientation_version":"cube24.v1",
		"rule_version":"foundation.rules.v1","level_id":&"key_fixture","content_hash":"0".repeat(64),
		"cell_size":1,"worlds":[],"cubes":[],"faces":[],"groups":[],
		"celestial":{"slots":[{"slot_id":&"a","position2":Vector3i(0,6,0)}],"slot_order":[&"a"],
			"wrap":false,"initial_slot_id":&"a","edges":[]},
		"mechanisms":[],"face_transitions":[],"shift_compatibilities":[0],
		"spawn":{"location":{"layer":0,"cube_id":&"floor","face":4},"orientation":0},
		"goal":{"face_id":&"floor/TOP","required_flags":[]},"flag_definitions":[],"build_info":{}
	}
	for layer in 2:
		level.worlds.append({"layer":layer,"pivot2":Vector3i.ZERO,"initial_orientation":0,
			"allowed_states":[0,2,9],"allowed_rotation_deltas":[],"allowed_rotation_intents":[]})
	add_cube(level,&"floor",0,&"alpha" if rich else &"",Vector3i.ZERO)
	if rich:
		add_cube(level,&"inner_floor",1,&"beta",Vector3i.ZERO)
		add_cube(level,&"inner_other",1,&"",Vector3i(2,0,0))
		level.worlds[0].initial_orientation = 9
		level.groups = [
			{"group_id":&"beta","layer":1,"cube_ids":[&"inner_floor"],"pivot2":Vector3i.ZERO,
				"initial_orientation":22,"allowed_states":[22,18],"allowed_rotation_deltas":[],"edges":[]},
			{"group_id":&"alpha","layer":0,"cube_ids":[&"floor"],"pivot2":Vector3i.ZERO,
				"initial_orientation":2,"allowed_states":[2,3],"allowed_rotation_deltas":[],"edges":[]}]
		level.celestial.slots.append({"slot_id":&"b","position2":Vector3i(4,6,0)})
		level.celestial.slot_order.append(&"b")
		level.celestial.initial_slot_id = &"b"
		level.flag_definitions = [{"flag_id":&"open","initial_value":true},{"flag_id":&"done","initial_value":false}]
		level.mechanisms = [
			{"mechanism_id":&"z_gate","face_id":&"floor/TOP","trigger":&"USE","action":{"kind":1},
				"priority":0,"initial_state":&"open","allowed_states":[&"open",&"closed"]},
			{"mechanism_id":&"plate","face_id":&"inner_floor/BOTTOM","trigger":&"ENTER","action":{"kind":1},
				"priority":1,"initial_state":&"down","allowed_states":[&"down",&"up"]}]
		level.faces[4].mechanism_ids = [&"z_gate"]
		level.faces[11].mechanism_ids = [&"plate"]
		level.spawn = {"location":{"layer":1,"cube_id":&"inner_floor","face":5},"orientation":19}
	return level

# Fixed value fixtures only; no orientation/spatial algorithms or neighbour module stubs.
func add_cube(level: Dictionary, id: StringName, layer: int, group: StringName, center: Vector3i) -> void:
	level.cubes.append({"cube_id":id,"layer":layer,"center2":center,"orientation":0,
		"group_id":group,"occludes_light":true,"tags":[]})
	var names := ["FRONT","BACK","LEFT","RIGHT","TOP","BOTTOM"]
	for face in 6:
		level.faces.append({"face_id":StringName(String(id)+"/"+names[face]),"cube_id":id,"face":face,
			"walkable":true,"shift_exit_blocked":false,"shift_entry_blocked":false,"mechanism_ids":[]})

func at(value: Variant, path: Array) -> Variant:
	for field in path:
		value = value[field]
	return value

func changed(value: Dictionary, path: Array, replacement: Variant) -> Dictionary:
	var result := value.duplicate(true)
	at(result,path.slice(0,-1))[path[-1]] = replacement
	return result

func has_code(issues: Array, code: int) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false

func reject(level: Dictionary, state: Dictionary, code: int, label: String) -> void:
	var level_before := level.duplicate(true)
	var state_before := state.duplicate(true)
	var result: Dictionary = Key.build(level,state)
	check(result.keys().size() == 3 and result.has("ok") and result.has("key") and result.has("issues"),label+" exact result schema")
	check(result.ok == false and result.key == "" and not result.issues.is_empty(),label+" returns no key")
	check(has_code(result.issues,code),label+" canonical issue")
	check(level == level_before and state == state_before,label+" preserves input")
	for issue in result.issues:
		check(issue.severity == 0 and issue.has("path") and issue.has("entity_ids") and issue.has("details"),label+" error context")

func reordered(value: Variant, reverse_order: bool) -> Variant:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		if reverse_order:
			keys.reverse()
		var result := {}
		for key in keys:
			result[key] = reordered(value[key],reverse_order)
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(reordered(item,reverse_order))
		return result
	return value

func run() -> void:
	var a := fixture()
	var b := fixture(true)
	check(Validation.validate_level_shape(a).is_empty(),"golden A has valid full level")
	check(Validation.validate_level_shape(b).is_empty(),"golden B has valid full level and real domains")
	var sa: Dictionary = Records.initial_state(a)
	var sb: Dictionary = Records.initial_state(b)
	check(Validation.validate_state_shape(b,sb).is_empty(),"golden B state validated")
	var a_before := a.duplicate(true)
	var sa_before := sa.duplicate(true)
	var ra: Dictionary = Key.build(a,sa)
	var rb: Dictionary = Key.build(b,sb)
	check(ra == {"ok":true,"key":GOLDEN_A,"issues":[]},"golden A exact public result")
	check(rb == {"ok":true,"key":GOLDEN_B,"issues":[]},"golden B exact public result")
	check(a == a_before and sa == sa_before,"success preserves inputs")
	check(ra.key.begins_with("statekey.v1:"),"statekey.v1 prefix")
	check(ra.key.to_utf8_buffer().size() == 347 and rb.key.to_utf8_buffer().size() == 428,"published golden byte lengths")
	check(not rb.key.begins_with(String.chr(0xfeff)) and not rb.key.ends_with("\n") and not rb.key.ends_with("\r"),"no BOM or final newline")
	var parsed = JSON.parse_string(rb.key.substr("statekey.v1:".length()))
	check(parsed is Dictionary and parsed.state.size() == 6,"serialization directly debuggable as full JSON")
	check(parsed.state.player.location.layer == "INNER" and parsed.state.player.location.face == "BOTTOM", "enum symbols preserved")
	check(parsed.state.world_orientations.size() == 2 and parsed.state.world_orientations[0] == 9 and parsed.state.world_orientations[1] == 0 and parsed.state.level_flags.done == false,"world order and false flags retained")
	for i in 3:
		check(Key.build(a,sa).key == GOLDEN_A and Key.build(b,sb).key == GOLDEN_B,"repeat build deterministic")
	for reverse_order in [false,true]:
		check(Key.build(reordered(b,reverse_order),reordered(sb,reverse_order)).key == GOLDEN_B,"all dictionary insertion orders ignored")
	for mask in 8:
		var order_state := sb.duplicate(true)
		for i in 3:
			var field: String = ["group_orientations","mechanism_states","level_flags"][i]
			order_state[field] = reordered(sb[field],(mask & (1 << i)) != 0)
		check(Key.build(b,order_state).key == GOLDEN_B,"independent map order combination %d" % mask)
	var visited := {rb.key:true}
	for entry in [
		[["player","orientation"],20],[["player","location","face"],4],
		[["player","location","cube_id"],&"inner_other"],[["world_orientations"],[0,0]],
		[["world_orientations"],[9,2]],[["world_orientations"],[0,9]],[["celestial","slot_id"],&"a"],
		[["group_orientations",&"alpha"],3],[["group_orientations",&"beta"],18],
		[["mechanism_states",&"plate"],&"up"],[["mechanism_states",&"z_gate"],&"closed"],
		[["level_flags",&"done"],true],[["level_flags",&"open"],false]]:
		var altered := changed(sb,entry[0],entry[1])
		var result: Dictionary = Key.build(b,altered)
		check(result.ok and result.key != GOLDEN_B,"single core field changes key "+str(entry[0]))
		if result.ok:
			visited[result.key] = true
	check(visited.size() == 14,"full string visited preserves distinct states")
	visited[Key.build(reordered(b,true),reordered(sb,true)).key] = true
	check(visited.size() == 14,"same-state visited deduplicates without search")
	# A layer-only state change needs a matching definition: valid synthetic fixture,
	# placeholder hash as in the contract goldens, not a claim of real Bake equality.
	var surface_b := b.duplicate(true)
	surface_b.cubes[1].layer = 0
	surface_b.groups[0].layer = 0
	surface_b.spawn.location.layer = 0
	var layer_state := changed(sb,["player","location","layer"],0)
	check(Key.build(surface_b,layer_state).ok and Key.build(surface_b,layer_state).key != GOLDEN_B,"layer symbol changes key")
	check(Key.build(changed(b,["content_hash"],"f".repeat(64)),sb).key != GOLDEN_B,"different level hash namespace")
	var metadata := b.duplicate(true)
	metadata.level_id = &"different_name"
	metadata.build_info = {"camera":"orbit","audio":"muted"}
	check(Key.build(metadata,sb).key == GOLDEN_B,"non-namespace level metadata excluded")
	test_exclusions(b,sb)
	test_failures(b,sb)
	test_text(b,sb)
	var bad := changed(sb,["celestial","slot_id"],&"missing")
	var first: Dictionary = Key.build(b,bad)
	var untouched := first.duplicate(true)
	first.issues[0].entity_ids.append(&"polluted")
	first.issues[0].details["injected"] = []
	first.issues.clear()
	check(Key.build(b,bad) == untouched,"failure outputs do not pollute later calls")
	ra.issues.append({"injected":true})
	check(Key.build(a,sa) == {"ok":true,"key":GOLDEN_A,"issues":[]},"success output owns issues")
	if failures.is_empty():
		print("STATE_KEY_PASS checks=",checks)
		print("GOLDEN_A=",GOLDEN_A)
		print("GOLDEN_B=",GOLDEN_B)
		quit(0)
	else:
		printerr("STATE_KEY_FAIL checks=",checks," failures=",failures.size())
		quit(1)

func test_exclusions(level: Dictionary, state: Dictionary) -> void:
	var ui := {}
	for field in ["camera","rotate_target","animation_progress","visual_fx","audio","face_light_state",
		"shift_mapping","anchor_overlap","connectivity","debug_state","ui_state","frame","transaction_id"]:
		ui[field] = 1
		check(Key.build(level,state).key == GOLDEN_B,"external presentation state excluded: "+field)
		for path in [[],["player"],["player","location"],["celestial"]]:
			var polluted := state.duplicate(true)
			at(polluted,path)[field] = 1
			reject(level,polluted,1001,"reject nested presentation field "+str(path)+"."+field)

func test_failures(level: Dictionary, state: Dictionary) -> void:
	for field in state:
		var missing := state.duplicate(true)
		missing.erase(field)
		reject(level,missing,1002,"missing core field "+field)
	for field in ["group_orientations","mechanism_states","level_flags"]:
		var missing := state.duplicate(true)
		missing[field].erase(missing[field].keys()[0])
		reject(level,missing,1006,"missing declared map member "+field)
		var added := state.duplicate(true)
		added[field][&"unknown"] = state[field].values()[0]
		reject(level,added,1006,"undeclared map member "+field)
	for entry in [
		[["player","orientation"],24,1101],[["player","orientation"],0.0,1000],
		[["player","location","cube_id"],&"missing",1006],[["player","location","layer"],0,1006],
		[["celestial","slot_id"],&"missing",1300],[["celestial","slot_id"],"b",1000],
		[["world_orientations"],[9],1006],[["world_orientations"],[9,24],1101],
		[["group_orientations",&"alpha"],23,1101],[["mechanism_states",&"plate"],&"not_declared",1006],
		[["level_flags",&"done"],0,1000]]:
		reject(level,changed(state,entry[0],entry[1]),entry[2],"invalid state "+str(entry[0]))
	for entry in [[["rule_version"],"foundation.rules.v2",1007],[["contract_version"],"foundation.contract.v1.1",1007],
		[["schema_version"],2,1007],[["content_hash"],"short",1004]]:
		reject(changed(level,entry[0],entry[1]),state,entry[2],"invalid level "+str(entry[0]))
	var missing_spawn := level.duplicate(true)
	missing_spawn.erase("spawn")
	reject(missing_spawn,state,1002,"level validated before encoding")
	var poisoned := changed(state,["player","orientation"],24)
	check(Key.build(missing_spawn,poisoned).issues == Validation.validate_level_shape(missing_spawn),"invalid level stops before state phase")

func text_case(level: Dictionary, state: Dictionary, text: String) -> Dictionary:
	var text_level := level.duplicate(true)
	text_level.mechanisms[1].allowed_states.append(StringName(text))
	var text_state := changed(state,["mechanism_states",&"plate"],StringName(text))
	return Key.build(text_level,text_state)

func test_text(level: Dictionary, state: Dictionary) -> void:
	var sample := "开\"\\\n" + String.chr(1) + "/"
	var result := text_case(level,state,sample)
	# Exact JSON escapes from §6.2.
	var expected_fragment := r'"plate":"开\"\\\n\u0001/"'
	check(result.ok and result.key == GOLDEN_B.replace('"plate":"down"',expected_fragment),"published escape golden exact full key")
	var cases := [
		["\b",r'\b'],["\t",r'\t'],["\n",r'\n'],["\f",r'\f'],["\r",r'\r'],
		[String.chr(1),r'\u0001'],[String.chr(11),r'\u000b'],[String.chr(31),r'\u001f'],
		["\"",r'\"'],["\\",r'\\'],["/","/"],[" space "," space "],
		["开睦🙂","开睦🙂"],[String.chr(0x2028)+String.chr(0x2029),String.chr(0x2028)+String.chr(0x2029)]]
	for pair in cases:
		var encoded := text_case(level,state,pair[0])
		var expected := GOLDEN_B.replace('"plate":"down"','"plate":"'+pair[1]+'"')
		check(encoded.ok and encoded.key == expected,"exact text escaping "+str(pair[0].to_utf32_buffer()))
		if encoded.ok:
			var decoded = JSON.parse_string(encoded.key.substr("statekey.v1:".length()))
			check(decoded.state.mechanism_states.plate == pair[0],"text roundtrip retains scalar sequence")
	var composed := text_case(level,state,"é")
	var decomposed := text_case(level,state,"e"+String.chr(0x301))
	check(composed.ok and decomposed.ok and composed.key != decomposed.key,"no Unicode normalization")
	# Godot String.chr rejects invalid scalars before the build boundary (probe evidence).
	# U+FFFD itself is legal and must not be rejected as though it were a surrogate.
	var replacement := text_case(level,state,String.chr(0xfffd))
	check(replacement.ok and replacement.key.contains(String.chr(0xfffd)),"legal replacement character preserved")

	# Every representable C0 control uses the frozen short or lowercase-hex escape.
	var short_escapes := {8:r'\b',9:r'\t',10:r'\n',12:r'\f',13:r'\r'}
	for scalar in range(1,32):
		var control_result := text_case(level,state,String.chr(scalar))
		var escaped: String = short_escapes.get(scalar,r'\u%04x' % scalar)
		check(control_result.ok and control_result.key == GOLDEN_B.replace('"plate":"down"','"plate":"'+escaped+'"'),"C0 escape %02x" % scalar)
	for orientation in 24:
		var pose := changed(state,["player","orientation"],orientation)
		var pose_result: Dictionary = Key.build(level,pose)
		check(pose_result.ok and pose_result.key == GOLDEN_B.replace('"orientation":19','"orientation":%d' % orientation),"orientation decimal %d" % orientation)
