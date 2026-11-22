extends GameArea
## Dawnmere's square: the arrival cutscene, Pip's humming, the north gate,
## and the light changing from sunset to dusk to night as the story advances.

const STAGES := {
	"sunset": {"ambient": Color(1.0, 0.9, 0.78), "rays": Color(1.0, 0.72, 0.47), "ray_alpha": 0.2,
		"mist": 0.26, "lights": 0.8, "fireflies": false},
	"dusk": {"ambient": Color(0.68, 0.6, 0.78), "rays": Color(0.88, 0.62, 0.92), "ray_alpha": 0.08,
		"mist": 0.36, "lights": 1.05, "fireflies": true},
	"night": {"ambient": Color(0.38, 0.42, 0.62), "rays": Color(0.62, 0.74, 1.0), "ray_alpha": 0.07,
		"mist": 0.5, "lights": 1.3, "fireflies": true},
}
const INTRO_STAND := Vector2(404, 358)
## The area title follows the light (QA-09: it said "at sundown" at night).
const SUBTITLES := {"sunset": "Village square, at sundown", "dusk": "Village square, at dusk",
	"night": "Village square, after dark"}

var _note_tex: Texture2D = preload("res://assets/sprites/fx/note.png")


func _area_ready() -> void:
	_apply_stage(false)
	_update_gate()
	GameState.flag_changed.connect(_on_flag_changed)
	if not GameState.has_flag("met_pip"):
		_run_intro()


func area_events() -> Dictionary:
	return {
		"pip_face_rowan": func() -> void: npc("Pip").face_toward(get_player().global_position),
		"pip_face_tower": func() -> void: npc("Pip").set_facing("up"),
		"pip_hum": _pip_hum,
		"gate_open": _gate_open,
	}


func area_subtitle() -> String:
	return SUBTITLES[stage()]


func stage() -> String:
	if GameState.has_flag("read_bellkeeper_ledger"):
		return "night"
	if GameState.has_flag("has_tuning_pin"):
		return "dusk"
	return "sunset"


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag in ["has_tuning_pin", "read_bellkeeper_ledger"]:
		_apply_stage(true)


func _apply_stage(animated: bool) -> void:
	var s: Dictionary = STAGES[stage()]
	set_ambient(s["ambient"], 3.0 if animated else 0.0)
	for ray in $Effects.get_children():
		if ray.name.begins_with("SunRay"):
			ray.modulate = Color(s["rays"], ray.modulate.a)
			ray.set("base_alpha", s["ray_alpha"])
	var mist := get_node_or_null("Mist")
	if mist:
		mist.set("density", s["mist"])
	($Effects/Fireflies as CPUParticles2D).emitting = s["fireflies"]
	for light in find_children("Light", "PointLight2D", true, false):
		if light.has_method("set_base_energy"):
			light.call("set_base_energy", 0.95 * float(s["lights"]))
	for glow in $Lights.get_children():
		if glow.name.begins_with("WindowGlow") and glow.has_method("set_base_energy"):
			glow.call("set_base_energy", 0.5 * float(s["lights"]))


func _update_gate() -> void:
	var gate := $Objects/Gate
	var open := GameState.has_flag("gate_unlocked")
	(gate.get_node("Sprite") as Sprite2D).frame = 1 if open else 0
	(gate.get_node("Shape") as CollisionShape2D).set_deferred("disabled", open)


func _gate_open() -> Signal:
	AudioManager.play_sfx("gate", -2.0)
	camera().shake(2.0, 0.5)
	var gate := $Objects/Gate
	(gate.get_node("Sprite") as Sprite2D).frame = 1
	(gate.get_node("Shape") as CollisionShape2D).set_deferred("disabled", true)
	return get_tree().create_timer(0.9).timeout


## Pip hums: floating notes and a few bars of the old tune.
func _pip_hum(slow: float = 0.0) -> Signal:
	var pip := npc("Pip")
	AudioManager.play_sfx("hum_slow" if slow > 0.0 else "hum", -3.0)
	var duration := 4.2 if slow > 0.0 else 2.8
	for i in (7 if slow > 0.0 else 4):
		var note := Sprite2D.new()
		note.texture = _note_tex
		note.modulate = Color(1.0, 0.92, 0.6, 0.0)
		note.position = pip.position + Vector2(randf_range(-4, 4), -26)
		note.z_index = 8
		$Effects.add_child(note)
		var t := note.create_tween()
		t.tween_interval(i * 0.45)
		t.tween_property(note, "modulate:a", 1.0, 0.2)
		t.parallel().tween_property(note, "position", note.position + Vector2(randf_range(-10, 10), -18), 1.4)
		t.tween_property(note, "modulate:a", 0.0, 0.4)
		t.tween_callback(note.queue_free)
	return get_tree().create_timer(duration).timeout


func _run_intro() -> void:
	var player := get_player()
	var cam := player.camera
	GameState.lock_input("cutscene")
	await get_tree().create_timer(1.2).timeout
	# a slow look at the silent tower beyond the trees, then down to Pip
	await cam.pan_to(Vector2(400, 0), 2.6)
	await get_tree().create_timer(1.4).timeout
	await cam.pan_to(npc("Pip").global_position + Vector2(0, -16), 1.8)
	await get_tree().create_timer(0.8).timeout
	await cam.pan_reset(1.4)
	await player.walk_to(INTRO_STAND, 0.8)
	player.face("up")
	await get_tree().create_timer(0.3).timeout
	GameState.unlock_input("cutscene")
	DialogueManager.start("pip_intro", npc("Pip"))
