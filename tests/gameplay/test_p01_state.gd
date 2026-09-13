extends SceneTree
var checks:=0
var failures: Array[String]=[]
const Movement=preload("res://prototype/perspective/grid_movement.gd")
const View=preload("res://prototype/perspective/perspective_controller.gd")
var graph
var view=View.new()
var mover
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func _initialize() -> void:
	if not ResourceLoader.exists("res://game/levels/mutsumi/p01_state.gd"):
		printerr("FAIL: P-01 level state missing"); quit(1); return
	graph=load("res://game/levels/mutsumi/p01_state.gd").new()
	mover=Movement.new(graph,view)
	graph.bind(mover)
	graph.reset_level()
	check(mover.cell==Vector2i(0,5) and mover.world==0 and view.current==0 and not graph.door_open and not graph.complete,"initial playable state")
	step(0,3)
	check(mover.cell==Vector2i(0,2),"held straight route reaches first shore")
	for v in 4:
		view.current=v; graph.recalculate(view,0)
		check(graph.neighbor(Vector2i(0,2),Vector2i.UP,view)==Vector2i(0,2),"Surface gap cannot be solved by view %s"%v)
	view.reset(); graph.recalculate(view,0)
	mover.shift(); mover.tick(0.26)
	step(0)
	check(mover.cell==Vector2i(0,1),"Inner bridge exists")
	var pose=mover.orientation.key()
	check(not mover.shift() and mover.world==1 and mover.orientation.key()==pose,"cannot shift onto absent Surface bridge")
	step(0); step(1,3)
	check(mover.cell==Vector2i(3,0),"middle anchor reached by ordinary moves")
	for w in 2:
		for v in 4:
			view.current=v; graph.recalculate(view,w)
			check(graph.link.active==(w==1 and v==1),"link policy %s/%s"%[w,v])
	view.current=1; graph.recalculate(view,1)
	mover.press(1,0); mover.release(1); mover.tick(0.16)
	check(mover.crossing and mover.cell==Vector2i(3,0),"connection delays grid commit")
	check(not mover.shift(),"crossing rejects shift")
	mover.tick(0.17)
	check(mover.cell==Vector2i(9,0),"crossing arrives at permanent node")
	view.current=0; graph.recalculate(view,1)
	check(graph.can_stand(mover.cell,1) and graph.neighbor(mover.cell,Vector2i.LEFT,view)==mover.cell,"disconnect removes edge, preserves support")
	view.current=1; graph.recalculate(view,1)
	step(0,2)
	check(not graph.plate_pressed and not graph.door_open,"Inner plate never activates Surface gate")
	step(0); check(mover.cell==Vector2i(11,0),"Inner cannot bypass gate")
	pose=mover.orientation.key()
	mover.shift(); mover.tick(0.26)
	check(mover.cell==Vector2i(11,0) and mover.orientation.key()==pose and view.current==1,"Shift preserves pose, cell and perspective")
	check(graph.plate_pressed and graph.door_open,"Surface momentary plate opens door")
	mover.press(1,0); mover.release(1); mover.tick(0.16)
	check(graph.door_open and graph.plate_pressed and mover.cell==Vector2i(11,0),"gate remains open through partial traversal")
	mover.tick(0.17)
	check(mover.cell==Vector2i(12,0) and not graph.door_open and not graph.plate_pressed,"gate closes only after safe landing beyond edge")
	step(0)
	check(graph.complete and mover.phase=="complete" and mover.cell==Vector2i(13,0),"Exit auto completes")
	step(2); check(mover.cell==Vector2i(13,0) and not mover.shift(),"completion locks gameplay")
	graph.reset_level()
	check(mover.cell==Vector2i(0,5) and mover.world==0 and mover.moves==0 and view.current==0 and not graph.door_open and not graph.complete and not graph.link.active and mover.order.is_empty(),"Reset clears state and caches")
	# Enumerate position/world/view states, using real can_stand and edge policy.
	# Orientation never gates any action; momentary gate is derived from occupancy.
	var pending: Array=[[Vector2i(0,5),0,0]]
	var states: Dictionary={}
	var reverse: Dictionary={}
	var goals: Array=[]
	while not pending.is_empty():
		var state: Array=pending.pop_front()
		var id=str(state)
		if states.has(id): continue
		states[id]=state
		mover.cell=state[0]; mover.world=state[1]; view.current=state[2]; mover.phase="idle"
		graph.complete=false; graph.settle(); graph.recalculate(view,mover.world)
		if graph.complete: goals.append(id)
		var nexts: Array=[]
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var to: Vector2i=graph.neighbor(mover.cell,d,view)
			if to!=mover.cell: nexts.append([to,mover.world,view.current])
		if graph.can_stand(mover.cell,1-mover.world): nexts.append([mover.cell,1-mover.world,view.current])
		for v in [posmod(view.current-1,4),posmod(view.current+1,4)]: nexts.append([mover.cell,mover.world,v])
		for ns in nexts:
			var nid=str(ns)
			if not reverse.has(nid): reverse[nid]=[]
			reverse[nid].append(id)
			if not states.has(nid): pending.append(ns)
	var solvable: Dictionary={}
	while not goals.is_empty():
		var id: String=goals.pop_back()
		if solvable.has(id): continue
		solvable[id]=true
		goals.append_array(reverse.get(id,[]))
	check(solvable.size()==states.size(),"every reachable state has exit route without Reset")
	print("P01 STATE: ",checks," checks, ",states.size()," reachable states, ",solvable.size()," solvable, failures=",failures)
	quit(0 if failures.is_empty() else 1)
func step(screen: int,count: int=1) -> void:
	for i in count:
		mover.press(1,screen); mover.release(1); mover.tick(0.33)
