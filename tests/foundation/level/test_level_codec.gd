extends SceneTree
const Fixture = preload("res://tests/foundation/level/baker_fixture.gd")
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Records = preload("res://foundation/contracts/contract_records.gd")
const StateKey = preload("res://foundation/contracts/state_key.gd")
const GOLDEN_RULE_JSON = '{"celestial":{"edges":[],"initial_slot_id":"a","slot_order":["a"],"slots":[{"position2":[0,10,0],"slot_id":"a"}],"wrap":false},"cell_size":1,"contract_version":"foundation.contract.v1","cubes":[{"center2":[0,0,0],"cube_id":"floor","group_id":"","layer":"SURFACE","occludes_light":true,"orientation":0,"tags":[]}],"face_transitions":[],"faces":[{"cube_id":"floor","face":"BACK","face_id":"floor/BACK","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"floor","face":"BOTTOM","face_id":"floor/BOTTOM","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"floor","face":"FRONT","face_id":"floor/FRONT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"floor","face":"LEFT","face_id":"floor/LEFT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"floor","face":"RIGHT","face_id":"floor/RIGHT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"floor","face":"TOP","face_id":"floor/TOP","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":true}],"flag_definitions":[],"goal":{"face_id":"floor/TOP","required_flags":[]},"groups":[],"level_id":"codec_golden","mechanisms":[],"orientation_version":"cube24.v1","rule_version":"foundation.rules.v1","schema_version":1,"shift_compatibilities":["SAME_NORMAL","OPPOSITE_NORMAL"],"spawn":{"location":{"cube_id":"floor","face":"TOP","layer":"SURFACE"},"orientation":0},"worlds":[{"allowed_rotation_deltas":[],"allowed_rotation_intents":[],"allowed_states":[0],"initial_orientation":0,"layer":"SURFACE","pivot2":[0,0,0]},{"allowed_rotation_deltas":[],"allowed_rotation_intents":[],"allowed_states":[0],"initial_orientation":0,"layer":"INNER","pivot2":[0,0,0]}]}'
const GOLDEN_HASH = '6983ed5f5e812c1bd10d0604aefb1b9661f0f93264536499b319d4bfeacbfc2b'
var codec: GDScript
var failures := 0
var checks := 0

func _initialize() -> void:
	check(Data.validate_level_shape(Fixture.make_level()).is_empty(), "fixture satisfies DATA")
	if not FileAccess.file_exists("res://foundation/level/level_codec.gd"):
		check(false, "Level codec implementation is required")
		quit(1)
		return
	codec = load("res://foundation/level/level_codec.gd")
	test_codec()
	if failures == 0:
		print("FOUNDATION_LEVEL_CODEC_PASS checks=%d" % checks)
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)

