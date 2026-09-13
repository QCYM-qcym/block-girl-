extends RefCounted
## Canonical Level JSON boundary; DATA owns memory validation, this module owns wire transforms.
const Data = preload("res://foundation/contracts/contract_validation.gd")
const Types = preload("res://foundation/contracts/foundation_types.gd")
const Code = Types.ValidationCode
const ENUMS = {"layer": Types.WorldLayer, "face": Types.FaceDirection, "intent": Types.RotationIntent,
	"compatibility": Types.FaceCompatibility, "axis": Types.FaceAxis, "kind": Types.PuzzleActionKind, "operation": Types.CelestialOp}
const RECORDS = {
	"level": {"schema_version":"int", "contract_version":"string", "orientation_version":"string", "rule_version":"string", "level_id":"name", "content_hash":"string", "cell_size":"int", "worlds":"array:world", "cubes":"array:cube", "faces":"array:face_record", "groups":"array:group", "celestial":"celestial", "mechanisms":"array:mechanism", "face_transitions":"array:transition", "shift_compatibilities":"array:compatibility", "spawn":"player", "goal":"goal", "flag_definitions":"array:flag", "build_info":"metadata"},
	"world": {"layer":"layer", "pivot2":"coordinate", "initial_orientation":"int", "allowed_states":"array:int", "allowed_rotation_deltas":"array:int", "allowed_rotation_intents":"array:intent"},
	"cube": {"cube_id":"name", "layer":"layer", "center2":"coordinate", "orientation":"int", "group_id":"name", "occludes_light":"bool", "tags":"array:name"},
	"face_record": {"face_id":"name", "cube_id":"name", "face":"face", "walkable":"bool", "shift_exit_blocked":"bool", "shift_entry_blocked":"bool", "mechanism_ids":"array:name"},
	"group": {"group_id":"name", "layer":"layer", "cube_ids":"array:name", "pivot2":"coordinate", "initial_orientation":"int", "allowed_states":"array:int", "allowed_rotation_deltas":"array:int", "edges":"array:rotation_edge"},
	"rotation_edge": {"from_orientation":"int", "rotation_delta":"int", "to_orientation":"int"},
	"celestial": {"slots":"array:slot", "slot_order":"array:name", "wrap":"bool", "initial_slot_id":"name", "edges":"array:slot_edge"},
	"slot": {"slot_id":"name", "position2":"coordinate"},
	"slot_edge": {"from_slot_id":"name", "to_slot_id":"name"},
	"mechanism": {"mechanism_id":"name", "face_id":"name", "trigger":"name", "action":"action", "priority":"int", "initial_state":"name", "allowed_states":"array:name"},
	"transition": {"transition_id":"name", "source_face_id":"name", "target_face_id":"name", "entry_axis":"axis", "exit_axis":"axis", "rotation_steps":"array:int", "required_flags":"array:name"},
	"location": {"layer":"layer", "cube_id":"name", "face":"face"},
	"player": {"location":"location", "orientation":"int"},
	"goal": {"face_id":"name", "required_flags":"array:name"},
	"flag": {"flag_id":"name", "initial_value":"bool"},
}
const ACTIONS = {
	0: {"kind":"kind", "face_axis":"axis"}, 1: {"kind":"kind"},
	2: {"kind":"kind", "rotation_delta":"int"}, 3: {"kind":"kind", "rotation_delta":"int"},
	4: {"kind":"kind", "transition_id":"name"}, 5: {"kind":"kind", "mechanism_id":"name"},
	6: {"kind":"kind", "group_id":"name", "rotation_delta":"int", "mechanism_id":"name"},
	7: {"kind":"kind", "celestial_op":"operation", "target_slot_id":"name", "alternate_slot_id":"name", "mechanism_id":"name"},
}
const RECORD_ORDER = {"world":["layer"], "cube":["cube_id"], "face_record":["face_id"], "group":["group_id"], "slot":["slot_id"], "mechanism":["mechanism_id"], "transition":["transition_id"], "flag":["flag_id"], "rotation_edge":["from_orientation", "rotation_delta", "to_orientation"], "slot_edge":["from_slot_id", "to_slot_id"]}
const SORTED_SETS = ["cube_ids", "mechanism_ids", "required_flags", "tags"]

