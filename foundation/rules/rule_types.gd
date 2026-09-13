extends RefCounted
## Execution-only enums; existing DATA codes are referenced, never duplicated.
enum TransitionStatus { APPLIED = 0, REJECTED = 1, ERROR = 2 }
enum ActionRejectionCode {
	MOVE_BLOCKED = 2000,
	ROTATION_NOT_ALLOWED = 2001,
	ROTATION_STATE_INVALID = 2002,
	FACE_TRANSITION_NOT_AVAILABLE = 2003,
}
