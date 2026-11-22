extends GameArea
## Mara's forge: the tuning pin on the workbench and Mara's hammering.

var _hammer_timer := 3.0

@onready var pin_sprite: Sprite2D = $Objects/TuningPin
@onready var sparks: CPUParticles2D = $Effects/AnvilSparks


func _area_ready() -> void:
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
	pin_sprite.visible = GameState.has_flag("mara_showed_pin") and not GameState.has_flag("has_tuning_pin")


func _hammer() -> Signal:
	sparks.restart()
	AudioManager.play_sfx("anvil", -4.0)
	camera().shake(1.0, 0.2)
	return get_tree().create_timer(0.45).timeout


func _show_pin() -> Signal:
	pin_sprite.visible = true
	pin_sprite.modulate = Color(1, 1, 1, 0)
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
