extends RefCounted

const DATA = preload("res://foundation/contracts/foundation_types.gd")

const _DEFINITION_FIELDS := ["slots", "slot_order", "wrap", "initial_slot_id", "edges"]
const _SLOT_FIELDS := ["slot_id", "position2"]
const _EDGE_FIELDS := ["from_slot_id", "to_slot_id"]


static func resolve_slot_request(
	definition: Dictionary,
	current_slot_id: StringName,
	operation: int,
	target_slot_id: StringName,
	alternate_slot_id: StringName
) -> Dictionary:
	var issues: Array[Dictionary] = []
	var slot_ids := _validate_definition(definition, issues)
	_validate_request(
		slot_ids,
		current_slot_id,
		operation,
		target_slot_id,
		alternate_slot_id,
		issues
	)
	_sort_issues(issues)
	if not issues.is_empty():
		return _failure(issues)

	var next_slot_id := current_slot_id
	match operation:
		DATA.CelestialOp.SET_SLOT:
			next_slot_id = target_slot_id
		DATA.CelestialOp.NEXT_SLOT:
			var next_result := _ordered_destination(definition, current_slot_id, 1)
			if not next_result.ok:
				return _step_failure(current_slot_id, operation, "slot_order has no next slot")
			next_slot_id = next_result.slot_id
		DATA.CelestialOp.PREVIOUS_SLOT:
			var previous_result := _ordered_destination(definition, current_slot_id, -1)
			if not previous_result.ok:
				return _step_failure(current_slot_id, operation, "slot_order has no previous slot")
			next_slot_id = previous_result.slot_id
		DATA.CelestialOp.TOGGLE_BETWEEN:
			next_slot_id = alternate_slot_id if current_slot_id == target_slot_id else target_slot_id

	if next_slot_id != current_slot_id and not _has_edge(definition.edges, current_slot_id, next_slot_id):
		return _step_failure(current_slot_id, operation, "directed slot edge is unavailable", next_slot_id)

	return {
		"ok": true,
		"changed": next_slot_id != current_slot_id,
		"next_slot_id": next_slot_id,
		"issues": [],
	}


static func _validate_definition(definition: Dictionary, issues: Array[Dictionary]) -> Dictionary:
	_validate_fields(definition, _DEFINITION_FIELDS, "", issues)
	var slot_ids: Dictionary = {}
	if definition.has("slots") and not definition.slots is Array:
		issues.append(_issue(
			DATA.ValidationCode.INVALID_TYPE,
			"slots",
			[],
			"slots must be an Array"
		))
	elif definition.has("slots"):
		for index in definition.slots.size():
			var path := "slots[%d]" % index
			var slot: Variant = definition.slots[index]
			if not slot is Dictionary:
				issues.append(_issue(
					DATA.ValidationCode.INVALID_TYPE,
					path,
					[],
					"slot must be a Dictionary"
				))
				continue
			_validate_fields(slot, _SLOT_FIELDS, path, issues)
			if slot.has("slot_id"):
				if not slot.slot_id is StringName:
					issues.append(_issue(
						DATA.ValidationCode.INVALID_TYPE,
						path + ".slot_id",
						[],
						"slot_id must be a StringName"
					))
				elif not _is_valid_id(slot.slot_id):
					issues.append(_issue(
						DATA.ValidationCode.INVALID_ID,
						path + ".slot_id",
						[slot.slot_id],
						"slot_id has invalid syntax"
					))
				elif slot_ids.has(slot.slot_id):
					issues.append(_issue(
						DATA.ValidationCode.DUPLICATE_ID,
						path + ".slot_id",
						[slot.slot_id],
						"slot_id is duplicated"
					))
				else:
					slot_ids[slot.slot_id] = index
			if slot.has("position2") and not slot.position2 is Vector3i:
				issues.append(_issue(
					DATA.ValidationCode.INVALID_TYPE,
					path + ".position2",
					[],
					"position2 must be a Vector3i"
				))

	_validate_slot_order(definition, slot_ids, issues)
	_validate_wrap(definition, issues)
	_validate_initial_slot(definition, slot_ids, issues)
	_validate_edges(definition, slot_ids, issues)
	return slot_ids


