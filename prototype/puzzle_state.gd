extends RefCounted
## P-01 only. Grid occupancy is authoritative; presentation commits actions.
const START := Vector2i(1, 9)
const PLATE := Vector2i(2, 1)
const DOOR := Vector2i(10, 3)
const EXIT := Vector2i(10, 1)
const SURFACE := 0
const INNER := 1

var cell := START
var world := SURFACE
var phase := "idle"
var plate_latched := false
var door_open := false
var moves := 0
var switches := 0
var rejection := ""
var destination := START
var floors: Array[Dictionary] = [{}, {}]

func _init() -> void:
	for w in 2:
		line(w, Vector2i(1,9), Vector2i(6,9))
		line(w, Vector2i(6,3), Vector2i(6,9))
		line(w, Vector2i(6,6), Vector2i(10,6))
	line(SURFACE, Vector2i(1,6), Vector2i(1,9))
	line(SURFACE, Vector2i(1,6), Vector2i(4,6))
	line(SURFACE, Vector2i(10,1), Vector2i(10,6))
	floors[SURFACE].erase(Vector2i(6,7))
	floors[SURFACE].erase(Vector2i(8,6))
	line(INNER, Vector2i(2,3), Vector2i(6,3))
	line(INNER, Vector2i(2,1), Vector2i(2,3))
	line(INNER, Vector2i(8,6), Vector2i(8,8))

func line(w: int, start: Vector2i, end: Vector2i) -> void:
	var step := (end - start).sign()
	var at := start
	floors[w][at] = true
	while at != end:
		at += step
		floors[w][at] = true

func can_stand(at: Vector2i, in_world: int) -> bool:
	return floors[in_world].has(at) and not (in_world == SURFACE and at == DOOR and not door_open)

func begin_move(direction: Vector2i) -> bool:
	if phase != "idle": return false
	if absi(direction.x) + absi(direction.y) != 1: return false
	destination = cell + direction
	if not can_stand(destination, world):
		rejection = "门还未开启。去里世界寻找压力板。" if destination == DOOR and world == SURFACE else "前方没有落脚点。试试另一个世界？"
		return false
	# The accepted gate has one fixed NE/SW pass axis.
	if world == SURFACE and (cell == DOOR or destination == DOOR) and direction.x != 0:
		rejection = "门只能沿通道方向通过。"
		return false
	phase = "moving"
	return true

func finish_move() -> void:
	if phase != "moving": return
	cell = destination
	moves += 1
	phase = "idle"
	arrive()

func begin_switch() -> bool:
	if phase != "idle": return false
	if not can_stand(cell, 1 - world):
		rejection = "无法切换：另一世界的同一格不可站立。先回到共有地面。"
		return false
	phase = "switching"
	return true

func finish_switch() -> void:
	if phase != "switching": return
	world = 1 - world
	switches += 1
	phase = "idle"
	arrive()

func arrive() -> void:
	if world == INNER and cell == PLATE and not plate_latched:
		phase = "pressing"
	elif world == SURFACE and cell == EXIT and door_open:
		phase = "completing"

func activate_plate() -> void:
	if phase != "pressing": return
	plate_latched = true
	phase = "idle"

func mark_door_open() -> void:
	if plate_latched: door_open = true

func finish_puzzle() -> void:
	if phase == "completing": phase = "complete"

func reset() -> void:
	cell = START
	destination = START
	world = SURFACE
	phase = "idle"
	plate_latched = false
	door_open = false
	moves = 0
	switches = 0
	rejection = ""
