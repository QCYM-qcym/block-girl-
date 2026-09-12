extends Node2D
## Temporary face-aware 2D polygons, not replacement production art or Node3D.
var mover
var view
var face_visible:=false
const NORMALS=[Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
func bind(movement,perspective) -> void:
	mover=movement
	view=perspective
func camera_basis() -> Basis:
	return Basis(Vector3.UP,view.displayed_angle())
func displayed_basis() -> Basis:
	var base: Basis=mover.orientation.as_basis()
	if mover.moving:
		var axis:=Vector3(mover.direction.y,0,-mover.direction.x)
		base=Basis(axis,mover.fraction*PI/2)*base
	return camera_basis()*base
func project_vertex(point: Vector3) -> Vector2:
	return Vector2((point.x-point.z)*16,(point.x+point.z)*8-point.y*20).round()
func _draw() -> void:
	if mover==null: return
	var transform_basis:=displayed_basis()
	var faces: Array=[]
	var camera:=Vector3(1,0.8,1)
	face_visible=false
	for index in 6:
		var normal: Vector3=NORMALS[index]
		var transformed:=transform_basis*normal
		if transformed.dot(camera)<=0.001: continue
		var horizontal:=Vector3.RIGHT if absf(normal.y)>0.5 else Vector3.UP.cross(normal)
		var vertical:=normal.cross(horizontal)
		var vertices: Array[Vector3]=[]
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			vertices.append((normal+horizontal*corner.x+vertical*corner.y)*0.38)
		faces.append({"index":index,"normal":transformed,"points":vertices,"depth":transformed.dot(camera)})
	faces.sort_custom(func(a,b): return a.depth<b.depth)
	var lift:=0.0
	if mover.moving:
		var angle: float=mover.fraction*PI/2
		lift=(sin(angle)+cos(angle)-1)*0.38
	var center:=Vector3(0,0.38+lift,0)
	for face in faces:
		var polygon:=PackedVector2Array()
		for point in face.points: polygon.append(project_vertex(transform_basis*point+center))
		var base:=Color("b6ccbb") if mover.world==0 else Color("a9a1c2")
		var brightness: float=0.70+0.30*maxf(0,face.normal.y)
		draw_colored_polygon(polygon,Color(base.r*brightness,base.g*brightness,base.b*brightness))
		var closed:=polygon.duplicate()
		closed.append(polygon[0])
		draw_polyline(closed,Color("35464c"),1.0,false)
		# Marker exists only on local +Z, and disappears when that face is hidden.
		if face.index==4:
			face_visible=true
			for x in [-0.14,0.14]:
				var dot:=project_vertex(transform_basis*Vector3(x,0.08,0.385)+center)
				draw_rect(Rect2(dot-Vector2.ONE,Vector2(2,2)),Color("283944"))
			var mouth_a:=project_vertex(transform_basis*Vector3(-0.08,-0.12,0.386)+center)
			var mouth_b:=project_vertex(transform_basis*Vector3(0.08,-0.12,0.386)+center)
			draw_line(mouth_a,mouth_b,Color("e5b884"),1.0,false)