static func _validate_slot_order(
	definition: Dictionary,
	slot_ids: Dictionary,
	issues: Array[Dictionary]
) -> void:
	if not definition.has("slot_order"):
		return
	if not definition.slot_order is Array:
		issues.append(_issue(
			DATA.ValidationCode.INVALID_TYPE,
			"slot_order",
			[],
			"slot_order must be an Array"
		))
		return
	var ordered_ids: Dictionary = {}
	for index in definition.slot_order.size():
		var path := "slot_order[%d]" % index
		var slot_id: Variant = definition.slot_order[index]
		if not slot_id is StringName:
			issues.append(_issue(
				DATA.ValidationCode.INVALID_TYPE,
				path,
				[],
				"slot_order entry must be a StringName"
			))
			continue
		if not _is_valid_id(slot_id):
			issues.append(_issue(
				DATA.ValidationCode.INVALID_ID,
				path,
				[slot_id],
				"slot_order entry has invalid syntax"
			))
		if ordered_ids.has(slot_id):
			issues.append(_issue(
				DATA.ValidationCode.DUPLICATE_ID,
				path,
				[slot_id],
				"slot_order entry is duplicated"
			))
		else:
			ordered_ids[slot_id] = index
		if not slot_ids.has(slot_id):
			issues.append(_issue(
				DATA.ValidationCode.INVALID_CELESTIAL_REFERENCE,
				path,
				[slot_id],
				"slot_order references an unknown slot"
			))
	for slot_id in slot_ids:
		if not ordered_ids.has(slot_id):
			issues.append(_issue(
				DATA.ValidationCode.INVALID_CELESTIAL_REFERENCE,
				"slot_order",
				[slot_id],
				"slot_order omits a defined slot"
			))


static func _validate_wrap(definition: Dictionary, issues: Array[Dictionary]) -> void:
	if definition.has("wrap") and not definition.wrap is bool:
		issues.append(_issue(
			DATA.ValidationCode.INVALID_TYPE,
			"wrap",
			[],
			"wrap must be a bool"
		))


static func _validate_initial_slot(
	definition: Dictionary,
	slot_ids: Dictionary,
	issues: Array[Dictionary]
) -> void:
	if not definition.has("initial_slot_id"):
		return
	var slot_id: Variant = definition.initial_slot_id
	if not slot_id is StringName:
		issues.append(_issue(
			DATA.ValidationCode.INVALID_TYPE,
			"initial_slot_id",
			[],
			"initial_slot_id must be a StringName"
		))
		return
	if not _is_valid_id(slot_id):
		issues.append(_issue(
			DATA.ValidationCode.INVALID_ID,
			"initial_slot_id",
			[slot_id],
			"initial_slot_id has invalid syntax"
		))
	if not slot_ids.has(slot_id):
		issues.append(_issue(
			DATA.ValidationCode.INVALID_CELESTIAL_REFERENCE,
			"initial_slot_id",
			[slot_id],
			"initial_slot_id references an unknown slot"
		))


static func _validate_edges(
	definition: Dictionary,
	slot_ids: Dictionary,
	issues: Array[Dictionary]
) -> void:
	if not definition.has("edges"):
		return
	if not definition.edges is Array:
		issues.append(_issue(
			DATA.ValidationCode.INVALID_TYPE,
			"edges",
			[],
			"edges must be an Array"
		))
		return
	var edge_keys: Dictionary = {}
	for index in definition.edges.size():
		var path := "edges[%d]" % index
		var edge: Variant = definition.edges[index]
		if not edge is Dictionary:
			issues.append(_issue(
				DATA.ValidationCode.INVALID_TYPE,
				path,
				[],
				"edge must be a Dictionary"
			))
			continue
		_validate_fields(edge, _EDGE_FIELDS, path, issues)
		var valid_ids := true
		for field in _EDGE_FIELDS:
			if not edge.has(field):
				valid_ids = false
				continue
			var slot_id: Variant = edge[field]
			var field_path: String = path + "." + field
			if not slot_id is StringName:
				valid_ids = false
				issues.append(_issue(
					DATA.ValidationCode.INVALID_TYPE,
					field_path,
					[],
					field + " must be a StringName"
				))
				continue
			if not _is_valid_id(slot_id):
				valid_ids = false
				issues.append(_issue(
					DATA.ValidationCode.INVALID_ID,
					field_path,
					[slot_id],
					field + " has invalid syntax"
				))
			if not slot_ids.has(slot_id):
				valid_ids = false
				issues.append(_issue(
					DATA.ValidationCode.INVALID_CELESTIAL_REFERENCE,
					field_path,
					[slot_id],
					field + " references an unknown slot"
				))
		if not valid_ids:
			continue
		var edge_key := String(edge.from_slot_id) + "\u001f" + String(edge.to_slot_id)
		if edge_keys.has(edge_key):
			issues.append(_issue(
				DATA.ValidationCode.DUPLICATE_ID,
				path,
				[edge.from_slot_id, edge.to_slot_id],
				"directed slot edge is duplicated"
			))
		else:
			edge_keys[edge_key] = index


