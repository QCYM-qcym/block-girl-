extends Node
## P-01 local voices only. Missing audio never changes gameplay.
signal cue_played(cue: String)
const GAINS={"PLAYER":-12.0,"MECHANISM":-10.0,"WORLD":-12.0,"UI":-8.0,"AMBIENCE":-10.0}
var players: Dictionary={}
var ambience: Array[AudioStreamPlayer]=[]
var enabled:=true
var blend:=0.0
var duck:=0.0
func _ready() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://production/audio/p01/manifest.json"))
	for cue in data:
		var entry: Dictionary=data[cue]
		var player:=AudioStreamPlayer.new()
		player.max_polyphony=1
		var path: String=entry.path
		if not path.begins_with("res://"): path="res://"+path
		if ResourceLoader.exists(path): player.stream=load(path)
		player.volume_db=GAINS.get(entry.category,-12.0)
		if cue in ["link_on","link_off"]: player.volume_db-=8.0
		player.bus="Ambience" if entry.category=="AMBIENCE" else "SFX"
		add_child(player)
		if entry.category=="AMBIENCE":
			player.set_meta("inner",cue=="amb_inner")
			if player.stream is AudioStreamWAV:
				player.stream=player.stream.duplicate()
				player.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
				player.stream.loop_begin=0
				player.stream.loop_end=int(player.stream.get_length()*player.stream.mix_rate)
			ambience.append(player)
		else: players[cue]=player
	# Manifest uses explicit surface/inner order, independent of dictionary order.
	for player in ambience:
		player.volume_db=-80
		if player.stream: player.play()
func play(cue: String) -> void:
	if not enabled or not players.has(cue): return
	var player: AudioStreamPlayer=players[cue]
	if player.stream==null: return
	player.play()
	cue_played.emit(cue)
func tick(delta: float,world: int,complete: bool) -> void:
	blend=move_toward(blend,float(world),delta/0.4)
	duck=move_toward(duck,1.0 if complete else 0.0,delta/0.6)
	for player in ambience:
		var amount:=blend if bool(player.get_meta("inner")) else 1.0-blend
		player.volume_db=linear_to_db(maxf(0.0001,amount)) + GAINS.AMBIENCE-duck*14 if enabled else -80
	if not enabled:
		for player in players.values(): player.stop()
func reset(world: int) -> void:
	blend=float(world); duck=0
	for player in players.values(): player.stop()
func active_sfx_count() -> int:
	var count:=0
	for player in players.values():
		if player.playing: count+=1
	return count