static func encode(level: Dictionary) -> Dictionary:
	var identity := compute_content_hash(level)
	if not identity.ok:
		return _result("text", "", identity.issues)
	if identity.content_hash != level.content_hash:
		return _result("text", "", [_issue(Code.INVALID_ID, "content_hash", "Content hash does not match canonical rule data.")])
	return _result("text", _json(_to_wire(level, "level")), [])

static func compute_content_hash(level: Dictionary) -> Dictionary:
	var issues := Data.validate_level_shape(level)
	if issues.is_empty():
		_check_extra(level, "", issues)
	if not issues.is_empty():
		return _result("content_hash", "", issues)
	var wire: Dictionary = _to_wire(level, "level")
	wire.erase("content_hash")
	wire.erase("build_info")
	return _result("content_hash", _json(wire).sha256_text(), [])

static func decode(text: String) -> Dictionary:
	var issues: Array[Dictionary] = []
	_check_extra(text, "", issues)
	if not issues.is_empty():
		return _result("level", null, issues)
	var parser := ExactJSON.new(text)
	var wire: Variant = parser.read_value(0)
	parser.skip_space()
	if parser.offset != text.length() and parser.issues.is_empty():
		parser.fail("Trailing JSON content.")
	if not parser.issues.is_empty():
		return _result("level", null, parser.issues)
	var level: Variant = _from_wire(wire, "level", "", issues)
	if typeof(level) != TYPE_DICTIONARY:
		issues.append(_issue(Code.INVALID_TYPE, "", "Expected a Level object."))
	if not issues.is_empty():
		return _result("level", null, issues)
	var encoded := encode(level)
	if not encoded.ok:
		return _result("level", null, encoded.issues)
	# Restore canonical record/set order as well as the typed memory values.
	return _result("level", _from_wire(_to_wire(level, "level"), "level", "", issues), issues)

static func _to_wire(value: Variant, descriptor: String, field: String = "") -> Variant:
	if descriptor.begins_with("array:"):
		var item_type := descriptor.substr(6)
		var source: Array = value.duplicate(true)
		if RECORD_ORDER.has(item_type):
			source.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _record_less(a, b, RECORD_ORDER[item_type]))
		elif field in SORTED_SETS:
			source.sort_custom(func(a: Variant, b: Variant) -> bool: return _less(String(a), String(b)))
		var output: Array = []
		for item in source:
			output.append(_to_wire(item, item_type))
		return output
	if RECORDS.has(descriptor) or descriptor == "action":
		var schema: Dictionary = ACTIONS[value.kind] if descriptor == "action" else RECORDS[descriptor]
		var output := {}
		for key in schema:
			output[key] = _to_wire(value[key], schema[key], key)
		return output
	if ENUMS.has(descriptor):
		return ENUMS[descriptor].find_key(value)
	if descriptor == "name":
		return String(value)
	if descriptor == "coordinate":
		return [value.x, value.y, value.z]
	return value.duplicate(true) if value is Dictionary else value

static func _from_wire(value: Variant, descriptor: String, path: String, issues: Array[Dictionary]) -> Variant:
	if descriptor.begins_with("array:") and value is Array:
		var output: Array = []
		for i in value.size():
			output.append(_from_wire(value[i], descriptor.substr(6), path + "[%d]" % i, issues))
		return output
	if (RECORDS.has(descriptor) or descriptor == "action") and value is Dictionary:
		var schema: Dictionary = RECORDS.get(descriptor, {})
		if descriptor == "action":
			var symbol: Variant = value.get("kind")
			var kind: int = Types.PuzzleActionKind.get(symbol, -1) if symbol is String else -1
			schema = ACTIONS.get(kind, {"kind":"kind"})
		var output := {}
		for key in value:
			var child: String = key if path.is_empty() else path + "." + key
			if not schema.has(key):
				issues.append(_issue(Code.UNKNOWN_FIELD, child, "Field is not part of the wire record."))
				continue
			output[key] = _from_wire(value[key], schema[key], child, issues)
		return output
	if ENUMS.has(descriptor):
		if value is String and ENUMS[descriptor].has(value):
			return ENUMS[descriptor][value]
		issues.append(_issue(Code.INVALID_ENUM, path, "Expected a frozen enum symbol."))
		return null
	if descriptor == "name" and value is String:
		return StringName(value)
	if descriptor == "coordinate":
		if not value is Array or value.size() != 3:
			issues.append(_issue(Code.INVALID_TYPE, path, "Coordinate requires three integers."))
			return null
		for component in value:
			if typeof(component) != TYPE_INT:
				issues.append(_issue(Code.INVALID_TYPE, path, "Coordinate requires exact integers."))
				return null
			if component < -2147483648 or component > 2147483647:
				issues.append(_issue(Code.ARITHMETIC_OVERFLOW, path, "Coordinate exceeds int32."))
				return null
		return Vector3i(value[0], value[1], value[2])
	return value

