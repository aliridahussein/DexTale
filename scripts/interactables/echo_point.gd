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
var _backing: Sprite2D
var _busy := false
var _holding_ui := false


func _ready() -> void:
	collision_layer = 1 << 4  # "echo"
	collision_mask = 0
	monitoring = false
	monitorable = true
	# A soft dark halo behind the vision keeps pale, additive art readable on
	# bright or busy backgrounds (QA-11).
	_backing = Sprite2D.new()
	_backing.texture = preload("res://assets/sprites/fx/light_radial.png")
	_backing.position = reveal_offset
	_backing.modulate = Color(0.02, 0.02, 0.06, 0.0)
	_backing.z_index = 19
	if reveal_texture:
		var s := reveal_texture.get_size()
		_backing.scale = Vector2(s.x / 128.0 * 1.9, s.y / 128.0 * 2.6).max(Vector2(0.3, 0.3))
	add_child(_backing)
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
	_hold_ui(true)
	var vision: Tween = null
	if _ghost.texture:
		vision = create_tween()
		vision.tween_property(_ghost, "modulate:a", reveal_tint.a, 0.7)
		vision.parallel().tween_property(_backing, "modulate:a", 0.4, 0.7)
		vision.parallel().tween_property(_ghost, "position", reveal_offset + Vector2(0, -3), 2.2)
		vision.tween_interval(reveal_hold)
		vision.tween_property(_ghost, "modulate:a", 0.0, 1.2)
		vision.parallel().tween_property(_backing, "modulate:a", 0.0, 1.2)
		vision.tween_callback(func() -> void: _ghost.position = reveal_offset)
	GameState.set_flag("echo_" + echo_id, true)
	GameState.set_flag("used_echo", true)
	if sets_flag != "":
		GameState.set_flag(sets_flag, true)
	revealed.emit()
	var conv := conversation_id
	if not first_time and replay_conversation_id != "":
		conv = replay_conversation_id
	if conv != "":
		await get_tree().create_timer(0.6).timeout
		if DialogueManager.start(conv, self):
			await DialogueManager.ended
	else:
		await get_tree().create_timer(reveal_hold).timeout
	# Let the vision finish fading before prompts and journal toasts return.
	if vision != null and vision.is_valid() and vision.is_running():
		await vision.finished
	_hold_ui(false)
	_busy = false


func _hold_ui(on: bool) -> void:
	if on and not _holding_ui:
		UI.begin_reveal()
	elif not on and _holding_ui:
		UI.end_reveal()
	_holding_ui = on


## Leaving the area mid-vision must not leave the UI waiting forever.
func _exit_tree() -> void:
	_hold_ui(false)


func get_prompt_position() -> Vector2:
	return global_position + hint_offset