static func _validate_request(
	slot_ids: Dictionary,
	current_slot_id: StringName,
	operation: int,
	target_slot_id: StringName,
	alternate_slot_id: StringName,
	issues: Array[Dictionary]
) -> void:
	_validate_slot_reference(current_slot_id, "current_slot_id", slot_ids, false, issues)
	if operation < DATA.CelestialOp.SET_SLOT or operation > DATA.CelestialOp.TOGGLE_BETWEEN:
		issues.append(_issue(
			DATA.ValidationCode.INVALID_ENUM,
			"operation",
			[],
			"operation is not a CelestialOp",
			{"value": operation}
		))
		return
	match operation:
		DATA.CelestialOp.SET_SLOT:
			_validate_slot_reference(target_slot_id, "target_slot_id", slot_ids, false, issues)
			_validate_slot_reference(alternate_slot_id, "alternate_slot_id", slot_ids, true, issues)
		DATA.CelestialOp.NEXT_SLOT, DATA.CelestialOp.PREVIOUS_SLOT:
			_validate_slot_reference(target_slot_id, "target_slot_id", slot_ids, true, issues)
			_validate_slot_reference(alternate_slot_id, "alternate_slot_id", slot_ids, true, issues)
		DATA.CelestialOp.TOGGLE_BETWEEN:
			_validate_slot_reference(target_slot_id, "target_slot_id", slot_ids, false, issues)
			_validate_slot_reference(alternate_slot_id, "alternate_slot_id", slot_ids, false, issues)
			if target_slot_id == alternate_slot_id:
				issues.append(_issue(
					DATA.ValidationCode.INVALID_CELESTIAL_REFERENCE,
					"alternate_slot_id",
					[alternate_slot_id],
					"TOGGLE endpoints must be different"
				))
			if current_slot_id != target_slot_id and current_slot_id != alternate_slot_id:
				issues.append(_issue(
					DATA.ValidationCode.INVALID_CELESTIAL_REFERENCE,
					"current_slot_id",
					[current_slot_id, target_slot_id, alternate_slot_id],
					"current slot is outside the TOGGLE endpoints"
				))


static func _validate_slot_reference(
	slot_id: StringName,
	path: String,
	slot_ids: Dictionary,
	allow_empty: bool,
	issues: Array[Dictionary]
) -> void:
	if slot_id == StringName():
		if not allow_empty:
			issues.append(_issue(
				DATA.ValidationCode.INVALID_CELESTIAL_REFERENCE,
				path,
				[],
				"slot reference is required"
			))
		return
	if allow_empty:
		issues.append(_issue(
			DATA.ValidationCode.INVALID_CELESTIAL_REFERENCE,
			path,
			[slot_id],
			"slot reference must be empty for this operation"
		))
		return
	if not _is_valid_id(slot_id):
		issues.append(_issue(
			DATA.ValidationCode.INVALID_ID,
			path,
			[slot_id],
			"slot reference has invalid syntax"
		))
	if not slot_ids.has(slot_id):
		issues.append(_issue(
			DATA.ValidationCode.INVALID_CELESTIAL_REFERENCE,
			path,
			[slot_id],
			"slot reference does not exist"
		))


static func _ordered_destination(definition: Dictionary, current_slot_id: StringName, delta: int) -> Dictionary:
	var index: int = definition.slot_order.find(current_slot_id)
	var destination_index: int = index + delta
	if destination_index < 0 or destination_index >= definition.slot_order.size():
		if not definition.wrap:
			return {"ok": false, "slot_id": StringName()}
		destination_index = 0 if destination_index >= definition.slot_order.size() else definition.slot_order.size() - 1
	return {"ok": true, "slot_id": definition.slot_order[destination_index]}


static func _has_edge(edges: Array, from_slot_id: StringName, to_slot_id: StringName) -> bool:
	for edge in edges:
		if edge.from_slot_id == from_slot_id and edge.to_slot_id == to_slot_id:
			return true
	return false


