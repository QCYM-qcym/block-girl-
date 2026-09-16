extends RefCounted
## TEST ONLY: controlled response for the 3A Graph.validate dependency.
## It deliberately performs no graph validation or topology traversal.

var calls := 0
var response: Dictionary


func _init(configured_response: Dictionary = {"ok": true, "issues": []}) -> void:
	response = configured_response.duplicate(true)


func validate(level: Dictionary, graph: Dictionary) -> Dictionary:
	calls += 1
	return response.duplicate(true)


func validator() -> Callable:
	return validate