static func _check_extra(value: Variant, path: String, issues: Array[Dictionary], field: String = "") -> void:
	if value is String or value is StringName:
		var text := String(value)
		for i in text.length():
			var scalar := text.unicode_at(i)
			if scalar > 0x10ffff or (scalar >= 0xd800 and scalar <= 0xdfff):
				issues.append(_issue(Code.INVALID_TYPE, path, "Text contains a non-scalar Unicode value."))
				return
	elif value is Dictionary:
		for key in value:
			var child: String = key if path.is_empty() else path + "." + key
			_check_extra(key, child, issues)
			_check_extra(value[key], child, issues, key)
	elif value is Array:
		var unique: bool = field in SORTED_SETS or field in ["allowed_states", "allowed_rotation_intents", "allowed_rotation_deltas", "edges"]
		var seen: Array = []
		for i in value.size():
			var child := path + "[%d]" % i
			if unique and value[i] in seen:
				issues.append(_issue(Code.DUPLICATE_ID, child, "Duplicate collection member."))
			seen.append(value[i])
			_check_extra(value[i], child, issues)

static func _record_less(a: Dictionary, b: Dictionary, fields: Array) -> bool:
	for field in fields:
		if a[field] != b[field]:
			return a[field] < b[field] if a[field] is int else _less(String(a[field]), String(b[field]))
	return false

static func _less(a: String, b: String) -> bool:
	for i in mini(a.length(), b.length()):
		if a.unicode_at(i) != b.unicode_at(i):
			return a.unicode_at(i) < b.unicode_at(i)
	return a.length() < b.length()

static func _json(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(_less)
		var parts: PackedStringArray = []
		for key in keys:
			parts.append(_quote(key) + ":" + _json(value[key]))
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var parts: PackedStringArray = []
		for item in value:
			parts.append(_json(item))
		return "[" + ",".join(parts) + "]"
	if value is String:
		return _quote(value)
	if value is bool:
		return "true" if value else "false"
	return str(value)

static func _quote(value: String) -> String:
	var encoded := '"'
	var escapes := {34:'\\"', 92:'\\\\', 8:'\\b', 9:'\\t', 10:'\\n', 12:'\\f', 13:'\\r'}
	for i in value.length():
		var scalar := value.unicode_at(i)
		if escapes.has(scalar):
			encoded += escapes[scalar]
		elif scalar < 32:
			encoded += "\\u%04x" % scalar
		else:
			encoded += value.substr(i, 1)
	return encoded + '"'

static func _issue(code: int, path: String, message: String) -> Dictionary:
	return {"code":code, "severity":Types.ValidationSeverity.ERROR, "path":path, "entity_ids":[], "message":message, "details":{}}

static func _result(field: String, payload: Variant, issues: Array) -> Dictionary:
	var owned: Array = issues.duplicate(true)
	owned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.path != b.path:
			return _less(a.path, b.path)
		if a.code != b.code:
			return a.code < b.code
		for i in mini(a.entity_ids.size(), b.entity_ids.size()):
			if a.entity_ids[i] != b.entity_ids[i]:
				return _less(String(a.entity_ids[i]), String(b.entity_ids[i]))
		return a.entity_ids.size() < b.entity_ids.size())
	return {"ok":owned.is_empty(), field:payload, "issues":owned}

