extends RefCounted
const Anchor=preload("res://prototype/perspective/perspective_anchor.gd")
const Link=preload("res://prototype/perspective/perspective_link.gd")
var nodes: Dictionary = {}
var link
var revision:=0
func _init() -> void:
	for x in range(0,5):
		for z in range(0,5): nodes[Vector2i(x,z)]=0
	for x in range(10,13):
		for z in range(1,4):
			# Only the authored endpoint touches A in the aligned presentation.
			if x!=10 or z==2: nodes[Vector2i(x,z)]=1
	link=Link.new(Anchor.new("A_east",Vector2i(4,2),Vector2i.RIGHT,0),Anchor.new("B_west",Vector2i(10,2),Vector2i.LEFT,1))
	# Both worlds display the same aligned EAST entrance in this authored fixture.
	link.allowed_world_states=[0,1]
func recalculate(view,world: int) -> void:
	if view.busy: return
	link.evaluate(view,world,nodes)
	revision+=1
func neighbor(cell: Vector2i,direction: Vector2i,view) -> Vector2i:
	if view.busy or not nodes.has(cell): return cell
	if absi(direction.x)+absi(direction.y)!=1: return cell
	var next:=cell+direction
	if nodes.has(next) and nodes[next]==nodes[cell]: return next
	if link.active:
		if cell==link.a.node and direction==link.entry_direction: return link.b.node
		if cell==link.b.node and direction==-link.exit_direction: return link.a.node
	return cell
