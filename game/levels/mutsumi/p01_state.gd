extends "res://prototype/perspective/connectivity.gd"
const START:=Vector2i(0,5)
const PLATE:=Vector2i(11,0)
const BEYOND_GATE:=Vector2i(12,0)
const EXIT:=Vector2i(13,0)
var floors: Array[Dictionary]=[{},{}]
var player_ref: WeakRef
var mover:
	get: return player_ref.get_ref() if player_ref else null
var world:=0
var plate_pressed:=false
var door_open:=false
var complete:=false
func _init() -> void:
	nodes.clear()
	for z in range(2,6): nodes[Vector2i(0,z)]=0
	for x in range(4): nodes[Vector2i(x,0)]=0
	nodes[Vector2i(0,1)]=0
	for x in range(9,14): nodes[Vector2i(x,0)]=1
	for w in 2:
		floors[w]=nodes.duplicate()
	floors[0].erase(Vector2i(0,1))
	link=Link.new(Anchor.new("middle_east",Vector2i(3,0),Vector2i.RIGHT,0),Anchor.new("goal_west",Vector2i(9,0),Vector2i.LEFT,1))
	link.allowed_world_states=[1]
func bind(player) -> void:
	player_ref=weakref(player)
	mover.committed.connect(settle)
func reset_level() -> void:
	mover.view.reset()
	mover.reset()
	mover.cell=START
	mover.destination=START
	complete=false
	settle()
	recalculate(mover.view,0)
func can_stand(cell: Vector2i,in_world: int) -> bool:
	return in_world in [0,1] and floors[in_world].has(cell)
func recalculate(view,in_world: int) -> void:
	if view.busy: return
	world=in_world
	link.evaluate(view,world,floors[world])
	revision+=1
func neighbor(cell: Vector2i,direction: Vector2i,view) -> Vector2i:
	var next:=super.neighbor(cell,direction,view)
	if not can_stand(next,world): return cell
	if (cell==PLATE and next==BEYOND_GATE) or (cell==BEYOND_GATE and next==PLATE):
		if not door_open: return cell
	return next
func settle() -> void:
	world=mover.world
	plate_pressed=world==0 and mover.cell==PLATE
	door_open=plate_pressed
	if world==0 and mover.cell==EXIT:
		complete=true
		mover.phase="complete"
		mover.clear_held()
