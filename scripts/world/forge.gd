extends GameArea
## Mara's forge: the tuning pin on the workbench and Mara's hammering.

var _hammer_timer := 3.0
var _glint: Sprite2D
var _glint_t := 0.0
var _pin_light: PointLight2D

@onready var pin_sprite: Sprite2D = $Objects/TuningPin
@onready var sparks: CPUParticles2D = $Effects/AnvilSparks


func _area_ready() -> void:
	_make_pin_cues()
	_update_pin()
	GameState.flag_changed.connect(func(f: String, _v: Variant) -> void:
		if f in ["mara_showed_pin", "has_tuning_pin"]:
			_update_pin())


func area_events() -> Dictionary:
	return {
		"mara_hammer": _hammer,
		"mara_show_pin": _show_pin,
		"mara_give_pin": _give_pin,
	}


func _process(delta: float) -> void:
	if _glint.visible:
		# a small twinkle on the pin every couple of seconds
		_glint_t += delta
		var c := fposmod(_glint_t, 2.2)
		var a := clampf(1.0 - absf(c - 0.3) / 0.3, 0.0, 1.0)
		_glint.modulate.a = a
		_glint.scale = Vector2.ONE * (0.6 + 0.5 * a)
	# Mara keeps working while nobody is talking to her.
	if DialogueManager.is_active() or GameState.is_input_locked():
		return
	_hammer_timer -= delta
	if _hammer_timer <= 0.0:
		_hammer_timer = randf_range(2.5, 4.5)
		var mara := npc("Mara")
		if mara and mara.facing == Vector2.LEFT:
			sparks.restart()
			AudioManager.play_sfx("anvil", -14.0, 1.0, 0.08)


func _update_pin() -> void:
	var out := GameState.has_flag("mara_showed_pin") and not GameState.has_flag("has_tuning_pin")
	pin_sprite.visible = out
	_glint.visible = out
	_pin_light.enabled = out


## QA-07: the pin is small and dark on a bench far from the furnace. While it
## is the thing to look at, a little lamp-light pools on the bench and the pin
## catches it now and then. No markers, nothing that stays on afterwards.
func _make_pin_cues() -> void:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for i in 5:
		var a := 1.0 if i == 2 else 0.55
		img.set_pixel(2, i, Color(1, 1, 1, a))
		img.set_pixel(i, 2, Color(1, 1, 1, a))
	_glint = Sprite2D.new()
	_glint.name = "PinGlint"
	_glint.texture = ImageTexture.create_from_image(img)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glint.material = add
	_glint.modulate = Color(1.0, 0.92, 0.7, 0.0)
	_glint.position = pin_sprite.position + pin_sprite.offset + Vector2(4, -2)
	$Effects.add_child(_glint)
	_pin_light = PointLight2D.new()
	_pin_light.name = "BenchLight"
	_pin_light.texture = preload("res://assets/sprites/fx/light_radial.png")
	_pin_light.texture_scale = 0.4
	_pin_light.color = Color("#ffcf8a")
	_pin_light.energy = 0.75
	_pin_light.position = pin_sprite.position + pin_sprite.offset
	$Lights.add_child(_pin_light)


func _hammer() -> Signal:
	sparks.restart()
	AudioManager.play_sfx("anvil", -4.0)
	camera().shake(1.0, 0.2)
	return get_tree().create_timer(0.45).timeout


func _show_pin() -> Signal:
	pin_sprite.visible = true
	pin_sprite.modulate = Color(1, 1, 1, 0)
	_glint.visible = true
	_pin_light.enabled = true
	_glint_t = 0.0
	AudioManager.play_sfx("item", -6.0)
	var t := create_tween()
	t.tween_property(pin_sprite, "modulate:a", 1.0, 0.5)
	return t.finished


func _give_pin() -> Signal:
	AudioManager.play_sfx("item_get", -4.0)
	var t := create_tween()
	t.tween_property(pin_sprite, "modulate:a", 0.0, 0.4)
	t.tween_callback(func() -> void: pin_sprite.visible = false)
	return t.finished
