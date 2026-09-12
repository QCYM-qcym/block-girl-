extends Label
func _ready() -> void:
	position=Vector2(24,124)
	add_theme_font_size_override("font_size",14)
	add_theme_color_override("font_color",Color("a9babb"))
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func refresh(mover,view,graph,scale_factor: int,face_visible: bool,board_origin: Vector2) -> void:
	var link=graph.link
	var a: Vector2=view.displayed(link.a.position(),link.a.elevation,link.a.platform)
	var b: Vector2=view.displayed(link.b.position(),link.b.elevation,link.b.platform)
	var direction_match: bool=absi(link.entry_direction.x)+absi(link.entry_direction.y)==1 and link.entry_direction==link.exit_direction and link.a.direction==link.entry_direction and link.b.direction==-link.exit_direction
	var edge: bool=graph.neighbor(link.a.node,link.entry_direction,view)==link.b.node
	var at_anchor: bool=mover.cell in [link.a.node,link.b.node]
	var desired: Vector2i=link.entry_direction if mover.cell==link.a.node else -link.exit_direction
	var target: Vector2i=graph.neighbor(mover.cell,desired,view) if at_anchor else mover.cell
	var can_traverse: bool=at_anchor and edge and mover.phase=="idle" and not view.busy and target!=mover.cell
	var blocker: String="ready" if can_traverse else "not at anchor"
	if view.busy: blocker="rotation lock"
	elif mover.phase!="idle": blocker="player "+mover.phase
	elif at_anchor and not edge: blocker=link.reason
	var neighbors: Array[String]=[]
	for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var n: Vector2i=graph.neighbor(mover.cell,d,view)
		if n!=mover.cell: neighbors.append(str(n))
	var worlds: Array[String]=[]
	for w in link.allowed_world_states: worlds.append("SURFACE" if w==0 else "INNER")
	var views: Array[String]=[]
	for v in link.allowed_perspectives: views.append(view.VIEW_NAMES[v])
	text="\n".join([
		"DEBUG · F3 可关闭",
		"World: "+("SURFACE" if mover.world==0 else "INNER"),
		"Perspective: "+view.view_name(view.current),
		"Rotation: %s | Player: %s" % ["ROTATING" if view.busy else "IDLE",mover.phase],
		"Node/Grid: %s | Moves: %d" % [mover.cell,mover.moves],
		"Cube X %s" % mover.orientation.right,
		"Cube Y %s" % mover.orientation.up,
		"Cube Z %s" % mover.orientation.forward,
		"Face: %s | visible: %s" % [mover.orientation.face_direction(),face_visible],
		"Link: %s | Enabled: %s" % ["ACTIVE" if link.active else "INACTIVE",link.enabled],
		"Reason: "+link.reason+(" (committed)" if view.busy else ""),
		"Anchor A: %s @%s" % [link.a.id,link.a.node],
		"A screen: %s" % (a*scale_factor+board_origin).round(),
		"Anchor B: %s @%s" % [link.b.id,link.b.node],
		"B screen: %s" % (b*scale_factor+board_origin).round(),
		"Projection Distance: %.2f native px" % a.distance_to(b),
		"Tolerance: %.1f native px (%d×)" % [link.projection_tolerance,scale_factor],
		"Allowed World: "+" / ".join(worlds),
		"Allowed View: "+" / ".join(views),
		"Direction Match: "+("YES" if direction_match else "NO"),
		"Elevation Match: %s (%d / %d)" % ["YES" if link.a.elevation==link.b.elevation else "NO",link.a.elevation,link.b.elevation],
		"Graph Edge: "+("PRESENT" if edge else "ABSENT"),
		"Player Can Traverse: "+("YES" if can_traverse else "NO"),
		"Traversal: %s → %s" % [blocker,target],
		"Neighbors: "+" ".join(neighbors),
		"Revision: %d | Logical gap: 5 cells" % graph.revision
	])
