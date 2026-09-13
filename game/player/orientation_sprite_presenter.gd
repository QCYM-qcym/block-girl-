extends "res://game/player/cube_visual_presenter.gd"
## Formal baked RGBA skins. Read-only lookup; authoritative pose stays in mover.
const ATLAS=[preload("res://production/sprites/v2_orientation/mutsumi/orientation_atlas.png"),preload("res://production/sprites/v2_orientation/mortis/orientation_atlas.png")]
static var DATA: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://production/sprites/v2_orientation/shared/orientation_sprite_manifest.json"))
static var POSE_INDEX: Dictionary=make_pose_index()
var frame_id:=0
var sample_index:=0
static func make_pose_index() -> Dictionary:
	var result: Dictionary={}
	for i in DATA.poses.size(): result[DATA.poses[i].key]=i
	return result
func refresh() -> void:
	if mover==null: return
	var pose: int=POSE_INDEX[mover.orientation.key()]
	var canonical: int=DATA.views[view.current][pose]
	sample_index=0
	frame_id=int(DATA.stable[canonical])
	if mover.moving:
		var screen_direction:=-1
		for d in 4:
			if view.world_direction(d)==mover.direction: screen_direction=d; break
		assert(screen_direction>=0)
		sample_index=clampi(roundi(mover.fraction*4),0,4)
		frame_id=int(DATA.roll[canonical][screen_direction][sample_index])
	elif view.busy:
		sample_index=clampi(roundi(view.progress*8),0,8)
		frame_id=int(DATA.camera[canonical][0 if view.rotation_step<0 else 1][sample_index])
	face_visible=face_is_visible()
	queue_redraw()
func frame_region() -> Rect2i:
	var r: Array=DATA.regions[frame_id]
	return Rect2i(int(r[0]),int(r[1]),24,24)
func world_basis() -> Basis:
	var b: Basis=mover.orientation.as_basis()
	if mover.moving:
		b=Basis(Vector3(mover.direction.y,0,-mover.direction.x),roundi(mover.fraction*4)*PI/8)*b
	return b
func face_is_visible() -> bool:
	return int(DATA.face_pixels[frame_id])>0
func _draw() -> void:
	if mover==null: return
	draw_texture_rect_region(ATLAS[mover.world],Rect2(-12,-21,24,24),frame_region())
func debug_text() -> String:
	return super.debug_text()+"\nFormal Sprite: frame %s / sample %s / 24×24"%[frame_id,sample_index]