func test_codec() -> void:
	# Golden was authored independently and its UTF-8 SHA-256 verified with .NET,
	# never captured from the codec under test. Metadata/hash are inserted literally.
	var golden := Fixture.make_golden_level()
	check(codec.compute_content_hash(golden).content_hash == GOLDEN_HASH, "external SHA-256 golden")
	golden.content_hash = GOLDEN_HASH
	var golden_text: String = GOLDEN_RULE_JSON.replace('{"celestial":', '{"build_info":{},"celestial":').replace('"contract_version":', '"content_hash":"' + GOLDEN_HASH + '","contract_version":')
	check(codec.encode(golden).text == golden_text, "independent full canonical JSON golden")
	check(codec.decode(golden_text).ok, "external golden decodes")
	var level := Fixture.make_level()
	var before := level.duplicate(true)
	var identity: Dictionary = codec.compute_content_hash(level)
	check(identity.ok and identity.content_hash.length() == 64, "canonical SHA-256")
	check(level == before, "hash does not mutate input")
	check(not codec.encode(level).ok, "placeholder hash cannot be encoded as truth")
	level.content_hash = identity.content_hash
	var encoded: Dictionary = codec.encode(level)
	check(encoded.ok and not encoded.text.ends_with("\n") and not encoded.text.begins_with(String.chr(0xfeff)), "UTF-8 payload has no BOM or trailing LF")
	check(encoded.text.contains('"kind":"MOVE_CELESTIAL"') and encoded.text.contains('"celestial_op":"TOGGLE_BETWEEN"') and encoded.text.contains('"position2":[0,10,0]'), "enum symbols and exact integer coordinate arrays")
	var decoded: Dictionary = codec.decode(encoded.text)
	check(decoded.ok, "canonical text decodes")
	if decoded.ok:
		check(typeof(decoded.level.level_id) == TYPE_STRING_NAME and typeof(decoded.level.cubes[0].center2) == TYPE_VECTOR3I and typeof(decoded.level.schema_version) == TYPE_INT, "decode restores memory ABI")
		check(codec.encode(decoded.level).text == encoded.text, "typed canonical round trip")
		check(StateKey.build(decoded.level, Records.initial_state(decoded.level)).ok, "official StateKey consumes decoded Level")
	var reordered := level.duplicate(true)
	for field in ["worlds", "cubes", "faces", "groups", "mechanisms"]:
		reordered[field].reverse()
	reordered.celestial.slots.reverse()
	reordered.celestial.edges.reverse()
	reordered.groups[0].edges.reverse()
	check(codec.encode(reordered).text == encoded.text, "record and edge order is irrelevant")
	reordered.build_info = {"source": "changed"}
	check(codec.compute_content_hash(reordered).content_hash == identity.content_hash, "metadata excluded from hash")
	reordered.cubes[0].occludes_light = false
	check(codec.compute_content_hash(reordered).content_hash != identity.content_hash, "real logic changes identity")
	for field in ["allowed_states", "allowed_rotation_deltas"]:
		var ordered := level.duplicate(true)
		ordered.groups[0][field].reverse()
		check(codec.compute_content_hash(ordered).content_hash != identity.content_hash, field + " retains author order")
	var slots := level.duplicate(true)
	slots.celestial.slot_order.reverse()
	check(codec.compute_content_hash(slots).content_hash != identity.content_hash, "slot_order retains author order")
	var text_level := level.duplicate(true)
	text_level.build_info = {"text": "开\"\\\b\t\n\f\r" + String.chr(1) + "/" + String.chr(0x2028) + String.chr(0x2029), "😀": "a", "\ue000": "b"}
	var text_encoded: Dictionary = codec.encode(text_level)
	check(text_encoded.ok and text_encoded.text.contains('"text":"开\\"\\\\\\b\\t\\n\\f\\r\\u0001/' + String.chr(0x2028) + String.chr(0x2029) + '"'), "exact Unicode and control escaping")
	check(text_encoded.text.find('"\ue000"') < text_encoded.text.find('"😀"'), "keys ordered by scalar code points")
	check(codec.decode(text_encoded.text).ok, "escaped strings decode")
	for invalid_text in [encoded.text.replace('"schema_version":1', '"schema_version":1.5'), encoded.text.replace('"schema_version":1', '"schema_version":1e0'), encoded.text.replace('"schema_version":1', '"schema_version":01'), encoded.text.replace('"schema_version":1', '"schema_version":9223372036854775808'), encoded.text.replace('"schema_version":1', '"schema_version":1,"schema_version":1'), encoded.text.replace('"schema_version":1', '"schema_version":1,"ui":false'), encoded.text.replace('"position2":[0,10,0]', '"position2":[2147483648,10,0]'), encoded.text.replace('"layer":"SURFACE"', '"layer":0'), encoded.text + "true", encoded.text.replace('"build_info":{}', '"build_info":{"x":"\\ud800"}')]:
		var rejected: Dictionary = codec.decode(invalid_text)
		check(not rejected.ok and rejected.level == null and not rejected.issues.is_empty(), "malformed/unsafe JSON fails atomically")
	check(not codec.decode(encoded.text.replace(identity.content_hash, "f".repeat(64))).ok, "decode verifies supplied hash")
	for change in ["unknown", "duplicate", "float", "version", "tags", "edges"]:
		var bad := level.duplicate(true)
		match change:
			"unknown": bad.cubes[0].ui = true
			"duplicate": bad.cubes.append(bad.cubes[0].duplicate(true))
			"float": bad.mechanisms[0].priority = 1.5
			"version": bad.schema_version = 2
			"tags": bad.cubes[0].tags = [&"x", &"x"]
			"edges": bad.celestial.edges.append(bad.celestial.edges[0].duplicate(true))
		var rejected: Dictionary = codec.compute_content_hash(bad)
		check(not rejected.ok and rejected.content_hash == "" and not rejected.issues.is_empty(), "reject " + change)
	var wide := level.duplicate(true)
	wide.mechanisms[0].priority = 9223372036854775807
	wide.content_hash = codec.compute_content_hash(wide).content_hash
	var wide_decoded: Dictionary = codec.decode(codec.encode(wide).text)
	check(wide_decoded.ok and wide_decoded.level.mechanisms[0].priority == 9223372036854775807, "integer precision survives beyond float64 range")
	wide.mechanisms[0].priority = -9223372036854775807 - 1
	wide.content_hash = codec.compute_content_hash(wide).content_hash
	wide_decoded = codec.decode(codec.encode(wide).text)
	check(wide_decoded.ok and wide_decoded.level.mechanisms[0].priority == (-9223372036854775807 - 1), "int64 minimum round trip")
	var tagged := level.duplicate(true)
	tagged.cubes[0].tags = [&"z", &"a", &"开", &"😀"]
	var tag_hash: String = codec.compute_content_hash(tagged).content_hash
	tagged.cubes[0].tags.reverse()
	check(codec.compute_content_hash(tagged).content_hash == tag_hash, "Unicode tag set order irrelevant")
	var transitions := level.duplicate(true)
	transitions.face_transitions = [{"transition_id": &"step", "source_face_id": &"floor/TOP", "target_face_id": &"exit/TOP", "entry_axis":0, "exit_axis":2, "rotation_steps":[22,18,22], "required_flags":[]}]
	var transition_hash: Dictionary = codec.compute_content_hash(transitions)
	check(transition_hash.ok, "ordered rotation_steps allow repeated turns")
	transitions.face_transitions[0].rotation_steps = [18,22,22]
	check(codec.compute_content_hash(transitions).content_hash != transition_hash.content_hash, "rotation_steps preserve authored sequence")
	var intentions := level.duplicate(true)
	intentions.worlds[0].allowed_rotation_intents = [0,1]
	var intent_hash: Dictionary = codec.compute_content_hash(intentions)
	intentions.worlds[0].allowed_rotation_intents.reverse()
	check(codec.compute_content_hash(intentions).content_hash != intent_hash.content_hash, "rotation intents preserve declaration order")
	check(codec.decode(encoded.text.replace('"build_info":{}', '"build_info":{"emoji":"\\ud83d\\ude00"}')).ok, "paired surrogate escapes decode to scalar")
	check(not codec.decode(encoded.text.replace('"build_info":{}', '"build_info":{"x":"a","\\u0078":"b"}')).ok, "escaped duplicate field names are rejected")
	check(codec.decode(" \n\t" + encoded.text + "\r\n").ok, "legal JSON whitespace accepted and canonicalized")
	check(not codec.decode(encoded.text.replace('"schema_version":1', '"schema_version":true')).ok, "boolean cannot masquerade as integer")
	check(not codec.decode(encoded.text.replace('"build_info":{}', '"build_info":{"nested":{}}')).ok, "metadata values require strings")
	check(not codec.decode(encoded.text.replace('"build_info":{}', '"build_info":{"x":"\\u12xz"}')).ok, "malformed Unicode escape rejected")
	check(not codec.decode(encoded.text.replace('"build_info":{}', '"build_info":{"x":"\\udc00"}')).ok, "isolated low surrogate rejected")
	check(not codec.decode(encoded.text.replace('"priority":0', '"priority":-9223372036854775809')).ok, "int64 negative overflow rejected")
	var actions := [
		{"kind":0, "face_axis":3}, {"kind":1}, {"kind":2, "rotation_delta":22}, {"kind":3, "rotation_delta":18},
		{"kind":4, "transition_id":&"step"}, {"kind":5, "mechanism_id":&"toggle_sky"},
		{"kind":6, "group_id":&"island", "rotation_delta":22, "mechanism_id":&"toggle_sky"},
	]
	var symbols := ["MOVE", "SHIFT_WORLD", "ROTATE_SURFACE", "ROTATE_INNER", "USE_FACE_TRANSITION", "TRIGGER_MECHANISM", "LOCAL_GROUP_ROTATE"]
	for i in actions.size():
		var action_level := transitions.duplicate(true)
		action_level.mechanisms[0].action = actions[i]
		action_level.content_hash = codec.compute_content_hash(action_level).content_hash
		var action_text: Dictionary = codec.encode(action_level)
		check(action_text.ok and action_text.text.contains('"kind":"' + symbols[i] + '"'), "action union symbol " + symbols[i])
		check(codec.decode(action_text.text).ok, "action union roundtrip " + symbols[i])
	var sets := level.duplicate(true)
	sets.flag_definitions = [{"flag_id":&"z", "initial_value":false}, {"flag_id":&"a", "initial_value":true}]
	sets.goal.required_flags = [&"z", &"a"]
	sets.cubes[2].group_id = &"island"
	sets.groups[0].cube_ids.append(&"inner_floor")
	var sets_hash: Dictionary = codec.compute_content_hash(sets)
	sets.flag_definitions.reverse()
	sets.goal.required_flags.reverse()
	sets.groups[0].cube_ids.reverse()
	check(sets_hash.ok and codec.compute_content_hash(sets).content_hash == sets_hash.content_hash, "flag records and ID reference sets sort canonically")
	sets.content_hash = sets_hash.content_hash
	var sets_decoded: Dictionary = codec.decode(codec.encode(sets).text)
	check(sets_decoded.ok and sets_decoded.level.goal.required_flags == [&"a", &"z"] and sets_decoded.level.cubes[0].cube_id == &"exit" and sets_decoded.level.worlds[0].layer == 0, "decoded memory uses canonical record and reference order")
	check(not codec.decode(encoded.text.replace('"kind":"MOVE_CELESTIAL"', '"kind":"UNKNOWN"')).ok, "unknown union discriminant rejected")
	check(not codec.decode(encoded.text.replace('"kind":"MOVE_CELESTIAL"', '"kind":"MOVE_CELESTIAL","face_axis":"U_POS"')).ok, "extra action payload field rejected")
	check(not codec.decode(encoded.text.replace('"schema_version":1,', '')).ok, "missing field rejected")
	check(not codec.decode(encoded.text.replace('"position2":[0,10,0]', '"position2":[0,10.00000000000000001,0]')).ok, "fraction cannot round into integral coordinate")
	check(not codec.decode(encoded.text.replace('"build_info":{}', '"build_info":{"x":"\\ud800\\u0041"}')).ok, "high surrogate cannot pair with ordinary scalar")
	var complete_before := sets.duplicate(true)
	codec.encode(sets)
	sets_decoded.level.goal.required_flags.append(&"private_copy")
	check(sets == complete_before, "encode and returned mutable collections never alias the input")
