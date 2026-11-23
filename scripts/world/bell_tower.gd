extends GameArea
## The bell chamber: the mechanism, Orin's echo, the view of the village and
## the three ending sequences (keeper / promise / chorus).

const ENDING_SCENE := "res://scenes/main/ending.tscn"
## Bell sprite offset in its prop scene; the thirteen marks are drawn by
## tools/art/props.py at x = 37 + sin(a) * 18, y = 30 + |a| * 3, a in [-0.9, 0.9].
const BELL_SPRITE_OFFSET := Vector2(-37, -64)
const MARK_GOLD := Color(1.0, 0.86, 0.5)

var _pulse_t := 0.0
var _glow_base := 0.9
var _vista_layer: CanvasLayer
var _vista_root: Control
var _marks: Array[Sprite2D] = []

@onready var bell: Node2D = $Objects/Bell
@onready var bell_sprite: Sprite2D = $Objects/Bell/Sprite
@onready var bell_glow: PointLight2D = $Lights/BellGlow
@onready var mechanism_sprite: Sprite2D = $Objects/Mechanism/Sprite
@onready var orin: NPC = npc("Orin")


func _area_ready() -> void:
	GameState.set_flag("entered_tower", true)
	# V2.2: reaching the tower means the crossing is behind Rowan (also true
	# for V1/V2 saves made inside the tower before the crossing existed).
	GameState.set_flag("crossing_complete", true)
	mechanism_sprite.frame = 1 if GameState.has_flag("pin_installed") else 0
	_build_vista()


func area_events() -> Dictionary:
	return {
		"install_pin": _install_pin,
		"bell_resonate": _resonate,
		"orin_appear": _orin_appear,
		"orin_look_bell": func() -> void: orin.set_facing("up"),
		"show_vista": _show_vista,
		"bell_ritual": _bell_ritual,
		"ending": _ending,
	}


func _process(delta: float) -> void:
	_pulse_t += delta
	bell_glow.energy = _glow_base + sin(_pulse_t * 1.3) * 0.22 * _glow_base


func _install_pin() -> Signal:
	AudioManager.play_sfx("clank", -2.0)
	camera().shake(2.0, 0.4)
	mechanism_sprite.frame = 1
	return get_tree().create_timer(0.7).timeout


func _resonate() -> Signal:
	AudioManager.play_sfx("bell_hum", -2.0)
	camera().shake(2.5, 1.0)
	bell_sprite.frame = 1
	var t := create_tween()
	t.tween_property(self, "_glow_base", 2.2, 0.4)
	t.tween_property(self, "_glow_base", 0.9, 1.0)
	t.tween_callback(func() -> void: bell_sprite.frame = 0)
	return t.finished


func _orin_appear() -> Signal:
	orin.modulate.a = 0.0
	GameState.set_flag("orin_appeared", true)
	AudioManager.play_sfx("orin_appear", -2.0)
	AudioManager.play_music("orin", 3.0)
	get_player().face_toward(orin.global_position)
	var t := create_tween()
	t.tween_property(orin, "modulate:a", 1.0, 2.0)
	return t.finished


# ----------------------------------------------------------------- vista --
## The village far below, seen through the tower window during the choice.
func _build_vista() -> void:
	_vista_layer = CanvasLayer.new()
	_vista_layer.layer = 12
	add_child(_vista_layer)
	_vista_root = Control.new()
	_vista_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vista_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vista_root.modulate.a = 0.0
	_vista_root.visible = false
	_vista_layer.add_child(_vista_root)
	var sky := TextureRect.new()
	sky.texture = load("res://assets/backgrounds/vista_night.png")
	_vista_root.add_child(sky)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for x in [62, 96, 130, 168, 205, 240, 276, 312]:
		var glow := TextureRect.new()
		glow.texture = load("res://assets/sprites/fx/light_radial.png")
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.size = Vector2(22, 22)
		glow.position = Vector2(x - 11, 206 - 11 + (x % 3) * 3)
		glow.material = add
		glow.modulate = Color(1.0, 0.7, 0.35, 0.8)
		_vista_root.add_child(glow)
	for i in 2:
		var mist := TextureRect.new()
		mist.name = "Mist%d" % i
		mist.texture = load("res://assets/backgrounds/mist_band_a.png" if i == 0 else "res://assets/backgrounds/mist_band_b.png")
		mist.position = Vector2(-20.0 * i, 236.0 - 24.0 * i)
		_vista_root.add_child(mist)
	var frame := TextureRect.new()
	frame.texture = load("res://assets/sprites/fx/vignette.png")
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vista_root.add_child(frame)


func _show_vista() -> Signal:
	_vista_root.visible = true
	AudioManager.play_sfx("wind_gust", -6.0)
	var t := create_tween()
	t.tween_property(_vista_root, "modulate:a", 1.0, 1.4)
	for i in 2:
		var mist := _vista_root.get_node("Mist%d" % i) as Control
		var mt := create_tween().set_loops()
		mt.tween_property(mist, "position:y", mist.position.y - 34.0, 6.0).set_trans(Tween.TRANS_SINE)
		mt.tween_property(mist, "position:y", mist.position.y - 26.0, 3.0).set_trans(Tween.TRANS_SINE)
	return t.finished


