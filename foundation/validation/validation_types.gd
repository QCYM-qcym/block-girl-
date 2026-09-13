extends RefCounted
## Execution-only query statuses; ValidationCode remains owned by DATA.
enum ValidationStatus { VALID = 0, INVALID = 1, INCOMPLETE = 2 }
enum SafetyStatus { SAFE = 0, UNSAFE = 1, UNPROVEN = 2, ERROR = 3 }
