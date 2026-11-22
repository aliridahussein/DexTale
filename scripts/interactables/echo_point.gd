class_name EchoPoint
extends Area2D
## A place where "Listen to the Echo" (F) reveals a fragment of the past.
##
## On reveal: a ghostly image fades in, a whisper plays, the flag
## "echo_<echo_id>" is set (plus `sets_flag`) and `conversation_id` starts.
## Listening again replays the vision without changing any state twice.

signal revealed

@export var echo_id := ""
@export var conversation_id := ""
@export var replay_conversation_id := ""
@export var reveal_texture: Texture2D
@export var reveal_offset := Vector2(0, -24)
@export var reveal_tint := Color(0.62, 0.86, 1.0, 0.9)
@export var reveal_hold := 2.6
@export var sets_flag := ""
@export var requires := ""
@export var hidden_when := ""
@export var hint_offset := Vector2(0, -30)
@export var sound := "echo_whisper"

var _ghost: Sprite2D
var _busy := false


func _ready() -> void:
	collision_layer = 1 << 4  # "echo"
	collision_mask = 0
	monitoring = false
	monitorable = true
	_ghost = Sprite2D.new()
	_ghost.texture = reveal_texture
	_ghost.position = reveal_offset
	_ghost.modulate = Color(reveal_tint.r, reveal_tint.g, reveal_tint.b, 0.0)
	_ghost.z_index = 20
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ghost.material = mat
	add_child(_ghost)


func is_available() -> bool:
	if not GameState.check(requires):
		return false
	if hidden_when != "" and GameState.check(hidden_when):
		return false
	return true


func heard() -> bool:
	return GameState.has_flag("echo_" + echo_id)


## Small sparkle when Rowan listens nearby (even if this is not the target).
func shimmer() -> void:
	if _ghost.texture == null or _busy:
		return
	var t := create_tween()
	t.tween_property(_ghost, "modulate:a", 0.25, 0.25)
	t.tween_property(_ghost, "modulate:a", 0.0, 0.6)


func reveal(_by: Node = null) -> void:
	if _busy:
		return
	_busy = true
	var first_time := not heard()
	AudioManager.play_sfx(sound, -2.0)
	if _ghost.texture:
		var t := create_tween()
		t.tween_property(_ghost, "modulate:a", reveal_tint.a, 0.7)
		t.parallel().tween_property(_ghost, "position", reveal_offset + Vector2(0, -3), 2.2)
		t.tween_interval(reveal_hold)
		t.tween_property(_ghost, "modulate:a", 0.0, 1.2)
		t.tween_callback(func() -> void: _ghost.position = reveal_offset)
	GameState.set_flag("echo_" + echo_id, true)
	if sets_flag != "":
		GameState.set_flag(sets_flag, true)
	revealed.emit()
	var conv := conversation_id
	if not first_time and replay_conversation_id != "":
		conv = replay_conversation_id
	if conv != "":
		await get_tree().create_timer(0.6).timeout
		DialogueManager.start(conv, self)
		await DialogueManager.ended
	else:
		await get_tree().create_timer(reveal_hold).timeout
	_busy = false


func get_prompt_position() -> Vector2:
	return global_position + hint_offset