static func _step_failure(
	current_slot_id: StringName,
	operation: int,
	message: String,
	destination_slot_id: StringName = StringName()
) -> Dictionary:
	var ids: Array[StringName] = [current_slot_id]
	if destination_slot_id != StringName():
		ids.append(destination_slot_id)
	return _failure([_issue(
		DATA.ValidationCode.SLOT_STEP_UNAVAILABLE,
		"operation",
		ids,
		message,
		{"operation": operation}
	)])


static func _failure(issues: Array[Dictionary]) -> Dictionary:
	_sort_issues(issues)
	return {
		"ok": false,
		"changed": false,
		"next_slot_id": StringName(),
		"issues": issues,
	}


static func _validate_fields(
	record: Dictionary,
	required_fields: Array,
	path: String,
	issues: Array[Dictionary]
) -> void:
	for field in required_fields:
		if not record.has(field):
			issues.append(_issue(
				DATA.ValidationCode.MISSING_FIELD,
				_join_path(path, field),
				[],
				"required field is missing"
			))
	var unexpected_fields: Array[Dictionary] = []
	for key in record:
		if typeof(key) != TYPE_STRING:
			var details := _invalid_field_key_details(key)
			unexpected_fields.append({
				"code": DATA.ValidationCode.INVALID_TYPE,
				"path": _join_path(path, "<invalid_field_key>"),
				"message": "record field keys must be String",
				"details": details,
			})
		elif not required_fields.has(key):
			var field: String = key
			unexpected_fields.append({
				"code": DATA.ValidationCode.UNKNOWN_FIELD,
				"path": _join_path(path, field),
				"message": "field is not part of the celestial contract",
				"details": {},
			})
	for unexpected in unexpected_fields:
		issues.append(_issue(
			unexpected.code,
			unexpected.path,
			[],
			unexpected.message,
			unexpected.details
		))


static func _invalid_field_key_details(key: Variant) -> Dictionary:
	var key_type := typeof(key)
	var details := {"key_type": key_type}
	match key_type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			details["key"] = key
		TYPE_STRING_NAME:
			var key_name: StringName = key
			details["key"] = String(key_name)
		TYPE_VECTOR2I:
			details["key"] = [key.x, key.y]
		TYPE_VECTOR3I:
			details["key"] = [key.x, key.y, key.z]
		TYPE_VECTOR4I:
			details["key"] = [key.x, key.y, key.z, key.w]
	return details


static func _join_path(prefix: String, field: String) -> String:
	return field if prefix.is_empty() else prefix + "." + field


static func _is_valid_id(value: StringName) -> bool:
	var text := String(value)
	if text.is_empty():
		return false
	var first := text.unicode_at(0)
	if first < 97 or first > 122:
		return false
	for index in range(1, text.length()):
		var character := text.unicode_at(index)
		if character == 95:
			continue
		if character >= 97 and character <= 122:
			continue
		if character >= 48 and character <= 57:
			continue
		return false
	return true


static func _issue(
	code: int,
	path: String,
	entity_ids: Array,
	message: String,
	details: Dictionary = {}
) -> Dictionary:
	return {
		"code": code,
		"severity": DATA.ValidationSeverity.ERROR,
		"path": path,
		"entity_ids": entity_ids.duplicate(),
		"message": message,
		"details": details.duplicate(true),
	}


static func _sort_issues(issues: Array[Dictionary]) -> void:
	issues.sort_custom(_issue_less)


static func _issue_less(left: Dictionary, right: Dictionary) -> bool:
	if left.path != right.path:
		return left.path < right.path
	if left.code != right.code:
		return left.code < right.code
	var left_entities := _entity_key(left.entity_ids)
	var right_entities := _entity_key(right.entity_ids)
	if left_entities != right_entities:
		return left_entities < right_entities
	return _issue_detail_key(left.details) < _issue_detail_key(right.details)


static func _entity_key(entity_ids: Array) -> String:
	var parts: Array[String] = []
	for entity_id in entity_ids:
		parts.append(String(entity_id))
	return "\u001f".join(parts)


static func _issue_detail_key(details: Dictionary) -> String:
	if not details.has("key_type"):
		return ""
	var key_type: int = details.key_type
	var value := ""
	if details.has("key"):
		match key_type:
			TYPE_NIL:
				value = "null"
			TYPE_BOOL:
				value = "true" if details.key else "false"
			TYPE_INT:
				value = "%d" % details.key
			TYPE_STRING_NAME:
				value = details.key
			TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I:
				for component in details.key:
					value += ":%d" % component
	return "%03d:%s" % [key_type, value]
