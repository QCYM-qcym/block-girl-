extends RefCounted
## Explicit discrete 2D projections. Not a single rigid 3D-camera simulation.
const SNAP_SECONDS := 0.4
const DRAG_THRESHOLD := 60.0
enum { VIEW_NORTH, VIEW_EAST, VIEW_SOUTH, VIEW_WEST }
const VIEW_NAMES := ["NORTH","EAST","SOUTH","WEST"]
var rotation_step := 1
var current := 0
var target := 0
var busy := false
var dragging := false
var progress := 0.0
var elapsed := 0.0
var preview_start := 0.0
var duration := SNAP_SECONDS
var platform_b_offsets: Array[Vector2] = [Vector2.ZERO,Vector2(-5,0),Vector2.ZERO,Vector2.ZERO]

func reset() -> void:
	current=0
	target=0
	busy=false
	dragging=false
	progress=0.0
	elapsed=0.0
	preview_start=0.0
	rotation_step=1

func request_rotate_left() -> bool: return request(-1)
func request_rotate_right() -> bool: return request(1)
func request(step: int) -> bool:
	if busy or absi(step)!=1: return false
	rotation_step=step
	target=posmod(current+step,4)
	busy=true
	elapsed=0.0
	preview_start=progress
	duration=SNAP_SECONDS
	return true

func begin_drag() -> bool:
	if busy: return false
	busy=true
	dragging=true
	rotation_step=1
	target=posmod(current+rotation_step,4)
	progress=0.0
	return true
func preview_drag(delta: Vector2) -> void:
	if not dragging: return
	rotation_step=-1 if delta.x<0 else 1
	target=posmod(current+rotation_step,4)
	progress=minf(absf(delta.x)/DRAG_THRESHOLD,1.0)*0.12 if absf(delta.x)>absf(delta.y) else 0.0
func end_drag(delta: Vector2) -> void:
	if not dragging: return
	dragging=false
	busy=false
	if absf(delta.x)>=DRAG_THRESHOLD and absf(delta.x)>absf(delta.y):
		if delta.x<0: request_rotate_left()
		else: request_rotate_right()
	else:
		busy=true
		preview_start=progress
		duration=0.18
		elapsed=0.0
		# Rebound interpolates towards zero; committed view remains current.
		target=current

func tick(delta: float) -> bool:
	if not busy or dragging: return false
	elapsed+=delta
	var t:=clampf(elapsed/duration,0,1)
	progress=lerpf(preview_start,0.0 if target==current else 1.0,smoothstep(0,1,t))
	if t<1: return false
	current=target
	busy=false
	progress=0.0
	preview_start=0.0
	return true

func world_direction(screen_direction: int) -> Vector2i:
	var dirs: Array[Vector2i]=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
	return dirs[posmod(screen_direction+current,4)]

func rotate_grid(p: Vector2, view: int) -> Vector2:
	match view:
		VIEW_NORTH: return p
		VIEW_EAST: return Vector2(p.y,-p.x)
		VIEW_SOUTH: return -p
		VIEW_WEST: return Vector2(-p.y,p.x)
	return p
func view_name(index: int) -> String: return "VIEW_"+VIEW_NAMES[index]
func displayed_angle() -> float:
	# Signed local step prevents a 270-degree interpolation at NORTH/WEST wrap.
	return (float(current)+rotation_step*progress if busy else float(current))*PI/2
func project_delta(p: Vector2, view: int) -> Vector2:
	var r:=rotate_grid(p,view)
	return Vector2(16*(r.x-r.y),8*(r.x+r.y))
func project(p: Vector2, elevation: float, platform: int, view: int) -> Vector2:
	var offset:=platform_b_offsets[view] if platform==1 else Vector2.ZERO
	return project_delta(p+offset,view)-Vector2(0,elevation*16)
func displayed(p: Vector2, elevation: float, platform: int) -> Vector2:
	var base:=project(p,elevation,platform,current)
	if not busy: return base
	var other:=posmod(current+rotation_step,4)
	return base.lerp(project(p,elevation,platform,other),progress)
