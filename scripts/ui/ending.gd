extends Control
## Plays the chosen ending (keeper / promise / chorus), then the title card,
## the "What Dawnmere remembers" epilogue built from story flags, and credits.

const DATA_PATH := "res://data/endings.json"
const TITLE_SCENE := "res://scenes/main/main_menu.tscn"
## Village window positions in vista_night.png (for lantern glows).
const LANTERNS := [Vector2(62, 210), Vector2(96, 206), Vector2(130, 212), Vector2(168, 204), Vector2(205, 210),
	Vector2(240, 205), Vector2(276, 212), Vector2(312, 207), Vector2(150, 222), Vector2(258, 222)]

var kind := "keeper"
var data: Dictionary = {}
var _t := 0.0
var _mist_speed := 5.0
var _waiting_input := false

signal _pressed

@onready var tint: ColorRect = %Tint
@onready var fx: Node2D = %FX
@onready var memory: TextureRect = %Memory
@onready var shade: ColorRect = %Shade
@onready var narration: Label = %Narration
@onready var narration_back: ColorRect = %NarrationBack
@onready var title_card: Label = %TitleCard
@onready var summary: Control = %Summary
@onready var hint: Label = %Hint


func _ready() -> void:
	get_tree().paused = false
	for reason in GameState.lock_reasons():
		GameState.clear_lock(reason)
	UI.set_gameplay_hud(false)
	kind = str(GameState.get_flag("ending_selected", "keeper"))
	if not kind in ["keeper", "promise", "chorus"]:
		kind = "keeper"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	data = parsed if parsed is Dictionary else {}
	shade.color.a = 1.0
	narration.modulate.a = 0.0
	narration_back.modulate.a = 0.0
	title_card.modulate.a = 0.0
	%ToTitle.pressed.connect(_to_title)
	%ToCredits.pressed.connect(_roll_credits)
	_play()


func _process(delta: float) -> void:
	_t += delta
	%MistA.position.x = -fposmod(_t * _mist_speed, 480.0)
	%MistB.position.x = -fposmod(_t * _mist_speed * 0.6 + 200.0, 480.0)


func _play() -> void:
	var music: String = {"keeper": "ending_keeper", "promise": "ending_promise", "chorus": "ending_chorus"}[kind]
	AudioManager.play_music(music, 2.0)
	AudioManager.play_ambience("village_night", 2.0)
	match kind:
		"keeper":
			await _keeper()
		"promise":
			await _promise()
		"chorus":
			await _chorus()
	await _title()
	_show_summary()


# ------------------------------------------------------------- sequences --
func _keeper() -> void:
	_set_mist(180.0, 0.95)
	await _fade_shade(0.0, 2.0)
	AudioManager.play_sfx("bell_toll", -2.0)
	await _flash_tint(Color(1, 1, 1), 0.7)
	_move_mist(240.0, 0.0, 6.0)  # the mist retreats
	var lines: Array = data["endings"]["keeper"]["lines"]
	await _say(lines[0], 3.0)
	await _say(lines[1], 3.0)
	# a warm memory surfaces... and is gone
	memory.visible = true
	memory.modulate.a = 0.0
	(memory.material as ShaderMaterial).set_shader_parameter("progress", 0.0)
	var t := create_tween()
	t.tween_property(memory, "modulate:a", 1.0, 2.0)
	await t.finished
	await _wait(2.5)
	AudioManager.play_sfx("memory_fade", -4.0)
	var d := create_tween()
	d.tween_method(func(v: float) -> void: (memory.material as ShaderMaterial).set_shader_parameter("progress", v),
		0.0, 1.05, 4.0)
	await _wait(1.5)
	await _say(lines[2], 4.0)
	await d.finished
	memory.visible = false


func _promise() -> void:
	_set_mist(205.0, 0.7)
	await _fade_shade(0.0, 2.0)
	AudioManager.play_sfx("bell_crack", -4.0)
	await _flash_tint(Color(0.4, 0.5, 0.9), 0.6)
	_move_mist(150.0, 1.0, 8.0)  # the mist creeps into the outskirts
	var lines: Array = data["endings"]["promise"]["lines"]
	await _say(lines[0], 3.4)
	# one lantern, then another, until the village is a ring of light
	for i in LANTERNS.size():
		_lantern(LANTERNS[i], Color(1.0, 0.72, 0.38))
		AudioManager.play_sfx("lantern", -14.0, 1.0 + i * 0.03)
		await _wait(0.45)
	await _say(lines[1], 3.2)
	await _say(lines[2], 4.0)


func _chorus() -> void:
	_set_mist(170.0, 0.9)
	await _fade_shade(0.0, 2.0)
	await _flash_tint(Color(1.0, 0.82, 0.45), 0.9)
	_move_mist(260.0, 0.0, 7.0)
	_memory_motes()
	var gold := create_tween()
	gold.tween_property(tint, "color", Color(1.0, 0.75, 0.35, 0.12), 3.0)
	var lines: Array = data["endings"]["chorus"]["lines"]
	await _say(lines[0], 2.6)
	await _say(lines[1], 2.0)
	await _say(lines[2], 3.0)
	for i in LANTERNS.size():
		_lantern(LANTERNS[i], Color(1.0, 0.82, 0.5))
	await _say(lines[3], 4.5)


