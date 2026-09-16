extends Node3D
## Test environment only. Production Replayer owns the real Presenter.
var caption: Label
var evidence_text: Label

func _ready() -> void:
	get_window().size = Vector2i(1200,760)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("121b2c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c9dbf2")
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0,0.1,11)
	camera.fov = 52
	camera.current = true
	add_child(camera)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var panel := VBoxContainer.new()
	panel.position = Vector2(30,25)
	panel.size = Vector2(1140,160)
	panel.add_theme_constant_override("separation",14)
	overlay.add_child(panel)
	var title := Label.new()
	title.text = "BLOCK GIRL / SOLUTION TRACE RUNTIME PARITY"
	title.add_theme_font_size_override("font_size",25)
	panel.add_child(title)
	var source := Label.new()
	source.text = "TEST TRACE → REAL SESSION → REAL KERNEL / SAFETY → REAL PRESENTER"
	source.add_theme_color_override("font_color",Color("efbc75"))
	panel.add_child(source)
	caption = Label.new()
	caption.text = "Semantic actions; natural Tween.finished completion; no simulated input."
	panel.add_child(caption)
	evidence_text = Label.new()
	evidence_text.position = Vector2(30,510)
	evidence_text.size = Vector2(1140,220)
	evidence_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_text.add_theme_font_size_override("font_size",14)
	overlay.add_child(evidence_text)

func show_evidence(label: String, value: Dictionary) -> void:
	caption.text = label
	evidence_text.text = JSON.stringify(value,"  ")
