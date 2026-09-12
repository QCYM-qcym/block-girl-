extends RefCounted
const Orientation=preload("res://prototype/perspective/cube_orientation.gd")
const ROLL_SECONDS:=0.32
var orientation=Orientation.new()
var cell:=Vector2i(0,4)
var destination:=cell
var direction:=Vector2i.ZERO
var world:=0
var phase:="idle"
var elapsed:=0.0
var moves:=0
var crossing:=false
var held: Dictionary={}
var order: Array[int]=[]
var graph
var view
var message:="按住 WASD 连续滚动；E 切换到 EAST 连接视角。"
var moving: bool:
	get: return phase=="roll"
var fraction: float:
	get: return clampf(elapsed/ROLL_SECONDS,0,1) if moving else 0.0
func _init(connectivity,perspective) -> void:
	graph=connectivity
	view=perspective
func press(token: int,screen_direction: int) -> void:
	if held.has(token): return
	held[token]=screen_direction
	order.append(token)
	try_held()
func release(token: int) -> void:
	held.erase(token)
	order.erase(token)
func clear_held() -> void:
	held.clear()
	order.clear()
func try_held() -> void:
	if phase!="idle" or view.busy or order.is_empty(): return
	var desired: Vector2i=view.world_direction(held[order.back()])
	var next: Vector2i=graph.neighbor(cell,desired,view)
	if next==cell:
		message="前方无可用边：%s。EAST 中两个世界均可通过中央连接。" % graph.link.reason
		return
	destination=next
	direction=desired
	crossing=(destination-cell).length_squared()>1
	phase="roll"
	elapsed=0.0
	message="穿越投影连接：正常滚动一格……" if crossing else "松开按键后，当前完整滚动结束即停。"
func shift() -> bool:
	if phase!="idle" or view.busy: return false
	phase="shift"
	elapsed=0.0
	return true
func tick(delta: float) -> void:
	if phase=="roll":
		elapsed+=delta
		if elapsed>=ROLL_SECONDS:
			cell=destination
			orientation.roll(direction)
			moves+=1
			phase="idle"
			crossing=false
	elif phase=="shift":
		elapsed+=delta
		if elapsed>=0.25:
			world=1-world
			phase="idle"
			graph.recalculate(view,world)
			message="世界已切换；格坐标与物理脸朝向保留。"
	try_held()
func reset() -> void:
	orientation=Orientation.new()
	cell=Vector2i(0,4)
	destination=cell
	direction=Vector2i.ZERO
	world=0
	phase="idle"
	elapsed=0.0
	moves=0
	crossing=false
	clear_held()
	message="已重置。A/B 逻辑间隔保持不变，E 查看连接视角。"
