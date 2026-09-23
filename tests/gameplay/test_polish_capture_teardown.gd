extends "res://tests/gameplay/test_p01_polish.gd"

# Reuse the real host teardown with its real capture effect, without replaying
# the 74 gameplay checks. Returning this coroutine is part of the contract.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence=arg.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	game=load("res://game/levels/mutsumi/p01_another_world.tscn").instantiate()
	root.add_child(game)
	game.polish.audio.cue_played.connect(record_cue)
	capture=AudioEffectCapture.new()
	AudioServer.add_bus_effect(0,capture)
	meter=Timer.new(); meter.wait_time=0.05
	meter.timeout.connect(sample_audio); game.add_child(meter); meter.start()
	await process_frame
	check(AudioServer.get_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)==capture,"real test capture attached")
	begin_audio_teardown()
