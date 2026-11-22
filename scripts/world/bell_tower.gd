extends GameArea
## The bell chamber: the mechanism, Orin's echo, the view of the village and
## the three ending sequences (keeper / promise / chorus).

const ENDING_SCENE := "res://scenes/main/ending.tscn"

var _pulse_t := 0.0
var _glow_base := 0.9
var _vista_layer: CanvasLayer
var _vista_root: Control

@onready var bell: Node2D = $Objects/Bell
@onready var bell_sprite: Sprite2D = $Objects/Bell/Sprite
@onready var bell_glow: PointLight2D = $Lights/BellGlow
@onready var mechanism_sprite: Sprite2D = $Objects/Mechanism/Sprite
@onready var orin: NPC = npc("Orin")


func _area_ready() -> void:
	GameState.set_flag("entered_tower", true)
	mechanism_sprite.frame = 1 if GameState.has_flag("pin_installed") else 0
	_build_vista()


func area_events() -> Dictionary:
	return {
		"install_pin": _install_pin,
		"bell_resonate": _resonate,
		"orin_appear": _orin_appear,
		"orin_look_bell": func() -> void: orin.set_facing("up"),
		"show_vista": _show_vista,
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
