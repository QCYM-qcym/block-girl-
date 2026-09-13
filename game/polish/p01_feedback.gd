extends Node2D
## Read-only, board-local pixels. All state commits belong to existing gameplay.
const DISSOLVE=preload("res://game/polish/pixel_dissolve.gdshader")
var game
var enabled:=true
var dissolve_amount:=0.0
var reveal_left:=0.0
var link_flash:=0.0
var plate_flash:=0.0
var land_flash:=0.0
var time:=0.0
var player_material:=ShaderMaterial.new()
var tile_material:=ShaderMaterial.new()
func bind(level) -> void:
	game=level
	z_index=2
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	player_material.shader=DISSOLVE; tile_material.shader=DISSOLVE
	game.board.player.material=player_material
	for tile in game.board.tiles.values(): tile.material=tile_material
func tick(delta: float,world_changed: bool) -> void:
	time+=delta
	if world_changed: reveal_left=0.15
	elif reveal_left>0: reveal_left=maxf(0,reveal_left-delta)
	dissolve_amount=0.0
	if enabled:
		if game.mover.phase=="shift": dissolve_amount=minf(0.85,game.mover.elapsed/0.25*0.85)
		elif reveal_left>0: dissolve_amount=reveal_left/0.15*0.85
	player_material.set_shader_parameter("amount",dissolve_amount)
	tile_material.set_shader_parameter("amount",dissolve_amount*0.32)
	link_flash=maxf(0,link_flash-delta); plate_flash=maxf(0,plate_flash-delta); land_flash=maxf(0,land_flash-delta)
	queue_redraw()
func reset() -> void:
	reveal_left=0; link_flash=0; plate_flash=0; land_flash=0; dissolve_amount=0; time=0
	player_material.set_shader_parameter("amount",0.0); tile_material.set_shader_parameter("amount",0.0)
	queue_redraw()
func _draw() -> void:
	if game==null or not enabled: return
	var color:=Color("9bada4") if game.mover.world==0 else Color("828eaf")
	# Sparse atmospheric pixels live outside the walkable silhouette.
	for i in 8:
		var p:=Vector2(-165+i*45,-92-float(i%3)*17+roundf(sin(time*0.35+i)*2))
		draw_rect(Rect2(p,Vector2.ONE),Color(color,0.13))
	if game.view.busy:
		var extent: Rect2=game.board.bounds_for(game.view.current)
		for p in [extent.position+Vector2(-18,-20),extent.end+Vector2(18,12)]:
			draw_line(p.round(),p.round()+Vector2(4,0),Color(color,0.35),1,false)
	var link=game.graph.link
	if link.active or link_flash>0:
		var alpha:=0.18+0.07*sin(time*2) if link.active else link_flash*0.25
		alpha+=link_flash*0.2
		for anchor in [link.a,link.b]:
			var p: Vector2=game.view.displayed(anchor.position(),anchor.elevation,anchor.platform).round()
			draw_line(p+Vector2(-2,-1),p+Vector2(2,1),Color(color,minf(alpha,0.45)),1,false)
	if land_flash>0:
		var p: Vector2=game.board.player.position
		draw_line(p+Vector2(-5,2),p+Vector2(5,2),Color(color,land_flash*1.3),1,false)
	if plate_flash>0:
		var p: Vector2=game.board.plate.position
		draw_line(p+Vector2(-7,2),p+Vector2(7,2),Color(color,plate_flash),1,false)
