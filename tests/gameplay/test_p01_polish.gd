extends "res://tests/gameplay/test_p01_runtime.gd"
const AudioCleanup = preload("res://tests/gameplay/helpers/polish_audio_cleanup.gd")
var cue_log: Array[String]=[]
var capture: AudioEffectCapture
var meter: Timer
var audio_peak:=0.0
var audio_energy:=0.0
var audio_samples:=0
var max_voices:=0
var recorded:=PackedVector2Array()
func _initialize() -> void:
	evidence="res://tests/gameplay/evidence/p01_polish/runtime_01"
	if not ResourceLoader.exists("res://game/polish/p01_polish.gd"):
		printerr("FAIL: P01 polish presentation missing"); quit(1); return
	call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	game=load("res://game/levels/mutsumi/p01_another_world.tscn").instantiate(); root.add_child(game)
	game.polish.audio.cue_played.connect(record_cue)
	capture=AudioEffectCapture.new(); capture.buffer_length=0.5
	AudioServer.add_bus_effect(0,capture)
	meter=Timer.new(); meter.wait_time=0.05; meter.timeout.connect(sample_audio); game.add_child(meter); meter.start()
	await delay(0.5)
	check(AudioServer.get_bus_index("SFX")>=0 and AudioServer.get_bus_index("Ambience")>=0,"three audio buses")
	check(not game.debug.visible and game.hint_label.text=="W A S D","F3 hidden and only movement tutorial")
	check(game.polish.audio.players.size()==12,"fixed twelve cue voices")
	await shot("00_start")
	# Input locks remain owned by the existing phase and View controller.
	await key(KEY_SPACE,true); await key(KEY_SPACE,false); await delay(0.06)
	var pose: String=game.mover.orientation.key()
	await key(KEY_W,true); await key(KEY_W,false); await key(KEY_E,true); await key(KEY_E,false)
	check(game.mover.phase=="shift" and game.mover.cell==Vector2i(0,5) and not game.view.busy,"Shift locks Move/Rotate")
	check(game.polish.feedback.dissolve_amount>0,"actual local dissolve during Shift")
	await shot("01_shift_out")
	await delay(0.23)
	check(game.mover.world==1 and game.mover.orientation.key()==pose,"Shift commit preserves pose")
	await delay(0.2); check(game.polish.feedback.dissolve_amount==0,"Shift effect settles within 0.4 seconds plus frame")
	await tap(KEY_R)
	await key(KEY_E,true); await key(KEY_E,false); await delay(0.08)
	await key(KEY_W,true); await key(KEY_W,false); await key(KEY_SPACE,true); await key(KEY_SPACE,false)
	check(game.view.busy and game.mover.cell==Vector2i(0,5) and game.mover.world==0,"Rotate locks Move/Shift")
	await tap(KEY_R)
	var end_states: Array=[]
	var door_stream: AudioStream=game.polish.audio.players.door_open.stream
	for mode in ["keyboard","mouse","muted","no_fx_no_audio","missing_stream"]:
		await tap(KEY_R)
		AudioServer.set_bus_mute(0,mode=="muted")
		game.polish.audio.enabled=mode!="no_fx_no_audio"
		game.polish.audio.players.door_open.stream=null if mode=="missing_stream" else door_stream
		game.polish.set_fx_enabled(mode!="no_fx_no_audio")
		await key(KEY_W,true); await delay(0.8); await key(KEY_W,false); await delay(0.4)
		check(game.mover.cell==Vector2i(0,2) and game.hints.moved,"hold reaches first gap "+mode)
		check(game.hint_label.text=="Space","contextual Space "+mode)
		await tap(KEY_SPACE); await tap(KEY_W,2); await tap(KEY_D,3)
		check(game.hints.rotation_hint_seen and game.hint_label.text.contains("Q / E"),"contextual rotation "+mode)
		if mode=="mouse":
			await drag(Vector2(500,450),Vector2(530,450)); check(game.view.current==0,"short drag rebounds")
			await drag(Vector2(500,450),Vector2(670,450))
		else: await tap(KEY_E)
		check(game.graph.link.active and game.hints.rotated,"Link and tutorial commit "+mode)
		await shot(mode+"_link")
		await tap(KEY_W); await tap(KEY_SPACE); await tap(KEY_W,2)
		check(game.graph.door_open and game.board.plate.state=="pressed","Plate opens Door independent of audio "+mode)
		await shot(mode+"_plate")
		await tap(KEY_W,2)
		check(game.graph.complete and game.mover.phase=="complete","Exit locks Player "+mode)
		await key(KEY_S,true); await key(KEY_S,false); await key(KEY_SPACE,true); await key(KEY_SPACE,false)
		await key(KEY_Q,true); await key(KEY_Q,false)
		check(game.mover.cell==Vector2i(13,0) and game.view.current==1 and game.mover.world==0,"Complete locks all gameplay "+mode)
		await delay(2.0)
		check(game.completion.visible and game.completion.elapsed>=1.8,"1.8 second completion presentation "+mode)
		if mode=="muted": check(AudioServer.is_bus_mute(0),"Master mute maintained through full solve")
		if mode=="no_fx_no_audio": check(game.polish.feedback.dissolve_amount==0,"FX disabled never changes logic")
		await shot(mode+"_complete")
		end_states.append([game.mover.cell,game.mover.orientation.key(),game.mover.world,game.view.current,game.mover.moves])
	for state in end_states: check(state==end_states[0],"sound/FX do not change solved state")
	game.polish.audio.players.door_open.stream=door_stream
	AudioServer.set_bus_mute(0,false); game.polish.audio.enabled=true; game.polish.set_fx_enabled(true)
	await tap(KEY_R)
	check(not game.graph.complete and not game.completion.visible and game.completion.elapsed==0,"Reset clears completion presentation")
	check(not game.hints.moved and not game.hints.shifted and not game.hints.rotated,"Reset clears local tutorial flags")
	check(game.polish.feedback.dissolve_amount==0,"Reset clears Shader state")
	for cue in ["roll","land","shift_inner","shift_surface","rotate","link_on","link_off","plate","door_open","door_close","exit_ready","complete"]:
		check(cue in cue_log,"actual cue played: "+cue)
	check(max_voices<=12,"bounded SFX polyphony")
	check(audio_samples>0 and audio_peak>0.001,"AudioServer produced nonzero mixed PCM")
	check(audio_peak<0.95,"mixed PCM has headroom")
	sample_audio(); save_audio()
	print("P01 POLISH: ",checks," checks; failures=",failures,"; audio_peak=",audio_peak,"; voices=",max_voices)
	FileAccess.open(evidence.path_join("polish_report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"audio_peak":audio_peak,"audio_rms":sqrt(audio_energy/maxi(1,audio_samples)),"audio_samples":audio_samples,"max_sfx_voices":max_voices,"cues":cue_log,"end_states":end_states,"checkpoints":checkpoints,"first_user":"TUTORIAL_FIRST_USER_VALIDATION_REQUIRED"},"\t"))
	# Functional checks and their evidence above remain separate from cleanup.
	door_stream=null
	begin_audio_teardown()
func begin_audio_teardown() -> void:
	game.process_mode=Node.PROCESS_MODE_DISABLED
	meter.stop(); meter.timeout.disconnect(sample_audio)
	game.polish.audio.cue_played.disconnect(record_cue)
	var targets: Array[Dictionary]=AudioCleanup.capture_audio(game.polish.audio)
	AudioCleanup.watch(capture,"test Master capture effect",targets)
	var capture_removed:=false
	for index in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0,index)==capture:
			AudioServer.remove_bus_effect(0,index); capture_removed=true; break
	capture.clear_buffer(); capture=null
	cue_log.clear(); recorded.clear(); meter=null
	var scene_id: int=game.get_instance_id()
	game.queue_free(); game=null
	# Let run() and this synchronous scope return before observing resources:
	# suspended GDScript frames can otherwise retain temporary capture refs.
	finish_audio_teardown.call_deferred(targets,scene_id,capture_removed)
func finish_audio_teardown(targets: Array[Dictionary],scene_id: int,capture_removed: bool) -> void:
	var cleanup: Dictionary=await AudioCleanup.wait_for_release(self,targets)
	cleanup["scene_released"]=not is_instance_id_valid(scene_id)
	cleanup["capture_bus_removed"]=capture_removed
	if not cleanup.scene_released:
		cleanup.ok=false; cleanup.exit_code=2; cleanup.failure="SCENE_CLEANUP_INCOMPLETE"
	if not capture_removed:
		cleanup.ok=false; cleanup.exit_code=2; cleanup.failure="CAPTURE_EFFECT_NOT_REMOVED"
	FileAccess.open(evidence.path_join("polish_cleanup.json"),FileAccess.WRITE).store_string(JSON.stringify(cleanup,"\t"))
	print("P01 AUDIO CLEANUP: ok=",cleanup.ok,"; watched=",cleanup.watched_count,"; frames=",cleanup.frames,"; elapsed_us=",cleanup.elapsed_us)
	if not cleanup.ok: printerr("FAIL: ",cleanup.failure,"; pending=",cleanup.pending)
	quit(1 if not failures.is_empty() else int(cleanup.exit_code))
func record_cue(cue: String) -> void:
	cue_log.append(cue)
func sample_audio() -> void:
	if not is_instance_valid(game): return
	max_voices=maxi(max_voices,game.polish.audio.active_sfx_count())
	var frames:=capture.get_buffer(capture.get_frames_available())
	for s in frames:
		audio_peak=maxf(audio_peak,maxf(absf(s.x),absf(s.y)))
		audio_energy+=s.length_squared(); audio_samples+=2
	if recorded.size()<AudioServer.get_mix_rate()*18: recorded.append_array(frames)
func save_audio() -> void:
	var bytes:=PackedByteArray(); bytes.resize(recorded.size()*4)
	for i in recorded.size():
		bytes.encode_s16(i*4,clampi(roundi(recorded[i].x*32767),-32768,32767))
		bytes.encode_s16(i*4+2,clampi(roundi(recorded[i].y*32767),-32768,32767))
	var wav:=AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.stereo=true
	wav.mix_rate=int(AudioServer.get_mix_rate()); wav.data=bytes; wav.save_to_wav(evidence.path_join("actual_mix.wav"))
