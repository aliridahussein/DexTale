extends Node
## Scene changes with fades, spawn placement and autosave.
##
## Areas call `register_area(self)` from their _ready(). When the change was
## requested through `change_area`, the player is moved to the requested spawn.

signal area_ready(area: Node)

var transitioning := false
var current_area: Node = null

var _pending := false
var _pending_spawn := "default"
var _pending_position: Variant = null
var _layer: CanvasLayer
var _fade: ColorRect
var _flash: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_flash = _make_rect(Color(1, 1, 1, 1))
	_fade = _make_rect(Color(0.02, 0.016, 0.03, 1))


func _make_rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.modulate.a = 0.0
	_layer.add_child(r)
	return r


## Move to another area. `position` (Vector2) overrides the spawn when loading a save.
func change_area(area_id: String, spawn: String = "default", position: Variant = null) -> void:
	if transitioning:
		return
	if not GameState.AREAS.has(area_id):
		push_error("SceneManager: unknown area '%s'" % area_id)
		return
	transitioning = true
	GameState.lock_input("transition")
	await fade_out(0.4)
	_pending = true
	_pending_spawn = spawn
	_pending_position = position
	GameState.current_area = area_id
	GameState.current_spawn = spawn
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.AREAS[area_id])
	await area_ready
	await get_tree().process_frame
	await fade_in(0.5)
	GameState.unlock_input("transition")
	transitioning = false
	SaveManager.request_autosave()


## Non-area scenes (menu, prologue, ending).
func goto_scene(path: String, fade_time: float = 0.6) -> void:
	if transitioning:
		return
	transitioning = true
	await fade_out(fade_time)
	current_area = null
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	transitioning = false
	await fade_in(fade_time)


func register_area(area: Node) -> void:
	current_area = area
	var area_id: String = area.get("area_id")
	if not _pending:
		# Area launched directly from the editor (F6): adopt it as the current area.
		GameState.current_area = area_id
	var player: Node2D = area.call("get_player")
	if player and _pending:
		var pos: Vector2 = area.call("get_spawn_position", _pending_spawn)
		if _pending_position is Vector2:
			pos = _pending_position
		player.call("teleport", pos)
		player.call("face", area.call("get_spawn_facing", _pending_spawn))
	_pending = false
	_pending_position = null
	call_deferred("_emit_area_ready", area)


func _emit_area_ready(area: Node) -> void:
	area_ready.emit(area)


func fade_out(duration: float = 0.4) -> void:
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, duration)
	await t.finished


func fade_in(duration: float = 0.4) -> void:
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 0.0, duration)
	await t.finished


func fade_to(alpha: float, duration: float) -> Signal:
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", alpha, duration)
	return t.finished


func set_black(on: bool) -> void:
	_fade.modulate.a = 1.0 if on else 0.0


func flash(color: Color = Color.WHITE, duration: float = 0.6, strength: float = 0.85) -> void:
	_flash.color = color
	_flash.modulate.a = strength
	var t := create_tween()
	t.tween_property(_flash, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT)