## JSON integers never pass through float64. Duplicate keys are rejected before Dictionary insertion.
class ExactJSON:
	var source: String
	var offset := 0
	var issues: Array[Dictionary] = []

	func _init(text: String) -> void:
		source = text

	func fail(message: String, code: int = Code.INVALID_TYPE) -> void:
		if issues.is_empty():
			issues.append({"code":code, "severity":Types.ValidationSeverity.ERROR, "path":"json[%d]" % offset, "entity_ids":[], "message":message, "details":{}})

	func peek() -> String:
		return source.substr(offset, 1)

	func skip_space() -> void:
		while offset < source.length() and peek() in [" ", "\t", "\r", "\n"]:
			offset += 1

	func read_value(depth: int) -> Variant:
		skip_space()
		if depth > 64 or offset >= source.length():
			fail("Missing value or JSON nesting limit exceeded.")
			return null
		var token := peek()
		if token == '"':
			return read_string()
		if token == "{" or token == "[":
			return read_collection(token == "{", depth)
		for literal in ["true", "false", "null"]:
			if source.substr(offset, literal.length()) == literal:
				offset += literal.length()
				return {"true":true, "false":false, "null":null}[literal]
		if token == "-" or token in "0123456789":
			return read_integer()
		fail("Unexpected JSON token.")
		return null

	func read_collection(object: bool, depth: int) -> Variant:
		offset += 1
		var dictionary := {}
		var array: Array = []
		var closing := "}" if object else "]"
		skip_space()
		if peek() == closing:
			offset += 1
			return dictionary if object else array
		while issues.is_empty():
			var key := ""
			if object:
				skip_space()
				if peek() != '"':
					fail("Object key must be a string.")
					break
				key = read_string()
				if dictionary.has(key):
					fail("Duplicate object field.", Code.DUPLICATE_ID)
					break
				skip_space()
				if peek() != ":":
					fail("Expected colon after object key.")
					break
				offset += 1
			var value: Variant = read_value(depth + 1)
			if object:
				dictionary[key] = value
			else:
				array.append(value)
			skip_space()
			if peek() == closing:
				offset += 1
				return dictionary if object else array
			if peek() != ",":
				fail("Expected comma or closing delimiter.")
				break
			offset += 1
		return null

	func read_integer() -> Variant:
		var start := offset
		var negative := peek() == "-"
		if negative:
			offset += 1
		var digits_start := offset
		while offset < source.length() and peek() in "0123456789":
			offset += 1
		var digits := source.substr(digits_start, offset - digits_start)
		if digits.is_empty() or (digits.length() > 1 and digits.begins_with("0")) or peek() in [".", "e", "E"]:
			fail("Expected an exact JSON integer with no leading zeros or exponent.")
			return null
		var limit := "9223372036854775808" if negative else "9223372036854775807"
		if digits.length() > limit.length() or (digits.length() == limit.length() and digits > limit):
			fail("JSON integer exceeds int64.", Code.ARITHMETIC_OVERFLOW)
			return null
		return source.substr(start, offset - start).to_int()

	func read_string() -> String:
		offset += 1
		var output := ""
		while offset < source.length() and issues.is_empty():
			var character := peek()
			offset += 1
			if character == '"':
				return output
			if character.unicode_at(0) < 32:
				fail("Unescaped control character.")
				break
			if character != "\\":
				output += character
				continue
			var escape := peek()
			offset += 1
			var simple := {'"':'"', "\\":"\\", "/":"/", "b":"\b", "f":"\f", "n":"\n", "r":"\r", "t":"\t"}
			if simple.has(escape):
				output += simple[escape]
			elif escape == "u":
				var scalar := read_hex()
				if scalar >= 0xd800 and scalar <= 0xdbff:
					if source.substr(offset, 2) != "\\u":
						fail("High surrogate requires a low surrogate.")
						break
					offset += 2
					var low := read_hex()
					if low < 0xdc00 or low > 0xdfff:
						fail("Invalid low surrogate.")
						break
					scalar = 0x10000 + (scalar - 0xd800) * 1024 + low - 0xdc00
				elif scalar >= 0xdc00 and scalar <= 0xdfff:
					fail("Isolated low surrogate.")
					break
				if issues.is_empty():
					output += String.chr(scalar)
			else:
				fail("Invalid string escape.")
		fail("Unterminated JSON string.")
		return ""

	func read_hex() -> int:
		var value := 0
		for i in 4:
			var digit := "0123456789abcdef".find(peek().to_lower()) if offset < source.length() else -1
			if digit < 0:
				fail("Unicode escape requires four hex digits.")
				return 0
			value = value * 16 + digit
			offset += 1
		return value
