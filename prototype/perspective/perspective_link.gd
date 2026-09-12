extends RefCounted
var a
var b
var allowed_perspectives: Array = [1]
var allowed_world_states: Array = [0]
var entry_direction:=Vector2i.RIGHT
var exit_direction:=Vector2i.RIGHT
var enabled:=true
var projection_tolerance:=1.0
var active:=false
var distance:=INF
var projected_a:=Vector2.ZERO
var projected_b:=Vector2.ZERO
var reason:="not evaluated"
func _init(anchor_a,anchor_b) -> void:
	a=anchor_a
	b=anchor_b
func evaluate(view,world: int,nodes: Dictionary) -> void:
	projected_a=view.project(a.position(),a.elevation,a.platform,view.current)
	projected_b=view.project(b.position(),b.elevation,b.platform,view.current)
	distance=projected_a.distance_to(projected_b)
	active=false
	if not enabled: reason="disabled"
	elif a.id==b.id or not nodes.has(a.node) or not nodes.has(b.node): reason="invalid authored pair"
	elif view.current not in allowed_perspectives: reason="wrong view"
	elif world not in allowed_world_states or world not in a.worlds or world not in b.worlds: reason="wrong world"
	elif a.elevation!=b.elevation: reason="different elevation"
	elif absi(entry_direction.x)+absi(entry_direction.y)!=1 or entry_direction!=exit_direction or a.direction!=entry_direction or b.direction!=-exit_direction: reason="invalid endpoint direction"
	elif distance>projection_tolerance: reason="projection mismatch"
	else:
		active=true
		reason="aligned authored pair"
