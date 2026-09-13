extends "res://prototype/perspective/cube_visual.gd"
## Temporary 2D verification skin, NOT final Mutsumi/Mortis art.
## No visual orientation state: all matrices derive from the authoritative mover.
const FACE_ID:="physical_face_front / local +Z"
const MARKER_COLOR:=Color("edb94f")
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func refresh() -> void:
	queue_redraw()
func world_basis() -> Basis:
	return camera_basis().inverse()*displayed_basis()
func target_basis() -> Basis:
	var target=mover.orientation.copy()
	if mover.moving: target.roll(mover.direction)
	return target.as_basis()
func face_world_direction() -> String:
	var d: Vector3i=mover.orientation.face_direction()
	return {Vector3i.UP:"TOP",Vector3i.DOWN:"BOTTOM",Vector3i(0,0,-1):"NORTH",Vector3i(0,0,1):"SOUTH",Vector3i.RIGHT:"EAST",Vector3i.LEFT:"WEST"}[d]
func face_is_visible() -> bool:
	return (displayed_basis()*Vector3.BACK).dot(Vector3(1,0.8,1))>0.001
func draw_face_marker(transform_basis: Basis,center: Vector3) -> void:
	# Every marker point is on exactly one fixed physical face, never billboarded.
	for diagonal in [-1,1]:
		var a:=project_vertex(transform_basis*Vector3(-0.22,-0.22*diagonal,0.386)+center)
		var b:=project_vertex(transform_basis*Vector3(0.22,0.22*diagonal,0.386)+center)
		draw_line(a,b,MARKER_COLOR,1,false)
func debug_text() -> String:
	return "Cube Orientation: %s\nFace Physical ID: %s\nFace World Direction: %s\nCurrent Perspective: %s\nFace Visible: %s\nRoll: %s (%.0f%%)\nStart Orientation: %s\nTarget Orientation: %s"%[mover.orientation.key(),FACE_ID,face_world_direction(),view.VIEW_NAMES[view.current],"YES" if face_is_visible() else "NO","IN_PROGRESS" if mover.moving else "IDLE",mover.fraction*100,mover.orientation.as_basis(),target_basis()]
