extends SceneTree
const Orientation=preload("res://prototype/perspective/cube_orientation.gd")
const DIRS=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
func _initialize() -> void:
	var poses: Array=[]
	var indices: Dictionary={}
	var queue: Array=[Orientation.new()]
	while not queue.is_empty():
		var o=queue.pop_front()
		if indices.has(o.key()): continue
		indices[o.key()]=poses.size(); poses.append(o)
		for d in DIRS:
			var n=o.copy(); n.roll(d); queue.append(n)
	var data: Array=[]
	var views: Array=[]
	for v in 4:
		var row: Array=[]
		for o in poses:
			var b: Basis=Basis(Vector3.UP,v*PI/2)*o.as_basis()
			var found:=-1
			for i in poses.size():
				if poses[i].as_basis().is_equal_approx(b): found=i; break
			assert(found>=0); row.append(found)
		views.append(row)
	for o in poses:
		var transitions: Array=[]
		for d in DIRS:
			var n=o.copy(); n.roll(d); transitions.append(indices[n.key()])
		var columns: Array=[]
		for axis in [o.right,o.up,o.forward]: columns.append([axis.x,axis.y,axis.z])
		data.append({"key":o.key(),"columns":columns,"next":transitions})
	var out:="res://tests/gameplay/evidence/sprite_rework/orientations.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify({"poses":data,"views":views},"\t"))
	print("EXPORTED existing CubeOrientation: ",poses.size()); quit(0)
