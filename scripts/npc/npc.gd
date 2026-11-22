class_name NPC
extends CharacterBody2D
## A talkable character. Turns to face Rowan, can wander, can be spectral.

signal arrived

@export var npc_id := ""
@export var sprite_frames: SpriteFrames
@export var conversation := ""
@export var talk_prompt := "Talk"
@export_enum("down", "up", "left", "right") var facing_name := "down"
@export var face_player := true
@export var return_to_facing := true
## Wander around the start position (0 = stand still).
@export var wander_radius := 0.0
@export var wander_speed := 22.0
## Ghostly look (Orin, the Sentinel).
@export var spectral := false
## Only present while this condition holds ("" = always).
@export var present_when := ""

var facing := Vector2.DOWN
var _home := Vector2.ZERO
var _target: Variant = null
var _pause := 0.0
var _blocked := 0.0
var _talking := false
var _walk_speed := 22.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var talk: Interactable = $Talk
@onready var body_shape: CollisionShape2D = $Collision


func _ready() -> void:
	add_to_group("npc")
	if sprite_frames:
		sprite.sprite_frames = sprite_frames
	talk.conversation_id = conversation
	talk.prompt = talk_prompt
	talk.interacted.connect(_on_talked)
	DialogueManager.ended.connect(_on_dialogue_ended)
	GameState.flag_changed.connect(_on_flag_changed)
	_home = global_position
	_walk_speed = wander_speed
	_pause = randf_range(0.5, 3.0)
	set_facing(facing_name)
	if sprite.sprite_frames:
		sprite.frame = randi() % maxi(1, sprite.sprite_frames.get_frame_count(sprite.animation))
	if spectral:
		_apply_spectral()
	_update_presence()


func _apply_spectral() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/spectral.gdshader")
	sprite.material = mat


func _on_flag_changed(_f: String, _v: Variant) -> void:
	_update_presence()


func _update_presence() -> void:
	var present := GameState.check(present_when)
	visible = present
	talk.enabled = present
	body_shape.set_deferred("disabled", not present)
	set_physics_process(present)


func _on_talked(by: Node) -> void:
	_talking = true
	_target = null
	velocity = Vector2.ZERO
	if face_player and by is Node2D:
		face_toward((by as Node2D).global_position)
	if by is Player:
		(by as Player).face_toward(global_position)


func _on_dialogue_ended(_id: String) -> void:
	if _talking:
		_talking = false
		if return_to_facing and wander_radius <= 0.0:
			set_facing(facing_name)


func _physics_process(delta: float) -> void:
	if _target != null:
		var to: Vector2 = (_target as Vector2) - global_position
		if to.length() < 1.5:
			_stop_walking()
		else:
			velocity = to.normalized() * _walk_speed
			_face_vector(velocity)
			_play("walk")
			var before := global_position
			move_and_slide()
			if global_position.distance_to(before) < 0.25 * _walk_speed * delta:
				_blocked += delta  # blocked: give up on this target soon
				if _blocked > 0.6:
					_stop_walking()
			else:
				_blocked = 0.0
		return
	if wander_radius > 0.0 and not _talking and not DialogueManager.is_active():
		_pause -= delta
		if _pause <= 0.0:
			_pause = randf_range(2.0, 5.0)
			var p := _home + Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius) * 0.6)
			walk_to(p, wander_speed)


func walk_to(pos: Vector2, speed: float = 30.0) -> Signal:
	_target = pos
	_walk_speed = speed
	_blocked = 0.0
	return arrived


func _stop_walking() -> void:
	_target = null
	velocity = Vector2.ZERO
	_blocked = 0.0
	_pause = randf_range(2.0, 5.0)
	_play("idle")
	arrived.emit()


func set_facing(dir_name: String) -> void:
	match dir_name:
		"up": facing = Vector2.UP
		"left": facing = Vector2.LEFT
		"right": facing = Vector2.RIGHT
		_: facing = Vector2.DOWN
	_play("idle")


func face_toward(world_pos: Vector2) -> void:
	_face_vector(world_pos - global_position)
	_play("idle")


func _face_vector(v: Vector2) -> void:
	if v.length() < 0.01:
		return
	facing = Vector2(signf(v.x), 0) if absf(v.x) > absf(v.y) else Vector2(0, signf(v.y))


func _dir_name() -> String:
	if facing.x < 0:
		return "left"
	if facing.x > 0:
		return "right"
	if facing.y < 0:
		return "up"
	return "down"


func _play(kind: String) -> void:
	if sprite.sprite_frames == null:
		return
	var anim := "%s_%s" % [kind, _dir_name()]
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle_down" if sprite.sprite_frames.has_animation("idle_down") else sprite.animation
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


## Fade the character in or out (used for ghosts).
func fade(to_alpha: float, duration: float = 1.0) -> Signal:
	var t := create_tween()
	t.tween_property(self, "modulate:a", to_alpha, duration)
	return t.finished
