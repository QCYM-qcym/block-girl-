extends RefCounted
## Analysis taxonomy; these tags are not PuzzleActionKind aliases.
enum MechanicTag {
	MOVE = 0,
	WORLD_SHIFT = 1,
	SURFACE_ROTATE = 2,
	INNER_ROTATE = 3,
	FACE_TRANSITION = 4,
	LOCAL_GROUP_ROTATE = 5,
	CELESTIAL_CHANGE = 6,
	MECHANISM_TRIGGER = 7,
}
enum PredicateKind { AT_FACE = 0, IN_LAYER = 1, FACE_LIGHT = 2, MECHANIC_USED = 3, GOAL = 4 }
enum AblationStatus { COMPLETE = 0, INCOMPLETE = 1, ERROR = 2, BASELINE_UNSOLVABLE = 3 }
enum MilestoneStatus { TRACE_MATCH = 0, TRACE_BYPASS = 1, INCOMPLETE = 2, ERROR = 3 }
enum QualityCode { MECHANIC_BYPASS = 4000, MILESTONE_BYPASS = 4001, UNUSED_MECHANISM = 4002 }

static func _issue(code: int, path: String, message: String, upstream: Array = []) -> Dictionary:
	# AnalysisCode numeric ABI is owned by 3A; no duplicate enum here.
	return {"code":code,"severity":0,"path":path,"message":message,"details":{},"upstream":upstream.duplicate(true)}
