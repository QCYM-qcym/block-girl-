extends SceneTree
## Passive evidence recorder: no injected inputs and no gameplay state writes.
var game
var previous:=""
var traces: Array=[]
const EVIDENCE="res://tests/gameplay/evidence/p01_polish/manual"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	game=load("res://game/levels/mutsumi/p01_another_world.tscn").instantiate(); root.add_child(game)
	var timer:=Timer.new(); timer.wait_time=0.2; game.add_child(timer); timer.timeout.connect(record); timer.start()
func record() -> void:
	var state: Dictionary={"cell":str(game.mover.cell),"world":game.mover.world,"view":game.view.current,"phase":game.mover.phase,"moves":game.mover.moves,"pose":game.mover.orientation.key(),"link":game.graph.link.active,"plate":game.graph.plate_pressed,"door":game.graph.door_open,"complete":game.graph.complete,"completion_elapsed":game.completion.elapsed,"muted":AudioServer.is_bus_mute(0),"fx":game.polish.feedback.enabled,"debug_visible":game.debug.visible,"hint":game.hints.text}
	var serialized:=JSON.stringify(state)
	if serialized==previous: return
	previous=serialized
	state["time_msec"]=Time.get_ticks_msec(); traces.append(state)
	FileAccess.open(EVIDENCE.path_join("current.json"),FileAccess.WRITE).store_string(JSON.stringify(state,"\t"))
	FileAccess.open(EVIDENCE.path_join("trace.json"),FileAccess.WRITE).store_string(JSON.stringify(traces,"\t"))
	if game.mover.phase in ["idle","complete"]:
		root.get_texture().get_image().save_png(EVIDENCE.path_join("state_%03d.png"%traces.size()))
