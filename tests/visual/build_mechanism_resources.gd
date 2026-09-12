extends SceneTree
const ROOT = "res://production/mechanisms/"
func _initialize() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"mechanism_manifest.json"))
	for m in manifest.mechanisms:
		var frames = SpriteFrames.new()
		frames.remove_animation("default")
		var texture = load(ROOT+m.texture)
		for name in m.states:
			var config = m.states[name]
			frames.add_animation(name)
			frames.set_animation_speed(name,config.fps)
			frames.set_animation_loop(name,config.loop)
			for index in config.frames:
				var atlas = AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(index*64,0,64,96)
				atlas.filter_clip = true
				frames.add_frame(name,atlas)
		var frame_path = ROOT+m.kind+"/"+m.kind+"_"+m.world+"_frames.tres"
		ResourceSaver.save(frames,frame_path)
		var node = Node2D.new()
		node.name = m.logical_id
		node.set_script(load(ROOT+m.kind+"/"+m.kind+".gd"))
		node.set("kind",m.kind)
		node.set("world",0 if m.world == "surface" else 1)
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var visual = AnimatedSprite2D.new()
		visual.name = "Visual"
		visual.sprite_frames = frames
		visual.animation = m.states.keys()[0]
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.add_child(visual)
		visual.owner = node
		if m.kind == "door":
			var piers = StaticBody2D.new()
			piers.name = "Piers"
			piers.collision_layer = 1
			piers.collision_mask = 0
			node.add_child(piers)
			piers.owner = node
			polygon(piers,node,rect(-8,-2,-6,2),"Left")
			polygon(piers,node,rect(6,-2,8,2),"Right")
			var shutter = StaticBody2D.new()
			shutter.name = "Shutter"
			shutter.collision_layer = 1
			shutter.collision_mask = 0
			node.add_child(shutter)
			shutter.owner = node
			polygon(shutter,node,rect(-6,-1,6,1))
		else:
			var area = Area2D.new()
			area.name = "Trigger"
			area.collision_layer = 0
			area.collision_mask = 4
			node.add_child(area)
			area.owner = node
			var points = rect(-8,-8,8,8) if m.kind != "rotator" else rect(-8,-4,8,4)
			polygon(area,node,points)
			if m.kind in ["moving_platform","rotator"]:
				var body = AnimatableBody2D.new()
				body.name = "Support"
				body.collision_layer = 2
				body.collision_mask = 0
				body.sync_to_physics = false
				node.add_child(body)
				body.owner = node
				polygon(body,node,points)
		var packed = PackedScene.new()
		packed.pack(node)
		ResourceSaver.save(packed,ROOT+m.scene)
		node.free()
	print("BUILT 10 reusable scenes and SpriteFrames")
	quit()
func rect(x0: float,z0: float,x1: float,z1: float) -> PackedVector2Array:
	var p = PackedVector2Array()
	for v in [Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z1)]: p.append(Vector2(v.x-v.y,(v.x+v.y)/2))
	return p
func polygon(parent: Node,owner_node: Node,points: PackedVector2Array,label: String = "Shape") -> void:
	var shape = CollisionPolygon2D.new()
	shape.name = label
	shape.polygon = points
	parent.add_child(shape)
	shape.owner = owner_node