func _hide_vista(duration: float) -> void:
	if _vista_root.visible:
		var t := create_tween()
		t.tween_property(_vista_root, "modulate:a", 0.0, duration)


# ------------------------------------------------------------ the ritual --
## V2: before The Chorus, Rowan performs the retuning (scripts/ui/ritual_view.gd).
## Coroutine: the conversation waits, then checks `bell_retuned`.
func _bell_ritual() -> void:
	_hide_vista(0.5)
	get_player().face_toward(bell.global_position)
	_make_marks()
	var view: Control = UI.ritual_view
	view.connect("marks_changed", _light_marks)
	view.connect("note_sung", _on_ritual_note)
	view.connect("soured", _on_ritual_sour)
	var completed: bool = await UI.open_ritual()
	view.disconnect("marks_changed", _light_marks)
	view.disconnect("note_sung", _on_ritual_note)
	view.disconnect("soured", _on_ritual_sour)
	if completed:
		GameState.set_flag("bell_retuned", true)
	else:
		_light_marks(0)


func mark_position(i: int) -> Vector2:
	var a := -0.9 + i * (1.8 / 12.0)
	return BELL_SPRITE_OFFSET + Vector2(int(37.0 + sin(a) * 18.0), 30 + int(absf(a) * 3.0)) + Vector2(0.5, 0.5)


func _make_marks() -> void:
	if not _marks.is_empty():
		return
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 13:
		var s := Sprite2D.new()
		s.texture = preload("res://assets/sprites/fx/spark.png")
		s.material = add
		s.position = mark_position(i)
		s.modulate = Color(MARK_GOLD, 0.0)
		s.z_index = 3
		bell.add_child(s)
		_marks.append(s)


func lit_marks() -> int:
	return _marks.filter(func(s: Sprite2D) -> bool: return s.modulate.a > 0.5).size()


func _light_marks(count: int) -> void:
	for i in _marks.size():
		var target := 1.0 if i < count else 0.0
		if absf(_marks[i].modulate.a - target) > 0.01:
			create_tween().tween_property(_marks[i], "modulate:a", target, 0.18 if target > 0.5 else 0.4)


func _on_ritual_note(_index: int) -> void:
	var t := create_tween()
	t.tween_property(self, "_glow_base", 1.5, 0.08)
	t.tween_property(self, "_glow_base", 0.9, 0.5)


func _on_ritual_sour() -> void:
	camera().shake(1.5, 0.35)
	var t := create_tween()
	t.tween_property(bell_glow, "color", Color(0.75, 0.4, 0.55), 0.08)
	t.tween_property(bell_glow, "color", Color("#6ad0ff"), 0.6)


# --------------------------------------------------------------- endings --
func _ending(kind: String) -> void:
	GameState.lock_input("ending")
	_hide_vista(0.6)
	get_player().face_toward(bell.global_position)
	await get_tree().create_timer(0.7).timeout
	match kind:
		"keeper":
			AudioManager.stop_music(0.5)
			bell_sprite.frame = 1
			AudioManager.play_sfx("bell_toll", 2.0)
			SceneManager.flash(Color(1.0, 1.0, 1.0), 1.6, 0.95)
			camera().shake(6.0, 1.4)
			bell_glow.color = Color(1.0, 1.0, 1.0)
			create_tween().tween_property(self, "_glow_base", 4.0, 0.3)
			create_tween().tween_property(orin, "modulate:a", 0.0, 2.5)
		"promise":
			AudioManager.stop_music(0.5)
			AudioManager.play_sfx("bell_crack", 2.0)
			SceneManager.flash(Color(0.45, 0.55, 0.9), 1.0, 0.8)
			camera().shake(8.0, 1.6)
			var t := create_tween().set_parallel(true)
			t.tween_property(bell, "rotation_degrees", 5.0, 0.5).set_trans(Tween.TRANS_BOUNCE)
			t.tween_property(bell, "position:y", bell.position.y + 5.0, 0.5).set_trans(Tween.TRANS_BOUNCE)
			t.tween_property(self, "_glow_base", 0.0, 1.6)
			t.tween_property(orin, "modulate:a", 0.0, 2.5)
			($Effects/BellMotes as CPUParticles2D).emitting = false
		"chorus":
			AudioManager.play_music("ending_chorus", 1.5)
			AudioManager.play_sfx("bell_warm", 2.0)
			bell_sprite.frame = 2
			bell_glow.color = Color(1.0, 0.82, 0.45)
			SceneManager.flash(Color(1.0, 0.85, 0.5), 1.8, 0.85)
			camera().shake(3.0, 1.0)
			create_tween().tween_property(self, "_glow_base", 2.6, 1.2)
			($Effects/BellMotes as CPUParticles2D).color = Color(1.0, 0.85, 0.5)
			($Effects/BellMotes as CPUParticles2D).amount = 40
			create_tween().tween_property(orin, "modulate:a", 0.0, 3.0)
	await get_tree().create_timer(2.8).timeout
	UI.set_gameplay_hud(false)
	SceneManager.goto_scene(ENDING_SCENE, 1.4)
