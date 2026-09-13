extends RefCounted
## Exact active column-vector rotations with the frozen cube24.v1 ID order.
## compose(a, b) applies b first. Callers validate IDs with is_valid(); all
## operations except is_valid/from_columns require valid IDs (no normalization).

const ORIENTATION_VERSION: String = "cube24.v1"

enum RotationAxis { X = 0, Y = 1, Z = 2 }

# Columns are right, up, forward (+Z), as frozen in core contracts section 4.
const _COLUMNS: Array = [
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)], # 0
	[Vector3i(1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 0, -1)], # 1
	[Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, -1, 0)], # 2
	[Vector3i(1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, 1, 0)], # 3
	[Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, -1)], # 4
	[Vector3i(-1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1)], # 5
	[Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 1, 0)], # 6
	[Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, -1, 0)], # 7
	[Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, -1)], # 8
	[Vector3i(0, 1, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1)], # 9
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)], # 10
	[Vector3i(0, 1, 0), Vector3i(0, 0, -1), Vector3i(-1, 0, 0)], # 11
	[Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)], # 12
	[Vector3i(0, -1, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)], # 13
	[Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)], # 14
	[Vector3i(0, -1, 0), Vector3i(0, 0, -1), Vector3i(1, 0, 0)], # 15
	[Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)], # 16
	[Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, -1, 0)], # 17
	[Vector3i(0, 0, 1), Vector3i(0, 1, 0), Vector3i(-1, 0, 0)], # 18
	[Vector3i(0, 0, 1), Vector3i(0, -1, 0), Vector3i(1, 0, 0)], # 19
	[Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, -1, 0)], # 20
	[Vector3i(0, 0, -1), Vector3i(-1, 0, 0), Vector3i(0, 1, 0)], # 21
	[Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(1, 0, 0)], # 22
	[Vector3i(0, 0, -1), Vector3i(0, -1, 0), Vector3i(-1, 0, 0)], # 23
]

# Each table maps an old ID to the result of LEFT multiplying one quarter turn.
const ROT_X_POS: Array[int] = [2, 3, 1, 0, 6, 7, 5, 4, 16, 17, 19, 18, 20, 21, 23, 22, 12, 13, 14, 15, 8, 9, 10, 11]
const ROT_X_NEG: Array[int] = [3, 2, 0, 1, 7, 6, 4, 5, 20, 21, 22, 23, 16, 17, 18, 19, 8, 9, 11, 10, 12, 13, 15, 14]
const ROT_Y_POS: Array[int] = [22, 23, 20, 21, 18, 19, 16, 17, 11, 10, 8, 9, 15, 14, 12, 13, 3, 2, 0, 1, 7, 6, 4, 5]
const ROT_Y_NEG: Array[int] = [18, 19, 17, 16, 22, 23, 21, 20, 10, 11, 9, 8, 14, 15, 13, 12, 6, 7, 4, 5, 2, 3, 0, 1]
const ROT_Z_POS: Array[int] = [9, 8, 10, 11, 13, 12, 14, 15, 4, 5, 6, 7, 0, 1, 2, 3, 18, 19, 17, 16, 22, 23, 21, 20]
const ROT_Z_NEG: Array[int] = [12, 13, 14, 15, 8, 9, 10, 11, 1, 0, 2, 3, 5, 4, 6, 7, 19, 18, 16, 17, 23, 22, 20, 21]

static func is_valid(id: int) -> bool:
	return id >= 0 and id < 24


static func columns(id: int) -> Array[Vector3i]:
	assert(is_valid(id), "cube24.v1 orientation ID must be in 0..23")
	var result: Array[Vector3i] = [_COLUMNS[id][0], _COLUMNS[id][1], _COLUMNS[id][2]]
	return result


static func from_columns(right: Vector3i, up: Vector3i, forward: Vector3i) -> int:
	# Exact membership rejects scale, zero axes, repeated axes and reflections,
	# without float conversion or arithmetic on potentially invalid coordinates.
	for id in range(24):
		if _COLUMNS[id][0] == right and _COLUMNS[id][1] == up and _COLUMNS[id][2] == forward:
			return id
	return -1


static func reframe(source_frame: int, target_frame: int, pose: int) -> int:
	assert(is_valid(source_frame) and is_valid(target_frame) and is_valid(pose), "reframe requires valid cube24.v1 IDs")
	return compose(compose(target_frame, inverse(source_frame)), pose)


static func apply(id: int, vector: Vector3i) -> Vector3i:
	assert(is_valid(id), "cube24.v1 orientation ID must be in 0..23")
	return _COLUMNS[id][0] * vector.x + _COLUMNS[id][1] * vector.y + _COLUMNS[id][2] * vector.z


static func compose(a: int, b: int) -> int:
	assert(is_valid(a) and is_valid(b), "compose requires valid cube24.v1 IDs")
	match a:
		2:
			return ROT_X_POS[b]
		3:
			return ROT_X_NEG[b]
		22:
			return ROT_Y_POS[b]
		18:
			return ROT_Y_NEG[b]
		9:
			return ROT_Z_POS[b]
		12:
			return ROT_Z_NEG[b]
	return from_columns(apply(a, _COLUMNS[b][0]), apply(a, _COLUMNS[b][1]), apply(a, _COLUMNS[b][2]))


static func inverse(id: int) -> int:
	assert(is_valid(id), "inverse requires a valid cube24.v1 ID")
	var right: Vector3i = _COLUMNS[id][0]
	var up: Vector3i = _COLUMNS[id][1]
	var forward: Vector3i = _COLUMNS[id][2]
	return from_columns(
		Vector3i(right.x, up.x, forward.x),
		Vector3i(right.y, up.y, forward.y),
		Vector3i(right.z, up.z, forward.z)
	)


static func quarter_turn(axis: int, sign: int) -> int:
	assert(axis >= RotationAxis.X and axis <= RotationAxis.Z, "rotation axis must be X, Y or Z")
	assert(sign == 1 or sign == -1, "quarter-turn sign must be +1 or -1")
	match axis:
		RotationAxis.X:
			return 2 if sign == 1 else 3
		RotationAxis.Y:
			return 22 if sign == 1 else 18
		RotationAxis.Z:
			return 9 if sign == 1 else 12
	return -1
