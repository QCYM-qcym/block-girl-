extends RefCounted
## Only 3B-owned enums. AnalysisCode and Graph schemas remain owned by 3A.
enum SoftlockStatus { COMPLETE = 0, INCOMPLETE = 1, ERROR = 2 }
enum ResetClassification { RECOVERABLE_BY_RESET = 0, NOT_RECOVERABLE_BY_RESET = 1, UNKNOWN = 2 }

static func _empty_result() -> Dictionary:
	return {"status": SoftlockStatus.INCOMPLETE, "initial_key": "", "reachable_states": [],
		"goal_reachable_states": [], "softlock_states": null, "softlock_count": null,
		"unknown_states": [], "reset_classification": ResetClassification.UNKNOWN,
		"reset_recoverable_count": null, "witnesses": [],
		"metrics": {"nodes_checked": 0, "edges_checked": 0, "elapsed_ms": 0}, "issues": []}
