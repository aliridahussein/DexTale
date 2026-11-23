extends GameArea
## The abandoned watchhouse beside the crossing (V2.2): the old lantern, the
## rope and the hook for the repair, the maintenance log, and, for those who
## look, the token on the window sill and a memory in the chair that faces it.


@onready var lantern_light: PointLight2D = $Lights/LanternLight


func _area_ready() -> void:
	_sync_lantern()
	GameState.flag_changed.connect(func(f: String, _v: Variant) -> void:
		if f == "found_lantern":
			_sync_lantern())


func area_events() -> Dictionary:
	return {"chair_memory": _chair_memory}


## The lantern's light leaves the desk with the lantern.
func _sync_lantern() -> void:
	var taken := GameState.has_flag("found_lantern")
	if taken and lantern_light.visible:
		var t := create_tween()
		t.tween_property(lantern_light, "energy", 0.0, 0.4)
		t.tween_callback(func() -> void: lantern_light.visible = false)
	elif not taken:
		lantern_light.visible = true
	var player := get_player()
	if player:
		player.refresh_light()


## A child at the window, the watchman in the chair. Two lines, then gone.
func _chair_memory() -> Signal:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var guard := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = preload("res://assets/sprites/characters/watchman.png")
	at.region = Rect2(0, 32, 24, 32)   # from behind, facing the window
	guard.texture = at
	guard.position = Vector2(112, 70)
	guard.material = add
	guard.modulate = Color(0.6, 0.85, 1.0, 0.0)
	guard.z_index = 8
	add_child(guard)
	var child := Sprite2D.new()
	child.texture = preload("res://assets/sprites/fx/echo_figure.png")
	child.scale = Vector2(0.6, 0.6)
	child.position = Vector2(136, 72)
	child.material = add
	child.modulate = Color(1.0, 0.88, 0.65, 0.0)
	child.z_index = 8
	add_child(child)
	var t := create_tween().set_parallel(true)
	t.tween_property(guard, "modulate:a", 0.75, 0.8)
	t.tween_property(child, "modulate:a", 0.75, 0.8)
	t.chain().tween_interval(3.2)
	t.chain().tween_property(guard, "modulate:a", 0.0, 1.0)
	t.tween_property(child, "modulate:a", 0.0, 1.0)
	t.chain().tween_callback(func() -> void:
		guard.queue_free()
		child.queue_free())
	return get_tree().create_timer(0.8).timeout
