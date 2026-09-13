extends SceneTree
var failures: Array[String]=[]
var checks:=0
var evidence:="res://tests/gameplay/evidence/p01_polish/pixels"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	var game=load("res://game/levels/mutsumi/p01_another_world.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	var viewport:=SubViewport.new(); viewport.size=Vector2i(512,512)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop:=ColorRect.new(); backdrop.size=Vector2(512,512); backdrop.color=Color("172327"); viewport.add_child(backdrop)
	var sprite=load("res://game/player/orientation_sprite_presenter.gd").new()
	viewport.add_child(sprite); sprite.bind(game.mover,game.view)
	sprite.position=Vector2(80,100); sprite.material=game.polish.feedback.player_material
	var tile:=Sprite2D.new(); tile.position=Vector2(320,270); tile.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	tile.material=game.polish.feedback.tile_material; viewport.add_child(tile)
	for world in 2:
		game.mover.world=world; sprite.refresh(); tile.texture=game.board.textures[world]
		for factor in range(1,5):
			sprite.scale=Vector2.ONE*factor; tile.scale=Vector2.ONE*factor
			for amount in [0.0,0.5]:
				sprite.material.set_shader_parameter("amount",amount); tile.material.set_shader_parameter("amount",amount)
				await process_frame; await RenderingServer.frame_post_draw
				var rendered:=viewport.get_texture().get_image()
				var source: Image=sprite.ATLAS[world].get_image().get_region(sprite.frame_region())
				verify(rendered,source,Vector2i(sprite.position)-Vector2i(12,21)*factor,factor,amount,"sprite")
				verify(rendered,game.board.ATLAS[world].get_image().get_region(Rect2i(0,0,64,96)),Vector2i(tile.position)-Vector2i(32,48)*factor,factor,amount,"tile")
				rendered.save_png(evidence.path_join("world%s_%sx_amount%s.png"%[world,factor,amount]))
	print("P01 POLISH PIXELS: ",checks," checks; failures=",failures)
	FileAccess.open(evidence.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	game.queue_free(); viewport.queue_free()
	# Let the audio thread release the two loop playbacks before ending this
	# unusually short rendering-only harness.
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
func close_color(a: Color,b: Color) -> bool:
	return absf(a.r-b.r)<0.006 and absf(a.g-b.g)<0.006 and absf(a.b-b.b)<0.006
func verify(rendered: Image,source: Image,origin: Vector2i,factor: int,amount: float,label: String) -> void:
	var wrong:=0; var opaque:=0; var removed:=0
	for y in source.get_height():
		for x in source.get_width():
			var want:=source.get_pixel(x,y)
			if want.a<0.5: want=Color("172327")
			else: opaque+=1
			var first:=rendered.get_pixelv(origin+Vector2i(x,y)*factor)
			if amount==0 and not close_color(first,want): wrong+=1
			elif amount>0 and not close_color(first,want) and not close_color(first,Color("172327")): wrong+=1
			if source.get_pixel(x,y).a>0.5 and close_color(first,Color("172327")): removed+=1
			for dy in factor:
				for dx in factor:
					if not close_color(rendered.get_pixelv(origin+Vector2i(x,y)*factor+Vector2i(dx,dy)),first): wrong+=1
	check(wrong==0,"nearest source colors and uniform %sx blocks, %s amount%s (%s wrong)"%[factor,label,amount,wrong])
	if amount>0: check(removed>0 and removed<opaque,"dissolve removes only a subset of opaque pixels "+label)
