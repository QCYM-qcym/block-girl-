extends SceneTree
const Graph=preload("res://prototype/perspective/connectivity.gd")
const View=preload("res://prototype/perspective/perspective_controller.gd")
const Movement=preload("res://prototype/perspective/grid_movement.gd")
const InputAdapter=preload("res://game/player/grid_input.gd")
const Legacy=preload("res://game/player/sprite_presentation.gd")
var graph=Graph.new()
var view=View.new()
var mover=Movement.new(graph,view)
var sprite=Legacy.new()
var rows: Array=[]
var evidence:="res://tests/gameplay/evidence/cube_visual_audit_02"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(800,600)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.add_child(sprite); sprite.position=Vector2(400,360); sprite.scale=Vector2.ONE*8
	sprite.bind(mover,view)
	var controls=InputAdapter.new(); controls.bind(mover,view); root.add_child(controls)
	var title:=Label.new(); title.text="BEFORE FIX / actual P01 presenter / W x 4"; title.position=Vector2(25,25); title.add_theme_font_size_override("font_size",22); root.add_child(title)
	graph.recalculate(view,0)
	for w in 2:
		mover.reset(); mover.world=w
		for step in 5:
			sprite.refresh()
			await RenderingServer.frame_post_draw
			var tex: Texture2D=sprite.body.sprite_frames.get_frame_texture(sprite.body.animation,sprite.body.frame)
			rows.append({"world":w,"step":step,"cell":str(mover.cell),"orientation":mover.orientation.key(),"face_world":str(mover.orientation.face_direction()),"animation":sprite.body.animation,"frame":sprite.body.frame,"texture_hash":tex.get_image().get_data().hex_encode().sha256_text()})
			root.get_texture().get_image().save_png(evidence.path_join("world_%s_north_%s.png"%[w,step]))
			if step<4:
				var e:=InputEventKey.new(); e.keycode=KEY_W; e.pressed=true; Input.parse_input_event(e)
				await process_frame
				e=InputEventKey.new(); e.keycode=KEY_W; e.pressed=false; Input.parse_input_event(e)
				await process_frame
				while mover.moving:
					mover.tick(1.0/60); sprite.refresh(); await process_frame
	var repeats:=0
	for i in [1,2,3,6,7,8]:
		if rows[i].texture_hash==rows[0 if i<5 else 5].texture_hash: repeats+=1
	var f:=FileAccess.open(evidence.path_join("audit.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows":rows,"wrong_repeated_idle_states":repeats,"display":DisplayServer.get_name()},"\t")); f.close()
	print("AUDIT: changed logical pose with same idle = ",repeats,"/6")
	if repeats>0: printerr("FAIL: production Sprite presenter resets visible face after every roll")
	sprite.queue_free(); controls.queue_free(); title.queue_free(); await process_frame
	quit(1 if repeats>0 else 0)
