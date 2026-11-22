class_name GameCamera
extends Camera2D
## Follows the player inside the area bounds; supports shake and cutscene pans.

var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_total := 0.0
var _pan_tween: Tween


## Clamp to the area. Rooms smaller than the screen are centred.
func set_bounds(rect: Rect2) -> void:
	var view := get_viewport_rect().size
	var l := rect.position.x
	var r := rect.end.x
	var t := rect.position.y
	var b := rect.end.y
	if rect.size.x < view.x:
		var cx := rect.get_center().x
		l = cx - view.x * 0.5
		r = cx + view.x * 0.5
	if rect.size.y < view.y:
		var cy := rect.get_center().y
		t = cy - view.y * 0.5
		b = cy + view.y * 0.5
	limit_left = int(floor(l))
	limit_right = int(ceil(r))
	limit_top = int(floor(t))
	limit_bottom = int(ceil(b))
	reset_physics_interpolation()


func shake(strength: float = 3.0, duration: float = 0.4) -> void:
	if not Settings.screen_shake:
		return
	_shake_strength = maxf(_shake_strength if _shake_time > 0.0 else 0.0, strength)
	_shake_time = maxf(_shake_time, duration)
	_shake_total = _shake_time


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		var k := clampf(_shake_time / maxf(_shake_total, 0.001), 0.0, 1.0)
		var s := roundf(_shake_strength * k)
		offset = Vector2(randf_range(-s, s), randf_range(-s, s)).round()
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO


## Smoothly look at a world position (the camera is a child of the player).
func pan_to(world_pos: Vector2, duration: float = 1.2) -> Signal:
	var parent := get_parent() as Node2D
	var local := world_pos - parent.global_position
	return _tween_position(local, duration)


func pan_reset(duration: float = 0.8) -> Signal:
	return _tween_position(Vector2.ZERO, duration)


func _tween_position(target: Vector2, duration: float) -> Signal:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _pan_tween.finished
