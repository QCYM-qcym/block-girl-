extends RefCounted
const Explorer = preload("res://foundation/solver/state_explorer.gd")

static func solve(level: Dictionary, initial: Dictionary, policy: Dictionary, budget: Dictionary) -> Dictionary:
	return Explorer.explore(level,initial,policy,budget)