func _title() -> void:
	narration.modulate.a = 0.0
	create_tween().tween_property(narration_back, "modulate:a", 0.0, 0.8)
	title_card.text = str(data["endings"][kind]["title"])
	var t := create_tween()
	t.tween_property(shade, "color:a", 0.55, 1.5)
	t.parallel().tween_property(title_card, "modulate:a", 1.0, 2.0)
	await t.finished
	await _wait(3.0)
	var o := create_tween()
	o.tween_property(title_card, "modulate:a", 0.0, 1.2)
	await o.finished


func _show_summary() -> void:
	%SummaryTitle.text = "What Dawnmere remembers"
	%SummaryText.text = "\n".join(epilogue_lines(kind, data))
	summary.visible = true
	summary.modulate.a = 0.0
	create_tween().tween_property(summary, "modulate:a", 1.0, 1.0)
	%ToTitle.grab_focus()


## Pure function (also used by tests): epilogue lines for an ending + flags.
static func epilogue_lines(ending: String, d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var used := {}
	for e in d.get("epilogue", []):
		var group := str(e.get("group", ""))
		if used.has(group):
			continue
		if e.has("ending") and str(e["ending"]) != ending:
			continue
		if e.has("if") and not GameState.check(e["if"]):
			continue
		used[group] = true
		out.append("• " + str(e["text"]))
	return out


func _roll_credits() -> void:
	summary.visible = false
	var roll := %CreditsRoll
	var text := %CreditsText as RichTextLabel
	text.text = "[center]" + "\n".join(data.get("credits", [])) + "[/center]"
	roll.visible = true
	text.position.y = 270
	hint.text = "Enter: skip"
	var t := create_tween()
	t.tween_property(text, "position:y", -260.0, 22.0)
	_waiting_input = true
	await _either(t.finished, _pressed)
	_to_title()


func _to_title() -> void:
	_waiting_input = false
	AudioManager.stop_all(1.5)
	SceneManager.goto_scene(TITLE_SCENE, 1.2)


# --------------------------------------------------------------- helpers --
func _say(text: String, hold: float) -> void:
	narration.text = text
	if narration_back.modulate.a < 0.99:
		create_tween().tween_property(narration_back, "modulate:a", 1.0, 0.8)
	var t := create_tween()
	t.tween_property(narration, "modulate:a", 1.0, 1.0)
	t.tween_interval(hold)
	t.tween_property(narration, "modulate:a", 0.0, 0.9)
	await t.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fade_shade(alpha: float, duration: float) -> void:
	var t := create_tween()
	t.tween_property(shade, "color:a", alpha, duration)
	await t.finished


func _flash_tint(color: Color, strength: float) -> void:
	tint.color = Color(color, strength)
	var t := create_tween()
	t.tween_property(tint, "color:a", 0.0, 1.8)
	await t.finished


func _set_mist(y: float, alpha: float) -> void:
	%MistA.position.y = y
	%MistB.position.y = y - 26.0
	%MistA.modulate.a = alpha
	%MistB.modulate.a = alpha


func _move_mist(y: float, alpha: float, duration: float) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(%MistA, "position:y", y, duration).set_trans(Tween.TRANS_SINE)
	t.tween_property(%MistB, "position:y", y - 26.0, duration).set_trans(Tween.TRANS_SINE)
	t.tween_property(%MistA, "modulate:a", alpha, duration)
	t.tween_property(%MistB, "modulate:a", alpha * 0.8, duration)


func _lantern(pos: Vector2, color: Color) -> void:
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/sprites/fx/light_radial.png")
	glow.scale = Vector2(0.2, 0.2)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.position = pos
	glow.modulate = Color(color, 0.0)
	fx.add_child(glow)
	var t := create_tween()
	t.tween_property(glow, "modulate:a", 0.9, 0.8)


func _memory_motes() -> void:
	var p := CPUParticles2D.new()
	p.texture = load("res://assets/sprites/fx/mote.png")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.position = Vector2(392, 88)
	p.amount = 60
	p.lifetime = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	p.direction = Vector2(-1, 0.3)
	p.spread = 70.0
	p.gravity = Vector2(-2, 6)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 30.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(1.0, 0.86, 0.55, 0.9)
	fx.add_child(p)


func _either(a: Signal, b: Signal) -> void:
	var done := [false]
	var finish := func() -> void: done[0] = true
	a.connect(finish, CONNECT_ONE_SHOT)
	b.connect(finish, CONNECT_ONE_SHOT)
	while not done[0]:
		await get_tree().process_frame


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_input and (event.is_action_pressed("ui_accept") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_pressed.emit()
